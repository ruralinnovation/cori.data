# Getting Started with CORI Rural Data

Rural America contains multitudes. It is a place of deep economic
resilience and persistent structural challenge — where the loss of a
single employer can reshape a community for a generation, and where a
new business opening can signal something much larger than its balance
sheet would suggest.

The CORI data ecosystem gives researchers, analysts, and practitioners
direct access to the socioeconomic data that describes these dynamics.
This vignette introduces the ecosystem and the consistent interface that
runs across every package.

## The packages

| Package | What it measures | Geography | Years |
|----|----|----|----|
| `cori.data.qcew` | Employment & wages (BLS QCEW) | county, state | 1990–present |
| `cori.data.bds` | Business dynamics (Census BDS) | county, state, nation | 1978–present |
| `cori.data.pep` | Population (Census PEP) | county, state, nation | 2000–present |
| `cori.data.bfs` | Business applications (Census BFS) | county, state, nation | 2004–present |
| `cori.data.bps` | Building permits (Census BPS) | county, metro | 1980–present |
| `cori.data.hu` | Housing units (Census HU) | county, state, nation | 2000–present |
| `cori.data.fcc` | Broadband coverage (FCC NBM) | county | 2023–present |
| `ruraldefinitions` | Rural classifications | county | multiple vintages |

## A consistent interface

Every package uses the same four parameters. Once you learn the pattern
once, you know it everywhere.

``` r

library(cori.data.qcew)
library(cori.data.pep)
library(cori.data.bds)

# The four parameters — same across every package:
#   geography = "county", "state", or "nation"
#   geoids    = character vector of FIPS codes (overrides geography)
#   years     = integer vector of years
#   variables = which variables to return (NULL = all)

get_employment(geography = "county",  years = 2019:2023)
get_population(geography = "county",  years = 2019:2023)
get_business_dynamics(geography = "county", years = 2019:2023)

# Filter to specific places with FIPS codes
get_employment(geoids = c("33009", "54011", "30001"), years = 2019:2023)
```

All functions return **tidy (long) format** data: one row per
`geoid × year × variable`. The `variable` column names the measure;
`value` holds the number.

    geoid   year  variable      value
    33009   2023  employment    28450
    33009   2022  employment    27810
    54011   2023  employment    12340
    ...

## Your first pull

``` r

library(cori.data.qcew)
library(dplyr)

# Pull county-level employment for the last five years
emp <- get_employment(geography = "county", years = 2019:2023)

glimpse(emp)

# Which counties had the most employment in 2023?
emp |>
  filter(year == 2023) |>
  slice_max(value, n = 10)
```

## Rural classifications

The `ruraldefinitions` package provides county-level rural/nonrural
classifications across several methodologies:

``` r

library(ruraldefinitions)

# CBSA-based (the CORI standard)
rural <- cbsa_2023
# Returns: geoid | name | year | rural_def | is_rural ("Rural" / "Nonrural")

# Other available definitions

rucc_2023 # USDA Rural-Urban Continuum Codes
nchs_2023 # NCHS Urban-Rural Classification Scheme
uic_2024  # USDA Urban Influence Codes
```

## Where to go next

- [**Employment
  Rate**](https://ruralinnovation.github.io/cori.data/articles/employment-rate.md)
  — combine QCEW + PEP to build a cross-package employment rate with
  line chart and county map
- [**Working with Tidy
  Data**](https://ruralinnovation.github.io/cori.data/articles/tidy-data.md)
  — filtering, pivoting wide, and joining datasets across packages
- [**Sector
  Analysis**](https://ruralinnovation.github.io/cori.data/articles/sector-analysis.md)
  — CORI super-sectors and what they reveal about rural economic
  composition
- [**Weighted
  Averages**](https://ruralinnovation.github.io/cori.data/articles/weighted-averages.md)
  — why `agg_var` matters and how to use it correctly
- [**Broadband**](https://ruralinnovation.github.io/cori.data/articles/broadband.md)
  — FCC broadband data and its relationship to economic outcomes

## Data sources

> The Center on Rural Innovation’s curation of U.S. Bureau of Labor
> Statistics, *Quarterly Census of Employment and Wages*.
> <https://www.bls.gov/cew/>
>
> The Center on Rural Innovation’s curation of U.S. Census Bureau,
> *Population Estimates Program*.
> <https://www.census.gov/programs-surveys/popest.html>
>
> The Center on Rural Innovation’s curation of U.S. Census Bureau,
> *Business Dynamics Statistics*.
> <https://www.census.gov/programs-surveys/bds.html>
>
> The Center on Rural Innovation’s curation of U.S. Census Bureau,
> *Metropolitan and Micropolitan Statistical Areas (OMB delineations)*.
> <https://www.census.gov/programs-surveys/metro-micro.html>
>
> The Center on Rural Innovation’s curation of USDA Economic Research
> Service, *Rural-Urban Continuum Codes*.
> <https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/>
>
> The Center on Rural Innovation’s curation of National Center for
> Health Statistics, *Urban-Rural Classification Scheme for Counties*.
> <https://www.cdc.gov/nchs/data_access/urban_rural.htm>
>
> The Center on Rural Innovation’s curation of USDA Economic Research
> Service, *Urban Influence Codes*.
> <https://www.ers.usda.gov/data-products/urban-influence-codes/>
>
> This product uses the Census Bureau Data API but is not endorsed or
> certified by the Census Bureau. BLS.gov cannot vouch for the data or
> analyses derived from these data after the data have been retrieved
> from BLS.gov.
