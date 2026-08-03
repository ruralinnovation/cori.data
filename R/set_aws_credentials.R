#' Install aws credentials in your .Renviron file and
#' load credentials into the current environment.
#' This actions will overwrite any values currently
#' stored in AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.
#'
#' @param keyID A valid Key ID
#' @param secretAccessKey A valid Access key
#' @param region A valid AWS region (default set )
#' @param install If TRUE, save credentials to .Renviron. Otherwise, set per session.
#'
#' @return keyID, secretAccessKey and region, invisibly
#' @export
#'
#' @importFrom crayon green
#' @importFrom crayon red
#' @importFrom cli symbol
#'
#' @examples
#'
#' \dontrun{
#' # Initilialize S3 credentials (this only needs to be done once for a given project)
#' cori.data::set_aws_credentials(keyID = "###", secretAccessKey = "###")
#'
#' # Open a duckdb connection configured for S3 access using the credentials
#' # just installed
#' con <- connect_to_s3("cori.data.bds")
#' }
#'

#### TODO: This conflicts with the way duckdb (and all other AWS SDKs/utils) use credentials... will update
set_aws_credentials <- function(keyID, secretAccessKey,
                                region = "us-east-1",
                                install = TRUE) {
  stopifnot(is.logical(install))

  if (install) {

    home <- Sys.getenv("HOME")

    renviron <- file.path(home, ".Renviron")
    #### TODO: This is wrong...
    ####  we should store credentials in the way that AWS recommends (using the aws cli) :
    ####  https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html#cli-authentication-user-configure-wizard
    ####  ... minus the bit about the uber-complex configuration of SSO in AWS IAM Identity Center (later)

    #### ... instead check for the standard aws "credentials" file
    credentials <- file.path(paste0(home, "/.aws"), "credentials")

    if (!file.exists(credentials)){

      file.create(credentials)

    } else {

      tv <- readLines(credentials)

      if(any(grepl("AWS_ACCESS_KEY_ID", tv))) {

        ans <- utils::menu(c(paste(crayon::green(cli::symbol$tick), "Yes"),
                             paste(crayon::red(cli::symbol$cross), "No")),
                           title = paste("An AWS_ACCESS_KEY_ID",
                                         "already exists.",
                                         "Do you want to overwrite it?"))

        if (ans == 1) {

          cat("Your original aws credentials will be backed up and stored in the .aws of your HOME directory.")

          file.copy(credentials, paste0(credentials, ".bak"), overwrite = TRUE)

        } else {

          cat(crayon::red(cli::symbol$cross), "Your AWS_ACCESS_KEY_ID was not updated.")

          return(NULL)

        }
      }

    }

    Sys.setenv(AWS_ACCESS_KEY_ID = keyID)
    Sys.setenv(AWS_SECRET_ACCESS_KEY = secretAccessKey)

    # Append API key to .Renviron file
    userconcat <- sprintf("AWS_ACCESS_KEY_ID='%s'", keyID)
    pwdconcat <- sprintf("AWS_SECRET_ACCESS_KEY='%s'", secretAccessKey)
    regionconcat <- sprintf("AWS_DEFAULT_REGION='%s'", region)
    write(userconcat, renviron, sep = "\n", append = TRUE)
    write(pwdconcat, renviron, sep = "\n", append = TRUE)
    write(regionconcat, renviron, sep = "\n", append = TRUE)

    cat(crayon::green(cli::symbol$tick),
        paste("Your AWS key ID  and secret key",
              "have been stored in your .Renviron",
              'and can be accessed by Sys.getenv("AWS_ACCESS_KEY_ID")',
              'and Sys.getenv("AWS_SECRET_ACCESS_KEY").',
              '\nTo use now, restart R or run `readRenviron("~/.Renviron")`'))

    base::system2("aws", args = "configure", input = c(
      keyID,
      secretAccessKey,
      region,
      "json"
    ))

    return(invisible(c(keyID, secretAccessKey)))

  } else {

    Sys.setenv(AWS_ACCESS_KEY_ID = keyID)
    Sys.setenv(AWS_SECRET_ACCESS_KEY = secretAccessKey)

    cat(crayon::green(cli::symbol$tick),
        paste("AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY",
              "set for current session.",
              "To install your key ID and secret key",
              "for use in future sessions,",
              " run this function with `install = TRUE`."))
  }
}