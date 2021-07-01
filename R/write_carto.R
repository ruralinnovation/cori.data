#' Write spatial data to Carto
#'
#' @param sf A spatial dataframe with class 'sf'
#' @param layer_name The name of the data set as it should appear on Carto
#' @param carto_conf Name of the YAML header containing the URL to upload to. Defaults to oscarto
#' @param overwrite Option to overwrite existing data
#' @param config_group Name of the YAML collection containing upload URLs.
#' @param config_file Path to the config YAML with credentials
#'
#' @export
#'
#' @importFrom config get
#' @importFrom sf st_write
#'
write_carto <- function(
  sf,
  layer_name,
  carto_conf = 'oscarto',
  overwrite = FALSE,
  config_group = "write_carto",
  config_file = "/data/Github/base/config.yml"
){
  if (!"sf" %in% class(sf)){
    stop("Input data is not a spatial dataframe")
  }

  if (Sys.info()['sysname'] == "Windows"){
    stop("write_carto() requires a Mac or Linux environment to execute")
  }

  # pull config and select needed element with []
  conf <- config::get(config_group, file = config_file)[[carto_conf]]

  # carto valid layer name
  layer_name_db <- gsub("\\s+","_", tolower(layer_name), perl = TRUE)

  # create file name/path variables
  # TODO: use temp file
  gpkg <- paste0(layer_name_db,".gpkg")

  # create path for gpkg file
  path <- paste0(tempdir(), "/", gpkg)

  # write gpkg
  sf::st_write(sf,
               path,
               delete_dsn = TRUE)

  # if overwrite == TRUE, add collision strategy to end of URL
  if (overwrite){
    conf <- paste0(conf, "&collision_strategy=overwrite")
  }

  # insert info into system command
  cmd <- sprintf("curl -v -F file=@'%s' '%s'", path, conf)

  # call system
  system(cmd)


}


