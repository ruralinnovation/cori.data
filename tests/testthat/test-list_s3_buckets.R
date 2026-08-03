if (!has_local_aws_credentials()) {
  test_that("list_s3_buckets requires local credentials", {
    expect_error(list_s3_buckets(), "read-only")
  })
} else {
  test_that("Return a data frame", {
    expect_equal(is.data.frame(list_s3_buckets()), TRUE)
  })
}
