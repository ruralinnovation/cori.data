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
#' conservative choice, since the vending path is the tracked and
#' bucket-scoped one.
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


# Internal: fetch short-lived, bucket-scoped credentials from the vending
# endpoint. Validates the response rather than letting a non-200 body flow
# into CREATE SECRET as NULLs, which would surface later as an opaque S3
# auth failure instead of a clear error here.
.fetch_vended_credentials <- function(vending_url, bucket) {
  resp <- httr::GET(vending_url, query = list(bucket = bucket))

  if (httr::http_error(resp)) {
    stop(sprintf(
      "Credential vending endpoint returned HTTP %s for bucket '%s': %s",
      httr::status_code(resp), bucket,
      httr::content(resp, "text", encoding = "UTF-8")
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
#' 2. Otherwise, short-lived credentials scoped to `bucket` are fetched from
#'    `vending_url` and installed directly as a static secret.
#'
#' `bucket` is only used for the vending path, where it scopes the issued
#' credentials; it is ignored when local credentials are present.
#'
#' @param bucket Character. S3 bucket to scope vended credentials to. Required
#'   when falling back to the vending endpoint.
#' @param region Character. AWS region for the S3 secret. Default: `"us-east-1"`.
#' @param vending_url Character. URL of the credential-vending endpoint. Only
#'   required when no local AWS credentials are configured. Default: `NULL`.
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
connect_to_s3 <- function(bucket, region = "us-east-1", vending_url = NULL) {
  con <- DBI::dbConnect(duckdb::duckdb())

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

  } else {
    # No local credentials -- fetch short-lived, bucket-scoped temporary
    # credentials from the vending endpoint instead. Fail loudly here if the
    # caller cannot reach it, rather than deep inside a later S3 read.
    if (missing(bucket) || !is.character(bucket) || !nzchar(bucket)) {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop("No local AWS credentials found; 'bucket' is required to request ",
           "vended credentials.", call. = FALSE)
    }
    if (is.null(vending_url) || !nzchar(vending_url)) {
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
