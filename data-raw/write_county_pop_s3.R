library(cori.db)
library(dplyr)
library(sf)

# setup data dir
data_dir <- paste0(here::here(), "/inst/ext_data/source")
if (! dir.exists(data_dir)) dir.create(data_dir)

data_prefix <- "cenpop2020/county"

# Manually download geometry files to data_dir from [US Census](https://www2.census.gov/geo/docs/reference/cenpop2020/)

cenpop_2020_file <- paste0(data_dir, "/", data_prefix, "/CenPop2020_Mean_CO.txt")

if (file.exists(cenpop_2020_file)) {
 county_pop_centroids <- data.table::fread(cenpop_2020_file)

 # usethis::use_data(zip_code_centroids)
 saveRDS(county_pop_centroids, file = paste0(data_dir, "/", data_prefix, "/county_pop_centroids.rds"))
}

### WRITE ------------------------------------------------------------------------------------------------------------

s3_bucket_name <- "cori.data.census"

cori.db::put_s3_objects_recursive(s3_bucket_name, data_prefix, paste0(data_dir, "/", data_prefix))


#### TEST ------------------------------------------------------------------------------------------------------------

test_dir <- paste0(here::here(), "/inst/ext_data/test")
dir.create(paste0(test_dir, "/", data_prefix), showWarnings = FALSE)

cori.db::get_s3_object(s3_bucket_name, paste0(data_prefix, "/county_pop_centroids.rds"), test_dir)

data_s3_files <- (
    cori.db::list_s3_objects(bucket_name = s3_bucket_name) |> dplyr::filter(grepl(data_prefix, key))
)$key

data_files <- lapply(data_s3_files,function (s3_key_path) {
    cori.db::get_s3_object(s3_bucket_name, s3_key_path, test_dir)
})
