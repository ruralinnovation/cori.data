#' Get drive time polygons around points
#'
#' @param points A data.frame of point data
#' @param column_lon Column name of longitude column
#' @param column_lat Column name of latitude column
#' @param drivetime Length of drive time in minutes (e.g. 30 for 30 minutes)
#' @param res Resolution. Higher resolution yields more detailed polygons and takes more time.
#' @param max_attempt Maximum number of tries to retrueve polygons. Defaults to 10
#'
#' @return A spatial data frame with drive time polygons
#' @export
#' @import osrm
#' @import dplyr
#' @import sf
#'
get_drive_time_polygons <- function(points, column_lon, column_lat, drivetime, res = 30, max_attempt = 10){

  if (!requireNamespace("osrm")){
    stop("Package osrm required but not installed")
  }

  if (!requireNamespace("dplyr")){
    stop("Package dplyr required but not installed")
  }

  if(missing(column_lon)) stop('Which column name to use as `Longtitude`?')
  if(missing(column_lat)) stop('Which column name to use as `Latitude`?')
  if(missing(drivetime)) stop('Please enter the drive time')

  pg_drive_time = NULL
  i = 1
  attempt = 0


  while (i <= nrow(points)) {
    # Current progress
    cat(paste0("Progress: ", i, "/", nrow(points)))
    onepoint = NULL
    error_msg = "NO ERROR"

    # Base table
    onepoint_info = points[i, ] %>%
      dplyr::left_join(data.frame("driveTime" = drivetime), by = character())


    while(is.null(onepoint)) {
      # New attempt
      attempt = attempt + 1

      cat(paste0("\nAttempt: ", attempt, "\n"))
      tryCatch(onepoint <- osrm::osrmIsochrone(loc = c(as.numeric(points[i,column_lon]), as.numeric(points[i,column_lat])), breaks = drivetime,
                                               returnclass="sf", res = res) %>%
                 select(driveTime = max, .data$geometry),
               error = function(c) {
                 error_msg <<- conditionMessage(c)
                 return(error_msg)
               })

      if (!is.null(onepoint)) {
        if (nrow(onepoint) < length(drivetime)) {
          onepoint = NULL
        }
      }

      # Only attempt X times
      if (attempt >= max_attempt) {
        # If the output still has nothing in there...
        if (is.null(onepoint)) {
          onepoint = data.frame(`driveTime` = drivetime) %>%
            left_join(data.frame("geometry" = NA), by = character())
        }
        break # After some experimentation, I believe next sends you back to the beginning of the inner while loop. Break exits to the main
      }

    }

    # Join and bind to all df
    onepoint_all = onepoint_info %>% left_join(onepoint, by = 'driveTime')
    pg_drive_time = rbind(pg_drive_time, onepoint_all)
    i = i + 1
    attempt = 0
    cat("============\n")


  }

  # After all points
  pg_drive_time = sf::st_as_sf(pg_drive_time)
  return(pg_drive_time)
}





