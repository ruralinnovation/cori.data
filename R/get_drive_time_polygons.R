#' Get drive time polygons around points
#'
#' @param lat Vector of latitudes
#' @param lon Vector of longitudes
#' @param drive_time Length of drive time in minutes (e.g. 30 for 30 minutes)
#' @param res Resolution. Higher resolution yields more detailed polygons and takes more time.
#'
#' @return A vector of drive time polygons
#' @export
#' @import osrm
#' @import dplyr
#' @import sf
#' @importFrom rlang .data
#'
get_drivetime_polygons <- function(lat, lon, drive_time, res = 30){

  stopifnot(is.numeric(drive_time))

  vdrivetime(as.numeric(lat), as.numeric(lon), drive_time, res)

}





