# Broadband as Economic Infrastructure

``` r

library(cori.data)
library(cori.data.qcew)
library(cori.data.fcc)
library(ruraldefinitions)
library(cori.charts)
library(dplyr)
library(ggplot2)
library(sf)
library(tigris)
library(scales)
library(stringr)

load_fonts()
update_cori_geom_defaults()
```

Broadband access is increasingly inseparable from economic
participation. Remote work, e-commerce, telemedicine, and digital
services all depend on reliable, high-speed internet — and rural areas
have historically faced the greatest gaps in coverage.

The `cori.data.fcc` package provides access to the FCC’s National
Broadband Map (NBM), which tracks broadband serviceable locations at the
address level. This vignette shows how to pull county-level broadband
data and connect it to economic outcomes.

## How FCC NBM data works

The NBM measures whether locations can **receive** broadband service at
a given speed threshold — it does not measure actual adoption or usage.
Key metrics available at the county level:

| Variable | Description |
|----|----|
| `cnt_total_locations` | Total serviceable locations |
| `cnt_fiber_locations` | Locations with fiber infrastructure |
| `cnt_100_20` | Locations with 100/20 Mbps coverage |
| `cnt_25_3` | Locations with 25/3 Mbps coverage (legacy FCC threshold) |

Data is published in releases: `"D23"` (December 2023), `"J24"` (June
2024), `"D24"` (December 2024), `"J25"` (June 2025). Use
`release = "latest"` for the most current data.

## Pulling broadband data

[`get_nbm_county()`](https://ruralinnovation.github.io/cori.data.fcc/reference/get_nbm_county.html)
queries one county at a time. For a state or regional analysis, loop
across county FIPS codes using
[`lapply()`](https://rdrr.io/r/base/lapply.html):

``` r

# Get all West Virginia county FIPS codes
wv_counties <- counties(year = 2024) |>
  filter(substr(GEOID, 1, 2) == "54") |>
  pull(GEOID)

# Pull broadband coverage for each county
broadband_wv <- lapply(wv_counties, function(cnty) {
  get_nbm_county(geoid_co = cnty, release = "latest")
}) |>
  bind_rows() |>
  mutate(
    pct_100_20 = cnt_100_20 / cnt_total_locations,
    pct_fiber  = cnt_fiber_locations / cnt_total_locations
  )
```

## Map: broadband coverage in West Virginia

``` r

wv_counties_sf <- counties( year = 2024) |>
  filter(substr(GEOID, 1, 2) == "54") |>
  left_join(broadband_wv, by = c("GEOID" = "geoid"))

wv_state_sf <- states(year = 2024) |>
  filter(GEOID == "54")

fig_map <- ggplot() +
  geom_sf(
    data      = wv_state_sf,
    fill      = "#FBF8E9",
    color     = "#d0d2ce",
    linewidth = 0.6
  ) +
  geom_sf(
    data  = wv_counties_sf,
    aes(fill = pct_100_20),
    color = "#d0d2ce",
    linewidth = 0.3
  ) +
  scale_fill_cori(
    palette  = "ctg3gn",
    discrete = FALSE,
    labels   = label_percent(accuracy = 1),
    na.value = "#d0d2ce"
  ) +
  theme_cori_map() +
  labs(
    title    = "Broadband access remains uneven across West Virginia",
    subtitle = "Share of serviceable locations with 100/20 Mbps coverage, latest FCC NBM release",
    caption  = str_wrap(
      "Source: FCC National Broadband Map via cori.data.fcc. Coverage reflects serviceable locations, not adoption.",
      width = 110
    ),
    fill = "100/20 Mbps\ncoverage"
  )

fig_map
```

## Connecting broadband to employment

Does broadband coverage correlate with stronger employment outcomes?
Joining FCC data with QCEW employment and rural classification gives a
first look:

``` r

# Employment rate in WV counties
emp <- get_employment(geoids = wv_counties, years = 2025) |>
  filter(variable == "employment") |>
  select(geoid, employment = value)

pop16 <- get_population(geoids = wv_counties, years = 2025) |>
  filter(variable == "population_16plus") |>
  select(geoid, pop_16plus = value)

rural <- cbsa_2023 |> select(geoid, is_rural)

wv_combined <- broadband_wv |>
  left_join(emp,   by = "geoid") |>
  left_join(pop16, by = "geoid") |>
  left_join(rural, by = "geoid") |>
  mutate(emp_rate = employment / pop_16plus) |>
  filter(!is.na(emp_rate), !is.na(pct_100_20))
```

``` r

 fig_scatter <- wv_combined |>                                                                                                                                                                
    ggplot(aes(
      x     = pct_100_20,                                                                            
      y     = emp_rate,                                                                             
      color = is_rural,
      size  = cnt_total_locations
    )) +                                                                               
    geom_point(alpha = 0.7) +
    geom_smooth(
      method = "lm", se = FALSE, linewidth = 1, aes(group = 1),                                                                               
      color = cori_colors["CORI Gray"]) +                                                       
    scale_color_cori(
      palette = "ctg2ruralnonrural",
      guide   = guide_legend(order = 1)
    ) +
    scale_x_continuous(
      labels = label_percent(accuracy = 1), 
      limits = c(0.25, 1.01)
      ) +
    scale_y_continuous(labels = label_percent(accuracy = 1)) +
    scale_size_continuous(
      range  = c(1, 8),
      labels = label_comma(),
      name   = "Broadband location size",
      guide  = guide_legend(order = 2)
    ) +
    theme_cori() +
    theme(
      legend.box = "vertical",
      axis.ticks.x = element_line()
      ) +
    labs(
      title    = "West Virginia Broadband coverage and labor force participation \nrate",
      subtitle = "Dots sized by number of broadband serviceable locations",
      caption  =                                                                                                                                                                     
        "Sources: 2025 FCC National Broadband Map; 2025 BLS QCEW; 2025 Census PEP. \nRural classification: CBSA 2023.",
      color = NULL,
      x     = "Share of locations with 100/20 Mbps coverage",
      y     = "Labor force participation rate"                                                                                                                                                                                                                                
    )

fig_scatter
```

## A note on interpretation

The FCC NBM measures **availability**, not **adoption**. A location
counted as covered may not have a subscribing household. In rural areas,
cost and digital literacy barriers can mean that even where coverage
exists, actual connectivity lags behind what the map suggests. Use
availability data as a floor estimate — the actual connected share is
likely lower.

For deeper analysis of broadband and economic outcomes in rural
communities, see [CORI’s broadband
research](https://ruralinnovation.us/our-work/research/).

## What broadband analysis reveals

Broadband coverage is uneven within rural geographies, not just between
rural and nonrural. Counties that are both classified as rural can
differ dramatically in their connectivity — reflecting topography,
population density, the presence of anchor institutions, and the pace of
infrastructure investment driven by federal programs like BEAD. That
variation is analytically useful: it lets you study broadband as a
factor in economic outcomes rather than treating all rural counties as
equally underconnected.

Counties that have seen meaningful improvements in coverage across
consecutive NBM releases are worth watching. The bi-annual data
structure — December and June reference dates — makes it possible to
track the deployment wave in near real time and connect it to labor
market and business formation trends as they unfold. Rural broadband is
one of the faster-moving stories in this ecosystem, and the data is now
granular enough to follow it at the county level.

## Data sources

> The Center on Rural Innovation’s curation of Federal Communications
> Commission, *National Broadband Map — Broadband Data Collection*.
> <https://broadbandmap.fcc.gov/>
>
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
> Broadband availability data from the FCC BDC are in the public domain
> (17 U.S.C. § 105). This product uses the Census Bureau Data API but is
> not endorsed or certified by the Census Bureau. BLS.gov cannot vouch
> for the data or analyses derived from these data after the data have
> been retrieved from BLS.gov.
