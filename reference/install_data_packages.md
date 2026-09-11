# Install the cori.data.\* companion packages

Installs the `cori.data.*` packages that provide read/write access to
specific public data sources on top of `cori.data`: Business Dynamics
Statistics, Business Formation Statistics, Building Permits Survey, FCC
broadband deployment data, Housing Unit estimates, Population Estimates,
and Quarterly Census of Employment and Wages.

## Usage

``` r
install_data_packages(
  packages = c("cori.data.bds", "cori.data.bfs", "cori.data.bps", "cori.data.fcc",
    "cori.data.hu", "cori.data.pep", "cori.data.qcew", "ruraldefinitions"),
  ...
)
```

## Arguments

- packages:

  Character vector of package names to install. Default: all seven
  `cori.data.*` companion packages.

- ...:

  Additional arguments passed to
  [`remotes::install_github()`](https://remotes.r-lib.org/reference/install_github.html).

## Value

Invisibly, the character vector of packages installed.

## Details

These are declared in `Suggests`, not `Imports`/`Depends`, because most
of them already depend on `cori.data` (for
[`cori.data.s3::connect_to_s3()`](https://ruralinnovation.github.io/cori.data.s3/reference/connect_to_s3.html))
– listing them as hard dependencies of `cori.data` itself would create a
circular dependency that R's namespace loader cannot resolve. This
function is the explicit, one-line alternative: run it right after
installing `cori.data` to pull in the rest of the suite.

## Examples

``` r
if (FALSE) { # \dontrun{
cori.data::install_data_packages()

# Install just one or two
cori.data::install_data_packages(c("cori.data.bds", "cori.data.qcew"))
} # }
```
