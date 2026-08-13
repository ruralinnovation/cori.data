# cori.data

> Rural data, made accessible.

At CORI, we believe that understanding rural America starts with good data.
This ecosystem of R packages gives researchers, analysts, and policy
practitioners direct access to the socioeconomic data we use every day —
employment, wages, population, business dynamics, housing, broadband, and more.

`cori.data` is the S3/cloud-access foundation for the `cori.data.*` family:
it provides the credential management, DuckDB S3 connection helper, and S3
object functions that every companion package builds on. **Reads require no
local AWS setup** — the package falls back to temporary, read-only credentials
from the CORI credential-vending endpoint automatically.

We're actively expanding these offerings and would love your collaboration.
Pull requests, issue reports, and feature requests are all welcome.

---

## Getting started

Install `cori.data` and all companion data packages in one call:

```r
# install.packages("devtools")
devtools::install_github("ruralinnovation/cori.data")

# Install all cori.data.* companion packages
cori.data::install_data_packages()
```

---

## The ecosystem

| Package | What it measures | Geography | Years |
|---|---|---|---|
| [cori.data.qcew](https://github.com/ruralinnovation/cori.data.qcew) | Employment & wages ([BLS QCEW](https://www.bls.gov/cew/)) | county, state | 1990–present |
| [cori.data.bds](https://github.com/ruralinnovation/cori.data.bds) | Business dynamics ([Census BDS](https://www.census.gov/programs-surveys/bds.html)) | county, state, nation | 1978–present |
| [cori.data.pep](https://github.com/ruralinnovation/cori.data.pep) | Population ([Census PEP](https://www.census.gov/programs-surveys/popest.html)) | county, state, nation | 2000–present |
| [cori.data.bfs](https://github.com/ruralinnovation/cori.data.bfs) | Business applications ([Census BFS](https://www.census.gov/programs-surveys/bfs.html)) | county, state, nation | 2004–present |
| [cori.data.bps](https://github.com/ruralinnovation/cori.data.bps) | Building permits ([Census BPS](https://www.census.gov/construction/bps/)) | county, metro | 1980–present |
| [cori.data.hu](https://github.com/ruralinnovation/cori.data.hu) | Housing units ([Census HU](https://www.census.gov/programs-surveys/popest.html)) | county, state, nation | 2000–present |
| [cori.data.fcc](https://github.com/ruralinnovation/cori.data.fcc) | Broadband coverage ([FCC NBM](https://broadbandmap.fcc.gov/)) | county | 2023–present |
| [ruraldefinitions](https://github.com/ruralinnovation/ruraldefinitions) | Rural classifications ([OMB](https://www.census.gov/programs-surveys/metro-micro.html), [USDA ERS](https://www.ers.usda.gov/topics/rural-economy-population/rural-classifications/), [NCHS](https://www.cdc.gov/nchs/data_access/urban_rural.htm)) | county | multiple vintages |

---

## Data sources

### BLS Quarterly Census of Employment and Wages (QCEW)

The Quarterly Census of Employment and Wages (QCEW) program, administered by
the U.S. Bureau of Labor Statistics, publishes quarterly data on employment
levels and wages for workers covered by state unemployment insurance (UI) laws,
capturing approximately 95% of all U.S. jobs. Data are organized by industry
using North American Industry Classification System (NAICS) codes and are
available at the county, state, and national level from 1990 onward. Because
QCEW counts are derived from employer tax filings rather than surveys, they
represent a near-complete census of covered employment rather than an estimate.
The QCEW is the primary source for understanding labor market structure, wage
levels, and industry composition across geographies.

> The Center on Rural Innovation's curation of U.S. Bureau of Labor Statistics,
> *Quarterly Census of Employment and Wages*. <https://www.bls.gov/cew/>
>
> BLS.gov cannot vouch for the data or analyses derived from these data after
> the data have been retrieved from BLS.gov.

---

### Census Bureau Business Dynamics Statistics (BDS)

The Business Dynamics Statistics (BDS) program, produced by the U.S. Census
Bureau, provides annual measures of establishment entry and exit, job creation
and destruction, and firm age and size distributions across the private sector.
Data are derived from the Longitudinal Business Database (LBD), which tracks
all U.S. employer establishments over time, and cover the full private-sector
universe from 1978 onward. The BDS is the primary public dataset for studying
the role of new and young businesses in job growth and for tracking trends in
entrepreneurship by firm size, age, and geography.

> The Center on Rural Innovation's curation of U.S. Census Bureau,
> *Business Dynamics Statistics*. <https://www.census.gov/programs-surveys/bds.html>
>
> This product uses the Census Bureau Data API but is not endorsed or certified
> by the Census Bureau.

---

### Census Bureau Population Estimates Program (PEP)

The Population Estimates Program (PEP), administered by the U.S. Census Bureau,
produces annual estimates of the resident population for counties, states, and
the nation between decennial census years. Estimates are constructed using the
most recent decennial census as a base and incorporate administrative records on
births, deaths, and domestic and international migration from federal sources.
County-level estimates are available from 2000 onward and are updated annually
with vintage-controlled series that supersede prior estimates. The PEP is the
standard source for intercensal population data and is used extensively in
per-capita calculations, federal funding formulas, and demographic research.

> The Center on Rural Innovation's curation of U.S. Census Bureau,
> *Population Estimates Program*. <https://www.census.gov/programs-surveys/popest.html>
>
> This product uses the Census Bureau Data API but is not endorsed or certified
> by the Census Bureau.

---

### Census Bureau Business Formation Statistics (BFS)

The Business Formation Statistics (BFS) program, produced by the U.S. Census
Bureau, provides weekly and quarterly data on new business applications derived
from IRS employer identification number (EIN) filings. Applications are
classified by their projected likelihood of becoming employer businesses,
distinguishing speculative formations from those likely to hire workers. State-
and county-level data are available from 2004 onward, providing a high-frequency
leading indicator of entrepreneurial activity that predates annual business
surveys by months. The BFS is particularly useful for tracking the pace of
business formation in response to economic shocks and local policy changes.

> The Center on Rural Innovation's curation of U.S. Census Bureau,
> *Business Formation Statistics*. <https://www.census.gov/programs-surveys/bfs.html>
>
> This product uses the Census Bureau Data API but is not endorsed or certified
> by the Census Bureau.

---

### Census Bureau Building Permits Survey (BPS)

The Building Permits Survey (BPS), conducted by the U.S. Census Bureau,
collects monthly data on new privately-owned residential construction units
authorized by building permits from permit-issuing jurisdictions across the
country. The survey covers approximately 20,000 permit-issuing places and
provides county- and metropolitan-area-level indicators of housing supply
activity from 1980 onward. Because permits are required before construction
begins, the BPS provides one of the earliest available signals of new housing
investment and is widely used in housing market research and local planning.

> The Center on Rural Innovation's curation of U.S. Census Bureau,
> *New Residential Construction: Building Permits Survey*. <https://www.census.gov/construction/bps/>
>
> This product uses the Census Bureau Data API but is not endorsed or certified
> by the Census Bureau.

---

### Census Bureau Housing Unit Estimates (HU)

The Housing Unit Estimates program, produced as part of the U.S. Census
Bureau's Population Estimates Program, provides annual estimates of the total
number of housing units for counties, states, and the nation. Estimates use the
most recent decennial census housing inventory as a base and incorporate building
permit issuances, demolitions, and administrative conversions to track changes in
the housing stock. County-level estimates are available from 2000 onward and are
updated annually alongside population estimates. These data are used in federal
allocation formulas, housing policy analysis, and as denominators for vacancy
and occupancy rate calculations.

> The Center on Rural Innovation's curation of U.S. Census Bureau,
> *Housing Unit Estimates (Population Estimates Program)*. <https://www.census.gov/programs-surveys/popest.html>
>
> This product uses the Census Bureau Data API but is not endorsed or certified
> by the Census Bureau.

---

### FCC National Broadband Map (NBM)

The National Broadband Map (NBM), administered by the Federal Communications
Commission, provides location-level data on broadband internet availability
across the United States collected from internet service providers under the
Broadband Data Collection (BDC) program. The BDC was established by the
Broadband DATA Act and expanded under the Infrastructure Investment and Jobs Act
of 2021, replacing the prior Form 477 census-block reporting with more precise
location-level availability data. Data are released on a bi-annual schedule
(December and June reference dates) and include coverage by technology type and
advertised upload and download speeds. The NBM is the primary federal source
for identifying unserved and underserved areas and for tracking progress toward
national broadband deployment goals.

> The Center on Rural Innovation's curation of Federal Communications Commission,
> *National Broadband Map — Broadband Data Collection*. <https://broadbandmap.fcc.gov/>
>
> Broadband availability data from the FCC BDC are in the public domain
> (17 U.S.C. § 105).

---

### Rural Classifications

The `ruraldefinitions` package provides county-level rural/nonrural
classifications drawn from four federal methodologies. The CORI standard uses
Office of Management and Budget (OMB) Core Based Statistical Area (CBSA)
delineations, which classify counties outside of metropolitan statistical areas
as rural. The USDA Economic Research Service Rural-Urban Continuum Codes (RUCC)
extend this by distinguishing metropolitan counties by population size and
nonmetropolitan counties by degree of urbanization and adjacency to metro areas.
The CDC National Center for Health Statistics (NCHS) urban-rural classification
and the USDA Urban Influence Codes (UIC) offer additional gradations suited to
health research and economic policy contexts, respectively. Each system reflects
different criteria and assumptions, and the choice of classification can
materially affect research conclusions about rural areas.

> The Center on Rural Innovation's curation of U.S. Census Bureau,
> *Metropolitan and Micropolitan Statistical Areas (OMB delineations)*.
> <https://www.census.gov/programs-surveys/metro-micro.html>
>
> The Center on Rural Innovation's curation of USDA Economic Research Service,
> *Rural-Urban Continuum Codes*. <https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/>
>
> The Center on Rural Innovation's curation of National Center for Health Statistics,
> *Urban-Rural Classification Scheme for Counties*. <https://www.cdc.gov/nchs/data_access/urban_rural.htm>
>
> The Center on Rural Innovation's curation of USDA Economic Research Service,
> *Urban Influence Codes*. <https://www.ers.usda.gov/data-products/urban-influence-codes/>
>
> This product uses the Census Bureau Data API but is not endorsed or certified
> by the Census Bureau.

---

## A consistent interface

Every data package speaks the same language. Once you learn one, you know them all.

```r
library(cori.data.qcew)
library(cori.data.pep)
library(cori.data.bds)

# Employment by county, last 5 years
get_employment(geography = "county", years = 2019:2023)

# Population by county, last 5 years
get_population(geography = "county", years = 2019:2023)

# Business dynamics by county, last 5 years
get_business_dynamics(geography = "county", years = 2019:2023)

# Filter to specific places with FIPS codes
get_employment(geoids = c("33009", "54011", "30001"), years = 2019:2023)
```

All functions return **tidy (long) format** data — one row per
`geoid × year × variable`, ready for `dplyr`, `ggplot2`, and `tidyr`.

---

## Rural classifications

The `ruraldefinitions` package gives you county-level rural classifications
across multiple vintages and methodologies:

```r
library(ruraldefinitions)

# CBSA-based rural/nonrural (the CORI standard)
rural <- get_definition("cbsa", 2023)
# Returns: geoid | name | year | rural_def | is_rural ("Rural" / "Nonrural")

# Other available definitions
get_definition("rucc", 2023)  # USDA Rural-Urban Continuum Codes
get_definition("nchs", 2023)  # NCHS Urban-Rural Classification Scheme
get_definition("uic",  2024)  # USDA Urban Influence Codes
```

---

## Cross-package analysis

The real power of the ecosystem comes from combining packages. Here's a taste:

```r
library(cori.data.qcew)
library(cori.data.pep)
library(ruraldefinitions)
library(dplyr)

# Employment rate = covered employment / working-age population (16+)
emp <- get_employment(geography = "county", years = 2010:2023)
pop <- get_population(geography = "county", years = 2010:2023,
                      variables = "population_16plus")

emp_rate <- emp |>
  filter(variable == "employment") |>
  select(geoid, year, employment = value) |>
  left_join(
    pop |> filter(variable == "population_16plus") |>
      select(geoid, year, pop_16plus = value),
    by = c("geoid", "year")
  ) |>
  mutate(emp_rate = employment / pop_16plus)

# Add rural classification and summarize
get_definition("cbsa", 2023) |>
  select(geoid, is_rural) |>
  left_join(emp_rate, by = "geoid") |>
  group_by(year, is_rural) |>
  summarize(avg_emp_rate = weighted.mean(emp_rate, employment, na.rm = TRUE))
```

For a full walkthrough — including charts and maps — see the
**[Getting Started vignette](vignettes/getting-started.Rmd)**.

---

## Infrastructure (for developers)

### Connecting to S3 via DuckDB

`connect_to_s3()` opens a DuckDB connection configured for S3 access, using
the same local-then-vended credential resolution as the S3 functions.
`has_local_aws_credentials()` checks whether local credentials are configured.

```r
con <- cori.data::connect_to_s3("cori.data.bds")
on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
DBI::dbGetQuery(con, "SELECT * FROM read_parquet('s3://cori.data.bds/**/*.parquet')")
```

### S3 object functions

The AWS S3 functions (`get_s3_object()`, `list_s3_objects()`,
`list_s3_buckets()`, `put_s3_object()`, `put_s3_objects_recursive()`,
`read_s3_object()`, `write_s3_object()`, `set_aws_credentials()`) provide
direct S3 access for package maintainers.

Reads use local AWS credentials when available, and otherwise fall back to
temporary read-only credentials — no local AWS setup required. Writes always
require local credentials.

---

## Contributing

We're a small team building tools for rural researchers, and we welcome
collaborators. If you find a bug, want a feature, or have data we should add
to the ecosystem, open an issue or start a discussion on any of the package
repositories above.

All packages follow the same design principles: tidy output, consistent
parameters, plain-English variable names, and no infrastructure knowledge
required. If you're building something that fits that model, we'd love to talk.

---

## Terms of use

Data in this ecosystem are curated from U.S. federal agency sources and
provided "as is" without warranty of any kind. The Center on Rural Innovation
processes and packages these data to improve accessibility for rural research
but cannot guarantee their accuracy, completeness, or timeliness, and cannot
vouch for analyses derived from these data after retrieval.

The following notices are required by the terms of service of the underlying
data providers:

- **Census Bureau:** This product uses the Census Bureau Data API but is not
  endorsed or certified by the Census Bureau.
- **BLS:** BLS.gov cannot vouch for the data or analyses derived from these
  data after the data have been retrieved from BLS.gov.
- **FCC:** Broadband availability data from the FCC Broadband Data Collection
  are in the public domain (17 U.S.C. § 105).

Full terms of service for each provider:

- [Census Bureau API Terms of Service](https://www.census.gov/data/developers/about/terms-of-service.html)
- [BLS Terms of Service](https://www.bls.gov/developers/termsOfService.htm)
- [FCC National Broadband Map — License and Attribution](https://broadbandmap.fcc.gov/about)