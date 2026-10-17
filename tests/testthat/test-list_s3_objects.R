if (!has_local_aws_credentials()) {
  test_that("No .Renviron file", {
    expect_error(set_aws_credentials())
  })
}

if (has_local_aws_credentials()) {
  test_that("list_s3_objects returns a well-formed data frame", {
    result <- list_s3_objects("test-coridata")
    expect_true(is.data.frame(result))
    expect_named(result, c("key", "last_modified"))
  })
}
