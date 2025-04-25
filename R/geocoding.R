

# Function to geocode missing records
geocode_missing_records <- function (dta_id = "company_id", dta_all, out_tidygeocoder, census_places_dataset, states, zip_code_centroids) {
  
  # Identify records not in tidygeocoder output (only US companies)
  missing_records <- (if (dta_id == "cisco_id") {

    dta_all |>
      filter(!(cisco_id %in% out_tidygeocoder$cisco_id))
    
  } else if (dta_id == "company_id") {

    dta_all |>
      filter(!(company_id %in% out_tidygeocoder$company_id))
    
  } else if (dta_id == "investor_id") {

    dta_all |>
      filter(!(investor_id %in% out_tidygeocoder$investor_id))
    
  })

  # return(missing_records)
  
  # Prepare a data frame for missing geocoded records
  out_tidygeocoder_missing <- missing_records |>
    mutate(
      # Step 1: Geocode using Census Places
      long = NA,
      lat = NA
    )

  # Function to get Census Place centroid
  get_census_place_centroid <- function(location) {

    # Parse location into city and state
    parts <- strsplit(location, ", ")[[1]]
    if (length(parts) == 2) {
      city <- parts[1]
      state_abbr <- parts[2]

      # message(state_abbr)
      if (!stringr::str_detect(state_abbr,  paste(states$STUSPS, collapse = "|", sep="|"))) {
        # Not in the US
        return(NULL)
      }

      if (!is.na(city) || city != "") {
        # Not in the US
        return(NULL)
      }

      state_fips <- (states |> filter(STUSPS == state_abbr))[1,]$STATEFP
      
      # Use a pre-loaded or dynamically fetched Census Places dataset
      # This is a placeholder - you'd need to implement the actual lookup
      place_centroid <- census_places_dataset |>
        filter(
          stringr::str_detect(tolower(NAMELSAD), tolower(city)),
          STATEFP == state_fips
        ) |>
        select(INTPTLON, INTPTLAT) |>
        slice(1)  # Take first match if multiple exist
      
      if (nrow(place_centroid) > 0) {
        return(list(
          long = as.numeric(place_centroid$INTPTLON), 
          lat = as.numeric(place_centroid$INTPTLAT)
        ))
      }
    }
    return(NULL)
  }
  
  # Function to get ZIP code centroid
  get_zipcode_centroid <- function(zipcode) {

    # Use a pre-loaded or dynamically fetched ZIP code centroids dataset
    # This is a placeholder - you'd need to implement the actual lookup
    zipcode_centroid <- zip_code_centroids |>
      filter(STD_ZIP5 == zipcode) |>
      select(LON, LAT) |>
      slice(1)
    
    if (nrow(zipcode_centroid) > 0) {
      return(list(
        long = zipcode_centroid$LON, 
        lat = zipcode_centroid$LAT
      ))
    }
    return(NULL)
  }
  
  # Populate long/lat for missing records
  missing_long_lat <- out_tidygeocoder_missing |>
    rowwise() |>
    mutate(
      centroid = if (!is.na(location)) { # <= changed 'hq_location' to 'location'
        # Step 1: Try Census Place geocoding
        cen_long_lat <- get_census_place_centroid(location)
        if (is.null(cen_long_lat) && !is.na(postal_code) && postal_code != "") { # <= changed 'hq_post_code' to 'postal_code'
          # Step 2: If Census Place fails, try ZIP code geocoding
          cen_long_lat <- get_zipcode_centroid(postal_code)
        }
        list(cen_long_lat)
      } else if (!is.na(postal_code) && postal_code != "") {
        # Step 2: If Census Place fails, try ZIP code geocoding
        cen_long_lat <- get_zipcode_centroid(postal_code)
        list(cen_long_lat)
      } else {
        list(NULL)
      }
    ) |>
    ungroup()

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
    filter(!is.na(long), !is.na(lat)) |>
    st_as_sf(
      coords = c("long", "lat"),
      crs = st_crs(out_tidygeocoder)  # Use same CRS as original
    )

  # Merge with original tidygeocoder results
  # Use st_drop_geometry to ensure clean merge
  final_geocoded_sf <- dplyr::bind_rows(
    out_tidygeocoder,
    out_tidygeocoder_missing_sf
  )
  counties <- readRDS(file = paste0(here::here(), "/data/counties.rds"))
  
  # Find points within polygons
  final_geocoded_sf_w_co <- st_join(
    final_geocoded_sf |> 
      mutate(geometry = sf::st_transform(geometry, sf::st_crs("+proj=longlat +datum=WGS84"))), 
    counties |> 
      mutate(geometry = sf::st_transform(geometry, sf::st_crs("+proj=longlat +datum=WGS84"))), 
    join = st_within
  ) |>
    mutate(
      state_fips = STATEFP,
      county_fips = COUNTYFP,
      county_name = NAME,
      geoid_co = GEOID
    ) |>
    select(
      # Drop most of the county attributes
      !(names(counties))
    ) |>
    dplyr::select( 
      # <= Drop centroid list value to avoid: "list columns are only allowed with raw vector contents"
      !centroid
    )
  
  return(final_geocoded_sf_w_co)
}
