library(cori.db)
library(dplyr)
library(sf)

# source(paste0(here::here(), "/R/tigris_helper.R"))

#' Function to load Census Place boundaries from S3 (or from local disk, if cached as .RDS)
#'
#' @param tiger_year integer, year of data release
#'
#' @return return Census Place boundaries as sf data.frame
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  places <- tiger_line_places(2024)
#' }
#'
tiger_line_places <- function (tiger_year = 2024) {

    # setup data dir
    data_dir <- paste0(here::here(), "/data")
    if (! dir.exists(data_dir)) dir.create(data_dir)

    # usethis::use_data_raw() # <= if we were committing local data to the package repo (version control)

    data_prefix <- "tiger/line/places"
    s3_bucket_name <- "cori.data.census"

    if (!file.exists(paste0(data_dir, "/places_", tiger_year, ".rds"))) {

        data_s3_files <- (
            cori.db::list_s3_objects(bucket_name = s3_bucket_name) |> 
                dplyr::filter(grepl(data_prefix, `key`)) |> 
                dplyr::filter(grepl(tiger_year, `key`))
        )$key

        dir.create(paste0(data_dir, "/", data_prefix), recursive = TRUE, showWarnings = FALSE)

        data_files <- lapply(data_s3_files, function (s3_key_path) {
            cori.db::get_s3_object(s3_bucket_name, s3_key_path, data_dir)
        })

        local_place_files <- list.files(paste0(data_dir, "/", data_prefix), full.names = TRUE)
        local_place_files_tiger_year <- local_place_files[grepl(tiger_year, local_place_files)]

        places <- lapply(local_place_files_tiger_year, load_tiger) |>
            dplyr::bind_rows()

        # usethis::use_data(places) # <= if we were committing local data to the package repo (version control)
        saveRDS(places, file = paste0(data_dir, "/places_", tiger_year, ".rds"))
    }

    return(readRDS(file = paste0(data_dir, "/places_", tiger_year, ".rds")))
}
