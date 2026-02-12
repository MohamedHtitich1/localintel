# Getting Started with localintel

## Overview

**localintel** (Local Intelligence) is an R package that provides a
unified pipeline for **150+ subnational indicators across 14 thematic
domains** from Eurostat. Any regional dataset — economy, health,
education, labour, demographics, tourism, transport, environment, and
more — can be fetched, harmonized, cascaded to NUTS 2, scored, mapped,
and exported through a single consistent workflow.

## Installation

``` r
# install.packages("devtools")
devtools::install_github("MohamedHtitich1/localintel")
```

``` r
library(localintel)
```

## Step 1: Browse the Indicator Registry

localintel ships with curated code lists for 14 Eurostat domains:

``` r
# How many indicators are available?
n <- indicator_count()
cat(n$indicators, "indicators across", n$domains, "domains\n")
print(n$by_domain)

# View codes for a specific domain
economy_codes()
labour_codes()
education_codes()
```

## Step 2: Fetch Data from Eurostat

Use
[`fetch_eurostat_batch()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md)
to download multiple datasets at once:

``` r
# Fetch economy indicators at NUTS2 level
econ_data <- fetch_eurostat_batch(economy_codes(), level = 2, years = 2015:2024)
econ_data <- drop_empty(econ_data)

# Fetch health indicators
hlth_data <- fetch_eurostat_batch(health_system_codes(), level = 2, years = 2015:2024)
hlth_data <- drop_empty(hlth_data)

# Fetch labour indicators
lab_data <- fetch_eurostat_batch(labour_codes(), level = 2, years = 2015:2024)
lab_data <- drop_empty(lab_data)
```

For individual datasets with more control:

``` r
gdp_raw <- get_nuts_level_robust("nama_10r_2gdp", level = 2, years = 2015:2024)
```

## Step 3: Process Datasets

Use domain-specific processors or the universal
[`process_eurostat()`](https://mohamedhtitich1.github.io/localintel/reference/process_eurostat.md):

``` r
# Domain-specific processors
gdp       <- process_gdp(econ_data$gdp_nuts2)
beds      <- process_beds(hlth_data$beds)
unemp     <- process_unemployment_rate(lab_data$unemployment_rate)

# Or the generic processor for any dataset
life_exp <- process_eurostat(
  get_nuts_level_robust("demo_r_mlifexp", level = 2, years = 2015:2024),
  filters = list(sex = "T", age = "Y_LT1"),
  out_col = "life_expectancy"
)
```

Combine processed datasets:

``` r
all_data <- merge_datasets(gdp, beds, unemp, life_exp)
```

## Step 4: Cascade Data to NUTS 2

Not every region reports at NUTS 2. The cascade fills gaps from parent
levels:

``` r
nuts2_ref <- get_nuts2_ref()

cascaded <- cascade_to_nuts2(
  all_data,
  vars = c("gdp", "beds", "unemployment_rate", "life_expectancy"),
  nuts2_ref = nuts2_ref,
  years = 2015:2024
)

# Check source levels — how much data was cascaded?
table(cascaded$src_gdp_level)
```

## Step 5: Visualize

``` r
geopolys <- get_nuts_geopolys()

plot_best_by_country_level(
  cascaded, geopolys,
  var = "unemployment_rate",
  years = 2022:2024,
  title = "Unemployment Rate (%)",
  scale = "global"
)
```

## Step 6: Export

``` r
# Single variable
sf_data <- build_display_sf(cascaded, geopolys, var = "gdp", years = 2015:2024)
export_to_geojson(sf_data, "output/gdp_nuts2.geojson")

# Multi-variable with labels and domain grouping
sf_all <- build_multi_var_sf(
  cascaded, geopolys,
  vars = c("gdp", "beds", "unemployment_rate", "life_expectancy"),
  years = 2015:2024,
  var_labels = regional_var_labels(),
  pillar_mapping = regional_domain_mapping()
)

sf_enriched <- enrich_for_tableau(sf_all, get_population_nuts2(), get_nuts2_names())
export_to_geojson(sf_enriched, "output/multi_domain_dashboard.geojson")
```

## Data Sources

localintel works with the full Eurostat regional statistics catalogue.
Use
[`all_regional_codes()`](https://mohamedhtitich1.github.io/localintel/reference/all_regional_codes.md)
for the complete list, or domain-specific functions like
[`economy_codes()`](https://mohamedhtitich1.github.io/localintel/reference/economy_codes.md),
[`education_codes()`](https://mohamedhtitich1.github.io/localintel/reference/education_codes.md),
[`tourism_codes()`](https://mohamedhtitich1.github.io/localintel/reference/tourism_codes.md),
etc.
