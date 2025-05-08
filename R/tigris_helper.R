library(sf)

# Adapted from tigirs: Function to convert input shape to WKT for filter_by param
input_to_wkt <- function(input) {
  if (is.null(input)) {
    wkt_input <- character(0)
  } else if (inherits(input, "sf")) {
    # Make NAD83 for coordinate alignment
    input <- sf::st_transform(input, 4269)
    # Convert to WKT
    wkt_input <- sf::st_as_text(sf::st_geometry(input))

  } else if (inherits(input, "bbox")) {
    bbox_sfc <- sf::st_as_sfc(input)
    bbox_sfc <- sf::st_transform(bbox_sfc, 4269)

    wkt_input <- sf::st_as_text(bbox_sfc)

  } else if (length(input) == 4) {
    names(input) <- c("xmin", "ymin", "xmax", "ymax")
    bbox <- sf::st_bbox(input, crs = 4269)
    bbox_sfc <- sf::st_as_sfc(bbox)

    wkt_input <- sf::st_as_text(bbox_sfc)

  } else {
    stop("Invalid input. Supply an sf object, a bbox object, or a length-4 vector that can be converted to a bbox.", call. = FALSE)
  }

  return(wkt_input)
}

#' (Adapted from tigris) Helper function to download Census data (modified to read from local file paths)
#'
#' @param local_file_path local path to zipped shapefile in TIGER database (constructed in calling function).
#' @param tigris_type Added as an attribute to return object (used internally).
#' @param class Class of return object. Must be one of "sf" (the default) or "sp".
#' @param filter_by Geometry used to filter the output returned by the function.  Can be an sf object, an object of class `bbox`, or a length-4 vector of format `c(xmin, ymin, xmax, ymax)` that can be converted to a bbox. Geometries that intersect the input to `filter_by` will be returned.
#'
#' @return sf or sp data frame
#'
#' @export
#'
#' @examples
#'
#' \dontrun{
#'   states <- lapply(local_state_files_tiger_year, load_tiger) |>
#'     dplyr::bind_rows()
#' }
#'
load_tiger <- function(
  local_file_path,
  tigris_type=NULL,
  class = getOption("tigris_class", "sf"),
  filter_by = NULL
) {

  if (!file.exists(local_file_path)) {
    stop(paste0("Could not locate ", local_file_path))
  }

  use_cache <- getOption("tigris_use_cache", FALSE)

  # Process filter_by
  wkt_filter <- input_to_wkt(filter_by)

  tmp <- tempdir()
  tiger_file <- basename(local_file_path)
  cache_dir <- dirname(local_file_path)

  obj <- NULL

  shape <- gsub(".zip", "", tiger_file)
  shape <- gsub("_shp", "", shape) # for historic tracts
  
  file_loc <- file.path(cache_dir, tiger_file)
  shp_loc  <- file.path(cache_dir, sprintf("%s.shp", shape))

  unzip(file_loc, exdir = tmp)
  shape <- gsub(".zip", "", tiger_file)
  shape <- gsub("_shp", "", shape) # for historic tracts

  obj <- sf::st_read(dsn = tmp, layer = shape,
    quiet = TRUE, stringsAsFactors = FALSE,
    wkt_filter = wkt_filter)

  if (is.na(sf::st_crs(obj)$proj4string)) {

    sf::st_crs(obj) <- "+proj=longlat +datum=NAD83 +no_defs"

  }

  attr(obj, "tigris") <- "tigris"

  # this will help identify the object "sub type"
  if (!is.null(tigris_type)) attr(obj, "tigris") <- tigris_type

  # Take care of COUNTYFP, STATEFP issues for historic data
  if ("COUNTYFP00" %in% names(obj)) {
    obj$COUNTYFP <- obj$COUNTYFP00
    obj$STATEFP <- obj$STATEFP00
  }
  if ("COUNTYFP10" %in% names(obj)) {
    obj$COUNTYFP <- obj$COUNTYFP10
    obj$STATEFP <- obj$STATEFP10
  }
  if ("COUNTY" %in% names(obj)) {
    obj$COUNTYFP <- obj$COUNTY
    obj$STATEFP <- obj$STATE
  }
  if ("CO" %in% names(obj)) {
    obj$COUNTYFP <- obj$CO
    obj$STATEFP <- obj$ST
  }

  if (class == "sp") {
    warning(stringr::str_wrap("Spatial* (sp) classes are no longer formally supported in tigris as of version 2.0. We strongly recommend updating your workflow to use sf objects (the default in tigris) instead.", 50), call. = FALSE)
    return(sf::as_Spatial(obj))
  } else {
    return(obj)
  }
}
