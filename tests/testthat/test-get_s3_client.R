# Exercises the credential fallback logic itself, with no network calls:
# has_local_aws_credentials() and .fetch_vended_credentials() are mocked.

test_that("vended path builds a client from fetched credentials", {
  local_mocked_bindings(
    has_local_aws_credentials = function() FALSE,
    .fetch_vended_credentials = function(vending_url, bucket) {
      list(
        access_key_id     = "FAKEKEYID",
        secret_access_key = "fakesecret",
        session_token     = "faketoken"
      )
    }
  )

  client <- get_s3_client("some.bucket")

  expect_true(is.list(client))
  expect_true(all(c("get_object", "list_objects_v2") %in% names(client)))
})

test_that("require_local stops with the read-only message when no local creds", {
  local_mocked_bindings(
    has_local_aws_credentials = function() FALSE
  )

  expect_error(get_s3_client(require_local = TRUE), "read-only")
})

test_that("vended path without a bucket stops with the bucket-required message", {
  local_mocked_bindings(
    has_local_aws_credentials = function() FALSE
  )

  expect_error(get_s3_client(), "'bucket' is required")
})

test_that("local path returns a client without touching the vending endpoint", {
  local_mocked_bindings(
    has_local_aws_credentials = function() TRUE,
    .fetch_vended_credentials = function(vending_url, bucket) {
      stop("vending endpoint should not be called on the local path")
    }
  )

  client <- get_s3_client("some.bucket")

  expect_true(is.list(client))
  expect_true(all(c("get_object", "list_objects_v2") %in% names(client)))
})

test_that("default_vending_url precedence: option, then env var, then deployed default", {
  withr::local_options(cori.data.vending_url = "https://example.test/opt")
  expect_equal(default_vending_url(), "https://example.test/opt")

  withr::local_options(cori.data.vending_url = NULL)
  withr::local_envvar(CORI_DATA_VENDING_URL = "https://example.test/env")
  expect_equal(default_vending_url(), "https://example.test/env")

  withr::local_envvar(CORI_DATA_VENDING_URL = "")
  expect_equal(default_vending_url(), "https://data.ruralinnovation.us/credentials")
})
