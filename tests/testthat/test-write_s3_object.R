test_that("Test error on class data.frame", {
  expect_error(write_s3_object("bob", "bob"))
})

test_that("Test error on sf object", {
  skip_if_not_installed("sf")
  expect_error(write_s3_object("bob", sf::read_sf(system.file("shape/nc.shp", package = "sf"))))
})
