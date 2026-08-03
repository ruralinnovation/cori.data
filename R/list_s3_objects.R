#' List every "keys" from a bucket
#'
#' @param bucket_name string, example "test-coridata""
#'
#' @return a data frame with a key and last_modified columns
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  s3_asset <- list_bucket("test-coridata")
#' }
#'

list_s3_objects <- function(bucket_name) {

  # convenience functions
  gimme_me_key <- function(x) x[["Key"]]
  gimme_me_last_modified <- function(x) x[["LastModified"]]

  s3 <- get_s3_client(bucket_name)

  n_page <- paws.storage::paginate(s3$list_objects_v2(Bucket = bucket_name))

  flatten_one_level <- unlist(n_page, recursive = FALSE)
  get_content <-  unlist(
    flatten_one_level[names(flatten_one_level) == "Contents"],
    recursive = FALSE, use.names = FALSE)

  df_temp <- data.frame(
    key = do.call(rbind, lapply(get_content, gimme_me_key)),
    last_modified = as.POSIXlt(do.call(rbind,
                                       lapply(get_content,
                                              gimme_me_last_modified)))
  )
  return(df_temp)
}
