library(cori.db)
library(dplyr)
library(sf)

#' Function to load ZIP Code Population Weighted Centroids from S3 (or from local disk, if cached as .RDS)
#' https://catalog.data.gov/dataset/zip-code-population-weighted-centroids
#'
#' @param hud_year integer, year of data release
#'
#' @return return ZIP Code Population Weighted Centroids as sf data.frame object
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  zips <- zip_code_centroids(2024)
#' }
#'
zip_code_centroids <- function (hud_year = 2024) {

    ## TODO: implement hud_year (for now always gets the same release)

    # setup data dir
    data_dir <- paste0(here::here(), "/data")
    if (! dir.exists(data_dir)) dir.create(data_dir)

    # usethis::use_data_raw() # <= if we were committing local data to the package repo (version control)

    data_prefix <- "zip_codes"
    s3_bucket_name <- "cori.data.census"

    if (!file.exists(paste0(data_dir, "/", data_prefix, "/zip_code_centroids.rds"))) {

        data_s3_files <- (
            cori.db::list_s3_objects(bucket_name = s3_bucket_name) |> 
                dplyr::filter(grepl(data_prefix, `key`))
        )$key

        dir.create(paste0(data_dir, "/", data_prefix), recursive = TRUE, showWarnings = FALSE)

        data_files <- lapply(data_s3_files, function (s3_key_path) {
            cori.db::get_s3_object(s3_bucket_name, s3_key_path, data_dir)
        })
    }

    return(readRDS(file = paste0(data_dir, "/", data_prefix, "/zip_code_centroids.rds")))
}
