# Weighted Averages and agg_var

``` r

library(cori.data.qcew)
library(ruraldefinitions)
library(cori.charts)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)
library(stringr)

load_fonts()
update_cori_geom_defaults()
```

Counties are not equal in size. Loving County, Texas has a few hundred
residents; Los Angeles County, California has ten million. When you
average a rate across counties — wages, employment share, sector
composition — treating each county as one observation lets the hundreds
of tiny counties dominate the result, even though they collectively
represent a small fraction of the actual workforce.

This distortion is especially consequential in rural analysis. The rural
landscape is dominated by small counties, and a handful of them with
large employers — a mine, a power plant, a major hospital system — can
pull a naive average far from the typical rural worker’s experience. The
same problem applies when aggregating counties to regions: summing wages
is meaningless; you need to weight by how many workers each wage
represents.

The CORI data ecosystem addresses this with `agg_var` — an employment
weight returned alongside certain variables that makes the correct
aggregation a single function call.

## What is `agg_var`?

Some functions return a fifth column — `agg_var` — alongside the
standard `geoid | year | variable | value`. This is the **employment
weight**: the denominator used to properly aggregate rates and shares
across geographies.

| Function | Variable | `agg_var` |
|----|----|----|
| [`get_wage_salary()`](https://ruralinnovation.github.io/cori.data.qcew/reference/get_wage_salary.html) | `avg_pay` | Total employment |
| [`get_sector_employment()`](https://ruralinnovation.github.io/cori.data.qcew/reference/get_sector_employment.html) | `emp_share` | Total employment |
| [`get_sector_wages()`](https://ruralinnovation.github.io/cori.data.qcew/reference/get_sector_wages.html) | `avg_pay` | Sector employment |

Functions that return raw counts
([`get_employment()`](https://ruralinnovation.github.io/cori.data.qcew/reference/get_employment.html),
[`get_employment_concentration()`](https://ruralinnovation.github.io/cori.data.qcew/reference/get_employment_concentration.html))
do not include `agg_var` — counts can simply be summed.

## The problem with simple averages

Suppose we want the average annual wage across all rural counties in
2023.

A simple [`mean()`](https://rdrr.io/r/base/mean.html) treats every
county equally — a county with 200 workers gets exactly the same weight
as one with 200,000. In practice, the result is dominated by hundreds of
small, low-employment rural counties that collectively represent a tiny
fraction of the actual rural workforce.

``` r

wages <- get_wage_salary(geography = "county", years = 2023) |>
  left_join(
    cbsa_2023 |> select(geoid, is_rural),
    by = "geoid"
  ) |>
  filter(!is.na(is_rural))

# Simple (naive) average — each county has equal weight
wages |>
  group_by(is_rural) |>
  summarize(avg_wage = mean(value, na.rm = TRUE))
```

This overstates wages in counties with large, high-paying employers (a
manufacturing plant, a hospital system) that happen to be in a small
county — and understates them in large rural counties that look more
like the typical rural experience.

## The correct approach: `weighted.mean()`

The fix is to weight each county’s wage by how many workers that wage
represents. That’s exactly what `agg_var` is for:

``` r

wages |>
  group_by(is_rural) |>
  summarize(
    naive_avg    = mean(value, na.rm = TRUE),
    weighted_avg = weighted.mean(value, agg_var, na.rm = TRUE)
  )
```

## Visualizing the difference

``` r

wage_comparison <- wages |>
  group_by(is_rural) |>
  summarize(
    `Simple average`        = mean(value, na.rm = TRUE),
    `Employment-weighted`   = weighted.mean(value, agg_var, na.rm = TRUE),
    .groups = "drop"
  ) |>
  pivot_longer(
    cols      = -is_rural,
    names_to  = "method",
    values_to = "avg_wage"
  )

title    <- "Employment-weighting changes the picture on wages"
subtitle <- "Average annual pay per worker, 2023"
caption  <- str_wrap(
  "Source: BLS Quarterly Census of Employment and Wages via cori.data.qcew. Rural classification: CBSA 2023.",
  width = 110
)

fig_bar <- wage_comparison |>
  ggplot(aes(x = is_rural, y = avg_wage, fill = method)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_text(
    aes(label = label_dollar(accuracy = 1)(avg_wage)),
    position  = position_dodge(width = 0.7),
    vjust     = -0.5,
    size      = 3.5,
    family    = "Lato",
    fontface  = "bold"
  ) +
  scale_fill_cori(palette = "ctg2buor") +
  scale_y_continuous(
    labels = label_dollar(scale = 1e-3, suffix = "k"),
    limits = c(0, NA),
    expand = expansion(mult = c(0, 0.15))
  ) +
  theme_cori() +
  labs(
    title    = title,
    subtitle = subtitle,
    caption  = caption,
    fill     = NULL,
    x        = NULL,
    y        = NULL
  )

fig_bar
# save_plot(fig_bar, here::here("export/wage_weighted_comparison.png"))
```

## Aggregating across geographies

`agg_var` also enables correct aggregation when you want to aggregate
counties to regions. Summing wages is meaningless — you need to weight
by employment:

``` r


rural <- cbsa_2023 |> 
  select(geoid, is_rural)

# Correct: employment-weighted regional average
sector_wages <- get_sector_wages(
  geography   = "county",
  years       = 2023,
  sector_type = "CORI"
) |>
  left_join(rural, by = "geoid") |>
  filter(!is.na(is_rural))

regional_wages <- sector_wages |>
  group_by(sector, is_rural) |>
  summarize(
    # agg_var here is sector employment — the correct weight for sector wages
    regional_avg_wage = weighted.mean(value, agg_var, na.rm = TRUE),
    total_sector_emp  = sum(agg_var, na.rm = TRUE),
    .groups = "drop"
  )
```

## Rule of thumb

Whenever a function returns `agg_var`, use
`weighted.mean(value, agg_var)` instead of `mean(value)` any time you’re
aggregating across multiple geographies. The difference matters most in
rural analysis, where high variance in county size means naive averages
can mislead analysis results significantly.

## Data sources

> The Center on Rural Innovation’s curation of U.S. Bureau of Labor
> Statistics, *Quarterly Census of Employment and Wages*.
> <https://www.bls.gov/cew/>
>
> The Center on Rural Innovation’s curation of U.S. Census Bureau,
> *Metropolitan and Micropolitan Statistical Areas (OMB delineations)*.
> <https://www.census.gov/programs-surveys/metro-micro.html>
>
> This product uses the Census Bureau Data API but is not endorsed or
> certified by the Census Bureau. BLS.gov cannot vouch for the data or
> analyses derived from these data after the data have been retrieved
> from BLS.gov.
