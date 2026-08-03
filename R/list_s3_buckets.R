#' Listing s3 bucket CORI draft
#'
#' @return a data frame with four columns: bucket_name, creation_date, group, owner (TODO: add lifecycle)
#'
#' @export
#'
list_s3_buckets <- function() {

  # list_buckets/get_bucket_tagging are account-wide calls that vended
  # (read-only) credentials cannot make, so local credentials are required.
  s3 <- get_s3_client(require_local = TRUE)
  list_s3  <- s3$list_buckets()
  bucket <- list_s3[["Buckets"]]
  s3_dat <- data.frame(bucket_name = sapply(bucket,
                                            function(x) x[["Name"]]),
                       creation_date = as.POSIXlt(
                            sapply(bucket,
                                   function(x) x[["CreationDate"]]
                                   )))

  get_me_tags <- function(key) {
    force(key)
    function(x) {
      fail_list <- list(TagSet = list(list(Key = key,
                                           Value = "Missing Value")))

      l <- fail_with(get_s3_tags(x, s3 = s3), fail_list)

      get_key <- function(x) x$Key
      get_value <- function(x) x$Value

      df <- data.frame(
        key = vapply(l$TagSet, function(x) x[["Key"]],
                     FUN.VALUE =  character(1)),
        value = vapply(l$TagSet, function(x) x[["Value"]],
                      FUN.VALUE = character(1))
      )

      ifelse(length(df$value[df$key == key]) == 0, "Missing Value",
             df$value[df$key == key])
    }
  }

  get_me_group <- get_me_tags("group")
  get_me_owner <- get_me_tags("owner")

  s3_dat$group <- vapply(s3_dat$bucket_name,
                         get_me_group,
                         FUN.VALUE = character(1))

  s3_dat$owner <- vapply(s3_dat$bucket_name,
                         get_me_owner,
                         FUN.VALUE = character(1))

  return(s3_dat)
}
