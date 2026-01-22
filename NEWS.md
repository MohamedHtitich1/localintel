# localintel 0.1.0

## Initial Release

### New Features

* **Data Fetching Functions**
  - `get_nuts2()`: Fetch NUTS2 level data from Eurostat
  - `get_nuts_level()`: Fetch data at any NUTS level (0, 1, 2, 3)
  - `get_nuts_level_robust()`: Fetch with retry logic
  - `fetch_eurostat_batch()`: Fetch multiple datasets at once
  - Pre-defined code lists: `health_system_codes()`, `causes_of_death_codes()`

* **Reference Data Functions**
  - `get_nuts2_ref()`: NUTS2 reference table with parent codes
  - `get_nuts_geopolys()`: Combined NUTS 0/1/2 geometries
  - `get_nuts2_names()`: Region name lookup
  - `get_population_nuts2()`: Population data

* **Data Cascading**
  - `cascade_to_nuts2_and_compute()`: Full cascade with indicator computation (DA, rLOS)
  - `cascade_to_nuts2_light()`: Simple cascading for pre-computed scores
  - `balance_panel()`: Fill missing year-geo combinations

* **Data Processing**
  - Processing functions for Eurostat datasets: `process_beds()`, `process_physicians()`, etc.
  - `merge_datasets()`: Combine multiple datasets
  - `transform_and_score()`: Apply transformations and scale to 0-100
  - `compute_composite()`: Calculate composite scores

* **Utility Functions**
  - `keep_eu27()`: Filter to EU27 countries
  - `safe_log10()`, `safe_log2()`: Safe logarithm functions
  - `scale_0_100()`: Min-max normalization
  - `interp_const_ends_flag()`: Linear interpolation with flags
  - `add_country_name()`: Add country names from NUTS codes

* **Visualization**
  - `build_display_sf()`: Build SF for best-level display
  - `lc_build_display_sf()`: Version for life course data with grouping
  - `plot_best_by_country_level()`: Create tmap visualizations
  - `build_multi_var_sf()`: Combine multiple variables for Tableau

* **Export Functions**
  - `export_to_geojson()`: GeoJSON export for Tableau
  - `enrich_for_tableau()`: Add metadata for Tableau dashboards
  - `export_to_excel()`: Excel export
  - `save_maps_to_pdf()`: Multi-page PDF maps

### Documentation

* Complete package documentation with roxygen2
* README with installation and quick start guide
* Example workflow script in `inst/examples/`
