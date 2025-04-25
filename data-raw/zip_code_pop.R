library(dplyr)
library(sf)

# TODO: Write code to source places files from s3://cori.data.zip
local_zip_code_pop_weighted_centroid_files <- list.files("data/ZIP", full.names = TRUE)
zip_code_centroids <- sf::st_read(local_zip_code_pop_weighted_centroid_files)

# usethis::use_data(zip_code_centroids)
saveRDS(zip_code_centroids, file = "data/zip_code_centroids.rds")
