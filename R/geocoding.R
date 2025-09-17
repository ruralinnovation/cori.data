library(dplyr)

# Function to get Census Place centroid
get_census_place_centroid <- function(location, places, states) {

  # Parse location into city and state
  parts <- strsplit(location, ", ")[[1]]
  if (length(parts) == 2) {
    city <- parts[1]
    state_abbr <- parts[2]

    if (!stringr::str_detect(state_abbr,  paste(states$STUSPS, collapse = "|", sep="|"))) {
      # Not in the US
      return(NULL)
    } else {
      message(city)
      message(state_abbr)
    }

    if (!is.na(city) || city != "") {

      state_fips <- (states |> dplyr::filter(STUSPS == state_abbr))[1,]$STATEFP

      message(paste0("state_fips: ", state_fips))
    
      # Use a pre-loaded or dynamically fetched Census Places dataset
      # This is a placeholder - you'd need to implement the actual lookup
      place_centroid <- places |>
        dplyr::filter(
          stringr::str_detect(tolower(`NAMELSAD`), tolower(city)),
          STATEFP == state_fips
        ) |>
        dplyr::select(`INTPTLON`, `INTPTLAT`) |>
        dplyr::slice(1)  # Take first match if multiple exist

      # print(list(
      #   long = as.numeric(place_centroid$INTPTLON), 
      #   lat = as.numeric(place_centroid$INTPTLAT),
      #   crs = sf::st_crs(place_centroid$geometry)
      # ))
      
      if (nrow(place_centroid) > 0) {
        return(list(
          long = as.numeric(place_centroid$INTPTLON), 
          lat = as.numeric(place_centroid$INTPTLAT),
          crs = sf::st_crs(place_centroid$geometry)
        ))
      }
    }

  }
  return(NULL)
}

# Function to get ZIP code centroid
get_zipcode_centroid <- function(zipcode, zips) {

  message(paste0("zipcode: ", zipcode))

  # Use a pre-loaded or dynamically fetched ZIP code centroids dataset
  # This is a placeholder - you'd need to implement the actual lookup
  zipcode_centroid <- zips |>
    dplyr::filter(STD_ZIP5 == zipcode) |>
    dplyr::select(LON, LAT) |>
    dplyr::slice(1)

  # print(list(
  #   long = as.numeric(zipcode_centroid$LON), 
  #   lat = as.numeric(zipcode_centroid$LAT),
  #   crs = sf::st_crs(zipcode_centroid$geometry)
  # ))
  
  if (nrow(zipcode_centroid) > 0) {
    return(list(
      long = as.numeric(zipcode_centroid$LON), 
      lat = as.numeric(zipcode_centroid$LAT),
      crs = sf::st_crs(zipcode_centroid$geometry)
    ))
  }
  return(NULL)
}

#' Function to get place or ZIP code centroids given a data.frame with either `location` or `postal_code`
#'
#' @param dta_loc_or_postal data.frame, which includes either a 
#' `location` attributes of the form "City(Town), ST" or a 
#' `postal_code` atttribute with a 5-digit ZIP code value
#'
#' @return return data.frame with county geoid and point geometry based on Census place or ZIP code centroid
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'  dta_loc_or_postal <- data.frame(
#'    rank = c(1),
#'    link =  c("Conduit Coders 5/6 profile"),
#'    name = c("Conduit Coders 5/6"),
#'    location = c("Ada, OK"),
#'    score = c(79))
#' 
#'  dta_centroid_and_geoid_co <- map_locations_to_counties(dta_loc_or_postal)
#' }
#'
map_locations_to_counties <- function (dta_loc_or_postal) {

  places <- cori.data::tiger_line_places(2024)
  counties <- cori.data::tiger_line_counties(2024)
  states <- cori.data::tiger_line_states(2024)
  zips <- cori.data::zip_code_centroids()

  message("Geocoding to (postal code) or (city/town, state)...")

  # Populate long/lat for missing records
  missing_long_lat <- dta_loc_or_postal |>
    dplyr::rowwise() |>
    dplyr::mutate(
      centroid = if (!is.na(postal_code) && postal_code != "") { # <= 5-digit US ZIP code
        # Step 1: Try ZIP code geocoding
        cen_long_lat_geom <- get_zipcode_centroid(postal_code, zips)
        if (is.null(cen_long_lat_geom) && !is.na(`location`)) {
          # Step 2: If ZIP code fails, try Census Place geocoding
          cen_long_lat_geom <- get_census_place_centroid(`location`, places, states)
        }
        list(cen_long_lat_geom)
      } else if (!is.na(`location`)) { # <= expect 'location' attribute with "City, ST" format
        # Step 2: Try Census Place geocoding
        cen_long_lat_geom <- get_census_place_centroid(`location`, places, states)
        list(cen_long_lat_geom)
      } else {
        list(NULL)
      }
    ) |>
    dplyr::ungroup()

  missing_long_lat$long <- unlist(lapply(missing_long_lat$centroid, function(centroid) {
    # print(is.null(centroid))
    ifelse(is.null(centroid), NA, as.numeric(unlist(centroid)[1]))
  }))

  missing_long_lat$lat <- unlist(lapply(missing_long_lat$centroid, function(centroid) {
    # print(is.null(centroid))
    ifelse(is.null(centroid), NA, as.numeric(unlist(centroid)[2]))
  }))

  missing_long_lat$crs <-
    lapply(missing_long_lat$centroid, function(centroid) {
      # print(centroid[[3]])
      ifelse(is.null(centroid), NA, centroid$crs)
    })
  
  # Convert to sf data frame (if necessary)
  dta_loc_or_postal_sf <- missing_long_lat |>
    dplyr::filter(!is.na(`long`), !is.na(`lat`)) |>
    as.data.frame() |>
    sf::st_as_sf(
      coords = c("long", "lat"),
      crs = sf::st_crs(missing_long_lat$crs),
      remove = FALSE
    )|> 
    dplyr::mutate(
      geometry = sf::st_sfc(
        geometry,
        crs = sf::st_crs("+proj=longlat +datum=WGS84")
      )
    ) |>
    dplyr::select(!crs)
  
  # Find points within polygons
  final_geocoded_sf_w_co <- sf::st_join(
    dta_loc_or_postal_sf |> 
      dplyr::mutate(geometry = sf::st_transform(geometry, sf::st_crs("+proj=longlat +datum=WGS84"))), 
    counties |> 
      dplyr::mutate(geometry = sf::st_transform(geometry, sf::st_crs("+proj=longlat +datum=WGS84"))), 
    join = sf::st_within
  ) |>
    dplyr::mutate(
      county_fips = `COUNTYFP`,
      state_fips = `STATEFP`,
      county_name = `NAME`,
      state_abbr = states$STUSPS[match(state_fips, states$STATEFP)],
      geoid_co = GEOID
    ) |>
    dplyr::select(
      # Drop most of the county attributes
      !(names(counties))
    ) |>
    dplyr::select( 
      # <= Drop centroid list value to avoid: "list columns are only allowed with raw vector contents"
      !centroid
    )
  
    return(final_geocoded_sf_w_co)

}

# Function to geocode missing records
geocode_missing_records <- function (dta_id = "company_id", dta_all, out_tidygeocoder, places, states, zip_code_centroids) {
 
  # TODO: Just copied from pitchbook data repo, needs revision (see changes above) ...

  # Identify records not in tidygeocoder output (only US companies)
  missing_records <- (if (dta_id == "cisco_id") {

    dta_all |>
      dplyr::filter(!(`cisco_id` %in% out_tidygeocoder$cisco_id))
    
  } else if (dta_id == "company_id") {

    dta_all |>
      dplyr::filter(!(`company_id` %in% out_tidygeocoder$company_id))
    
  } else if (dta_id == "investor_id") {

    dta_all |>
      dplyr::filter(!(`investor_id` %in% out_tidygeocoder$investor_id))
    
  })

  # return(missing_records)
  
  # Prepare a data frame for missing geocoded records
  out_tidygeocoder_missing <- missing_records |>
    dplyr::mutate(
      # Step 1: Geocode using Census Places
      long = NA,
      lat = NA
    )

  
  
  # Populate long/lat for missing records
  missing_long_lat <- out_tidygeocoder_missing |>
    dplyr::rowwise() |>
    dplyr::mutate(
      centroid = if (!is.na(`location`)) { # <= changed 'hq_location' to 'location'
        # Step 1: Try Census Place geocoding
        cen_long_lat <- get_census_place_centroid(`location`, places, states)
        if (is.null(cen_long_lat) && !is.na(`postal_code`) && `postal_code` != "") { # <= changed 'hq_post_code' to 'postal_code'
          # Step 2: If Census Place fails, try ZIP code geocoding
          cen_long_lat <- get_zipcode_centroid(`postal_code`)
        }
        list(cen_long_lat)
      } else if (!is.na(`postal_code`) && `postal_code` != "") {
        # Step 2: If Census Place fails, try ZIP code geocoding
        cen_long_lat <- get_zipcode_centroid(`postal_code`)
        list(cen_long_lat)
      } else {
        list(NULL)
      }
    ) |>
    dplyr::ungroup()

  missing_long_lat$long <- unlist(lapply(missing_long_lat$centroid, function(centroid) {
    # print(is.null(centroid))
    ifelse(is.null(centroid), NA, as.numeric(unlist(centroid)[1]))
  }))

  missing_long_lat$lat <- unlist(lapply(missing_long_lat$centroid, function(centroid) {
    # print(is.null(centroid))
    ifelse(is.null(centroid), NA, as.numeric(unlist(centroid)[2]))
  }))
  
  # Convert to sf data frame
  out_tidygeocoder_missing_sf <- missing_long_lat |>
    dplyr::filter(!is.na(`long`), !is.na(`lat`)) |>
    sf::st_as_sf(
      coords = c("long", "lat"),
      crs = sf::st_crs(out_tidygeocoder)  # Use same CRS as original
    )

  # Merge with original tidygeocoder results
  # Use st_drop_geometry to ensure clean merge
  final_geocoded_sf <- dplyr::bind_rows(
    out_tidygeocoder,
    out_tidygeocoder_missing_sf
  )
  counties <- readRDS(file = paste0(here::here(), "/data/counties.rds"))
  
  # Find points within polygons
  final_geocoded_sf_w_co <- sf::st_join(
    final_geocoded_sf |> 
      dplyr::mutate(geometry = sf::st_transform(geometry, sf::st_crs("+proj=longlat +datum=WGS84"))), 
    counties |> 
      dplyr::mutate(geometry = sf::st_transform(geometry, sf::st_crs("+proj=longlat +datum=WGS84"))), 
    join = sf::st_within
  ) |>
    dplyr::mutate(
      state_fips = `STATEFP`,
      county_fips = `COUNTYFP`,
      county_name = `NAME`,
      geoid_co = `GEOID`
    ) |>
    dplyr::select(
      # Drop most of the county attributes
      !(names(counties))
    ) |>
    dplyr::select( 
      # <= Drop centroid list value to avoid: "list columns are only allowed with raw vector contents"
      !centroid
    )
  
  return(final_geocoded_sf_w_co)
}

#' A function that can turn an array of GeoJSON objects into an sf data.fame
#'
#' @param geo_json_list A list of GeoJSON objects (i.e. the "features" array property of a FeatureCollection) 
#'
#' @return sf data.frame
#' 
#' @importFrom dplyr bind_rows
#' @importFrom sf st_geometry
#' @importFrom sf st_sf
#' 
#' @export
# Since geocoding results come back as GeoJSON objects, need to define function 
geojson_array_to_sf <- function (geo_json_list) { # <- geo_json_list: array of list representation of GeoJSON
  sf::st_sf(geo_json_list |>
    lapply(function (x) {
      geojson_properties <- as.data.frame(x[["properties"]])
      # creates row of class "sf tbl_df tbl data.frame" with "geometry" column, but ...
      # read_sf can *only* operate on n the "geometry" property of the GeoJSON feature
      geojson_table <- sf::read_sf(jsonlite::toJSON(x[["geometry"]], auto_unbox = TRUE))
      # enriches geojson_properties data.frame with "geometry" column
      sf::st_geometry(geojson_properties) <- geojson_table$geometry
      geojson_properties
    }) |>
    dplyr::bind_rows()
  )
}

