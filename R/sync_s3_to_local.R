#' Sync S3 objects to a local directory
#'
#' Downloads objects from an S3 prefix to a local directory using `aws s3 sync`.
#' Uses the same credential resolution as [connect_to_s3()]: local credentials
#' if available, otherwise short-lived vended credentials from the CORI
#' credential-vending endpoint.
#'
#' When vended credentials are used, they are temporarily injected as
#' environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
#' `AWS_SESSION_TOKEN`) for the duration of the sync, then restored.
#'
#' Requires the AWS CLI (`aws`) to be installed and on the PATH.
#'
#' @param bucket Character. S3 bucket name (without `s3://` prefix).
#' @param prefix Character. S3 key prefix within the bucket (e.g.,
#'   `"nbm_block-D25/state_abbr=NC/"`). Include trailing slash for directories.
#' @param local_path Character. Local directory path to sync to. Created if it
#'   does not exist.
#' @param region Character. AWS region for the bucket. Default: `"us-east-1"`.
#' @param vending_url Character. URL of the credential-vending endpoint. Only
#'   used when no local AWS credentials are configured. Defaults to the
#'   `"cori.data.vending_url"` option, then the `CORI_DATA_VENDING_URL`
#'   environment variable, then the deployed CORI endpoint.
#' @param extra_args Character vector. Additional arguments to pass to
#'   `aws s3 sync` (e.g., `c("--delete", "--quiet")`). Default: `character(0)`.
#'
#' @return Invisibly returns the exit status of the `aws s3 sync` command
#'   (0 on success). Throws an error if the sync fails.
#'
#' @examples
#' \dontrun{
#'   sync_s3_to_local(
#'     bucket = "cori.data.fcc",
#'     prefix = "nbm_block-D25/state_abbr=NC/",
#'     local_path = file.path(tempdir(), "nbm_block-D25", "state_abbr=NC")
#'   )
#' }
#'
#' @export
sync_s3_to_local <- function(bucket, prefix, local_path,
                             region = "us-east-1",
                             vending_url = default_vending_url(),
                             extra_args = character(0)) {

  if (!nzchar(Sys.which("aws"))) {
    stop("AWS CLI ('aws') not found on PATH. Install it from ",
         "https://aws.amazon.com/cli/", call. = FALSE)
  }

  if (!dir.exists(local_path)) {
    dir.create(local_path, recursive = TRUE, showWarnings = FALSE)
  }

  s3_uri <- sprintf("s3://%s/%s", bucket, prefix)

  old_key    <- Sys.getenv("AWS_ACCESS_KEY_ID", unset = NA)
  old_secret <- Sys.getenv("AWS_SECRET_ACCESS_KEY", unset = NA)
  old_token  <- Sys.getenv("AWS_SESSION_TOKEN", unset = NA)
  old_region <- Sys.getenv("AWS_DEFAULT_REGION", unset = NA)
  injected   <- FALSE

  restore_env <- function() {
    if (!injected) return()
    if (is.na(old_key))    Sys.unsetenv("AWS_ACCESS_KEY_ID")
    else                   Sys.setenv(AWS_ACCESS_KEY_ID = old_key)
    if (is.na(old_secret)) Sys.unsetenv("AWS_SECRET_ACCESS_KEY")
    else                   Sys.setenv(AWS_SECRET_ACCESS_KEY = old_secret)
    if (is.na(old_token))  Sys.unsetenv("AWS_SESSION_TOKEN")
    else                   Sys.setenv(AWS_SESSION_TOKEN = old_token)
    if (is.na(old_region)) Sys.unsetenv("AWS_DEFAULT_REGION")
    else                   Sys.setenv(AWS_DEFAULT_REGION = old_region)
  }
  on.exit(restore_env(), add = TRUE)

  if (!has_local_aws_credentials()) {
    if (is.null(vending_url) || !is.character(vending_url) || !nzchar(vending_url)) {
      stop("No local AWS credentials found and no 'vending_url' supplied. ",
           "Configure AWS credentials, or pass the credential-vending ",
           "endpoint URL.", call. = FALSE)
    }

    creds <- .fetch_vended_credentials(vending_url, bucket)

    Sys.setenv(
      AWS_ACCESS_KEY_ID     = creds$access_key_id,
      AWS_SECRET_ACCESS_KEY = creds$secret_access_key,
      AWS_SESSION_TOKEN     = creds$session_token,
      AWS_DEFAULT_REGION    = region
    )
    injected <- TRUE
  }

  args <- c("s3", "sync", s3_uri, local_path, extra_args)
  result <- system2("aws", args = args, stdout = TRUE, stderr = TRUE)

  status <- attr(result, "status")
  if (!is.null(status) && status != 0) {
    stop("aws s3 sync failed (exit ", status, "): ",
         paste(result, collapse = "\n"), call. = FALSE)
  }

  invisible(0L)
}
