drivetime <- function(lat, lon, drivetime, res){

  tryCatch({
    dt_sf <- osrm::osrmIsochrone(loc = c(lon, lat), breaks = drivetime,
                                 returnclass="sf", res = res)

    geom <- dplyr::pull(dplyr::select(dt_sf, .data$geometry))

    return(geom)
  }, error = function(err) NA
  )

}

vdrivetime <- Vectorize(drivetime, vectorize.args = c('lat', 'lon'), SIMPLIFY = TRUE)
