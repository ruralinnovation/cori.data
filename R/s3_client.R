# Internal: resolve the credential-vending endpoint URL. Precedence:
# the "cori.data.vending_url" option, then the CORI_DATA_VENDING_URL
# environment variable, then the deployed default. Callers can override
# per-call via the vending_url argument.
default_vending_url <- function() {
  url <- getOption("cori.data.vending_url")
  if (!is.null(url) && is.character(url) && nzchar(url)) return(url)

  url <- Sys.getenv("CORI_DATA_VENDING_URL")
  if (nzchar(url)) return(url)

  "https://data.ruralinnovation.us/credentials"
}


# Internal: build a paws.storage S3 client using the same credential
# resolution as connect_to_s3():
#
# 1. If has_local_aws_credentials() finds credentials in the environment or
#    ~/.aws/credentials, return a client on the caller's own identity via
#    paws's ambient provider chain.
# 2. Otherwise fetch short-lived vended credentials from the vending
#    endpoint and inject them as static credentials. Vended credentials are
#    read-only (across the allowlisted cori.data.* buckets), so operations
#    that write to S3 or make account-wide calls must pass
#    require_local = TRUE to fail here with a clear message instead of an
#    opaque AccessDenied later.
get_s3_client <- function(bucket = NULL, region = "us-east-1",
                          vending_url = default_vending_url(),
                          require_local = FALSE) {

  if (has_local_aws_credentials()) {
    return(paws.storage::s3(config = list(region = region)))
  }

  if (require_local) {
    stop("No local AWS credentials found. Vended credentials are read-only ",
         "(across the allowlisted cori.data.* buckets), so this operation ",
         "requires local AWS credentials. Run set_aws_credentials() or ",
         "configure the AWS CLI.", call. = FALSE)
  }

  if (is.null(bucket) || !is.character(bucket) || !nzchar(bucket)) {
    stop("No local AWS credentials found; a 'bucket' is required to request ",
         "vended credentials.", call. = FALSE)
  }

  if (is.null(vending_url) || !is.character(vending_url) || !nzchar(vending_url)) {
    stop("No local AWS credentials found and no 'vending_url' supplied. ",
         "Configure AWS credentials, or pass the credential-vending ",
         "endpoint URL.", call. = FALSE)
  }

  creds <- .fetch_vended_credentials(vending_url, bucket)

  paws.storage::s3(config = list(
    credentials = list(
      creds = list(
        access_key_id     = creds$access_key_id,
        secret_access_key = creds$secret_access_key,
        session_token     = creds$session_token
      )
    ),
    region = region
  ))
}


# from https://adv-r.hadley.nz/conditions.html
fail_with <- function(expr, value = NULL) {
  tryCatch(
    error = function(cnd) value,
    expr
  )
}
