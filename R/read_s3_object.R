#' read a text file (csv) in a s3 object in memory
#'
#'@details works only for content type
#'
#' @param bucket_name string, a bucket name
#' @param key string, object/file that you want to download
#' @param ... extra argument to pass on read.csv()
#'
#' @return return a data frame
#'
#' @export
#' @importFrom utils read.csv
#' 
#' @examples
#'
#' \dontrun{
#'  my_csv <- read_s3_object("test-coridata", "data-1715776270877.csv")
#' }
#'

read_s3_object <- function(bucket_name, key, ...) {

  # Build the client once and reuse it for the content-type check, so a
  # single read never vends credentials twice.
  s3 <- get_s3_client(bucket_name)

  if (! get_s3_content_type(bucket_name, key, s3 = s3) == "text/csv") {
    stop("read_s3_object has only be implemented for text/csv files")
  }

  body_raw <- s3$get_object(Bucket = bucket_name,
                            Key = key)$Body

  txt <- rawToChar(body_raw)

  temp_file <- tempfile()

  on.exit(unlink(temp_file), add = TRUE)
  write(txt, temp_file)
  read.csv(temp_file, ...)

}
