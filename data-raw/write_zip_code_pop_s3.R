library(cori.db)
library(dplyr)
library(sf)

# setup data dir
data_dir <- paste0(here::here(), "/inst/ext_data/source")
if (! dir.exists(data_dir)) dir.create(data_dir)

# Manually download geometry files to data_dir from [US Department of Housing and Urban Development](https://hudgis-hud.opendata.arcgis.com/datasets/zip-code-population-weighted-centroids-1/about)

# TODO: Write code to source places files from s3://cori.data.zip
local_zip_code_pop_weighted_centroid_files <- list.files("inst/ext_data/source/zip_codes", full.names = TRUE)
message(paste(local_zip_code_pop_weighted_centroid_files, collapse = "\n"))

zip_code_pop_weighted_centroid_file <- "inst/ext_data/source/zip_codes/ZIP_Code_Population_Weighted_Centroids_1937758471934638182.geojson"

if (file.exists(zip_code_pop_weighted_centroid_file)) {
 zip_code_centroids <- sf::st_read(zip_code_pop_weighted_centroid_file)

 # usethis::use_data(zip_code_centroids)
 saveRDS(zip_code_centroids, file = "inst/ext_data/source/zip_codes/zip_code_centroids.rds")
}

### WRITE ------------------------------------------------------------------------------------------------------------

data_prefix <- "zip_codes"
s3_bucket_name <- "cori.data.census"

cori.db::put_s3_objects_recursive(s3_bucket_name, data_prefix, paste0(data_dir, "/", data_prefix))


#### TEST ------------------------------------------------------------------------------------------------------------

test_dir <- paste0(here::here(), "/inst/ext_data/test")
dir.create(paste0(test_dir, "/", data_prefix), showWarnings = FALSE)

cori.db::get_s3_object(s3_bucket_name, paste0(data_prefix, "/zip_code_centroids.rds"), test_dir)

data_s3_files <- (
    cori.db::list_s3_objects(bucket_name = s3_bucket_name) |> dplyr::filter(grepl(data_prefix, key))
)$key

data_files <- lapply(data_s3_files,function (s3_key_path) {
    cori.db::get_s3_object(s3_bucket_name, s3_key_path, test_dir)
})
