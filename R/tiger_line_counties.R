library(cori.db)
library(dplyr)
library(sf)

# source(paste0(here::here(), "/R/tigris_helper.R"))

# setup data dir
data_dir <- paste0(here::here(), "/data")
if (! dir.exists(data_dir)) dir.create(data_dir)

#' Function to load Census County boundaries from S3 (or from local disk, if cached as .RDS)
#'
#' @param tiger_year integer, year of data release
#'
#' @return return Census County boundaries as "sf" "data.frame" object
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  counties <- tiger_line_counties(2024)
#' }
#'
tiger_line_counties <- function (tiger_year = 2024) {

    # usethis::use_data_raw() # <= if we were committing local data to the package repo (version control)

    data_prefix <- "tiger/line/counties"
    s3_bucket_name <- "cori.data.census"

    if (!file.exists(paste0(data_dir, "/counties_", tiger_year, ".rds"))) {

        data_s3_files <- (
            cori.db::list_s3_objects(bucket_name = s3_bucket_name) |> 
                dplyr::filter(grepl(data_prefix, `key`)) |> 
                dplyr::filter(grepl(tiger_year, `key`))
        )$key

        dir.create(paste0(data_dir, "/", data_prefix), recursive = TRUE, showWarnings = FALSE)

        data_files <- lapply(data_s3_files, function (s3_key_path) {
            cori.db::get_s3_object(s3_bucket_name, s3_key_path, paste0(data_dir, "/", data_prefix, "/", basename(s3_key_path)))
        })

        local_county_files <- list.files(paste0(data_dir, "/", data_prefix), full.names = TRUE)
        local_county_files_tiger_year <- local_county_files[grepl(tiger_year, local_county_files)]

        counties <- lapply(local_county_files_tiger_year, load_tiger) |>
            dplyr::bind_rows()

        # usethis::use_data(counties) # <= if we were committing local data to the package repo (version control)
        saveRDS(counties, file = paste0(data_dir, "/counties_", tiger_year, ".rds"))
    }

    return(readRDS(file = paste0(data_dir, "/counties_", tiger_year, ".rds")))
}
