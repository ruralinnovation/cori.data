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
| [cori.data.qcew](https://github.com/ruralinnovation/cori.data.qcew) | Employment & wages (BLS QCEW) | county, state | 1990–present |
| [cori.data.bds](https://github.com/ruralinnovation/cori.data.bds) | Business dynamics (Census BDS) | county, state, nation | 1978–present |
| [cori.data.pep](https://github.com/ruralinnovation/cori.data.pep) | Population (Census PEP) | county, state, nation | 2000–present |
| [cori.data.bfs](https://github.com/ruralinnovation/cori.data.bfs) | Business applications (Census BFS) | county, state, nation | 2004–present |
| [cori.data.bps](https://github.com/ruralinnovation/cori.data.bps) | Building permits (Census BPS) | county, metro | 1980–present |
| [cori.data.hu](https://github.com/ruralinnovation/cori.data.hu) | Housing units (Census HU) | county, state, nation | 2000–present |
| [cori.data.fcc](https://github.com/ruralinnovation/cori.data.fcc) | Broadband coverage (FCC NBM) | county | 2023–present |
| [ruraldefinitions](https://github.com/ruralinnovation/ruraldefinitions) | Rural classifications | county | multiple vintages |

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