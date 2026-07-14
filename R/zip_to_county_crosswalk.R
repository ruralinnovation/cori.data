#' Function to load the HUD USPS ZIP -> County crosswalk from S3 (or from local disk, if cached as .RDS)
#' https://www.huduser.gov/portal/datasets/usps_crosswalk.html
#'
#' Mirrors zip_code_centroids(): the source is stored under the shared
#' `zip_codes` prefix in the `cori.data.census` bucket and cached locally as
#' zip_to_county_crosswalk.rds. Each row is a ZIP -> county pair with USPS
#' preferred city/state and the HUD address-ratio columns (res/bus/oth/tot);
#' a single ZIP may map to multiple counties, disambiguated by `bus_ratio`.
#'
#' @param hud_year integer, year of data release
#'
#' @return HUD ZIP -> County crosswalk as a tibble
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  xwalk <- zip_to_county_crosswalk(2021)
#' }
#'
zip_to_county_crosswalk <- function (hud_year = 2021) {

    ## TODO: implement hud_year (for now always gets the same release)

    # setup data dir
    data_dir <- paste0(here::here(), "/data")
    if (! dir.exists(data_dir)) dir.create(data_dir)

    data_prefix <- "zip_codes"
    s3_bucket_name <- "cori.data.census"

    if (!file.exists(paste0(data_dir, "/", data_prefix, "/zip_to_county_crosswalk.rds"))) {

        s3_objects <- cori.db::list_s3_objects(bucket_name = s3_bucket_name)
        data_s3_files <- s3_objects$key[grepl(data_prefix, s3_objects$key)]

        dir.create(paste0(data_dir, "/", data_prefix), recursive = TRUE, showWarnings = FALSE)

        data_files <- lapply(data_s3_files, function (s3_key_path) {
            cori.db::get_s3_object(s3_bucket_name, s3_key_path, data_dir)
        })
    }

    return(readRDS(file = paste0(data_dir, "/", data_prefix, "/zip_to_county_crosswalk.rds")))
}
