#' put files from a local directory into an S3 bucket
#'
#' @param bucket_name string, a bucket name
#' @param s3_key_prefix string, name of the prefix (directory path) used within the S3 bucket
#' @param  dir_path string, local directory path containing the files that you want to upload
#' @param ... other arguments to paws's put_object()
#'
#' @return return invisibly the response from AWS
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  txt <- put_s3_objects_recursive("test-coridata", "test/blabla.txt" ,"test")
#' }
#'

put_s3_objects_recursive <- function(bucket_name, s3_key_prefix, dir_path, ...) {

  # This function shells out to the AWS CLI, which reads the same
  # env-var/credentials-file chain checked here. Writes cannot use vended
  # (read-only) credentials, so local credentials are required.
  if (! has_local_aws_credentials()) {
    stop("No local AWS credentials found. Vended credentials are read-only ",
         "(across the allowlisted cori.data.* buckets), so this operation ",
         "requires local AWS credentials. Run set_aws_credentials() or ",
         "configure the AWS CLI.", call. = FALSE)
  }

  if (! can_i_write_in_that_bucket(bucket_name)) {
    stop(sprintf("%s is not on the list of curated bucket", bucket_name))
  }

  prefix_is_present <- is_prefix_already_present(bucket_name, s3_key_prefix)

  if ((!prefix_is_present)
    # If the key/prefix includes "dev/" or "test/" skip overwrite check
    || grepl("^dev", s3_key_prefix) || grepl("^test", s3_key_prefix)
  ) {

    message(paste0("aws s3 cp --recursive ", dir_path, " s3://", bucket_name, "/", s3_key_prefix))

    base::system2("aws", args = c("s3", "cp", "--recursive", dir_path, paste0("s3://", bucket_name, "/", s3_key_prefix)))

  } else if (prefix_is_present) {
    stop(sprintf("%s already exists in %s", s3_key_prefix, bucket_name), call. = FALSE)
  }

  return(NULL)
}
