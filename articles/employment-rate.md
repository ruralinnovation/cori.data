# Employment Rate: A Cross-Package Story

``` r

library(cori.data)
library(cori.charts)
library(dplyr)
library(tidyr)
library(ggplot2)
library(sf)
library(tigris)
library(scales)
library(stringr)

load_fonts()
update_cori_geom_defaults()
```

Employment levels tell you how many people work somewhere. But without
context — how many people *could* work — they don’t tell you much about
a local labor market’s health. A county with 10,000 covered workers
looks very different if its working-age population is 20,000 versus
200,000.

This vignette builds a more meaningful measure — **covered employment as
a share of working-age population (16+)** — by combining data from two
packages.

## Pulling the data

``` r

# Covered employment from BLS QCEW — total workers, private + government
emp <- get_employment(geography = "county", years = 2010:2023)

# Working-age population (16+) from Census PEP
pop16 <- get_population(
  geography = "county",
  years     = 2010:2023,
  variables = "population_16plus"
)

# Rural classification — CBSA-based, 2023 vintage
rural <- cbsa_2023 |>
  select(geoid, is_rural)
```

## Computing the rate

Both datasets are tidy, so the join is clean. We extract the relevant
variable from each, then divide.

``` r

emp_wide <- emp |>
  filter(variable == "employment") |>
  select(geoid, year, employment = value)

pop_wide <- pop16 |>
  filter(variable == "population_16plus") |>
  select(geoid, year, pop_16plus = value)

emp_rate <- emp_wide |>
  inner_join(pop_wide, by = c("geoid", "year")) |>
  mutate(emp_rate = employment / pop_16plus) |>
  left_join(rural, by = "geoid") |>
  filter(!is.na(is_rural), !is.na(emp_rate))
```

## Line chart: rural vs. nonrural over time

We use an employment-weighted average so that large counties don’t get
the same voice as small ones. See the [Weighted Averages
vignette](https://ruralinnovation.github.io/cori.data/articles/weighted-averages.md)
for more on why this matters.

``` r

trend <- emp_rate |>
  group_by(year, is_rural) |>
  summarize(
    avg_emp_rate = weighted.mean(emp_rate, employment, na.rm = TRUE),
    .groups = "drop"
  )

title    <- "Rural counties have trailed nonrural on employment rates\nsince the Great Recession"
subtitle <- "Employment-weighted average covered employment rate, 2010\u20132023"
caption  <- str_wrap(
  "Source: BLS Quarterly Census of Employment and Wages; U.S. Census Bureau Population Estimates Program. Rural classification: CBSA 2023. Note: covered employment excludes self-employed workers.",
  width = 110
)

fig_line <- trend |>
  ggplot(aes(x = year, y = avg_emp_rate, color = is_rural)) +
  geom_line(linewidth = 1.5) +
  scale_color_manual(values = c("Rural" = "#00825B", "Nonrural" = "#211448")) +
  scale_x_continuous(breaks = seq(2010, 2023, by = 2)) +
  scale_y_continuous(
    labels = label_percent(accuracy = 1),
    limits = c(0, NA),
    expand = expansion(mult = c(0, 0.05))
  ) +
  theme_cori() +
  theme(legend.position = "right", legend.direction = "vertical") +
  guides(color = guide_legend(byrow = TRUE, reverse = TRUE)) +
  labs(
    title    = title,
    subtitle = subtitle,
    caption  = caption,
    color    = NULL,
    x        = NULL,
    y        = NULL
  )

fig_line
```

## County map: where are employment rates lowest?

``` r

counties_sf <- counties(year = 2024) |>
  shift_geometry() |>
  select(geoid = GEOID) |> 
  filter( as.numeric(substr(geoid, 1, 2)) < 60 ) ## filter for US states

states_sf <- states(year = 2024) |>
  shift_geometry() |> 
  filter( as.numeric(GEOID) < 60 )

map_data <- emp_rate |>
  filter(year == 2023) |>
  select(geoid, emp_rate) |>
  mutate(quintile = cut_number(emp_rate, n = 5))

counties_map <- counties_sf |>
  left_join(map_data, by = "geoid")

fig_map <- ggplot() +
  geom_sf(
    data      = states_sf,
    fill      = "#FBF8E9",
    color     = "#d0d2ce",
    linewidth = 0.4
  ) +
  geom_sf(
    data  = counties_map,
    aes(fill = quintile),
    color = NA
  ) +
  scale_fill_manual(
    values   = colorRampPalette(c("#d4ede6", "#00825B"))(5),
    na.value = "#d0d2ce",
    labels   = c("1st (lowest)", "2nd", "3rd", "4th", "5th (highest)"),
    na.translate = FALSE
  ) +
  theme_cori_map() +
  labs(
    title    = "Employment rates vary widely across rural counties",
    subtitle = "Covered employment as share of population 16+, 2023",
    caption  = str_wrap(
      "Sources: BLS QCEW; Census Bureau Population Estimates Program; U.S. Census Bureau TIGER/Line Shapefiles via the tigris R package. Rural classification: CBSA 2023.",
      width = 110
    ),
    fill = "Employment\nrate quintile"
  )

fig_map
```

## What this analysis reveals

When you run this across U.S. counties, a persistent gap emerges: rural
counties have carried lower covered employment rates than nonrural
counties since the Great Recession, and the gap has not fully closed
even during the tightest labor markets in recent memory. The pattern
isn’t uniform — rural counties anchored by large employers or adjacent
to metro areas can rival nonrural peers — but the central tendency is
clear and durable.

The cross-package approach here gives a cleaner picture of labor market
health than either dataset alone. Raw employment counts can’t tell you
whether a county is punching above or below its demographic weight; the
employment rate can. And because both the numerator (QCEW) and
denominator (PEP) follow consistent geographic and vintage conventions,
the join is clean across all counties and years.

## A note on coverage

QCEW employment counts **covered** workers — those employed by
businesses that pay into unemployment insurance. Self-employed workers,
independent contractors, and some farm workers are not included. This
means the employment rate derived here is not directly comparable to the
BLS official unemployment rate, which uses a different survey
methodology. It is most useful for comparing trends and relative
differences across geographies.

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
> *Metropolitan and Micropolitan Statistical Areas (OMB delineations)*.
> <https://www.census.gov/programs-surveys/metro-micro.html>
>
> This product uses the Census Bureau Data API but is not endorsed or
> certified by the Census Bureau. BLS.gov cannot vouch for the data or
> analyses derived from these data after the data have been retrieved
> from BLS.gov.
