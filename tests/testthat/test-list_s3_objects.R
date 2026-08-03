if (!has_local_aws_credentials()) {
  test_that("No .Renviron file", {
    expect_error(set_aws_credentials())
  })
}
