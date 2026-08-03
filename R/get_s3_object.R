#' Download an object that is hosted on S3
#'
#'@details If dir_path is not provided, the object will be saved in the current directory
#'
#' @param bucket_name string, a bucket name
#' @param key string, object/file that you want to download (e.g, county_data.csv)
#' @param dir_path string, a directory path to which you want the file to be downloaded ("~/Documents/my_proj/")
#' @param key_path string, path to your key in the s3 bucket (e.g., "raw/" if you want to retrieve `s3://[bucket_name]/raw/county_data.csv`)
#' @param create_local_directory logical, TRUE or FALSE to create a directory at dir_path if none exists (defaults to FALSE)
#' @param ... other arguments from paws's downloadfile
#'
#' @return return invisibly the path where the file has been downloaded
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  txt <- get_s3_object("test-coridata", "county_data.csv", "proj_data/", key_path = "raw/")
#'  txt
#' }
#'

get_s3_object <- function(bucket_name, key, dir_path, key_path = "", create_local_directory = FALSE, ...) {

  # Set download path as current directory if no dir_path given
  if (missing(dir_path)) {
    where_to_write <- file.path(getwd(), key)
  } else {
    # Ensures no duplicate slashes
    file_path_clean <- paste0(sub("/$", "", dir_path), "/", sub("^/", "", key))
    if (dir.exists(dir_path) || grepl("/$", dir_path)) {
      dir_path <- dir_path
      where_to_write <- file_path_clean
    } else {
      dir_path <- dirname(file_path_clean)
      where_to_write <- dir_path
    }

    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
    }
  }

  s3 <- get_s3_client(bucket_name)

  # Remove duplicate leading slashes
  s3_key_path <- paste0(sub("/$", "", key_path), "/", sub("^/", "", key))
  # Remove leading slashes
  s3_key_clean <- sub("^/", "", s3_key_path)

  if (!dir.exists(dir_path)) {
    if (create_local_directory) {
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    } else {
      stop(paste0("No directory at ", dir_path))
    }
  }

  s3$download_file(
    Bucket = bucket_name,
    Key = s3_key_clean,
    Filename = where_to_write,
    ...
  )

  message(sprintf("Downloaded '%s' to: %s", s3_key_clean, where_to_write))
  return(invisible(where_to_write))
}
