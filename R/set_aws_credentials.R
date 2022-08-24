set_aws_credentials <- function(aws_access_key, aws_secret_access_key, install = TRUE){
  stopifnot(is.logical(install))

  if (install) {

    home <- Sys.getenv("HOME")
    renv <- file.path(home, ".Renviron")

    if (!file.exists(renv)){

      file.create(renv)

    } else {
      # Backup original .Renviron before doing anything else here.
      file.copy(renv, file.path(home, ".Renviron_backup"))

      tv <- readLines(renv)


      cat("Your original .Renviron will be backed up and stored in your R HOME directory if needed.")

      oldenv <- utils::read.table(renv, stringsAsFactors = FALSE)$V1
      newenv <- oldenv[!grepl("AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY", oldenv)]

      utils::write.table(newenv, renv, quote = FALSE, sep = "\n",
                         col.names = FALSE, row.names = FALSE
      )



    }

    userconcat <- sprintf("AWS_ACCESS_KEY_ID='%s'", aws_access_key)
    pwdconcat <- sprintf("AWS_SECRET_ACCESS_KEY='%s'", aws_secret_access_key)
    regionconcat <- "AWS_DEFAULT_REGION='us-east-1'"

    # Append API key to .Renviron file
    write(userconcat, renv, sep = "\n", append = TRUE)
    write(pwdconcat, renv, sep = "\n", append = TRUE)
    write(regionconcat, renv, sep = "\n", append = TRUE)

    # cat(crayon::green(cli::symbol$tick), 'Your Amazon credentials have been stored in your .Renviron and can be accessed by Sys.getenv("AWS_ACCESS_KEY_ID") and Sys.getenv("AWS_SECRET_ACCESS_KEY"). \nTo use now, restart R or run `readRenviron("~/.Renviron")`')
    return(invisible(c(aws_access_key, aws_secret_access_key)))

  } else {

    Sys.setenv(AWS_ACCESS_KEY_ID = aws_access_key)
    Sys.setenv(AWS_SECRET_ACCESS_KEY = aws_secret_access_key)

    # cat(crayon::green(cli::symbol$tick), "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY set for current session. To install your Amazon credentials for use in future sessions, run this function with `install = TRUE`.")
  }
}
