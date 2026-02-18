# Package index

## Package Overview

- [`localintel-package`](https://mohamedhtitich1.github.io/localintel/reference/localintel-package.md)
  [`localintel`](https://mohamedhtitich1.github.io/localintel/reference/localintel-package.md)
  : Local Intelligence for Subnational Data Analysis

## Indicator Registry

Curated registries of Eurostat dataset codes across 14 thematic domains
— 150+ indicators ready for seamless fetching and processing.

- [`all_regional_codes()`](https://mohamedhtitich1.github.io/localintel/reference/all_regional_codes.md)
  : All Regional Indicator Dataset Codes
- [`indicator_count()`](https://mohamedhtitich1.github.io/localintel/reference/indicator_count.md)
  : Count Available Regional Indicators
- [`economy_codes()`](https://mohamedhtitich1.github.io/localintel/reference/economy_codes.md)
  : Economy and Regional Accounts Dataset Codes
- [`demography_codes()`](https://mohamedhtitich1.github.io/localintel/reference/demography_codes.md)
  : Demography Dataset Codes
- [`education_codes()`](https://mohamedhtitich1.github.io/localintel/reference/education_codes.md)
  : Education Dataset Codes
- [`labour_codes()`](https://mohamedhtitich1.github.io/localintel/reference/labour_codes.md)
  : Labour Market Dataset Codes
- [`health_system_codes()`](https://mohamedhtitich1.github.io/localintel/reference/health_system_codes.md)
  [`causes_of_death_codes()`](https://mohamedhtitich1.github.io/localintel/reference/health_system_codes.md)
  : Eurostat Dataset Code Lists
- [`tourism_codes()`](https://mohamedhtitich1.github.io/localintel/reference/tourism_codes.md)
  : Tourism Dataset Codes
- [`transport_codes()`](https://mohamedhtitich1.github.io/localintel/reference/transport_codes.md)
  : Transport Dataset Codes
- [`environment_codes()`](https://mohamedhtitich1.github.io/localintel/reference/environment_codes.md)
  : Environment and Energy Dataset Codes
- [`science_codes()`](https://mohamedhtitich1.github.io/localintel/reference/science_codes.md)
  : Science and Technology Dataset Codes
- [`poverty_codes()`](https://mohamedhtitich1.github.io/localintel/reference/poverty_codes.md)
  : Poverty and Social Exclusion Dataset Codes
- [`agriculture_codes()`](https://mohamedhtitich1.github.io/localintel/reference/agriculture_codes.md)
  : Agriculture Dataset Codes
- [`business_codes()`](https://mohamedhtitich1.github.io/localintel/reference/business_codes.md)
  : Business Statistics Dataset Codes
- [`information_society_codes()`](https://mohamedhtitich1.github.io/localintel/reference/information_society_codes.md)
  : Information Society Dataset Codes
- [`crime_codes()`](https://mohamedhtitich1.github.io/localintel/reference/crime_codes.md)
  : Crime Dataset Codes

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

Transform raw Eurostat downloads into analysis-ready tables. Use the
generic processor for any dataset, or domain-specific convenience
functions for common indicators.

- [`process_eurostat()`](https://mohamedhtitich1.github.io/localintel/reference/process_eurostat.md)
  : Process Any Eurostat Dataset
- [`process_gdp()`](https://mohamedhtitich1.github.io/localintel/reference/process_gdp.md)
  : Process GDP Data
- [`process_employment()`](https://mohamedhtitich1.github.io/localintel/reference/process_employment.md)
  : Process Employment Data
- [`process_unemployment_rate()`](https://mohamedhtitich1.github.io/localintel/reference/process_unemployment_rate.md)
  : Process Unemployment Rate Data
- [`process_population()`](https://mohamedhtitich1.github.io/localintel/reference/process_population.md)
  : Process Population Data
- [`process_life_expectancy()`](https://mohamedhtitich1.github.io/localintel/reference/process_life_expectancy.md)
  : Process Life Expectancy Data
- [`process_tourism_nights()`](https://mohamedhtitich1.github.io/localintel/reference/process_tourism_nights.md)
  : Process Tourism Nights Spent Data
- [`process_rd_expenditure()`](https://mohamedhtitich1.github.io/localintel/reference/process_rd_expenditure.md)
  : Process R&D Expenditure Data
- [`process_education_attainment()`](https://mohamedhtitich1.github.io/localintel/reference/process_education_attainment.md)
  : Process Education Attainment Data
- [`process_poverty_rate()`](https://mohamedhtitich1.github.io/localintel/reference/process_poverty_rate.md)
  : Process Poverty Rate Data
- [`process_waste()`](https://mohamedhtitich1.github.io/localintel/reference/process_waste.md)
  : Process Municipal Waste Data
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

Fill missing regional data by propagating from parent NUTS levels (NUTS
0 → NUTS 1 → NUTS 2) with source-level tracking.

- [`cascade_to_nuts2()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2.md)
  : Cascade Data to NUTS2 (Generic / Domain-Agnostic)
- [`cascade_to_nuts2_and_compute()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md)
  [`cascade_to_nuts2_light()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md)
  [`balance_panel()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md)
  : Data Cascading Functions

## Econometric Imputation

Advanced time series imputation combining PCHIP interpolation for
internal gaps with autoregressive ETS forecasting for future periods —
with flag-based provenance tracking.

- [`interp_pchip_flag()`](https://mohamedhtitich1.github.io/localintel/reference/interp_pchip_flag.md)
  : PCHIP Interpolation with Constant Endpoints
- [`forecast_autoregressive()`](https://mohamedhtitich1.github.io/localintel/reference/forecast_autoregressive.md)
  : Autoregressive Forecast for Future Observations
- [`impute_series()`](https://mohamedhtitich1.github.io/localintel/reference/impute_series.md)
  : Full Imputation Pipeline

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

## Export & Labels

Export enriched GeoJSON for Tableau, multi-sheet Excel workbooks, RDS
snapshots, and multi-page PDF map books. Includes label registries for
all 14 domains.

- [`export_to_geojson()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`export_to_excel()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`export_to_rds()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`save_maps_to_pdf()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`enrich_for_tableau()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`health_var_labels()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`health_pillar_mapping()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  [`cod_labels()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
  : Export Functions
- [`regional_var_labels()`](https://mohamedhtitich1.github.io/localintel/reference/regional_var_labels.md)
  : Regional Variable Labels (All Domains)
- [`regional_domain_mapping()`](https://mohamedhtitich1.github.io/localintel/reference/regional_domain_mapping.md)
  : Regional Domain Mapping (All Domains)

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
