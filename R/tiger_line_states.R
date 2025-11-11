library(cori.db)
library(dplyr)
library(sf)

# source(paste0(here::here(), "/R/tigris_helper.R"))

#' Function to load Census State boundaries from S3 (or from local disk, if cached as .RDS)
#'
#' @param year character, year of data release; prefix with "cb_" for cartographic boundaries
#'
#' @return return Census State boundaries as sf data.frame object
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  states <- tiger_line_states("2024") # Returns full tiger line 2024 state boundary geomtry
#' }
#'
tiger_line_states <- function (year = "cb_2024") {

    # setup data dir
    data_dir <- paste0(here::here(), "/data")
    if (! dir.exists(data_dir)) dir.create(data_dir)

    # usethis::use_data_raw() # <= if we were committing local data to the package repo (version control)

    data_prefix <- "tiger/line/states"
    s3_bucket_name <- "cori.data.census"
      
    if (startsWith(as.character(year), "20")) {
      tiger_year <- paste0("tl_", as.character(year))
    } else if (startsWith(as.character(year), "tl_")) {
      tiger_year <- year
    } else if (startsWith(as.character(year), "cb_")) {
      tiger_year <- year
    } else {
      stop("tiger_line_states expects `year` argument as \"YYYY\", \"tl_YYYY\", or \"cb_YYYY\" (for cartographic boundaries)")
    }


    if (!file.exists(paste0(data_dir, "/states_", tiger_year, ".rds"))) {

        data_s3_files <- (
            cori.db::list_s3_objects(bucket_name = s3_bucket_name) |> 
                dplyr::filter(grepl(data_prefix, `key`)) |> 
                dplyr::filter(grepl(tiger_year, `key`))
        )$key

        dir.create(paste0(data_dir, "/", data_prefix), recursive = TRUE, showWarnings = FALSE)

        data_files <- lapply(data_s3_files, function (s3_key_path) {
            cori.db::get_s3_object(s3_bucket_name, s3_key_path, data_dir)
        })

        local_state_files <- list.files(paste0(data_dir, "/", data_prefix), full.names = TRUE)
        local_state_files_tiger_year <- local_state_files[grepl(tiger_year, local_state_files)]

        states <- lapply(local_state_files_tiger_year, load_tiger) |>
            dplyr::bind_rows()

        # usethis::use_data(states) # <= if we were committing local data to the package repo (version control)
        saveRDS(states, file = paste0(data_dir, "/states_", tiger_year, ".rds"))
    }

    return(readRDS(file = paste0(data_dir, "/states_", tiger_year, ".rds")))
}
