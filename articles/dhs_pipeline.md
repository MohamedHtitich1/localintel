# DHS Pipeline: Sub-Saharan Africa Subnational Data

## Overview

Since v0.3.0, **localintel** extends beyond EU/Eurostat to cover
**Sub-Saharan Africa** using the DHS Program Indicator Data API. The DHS
pipeline mirrors the Eurostat workflow — fetch, process, gap-fill,
cascade, visualize — but adapts each layer for DHS survey data
characteristics: irregular temporal spacing (3–13 years between
surveys), Admin 1 geographic units, and region-name instability across
survey waves.

The pipeline covers **62 indicators across 8 thematic domains** for **44
SSA countries** (35 with subnational survey data).

## Setup

``` r
library(localintel)
```

### DHS API Key

Register for a free partner key at <https://api.dhsprogram.com> and set
it as an environment variable:

``` r
# In your .Renviron or before loading the package:
Sys.setenv(DHS_API_KEY = "YOUR-KEY-HERE")

# Or add to ~/.Renviron:
# DHS_API_KEY=YOUR-KEY-HERE
```

If no key is set, the package falls back to a built-in development key.

## Step 1: Browse Available Indicators

The 62 DHS indicators span 8 domains. Each domain has its own code
registry:

``` r
# Domain code registries
dhs_health_codes()     # 11 — ANC, vaccination, skilled birth, contraception
dhs_mortality_codes()  # 5  — Under-5, infant, neonatal, perinatal, child
dhs_nutrition_codes()  # 10 — Stunting, wasting, anemia, breastfeeding
dhs_hiv_codes()        # 7  — HIV prevalence, testing, knowledge
dhs_education_codes()  # 9  — Literacy, attendance, educational attainment
dhs_wash_codes()       # 6  — Water, sanitation, handwashing
dhs_wealth_codes()     # 8  — Wealth quintiles, electricity, mobile, banking
dhs_gender_codes()     # 6  — Decision-making, domestic violence attitudes

# All 62 codes combined
all_dhs_codes()
dhs_indicator_count()  # 62

# Human-readable labels
dhs_var_labels()["u5_mortality"]
#> "Under-5 mortality rate (per 1,000)"
```

## Step 2: Fetch Data from the DHS API

``` r
# Single indicator, single country
ke_u5m <- get_dhs_data(
  country_ids  = "KE",
  indicator_ids = "CM_ECMR_C_U5M",
  breakdown     = "subnational"
)
nrow(ke_u5m)
# ~146 rows: 7 survey rounds × ~20 regions each
```

``` r
# Multi-indicator batch fetch
mortality_codes <- dhs_mortality_codes()
tier1 <- tier1_codes()  # 15 high-data-quality countries

batch_raw <- fetch_dhs_batch(
  country_ids    = tier1,
  indicator_list = mortality_codes
)
# Returns a named list: one tibble per indicator
names(batch_raw)
```

### Country Codes & Metadata

``` r
# All 44 SSA country codes
ssa_codes()

# 15 Tier 1 validation countries (~70% of SSA population)
tier1_codes()

# Discover surveys for a country
get_dhs_surveys(country_ids = "KE")
```

## Step 3: Process Raw API Data

The processing layer handles deduplication (the API returns ~1,000 exact
duplicates), reference period filtering (mortality indicators return
both 5-year and 10-year periods), and geographic key construction.

``` r
# Single indicator
ke_processed <- process_dhs(ke_u5m, indicator_id = "CM_ECMR_C_U5M")
# Columns: geo, admin0, year, region, value, indicator, ...
# geo = "KE_Nairobi", admin0 = "KE", year = 2022, ...

# Batch processing
batch_processed <- process_dhs_batch(batch_raw)
```

### Reference Tables

``` r
# Admin 1 region reference for latest survey per country
admin1_ref <- get_admin1_ref(country_ids = c("KE", "NG"))
# 54 KE counties + 43 NG states = 97 rows

# Filter to SSA only
keep_ssa(some_dataframe)

# Join country names
add_dhs_country_name(some_dataframe)
```

## Step 4: Temporal Gap-Filling

DHS surveys are conducted every 3–13 years (median 5). The gap-filling
layer interpolates between survey waves using a two-component design:

- **Point estimates**: FMM cubic spline (passes exactly through observed
  survey values — no smoothing)
- **Uncertainty**: Penalized GAM standard errors with a calibrated
  `sigma_floor` parameter for 95% prediction interval coverage

Transforms ensure natural bounds are respected: logit for proportions
(0–100%), log for rates (\>0).

``` r
# Single region time series
result <- gapfill_series(
  years     = c(2003, 2008, 2014, 2022),
  values    = c(115, 74, 52, 44),
  transform = "log"    # mortality: always positive
)
# Returns annual estimates 2003-2022 with CI

# With ETS forecasting beyond last survey
result_fcast <- gapfill_series(
  years       = c(2003, 2008, 2014, 2022),
  values      = c(115, 74, 52, 44),
  transform   = "log",
  forecast_to = 2025
)
# Adds damped-trend forecasted rows through 2025
```

``` r
# All regions for one indicator across multiple countries
gf_u5m <- gapfill_indicator(
  indicator_id = "CM_ECMR_C_U5M",
  indicator_name = "u5_mortality",
  country_ids = tier1_codes(),
  transform   = "log",
  forecast_to = 2024
)
# $gapfilled: tibble with year, estimate, ci_lo, ci_hi, source, geo, indicator
# $summary: tibble with coverage stats per country
```

``` r
# Full pipeline: all 62 indicators × all SSA countries
all_gf <- gapfill_all_dhs(
  country_ids = ssa_codes(),
  forecast_to = 2024
)
# Returns named list: one gap-filled tibble per indicator
```

## Step 5: Panel Assembly

The cascade layer assembles gap-filled output into a wide panel aligned
to an Admin 1 reference skeleton — the DHS counterpart of
[`cascade_to_nuts2()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2.md).

``` r
panel <- cascade_to_admin1(all_gf, include_ci = TRUE)
# Columns: geo, admin0, year, u5_mortality, u5_mortality_ci_lo, ...
#           src_u5_mortality_level (always 1L = Admin 1 direct),
#           imp_u5_mortality_flag (0=observed, 1=interpolated, 2=forecasted)

# Balance the panel (drop thin coverage)
balanced <- balance_dhs_panel(panel,
  min_countries  = 5,   # indicator must cover >= 5 countries
  min_indicators = 10   # region must have >= 10 non-NA indicators
)
```

### One-Step Pipeline

``` r
# Full pipeline in one call
final_panel <- dhs_pipeline(
  country_ids    = ssa_codes(),
  forecast_to    = 2024,
  min_countries  = 5,
  min_indicators = 10
)
# Returns the balanced wide panel ready for analysis
```

## Step 6: Visualization & Export

``` r
# Fetch Admin 1 geometries (GADM primary, Natural Earth fallback)
geo <- get_admin1_geo(country_ids = c("KE", "NG", "GH"))

# Country borders for basemap
basemap <- get_admin0_geo()
```

``` r
# Build display sf for one indicator
display_sf <- build_dhs_display_sf(
  panel = balanced,
  geo   = geo,
  var   = "u5_mortality",
  year  = 2020
)

# Choropleth map
plot_dhs_map(display_sf, var = "u5_mortality", year = 2020)
```

``` r
# Multi-indicator sf for Tableau / GIS export
export_sf <- build_dhs_multi_var_sf(
  panel = balanced,
  geo   = geo,
  vars  = c("u5_mortality", "stunting", "literacy_women"),
  year  = 2020
)

# Enrich with country names, averages, and performance tags
enriched <- enrich_dhs_for_tableau(export_sf)
sf::st_write(enriched, "ssa_admin1_export.gpkg")
```

## Harmonised Output Format

The DHS and Eurostat pipelines produce harmonised panel formats:

| Column            | DHS                            | Eurostat                       |
|-------------------|--------------------------------|--------------------------------|
| `geo`             | `KE_Nairobi`                   | `DE11`                         |
| `admin0`          | `KE`                           | `DE`                           |
| `year`            | 2020                           | 2020                           |
| `<indicator>`     | 44.2                           | 9.5                            |
| `src_<ind>_level` | Always `1L`                    | `0L/1L/2L`                     |
| `imp_<ind>_flag`  | `0`=obs, `1`=interp, `2`=fcast | `0`=obs, `1`=interp, `2`=fcast |

## Technical Notes

- **DHS country codes** differ from ISO for 8 countries (e.g.,
  BT=Botswana, BU=Burundi, MD=Madagascar). The package handles mapping
  internally.
- **Region name harmonization** achieves 100% geometry match rate across
  652 DHS regions via a 6-pass system: normalized text → manual
  crosswalk → composite split → dissolve lookup → non-geographic strata
  → fuzzy matching.
- **Gap-fill calibration**: The `sigma_floor=0.25` parameter yields ~87%
  leave-one-out cross-validation coverage across 17 countries (505
  predictions). Set `sigma_floor=0.30` for more conservative intervals.
