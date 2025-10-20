library(cori.db)
library(dplyr)
library(sf)

#' County Population Centers
#'
#' This function downloads the 2020 U.S. county population center data from the
#' Census Bureau, constructs a combined GEOID, and returns a table with
#' `geoid`, `lon`, and `lat`.
#'
#' @param year integer, year of data release
#'
#' @return A `data.table` containing:
#'   - `geoid`: concatenated state and county FIPS code
#'   - `lon`: longitude of county population center
#'   - `lat`: latitude of county population center
#'
#' @importFrom data.table fread
#' @importFrom dplyr mutate select
#' @importFrom stringr str_pad
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  county_pop_centers <- county_pop_centroids(2020)
#'  head(county_centers)
#' }
#'
county_pop_centroids <- function (year = 2020) {

    ## TODO: implement hud_year (for now always gets the same release)

    # setup data dir
    data_dir <- paste0(here::here(), "/data")
    if (! dir.exists(data_dir)) dir.create(data_dir)

    # usethis::use_data_raw() # <= if we were committing local data to the package repo (version control)

    data_prefix <- "cenpop2020/county"
    s3_bucket_name <- "cori.data.census"

    raw_file <- paste0(data_dir, "/", data_prefix, "/county_pop_centroids.rds")

    if (!file.exists(raw_file)) {

        data_s3_files <- (
            cori.db::list_s3_objects(bucket_name = s3_bucket_name) |> 
                dplyr::filter(grepl(data_prefix, `key`))
        )$key

        dir.create(paste0(data_dir, "/", data_prefix), recursive = TRUE, showWarnings = FALSE)

        data_files <- lapply(data_s3_files, function (s3_key_path) {
            cori.db::get_s3_object(s3_bucket_name, s3_key_path, data_dir)
        })
    }

    raw_dt <- readRDS(file = raw_file)
    
    # Process data: construct GEOID and select relevant columns
    processed_dt <- raw_dt |>
      dplyr::mutate(
        geoid = paste0(
          stringr::str_pad(STATEFP, 2, 'left', '0'),
          stringr::str_pad(COUNTYFP, 3, 'left', '0')
        )
      ) |>
      dplyr::select(
        geoid,
        lon = LONGITUDE,
        lat = LATITUDE
      )

    return(processed_dt)
}
