if (!has_local_aws_credentials()) {
  test_that("No .Renviron file", {
    expect_error(set_aws_credentials())
  })
} else {
  test_that("Should not allow to write on non curated bucket", {
    expect_error(put_s3_object("bob", "bill"))
  })
}
