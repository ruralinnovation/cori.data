## CORI/RISI commonly used data sets and data functions

![lifecycle](https://img.shields.io/badge/lifecycle-maturing-blue.svg)

### Part of the [coriverse](https://github.com/ruralinnovation/coriverse/wiki)

This package is the S3/cloud-access layer for the `cori.data.*` family: AWS S3 object functions, a DuckDB S3 connection helper, and an installer for the companion `cori.data.*` packages that build on it.

~~This also serves as cache (temporary) for some commonly referenced geographic data sets.~~

## S3 access functions

The AWS S3 functions (`get_s3_object()`, `list_s3_objects()`, `list_s3_buckets()`, `put_s3_object()`, `put_s3_objects_recursive()`, `read_s3_object()`, `write_s3_object()`, `set_aws_credentials()`) moved here from the `cori.db` package.

Reads (`get_s3_object()`, `list_s3_objects()`, `read_s3_object()`) use local AWS credentials when available (env vars or `~/.aws/credentials`), and otherwise fall back to temporary, read-only credentials from the CORI credential-vending endpoint — no local AWS setup required. Writes (`put_s3_object()`, `put_s3_objects_recursive()`, `write_s3_object()`) and `list_s3_buckets()` always require local credentials, since vended credentials are read-only.

## Connecting to S3 via DuckDB

`connect_to_s3(bucket, region, vending_url)` opens a DuckDB connection configured for S3 access, using the same local-then-vended credential resolution as the S3 functions above. `has_local_aws_credentials()` checks whether local credentials are configured.

```r
con <- cori.data::connect_to_s3("cori.data.bds")
on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
DBI::dbGetQuery(con, "SELECT * FROM read_parquet('s3://cori.data.bds/**/*.parquet')")
```

## Installing the cori.data.* companion packages

`install_data_packages()` installs the `cori.data.*` packages built on top of `cori.data` (`cori.data.bds`, `cori.data.bfs`, `cori.data.bps`, `cori.data.fcc`, `cori.data.hu`, `cori.data.pep`, `cori.data.qcew`). They're declared in `Suggests`, not `Imports`/`Depends` — most of them already depend on `cori.data`, so a dependency the other way would be circular.

```r
cori.data::install_data_packages()
```

## Functions removed from this package

These functions used to live in `cori.data` and were moved to `cori.utils`: `calculate_entropy_index()`, `county_pop_centroids()`, `geojson_array_to_sf()`, `load_tiger()`, `map_locations_to_counties()`, `tiger_line_counties()`, `tiger_line_county_state_fips()`, `tiger_line_places()`, `tiger_line_states()`, `zip_code_centroids()`, `zip_to_county_crosswalk()`.

Two of those, `compare_dimensions()` and `get_dims()`, later moved again from `cori.utils` to `cori.db` — see the `cori.db` README.
