library(cori.db)
library(dplyr)

# setup data dir
data_dir <- paste0(here::here(), "/data/")
if (! dir.exists(data_dir)) dir.create(data_dir)

### WRITE ------------------------------------------------------------------------------------------------------------

data_prefix <- "tiger/line/states"
s3_bucket_name <- "cori.data.census"

cori.db::put_s3_objects_recursive(s3_bucket_name, data_prefix, paste0("data/source/", data_prefix))


#### TEST ------------------------------------------------------------------------------------------------------------

dir.create(paste0(data_dir, "/data/test"), showWarnings = FALSE)

cori.db::get_s3_object(s3_bucket_name, paste0(data_prefix, "/tl_2024_us_state.zip"), "data/test/tl_2024_us_state.zip")

data_s3_files <- (
    cori.db::list_s3_objects(bucket_name = s3_bucket_name) |> dplyr::filter(grepl(data_prefix, key))
)$key

dir.create(paste0("data/test/", data_prefix), recursive = TRUE, showWarnings = FALSE)

data_files <- lapply(data_s3_files,function (s3_key_path) {
    cori.db::get_s3_object(s3_bucket_name, s3_key_path, paste0("data/test/", data_prefix, "/", basename(s3_key_path)))
})
