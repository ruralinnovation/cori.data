#' Detect locally configured AWS credentials
#'
#' Checks the two places DuckDB's own `CHAIN 'env;config'` would look for
#' credentials: the `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` environment
#' variables, and `~/.aws/credentials`. Keeping the detection aligned with
#' the chain DuckDB actually uses means "already has credentials" means the
#' same thing to both.
#'
#' This deliberately does not detect credentials sourced from an EC2 instance
#' profile, an ECS task role, or an SSO session that only populated a cached
#' token (`~/.aws/sso/`). Callers in those environments fall through to the
#' vending path even though they could authenticate another way — the
#' conservative choice, since the vending path is the tracked, read-only one.
#'
#' @return Logical. `TRUE` if credentials are present in either standard
#'   location.
#'
#' @keywords internal
#' @export
has_local_aws_credentials <- function() {
  env_creds <- nzchar(Sys.getenv("AWS_ACCESS_KEY_ID")) &&
               nzchar(Sys.getenv("AWS_SECRET_ACCESS_KEY"))

  creds_file <- path.expand("~/.aws/credentials")
  file_creds <- file.exists(creds_file) && length(readLines(creds_file, warn = FALSE)) > 0

  env_creds || file_creds
}


# Internal: fetch short-lived, read-only credentials from the vending
# endpoint. Validates the response rather than letting a non-200 body flow
# into CREATE SECRET as NULLs, which would surface later as an opaque S3
# auth failure instead of a clear error here.
.fetch_vended_credentials <- function(vending_url, bucket) {
  resp <- httr::GET(vending_url, query = list(bucket = bucket))

  if (httr::http_error(resp)) {
    body <- httr::content(resp, "text", encoding = "UTF-8")

    if (grepl("Bucket not permitted", body, fixed = TRUE)) {
      stop(sprintf(
        paste0("Bucket '%s' is not available via the credential-vending ",
               "endpoint. Check the name, or use local AWS credentials if ",
               "it's a private/project bucket."),
        bucket
      ), call. = FALSE)
    }

    stop(sprintf(
      "Credential vending endpoint returned HTTP %s for bucket '%s': %s",
      httr::status_code(resp), bucket, body
    ), call. = FALSE)
  }

  creds <- httr::content(resp, "parsed")

  required <- c("access_key_id", "secret_access_key", "session_token")
  missing  <- required[!vapply(required, function(f) {
    is.character(creds[[f]]) && nzchar(creds[[f]])
  }, logical(1))]

  if (length(missing) > 0) {
    stop(sprintf(
      "Credential vending endpoint response is missing required field(s): %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }

  creds
}


#' Open a DuckDB connection configured for S3 access
#'
#' Creates a DuckDB connection with the `httpfs` and `aws` extensions loaded
#' and an S3 secret configured. This is the shared connection utility for
#' `cori.data.*` packages, so S3/DuckDB setup lives in one place instead of
#' being duplicated in each package's `read_*_from_s3()` function.
#'
#' Credentials are resolved in two ways, in order:
#'
#' 1. If [has_local_aws_credentials()] finds credentials in the environment
#'    or `~/.aws/credentials`, the connection uses the caller's own identity
#'    via `PROVIDER CREDENTIAL_CHAIN` — no network round-trip.
#' 2. Otherwise, short-lived read-only credentials for `bucket` are fetched
#'    from `vending_url` and installed directly as a static secret.
#'
#' `bucket` is only used for the vending path, where the endpoint requires
#' it; it is ignored when local credentials are present. Vended credentials
#' are read-only (across the allowlisted `cori.data.*` buckets), so writes
#' through this connection require local credentials -- pass
#' `require_local = TRUE` to fail fast with a clear message instead of
#' getting an opaque S3 access-denied error mid-query.
#'
#' @param bucket Character. S3 bucket to request vended credentials for.
#'   Required when falling back to the vending endpoint.
#' @param region Character. AWS region for the S3 secret. Default: `"us-east-1"`.
#' @param vending_url Character. URL of the credential-vending endpoint. Only
#'   used when no local AWS credentials are configured. Defaults to the
#'   `"cori.data.vending_url"` option, then the `CORI_DATA_VENDING_URL`
#'   environment variable, then the deployed CORI endpoint.
#' @param require_local Logical. If `TRUE`, error immediately when no local
#'   AWS credentials are configured instead of falling back to (read-only)
#'   vended credentials. Use this for connections that will write to S3.
#'   Default: `FALSE`.
#' @param dbdir Character. Path to a persistent DuckDB database file. Default
#'   `":memory:"` opens an in-memory instance, matching prior behavior. Pass
#'   a file path for callers that need the catalog/temp state to persist
#'   across a script run.
#'
#' @return An open `duckdb_connection`. The caller owns the connection and
#'   must disconnect it, e.g. `on.exit(DBI::dbDisconnect(con, shutdown = TRUE))`.
#'
#' @examples
#' \dontrun{
#'   con <- connect_to_s3("cori.data.bds")
#'   on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
#'   DBI::dbGetQuery(con, "SELECT * FROM read_parquet('s3://cori.data.bds/**/*.parquet')")
#' }
#'
#' @export
connect_to_s3 <- function(bucket, region = "us-east-1",
                          vending_url = default_vending_url(),
                          require_local = FALSE,
                          dbdir = ":memory:") {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = dbdir)

  DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
  DBI::dbExecute(con, "INSTALL aws;   LOAD aws;")
  DBI::dbExecute(con, "SET http_timeout = 300;")

  if (has_local_aws_credentials()) {
    # Caller already has AWS credentials configured (env vars or
    # ~/.aws/credentials) -- use their own identity via the standard chain,
    # no round-trip to the vending endpoint needed.
    DBI::dbExecute(con, sprintf("CREATE OR REPLACE SECRET s3_secret (
      TYPE S3,
      PROVIDER CREDENTIAL_CHAIN,
      CHAIN 'env;config',
      REGION '%s',
      URL_STYLE 'path'
    );", region))

  } else if (require_local) {
    DBI::dbDisconnect(con, shutdown = TRUE)
    stop("No local AWS credentials found. Vended credentials are read-only ",
         "(across the allowlisted cori.data.* buckets), so this operation ",
         "requires local AWS credentials. Run set_aws_credentials() or ",
         "configure the AWS CLI.", call. = FALSE)

  } else {
    # No local credentials -- fetch short-lived, read-only temporary
    # credentials from the vending endpoint instead. Fail loudly here if the
    # caller cannot reach it, rather than deep inside a later S3 read.
    if (missing(bucket) || !is.character(bucket) || !nzchar(bucket)) {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop("No local AWS credentials found; 'bucket' is required to request ",
           "vended credentials.", call. = FALSE)
    }
    if (is.null(vending_url) || !is.character(vending_url) || !nzchar(vending_url)) {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop("No local AWS credentials found and no 'vending_url' supplied. ",
           "Configure AWS credentials, or pass the credential-vending ",
           "endpoint URL.", call. = FALSE)
    }

    creds <- tryCatch(
      .fetch_vended_credentials(vending_url, bucket),
      error = function(e) {
        DBI::dbDisconnect(con, shutdown = TRUE)
        stop(conditionMessage(e), call. = FALSE)
      }
    )

    DBI::dbExecute(con, sprintf("CREATE OR REPLACE SECRET s3_secret (
      TYPE S3,
      KEY_ID '%s',
      SECRET '%s',
      SESSION_TOKEN '%s',
      REGION '%s',
      URL_STYLE 'path'
    );", creds$access_key_id, creds$secret_access_key, creds$session_token, region))
  }

  con
}
