# localintel 0.2.1

## Imputation Integration, Smart Caching, Tests

### New Features

* **Integrated Adaptive Imputation in Cascade**
  - `cascade_to_nuts2()` now accepts `impute = TRUE` (default) and `forecast_to`
    parameters. After cascading, each region's time series is automatically filled
    using PCHIP interpolation (internal gaps) and optionally ETS forecasting
    (future periods, best model selected via AIC).
  - New `imp_{variable}_flag` columns track imputation method per value:
    0 = observed/cascaded, 1 = PCHIP interpolated, 2 = ETS forecasted.
  - The existing `src_{variable}_level` columns are preserved for cascade
    source tracking.
  - Set `impute = FALSE` for legacy behaviour (no gap-filling).

* **Session-Level Smart Caching** (`R/cache.R`)
  - All geometry and reference functions (`get_nuts_geo()`, `get_nuts_geopolys()`,
    `get_nuts2_ref()`, `get_nuts2_names()`) now cache results in a package-level
    environment for instant repeated access within an R session.
  - `clear_localintel_cache()`: Exported function to reset the cache and force
    fresh data fetches.
  - Cascade functions now use the cached `get_nuts2_ref()` instead of duplicating
    the geospatial fetch logic.

* **Test Suite** (`tests/testthat/`)
  - Comprehensive unit tests for utils, imputation, cascade, data processing,
    and caching functions using mock data (no Eurostat API calls required).

### Bug Fixes

* `cascade_to_nuts2()` and `cascade_to_nuts2_and_compute()` now use the cached
  `get_nuts2_ref()` function, avoiding redundant geospatial API calls.
* Added `giscoR` checks with informative error messages to all functions
  that depend on geospatial data.

---

# localintel 0.2.0

## Econometric Imputation

### New Features

* **Econometric Imputation Module** (`R/imputation.R`)
  - `interp_pchip_flag()`: PCHIP (Piecewise Cubic Hermite Interpolating Polynomial)
    interpolation for missing years within the observed range. Uses monotone Hermite
    splines (Fritsch-Carlson method) which preserve monotonicity and handle non-linear
    patterns without overshooting — a significant upgrade over the previous linear
    interpolation approach.
  - `forecast_autoregressive()`: Exponential smoothing state space model (ETS) for
    forecasting beyond observed data. Autoregressive by design, it automatically
    selects optimal smoothing parameters via AICc. Falls back to Holt's linear
    trend when the `forecast` package is unavailable.
  - `impute_series()`: Unified pipeline combining PCHIP interpolation (for internal
    gaps) with autoregressive forecasting (for future periods). Returns a complete
    series with flags distinguishing observed (0), interpolated (1), and
    forecasted (2) values.

### Design Decisions

* **Interpolation vs Forecasting**: The package now uses two distinct methods — PCHIP
  for within-range imputation (where the curve should respect existing data points)
  and ETS for beyond-range forecasting (where autoregressive dynamics drive the
  projection). This separation reflects the fundamentally different statistical
  requirements of each task.

* **Graceful Degradation**: The `forecast` package is placed in `Suggests` rather
  than `Imports`. When unavailable, the system falls back to Holt's linear trend
  extrapolation with manually estimated smoothing parameters (α=0.3, β=0.1).

---

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
