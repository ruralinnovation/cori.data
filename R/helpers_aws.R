# what is the type of content of an object

get_s3_content_type <- function(bucket_name, key, s3 = get_s3_client(bucket_name)) {

  head <- s3$head_object(
    Bucket = bucket_name,
    Key = key)

  return(head$ContentType)
}

can_i_write_in_that_bucket <- function(bucket_name) {
  # # v1 implementation should go against a list
  # # v2 could use a specific tag
  # # TODO: do it better, but for now....
  # curated_bucket <- c("cori-risi-apps", "fcc-raw-cori", "test-coridata")
  # bucket_name %in% curated_bucket
  return(TRUE)
}

get_s3_tags <- function(bucket_name, s3 = get_s3_client(bucket_name)) {
  s3$get_bucket_tagging(
    Bucket = bucket_name
  )
}

is_key_already_here <- function(bucket_name, key) {
  df_key <- list_s3_objects(bucket_name = bucket_name)
  key_is_present <- key %in% df_key[["key"]]

  if (key_is_present) {
    message(paste0("Warning: ", bucket_name, " contains a previous version of ", key))
    return(key_is_present)
  } else {
    return (FALSE)
  }
}

is_prefix_already_present <- function(bucket_name, prefix) {
  df_key <- list_s3_objects(bucket_name = bucket_name)

  key_is_present <- any(unlist(lapply(df_key[["key"]], function (x) {
    grepl(prefix, x)
  })))

  if (key_is_present) {
    message(paste0("Warning: ", bucket_name, " already contains files under the prefix '", prefix, "'"))
    return(key_is_present)
  } else {
    return (FALSE)
  }
}