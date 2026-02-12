# Changelog

## localintel 0.1.0

### Initial Release

#### New Features

- **Data Fetching Functions**
  - [`get_nuts2()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md):
    Fetch NUTS2 level data from Eurostat
  - [`get_nuts_level()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md):
    Fetch data at any NUTS level (0, 1, 2, 3)
  - [`get_nuts_level_robust()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md):
    Fetch with retry logic
  - [`fetch_eurostat_batch()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md):
    Fetch multiple datasets at once
  - Pre-defined code lists:
    [`health_system_codes()`](https://mohamedhtitich1.github.io/localintel/reference/health_system_codes.md),
    [`causes_of_death_codes()`](https://mohamedhtitich1.github.io/localintel/reference/health_system_codes.md)
- **Reference Data Functions**
  - [`get_nuts2_ref()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md):
    NUTS2 reference table with parent codes
  - [`get_nuts_geopolys()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md):
    Combined NUTS 0/1/2 geometries
  - [`get_nuts2_names()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md):
    Region name lookup
  - [`get_population_nuts2()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md):
    Population data
- **Data Cascading**
  - [`cascade_to_nuts2_and_compute()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md):
    Full cascade with indicator computation (DA, rLOS)
  - [`cascade_to_nuts2_light()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md):
    Simple cascading for pre-computed scores
  - [`balance_panel()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md):
    Fill missing year-geo combinations
- **Data Processing**
  - Processing functions for Eurostat datasets:
    [`process_beds()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md),
    [`process_physicians()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md),
    etc.
  - [`merge_datasets()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md):
    Combine multiple datasets
  - [`transform_and_score()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md):
    Apply transformations and scale to 0-100
  - [`compute_composite()`](https://mohamedhtitich1.github.io/localintel/reference/process_beds.md):
    Calculate composite scores
- **Utility Functions**
  - [`keep_eu27()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md):
    Filter to EU27 countries
  - [`safe_log10()`](https://mohamedhtitich1.github.io/localintel/reference/safe_log10.md),
    [`safe_log2()`](https://mohamedhtitich1.github.io/localintel/reference/safe_log10.md):
    Safe logarithm functions
  - [`scale_0_100()`](https://mohamedhtitich1.github.io/localintel/reference/safe_log10.md):
    Min-max normalization
  - [`interp_const_ends_flag()`](https://mohamedhtitich1.github.io/localintel/reference/interp_const_ends_flag.md):
    Linear interpolation with flags
  - [`add_country_name()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md):
    Add country names from NUTS codes
- **Visualization**
  - [`build_display_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md):
    Build SF for best-level display
  - [`lc_build_display_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md):
    Version for life course data with grouping
  - [`plot_best_by_country_level()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md):
    Create tmap visualizations
  - [`build_multi_var_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md):
    Combine multiple variables for Tableau
- **Export Functions**
  - [`export_to_geojson()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md):
    GeoJSON export for Tableau
  - [`enrich_for_tableau()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md):
    Add metadata for Tableau dashboards
  - [`export_to_excel()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md):
    Excel export
  - [`save_maps_to_pdf()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md):
    Multi-page PDF maps

#### Documentation

- Complete package documentation with roxygen2
- README with installation and quick start guide
- Example workflow script in `inst/examples/`
