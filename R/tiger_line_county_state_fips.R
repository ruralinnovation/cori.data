library(dplyr)
library(sf)

#' Function to load data.frame that maps County FIPS codes to States
#'
#' @param tiger_year integer, year of data release
#'
#' @return return Census County & State FIPS codes as "data.frame" object
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  county_state_fips <- tiger_line_county_state_fips(2024)
#' }
#'
tiger_line_county_state_fips <- function (tiger_year = 2024) {

  states <- tiger_line_states(tiger_year)
  counties <- tiger_line_counties(tiger_year)
    
  county_state_fips <- lapply(states$STATEFP, function(state_fp) { 
    state <- states |> filter(STATEFP == state_fp)
    counties <- counties |> filter(STATEFP == state_fp)
    return(
      data.frame(
        county_name = counties$NAME, 
        state_name = state$NAME, 
        state_fips = state_fp, 
        geoid_co = paste0(state_fp, counties$COUNTYFP))
      )
  }) |> 
    dplyr::bind_rows() |>
    dplyr::arrange(`state_fips`)

  return(county_state_fips)
}

