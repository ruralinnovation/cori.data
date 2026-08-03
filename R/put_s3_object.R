#' put a local file into an S3 bucket
#'
#' @param bucket_name string, S3 bucket name
#' @param s3_key_path string, intended path + name of the file within S3 bucket
#' @param file_path string, local path + name of the file that you want to upload
#' @param ... other arguments to paws's put_object()
#'
#' @return return invisibly the response from AWS
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  txt <- put_s3_object("test-coridata", "blabla.txt" ,"blabla.txt")
#' }
#'

put_s3_object <- function(bucket_name, s3_key_path, file_path, ...) {

  # Writes cannot use vended (read-only) credentials, so require local
  # credentials up front; the overwrite check below then also runs on the
  # caller's own identity.
  s3 <- get_s3_client(bucket_name, require_local = TRUE)

  if (! can_i_write_in_that_bucket(bucket_name)) {
    stop(sprintf("%s is not on the list of curated bucket", bucket_name))
  }

  key_is_present <- is_key_already_here(bucket_name, s3_key_path)

  if ((!key_is_present)
    # If the key/prefix includes "dev/" or "test/" skip overwrite check
    || grepl("^dev", s3_key_path) || grepl("^test", s3_key_path)
  ) {

    response <- s3$put_object(Body = file_path,
                              Bucket = bucket_name,
                              Key = s3_key_path,
                              ...)

    return(invisible(response))

  } else if (key_is_present) {
    stop(sprintf("%s already exists in %s", s3_key_path, bucket_name), call. = FALSE)
  }

  return(NULL)
}
