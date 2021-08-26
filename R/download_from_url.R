#' Download a file from a URL
#'
#' @param url URL to download from
#' @param file_name Name for the file
#' @param output_dir Directory for output. Defaults to current working directory
#'
#' @return The file path, to be passed on to other functions
#' @export
#'
#'
download_from_url <- function(url, file_name, output_dir = "."){

  filepath = paste(output_dir, file_name, sep = "/")

  # Download
  if(missing(url)) {
    url = "NULL"
  } else {
    utils::download.file(url, filepath)
  }

  if(!file.exists(filepath)) {
    stop(paste0("Download unsuccesful: No file available at ", filepath))
  }

  return(filepath)

}
