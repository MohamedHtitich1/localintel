# Getting Started with localintel

## Overview

**localintel** (Local Intelligence) is an R package for fetching,
processing, and visualizing subnational (NUTS 0/1/2) data from Eurostat.
It provides a complete pipeline from raw Eurostat data to
publication-ready maps and Tableau-ready exports.

## Installation

Install localintel from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("MohamedHtitich1/localintel")
```

``` r
library(localintel)
```

## Step 1: Fetch Data from Eurostat

The package provides pre-defined code lists for common health system
datasets. Use
[`fetch_eurostat_batch()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md)
to download multiple datasets at once:

``` r
# View available dataset codes
codes <- health_system_codes()
print(codes)

# Fetch all datasets at NUTS2 level
data_list <- fetch_eurostat_batch(codes, level = 2, years = 2010:2024)

# Remove any datasets that returned empty
data_list <- drop_empty(data_list)
```

You can also fetch individual datasets with more control:

``` r
# Fetch a single dataset
beds_raw <- get_nuts_level_robust("hlth_rs_bdsrg2", level = 2, years = 2010:2024)
```

## Step 2: Process Datasets

Each Eurostat dataset has a dedicated processing function that filters
for the correct indicators and reshapes the data:

``` r
beds       <- process_beds(data_list$beds)
physicians <- process_physicians(data_list$physicians)
los        <- process_los(data_list$los)
disch_inp  <- process_disch_inp(data_list$disch_inp)
```

Combine processed datasets into a single table:

``` r
all_data <- merge_datasets(beds, physicians, los, disch_inp)
```

## Step 3: Get Reference Data

Reference geometries and lookup tables are needed for cascading and
mapping:

``` r
# NUTS2 reference table (maps NUTS2 codes to parent NUTS1/NUTS0)
nuts2_ref <- get_nuts2_ref()

# Combined NUTS 0/1/2 boundary geometries
geopolys <- get_nuts_geopolys()
```

## Step 4: Cascade Data to NUTS2

Not every region reports data at the NUTS2 level. The cascade functions
intelligently fill gaps by propagating values from parent NUTS levels:

    NUTS0 (Country) → NUTS1 (Major Regions) → NUTS2 (Regions)

The full cascade also computes derived indicators like Discharge
Activity (DA) and Relative Length of Stay (rLOS):

``` r
cascaded <- cascade_to_nuts2_and_compute(
  all_data,
  vars = c("beds", "physicians", "los"),
  nuts2_ref = nuts2_ref,
  years = 2010:2024
)
```

For pre-computed scores where you just need cascading without indicator
computation:

``` r
cascaded_light <- cascade_to_nuts2_light(
  scored_data,
  vars = c("score_health_outcome"),
  nuts2_ref = nuts2_ref,
  years = 2010:2024
)
```

## Step 5: Visualize

Create publication-ready maps that automatically select the best
available NUTS level for each country:

``` r
# Maps with consistent color scale across years
plot_best_by_country_level(
  cascaded, geopolys,
  var = "beds",
  years = 2020:2024,
  title = "Hospital Beds per 100,000",
  scale = "global"
)

# Maps with per-year color scale
plot_best_by_country_level(
  cascaded, geopolys,
  var = "beds",
  years = 2020:2024,
  title = "Hospital Beds per 100,000",
  scale = "per_year"
)
```

## Step 6: Export for Tableau

Build enriched spatial datasets ready for Tableau:

``` r
# Single variable
sf_data <- build_display_sf(cascaded, geopolys, var = "beds", years = 2010:2024)
export_to_geojson(sf_data, "output/beds_nuts2.geojson")

# Multiple variables combined
sf_all <- build_multi_var_sf(
  cascaded, geopolys,
  vars = c("beds", "physicians", "score_health_outcome"),
  years = 2010:2024,
  var_labels = health_var_labels(),
  pillar_mapping = health_pillar_mapping()
)

# Enrich with population and performance tags
pop_data    <- get_population_nuts2()
nuts2_names <- get_nuts2_names()
sf_enriched <- enrich_for_tableau(sf_all, pop_data, nuts2_names)

export_to_geojson(sf_enriched, "tableau_export.geojson")
```

## Utility Functions

The package includes several handy utilities:

``` r
# Filter to EU27 countries only
eu_data <- keep_eu27(all_data)

# Safe log transforms (handles NA and non-positive values)
safe_log10(c(100, 0, NA, -5))
# [1] 2 NA NA NA

# Min-max normalization to 0-100
scale_0_100(c(10, 20, 30, 40, 50))
# [1]   0  25  50  75 100

# Linear interpolation with flags
interp_const_ends_flag(c(1, NA, NA, 4, NA, 6))
```

## Data Sources

localintel works with standard Eurostat datasets. See
[`health_system_codes()`](https://mohamedhtitich1.github.io/localintel/reference/health_system_codes.md)
and
[`causes_of_death_codes()`](https://mohamedhtitich1.github.io/localintel/reference/health_system_codes.md)
for the full list of pre-configured dataset identifiers.
