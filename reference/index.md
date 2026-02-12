# Package index

## Package Overview

- [`localintel-package`](https://mohamedhtitich1.github.io/localintel/reference/localintel-package.md)
  [`localintel`](https://mohamedhtitich1.github.io/localintel/reference/localintel-package.md)
  : Local Intelligence for Subnational Data Analysis

## Data Fetching

Robust wrappers for the Eurostat API — fetch single or batch datasets at
any NUTS level with automatic retry and caching.

- [`get_nuts2()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md)
  [`get_nuts_level()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md)
  [`get_nuts_level_robust()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md)
  [`get_nuts_level_safe()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md)
  [`fetch_eurostat_batch()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md)
  [`drop_empty()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md)
  : Eurostat Data Fetching Functions
- [`health_system_codes()`](https://mohamedhtitich1.github.io/localintel/reference/health_system_codes.md)
  [`causes_of_death_codes()`](https://mohamedhtitich1.github.io/localintel/reference/health_system_codes.md)
  : Eurostat Dataset Code Lists

## Reference Data

NUTS boundary geometries, hierarchical lookup tables, and population
data for spatial joins and cascading.

- [`get_nuts2_ref()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md)
  [`get_nuts_geo()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md)
  [`get_nuts_geopolys()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md)
  [`get_nuts2_names()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md)
  [`get_population_nuts2()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md)
  : NUTS Reference Data Functions
- [`keep_eu27()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md)
  [`eu27_codes()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md)
  [`nuts_country_names()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md)
  [`add_country_name()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md)
  : EU27 Country Filtering and Naming Functions

## Data Processing

Transform raw Eurostat downloads into analysis-ready tables — one
function per dataset, plus merging and composite scoring.

- [`process_beds()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  [`process_physicians()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  [`process_los()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  [`process_hos_days()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  [`process_disch_inp()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  [`process_disch_day()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  [`process_cod()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  [`process_health_perceptions()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  [`merge_datasets()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  [`compute_composite()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  [`transform_and_score()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md)
  : Data Processing Functions

## Data Cascading

Fill missing regional data by propagating from parent NUTS levels (NUTS0
→ NUTS1 → NUTS2) with source-level tracking.

- [`cascade_to_nuts2_and_compute()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md)
  [`cascade_to_nuts2_light()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md)
  [`balance_panel()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md)
  : Data Cascading Functions

## Visualization

Build spatial objects and render publication-ready tmap facets —
automatic best-level selection per country-year.

- [`build_display_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)
  [`lc_build_display_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)
  [`plot_best_by_country_level()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)
  [`build_multi_var_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)
  [`level_col_for()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)
  [`level_cols_for()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)
  : Visualization Functions

## Export

Export enriched GeoJSON for Tableau, multi-sheet Excel workbooks, RDS
snapshots, and multi-page PDF map books.

- [`export_to_geojson()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`export_to_excel()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`export_to_rds()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`save_maps_to_pdf()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`enrich_for_tableau()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`health_var_labels()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`health_pillar_mapping()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`cod_labels()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  : Export Functions

## Utilities

Helper functions for safe transformations, min-max scaling,
interpolation, EU27 filtering, and country-name enrichment.

- [`keep_eu27()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md)
  [`eu27_codes()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md)
  [`nuts_country_names()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md)
  [`add_country_name()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md)
  : EU27 Country Filtering and Naming Functions
- [`safe_log10()`](https://mohamedhtitich1.github.io/localintel/reference/safe_log10.md)
  [`safe_log2()`](https://mohamedhtitich1.github.io/localintel/reference/safe_log10.md)
  [`scale_0_100()`](https://mohamedhtitich1.github.io/localintel/reference/safe_log10.md)
  [`rescale_minmax()`](https://mohamedhtitich1.github.io/localintel/reference/safe_log10.md)
  : Safe Logarithm and Scaling Functions
- [`interp_const_ends_flag()`](https://mohamedhtitich1.github.io/localintel/reference/interp_const_ends_flag.md)
  [`standardize_time()`](https://mohamedhtitich1.github.io/localintel/reference/interp_const_ends_flag.md)
  : Data Interpolation and Time Utilities
