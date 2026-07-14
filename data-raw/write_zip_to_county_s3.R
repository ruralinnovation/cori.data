library(cori.db)
library(dplyr)
library(readxl)

# setup data dir
data_dir <- paste0(here::here(), "/inst/ext_data/source")
if (! dir.exists(data_dir)) dir.create(data_dir)

# HUD USPS ZIP Code Crosswalk Files (ZIP -> County), Q4 2021 release.
# Manually downloaded to inst/ext_data/source/zip_codes/ from
# https://www.huduser.gov/portal/datasets/usps_crosswalk.html
# (ZIP_COUNTY_122021.xlsx). Kept alongside the ZIP centroid source files under
# the shared `zip_codes` prefix.

zip_to_county_source_file <- "inst/ext_data/source/zip_codes/ZIP_COUNTY_122021.xlsx"

if (file.exists(zip_to_county_source_file)) {
 # read as-is; the workbook already ships lower-case headers
 # (zip, county, usps_zip_pref_city, usps_zip_pref_state, res_ratio, bus_ratio,
 #  oth_ratio, tot_ratio)
 zip_to_county_crosswalk <- readxl::read_excel(zip_to_county_source_file)

 saveRDS(zip_to_county_crosswalk, file = "inst/ext_data/source/zip_codes/zip_to_county_crosswalk.rds")
}

### WRITE ------------------------------------------------------------------------------------------------------------

data_prefix <- "zip_codes"
s3_bucket_name <- "cori.data.census"

# The `zip_codes` prefix already exists on S3 (it holds the ZIP centroid files),
# so put_s3_objects_recursive() refuses to write into it. Upload just the new
# crosswalk object with the single-object helper instead.
cori.db::put_s3_object(
  s3_bucket_name,
  paste0(data_prefix, "/zip_to_county_crosswalk.rds"),
  paste0(data_dir, "/", data_prefix, "/zip_to_county_crosswalk.rds")
)


#### TEST ------------------------------------------------------------------------------------------------------------

test_dir <- paste0(here::here(), "/inst/ext_data/test")
dir.create(paste0(test_dir, "/", data_prefix), showWarnings = FALSE)

cori.db::get_s3_object(s3_bucket_name, paste0(data_prefix, "/zip_to_county_crosswalk.rds"), test_dir)

data_s3_files <- (
    cori.db::list_s3_objects(bucket_name = s3_bucket_name) |> dplyr::filter(grepl(data_prefix, key))
)$key

data_files <- lapply(data_s3_files,function (s3_key_path) {
    cori.db::get_s3_object(s3_bucket_name, s3_key_path, test_dir)
})
