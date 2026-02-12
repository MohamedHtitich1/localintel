# FAQ & Troubleshooting

## Frequently Asked Questions

### Data Fetching

#### Q: The Eurostat API is returning empty data or timing out. What should I do?

The Eurostat bulk download API can be intermittent. localintel has
built-in mitigation:

``` r
# get_nuts_level_robust() retries with different cache strategies
data <- get_nuts_level_robust("hlth_rs_bdsrg2", level = 2, years = 2010:2024)

# get_nuts_level_safe() goes further — returns an empty tibble instead of
# erroring, so batch operations don't break on one failed dataset
data <- get_nuts_level_safe("hlth_rs_bdsrg2", level = 2, years = 2010:2024)
```

If problems persist, try clearing the Eurostat cache:

``` r
eurostat::clean_eurostat_cache()
```

#### Q: Why does `fetch_eurostat_batch()` take so long?

Each dataset requires a separate API call. For a typical set of 5–8
health datasets, expect 1–3 minutes depending on your connection and
Eurostat server load. Tips for faster workflows:

1.  Save fetched data locally with
    [`export_to_rds()`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)
    after the first fetch
2.  Load from disk on subsequent runs instead of re-fetching
3.  Use narrower year ranges when exploring

``` r
# First run — fetch and save
data_list <- fetch_eurostat_batch(health_system_codes(), level = 2, years = 2010:2024)
export_to_rds(data_list, "data/raw_eurostat.rds")

# Subsequent runs — load from disk
data_list <- readRDS("data/raw_eurostat.rds")
```

#### Q: Can I fetch data at NUTS3 level?

Yes, but coverage is very sparse at NUTS3 for most health datasets. Use
[`get_nuts_level()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md)
with `level = 3`:

``` r
nuts3_data <- get_nuts_level("hlth_rs_bdsrg2", level = 3, years = 2015:2024)
```

Be aware that the cascading functions are designed for the NUTS0 → NUTS1
→ NUTS2 hierarchy and don’t currently cascade down to NUTS3.

------------------------------------------------------------------------

### Data Processing

#### Q: My dataset isn’t one of the pre-built `process_*` functions. How do I handle it?

The `process_*` functions are convenience wrappers for common Eurostat
datasets. For a custom dataset, you can process it manually following
the same pattern:

``` r
library(dplyr)

custom <- raw_data %>%
  # Filter to the specific indicator/unit you need
  filter(unit == "P_HTHAB", sex == "T") %>%
  # Standardize time column
  standardize_time() %>%
  # Select and rename
  select(geo, year, my_variable = values) %>%
  # Filter to EU27
  keep_eu27()
```

The key requirement for downstream functions is a tibble with `geo`
(NUTS code), `year` (integer), and one or more numeric value columns.

#### Q: What does `merge_datasets()` actually do?

It performs a sequential `full_join` on `geo` and `year`. This means:

- All geo-year combinations from all datasets are preserved
- Missing values become `NA` where a dataset doesn’t cover a particular
  region or year
- No data is dropped

------------------------------------------------------------------------

### Cascading

#### Q: How does cascading decide which level to use?

The cascade follows a priority order: NUTS2 \> NUTS1 \> NUTS0. For each
region-year combination:

1.  If a NUTS2 value exists, use it (source = `2`)
2.  Else, if the parent NUTS1 has a value, use that (source = `1`)
3.  Else, if the country (NUTS0) has a value, use that (source = `0`)
4.  If no level has data, the value remains `NA`

The `src_<variable>` column tracks which level the value came from.

#### Q: Is cascading appropriate for my analysis?

Cascading makes a strong assumption: that the parent-level value is a
reasonable proxy for sub-regions. This is often fine for national
indicators (e.g., country-level physician density applied to all
regions), but may be misleading for highly variable metrics.

Check the source-level distribution to assess how much cascading
occurred:

``` r
cascaded %>%
  count(src_beds) %>%
  mutate(pct = n / sum(n) * 100)
```

If \>50% of values are cascaded from NUTS0, consider whether NUTS2-level
analysis is appropriate for that variable.

#### Q: What are DA and rLOS?

These are derived indicators computed during the full cascade:

- **DA (Discharge Activity)**: `log2(discharges) / log2(beds)`. Values
  near 1 indicate hospitals are being used proportionally to their
  capacity. Higher values suggest more intensive use.

- **rLOS (Relative Length of Stay)**: `regional_LOS / national_LOS`. A
  value of 1.0 means the region matches the national average. Values \>1
  indicate longer-than-average stays.

Both require the `disch_inp`, `beds`, and `los` columns in the input
data.

------------------------------------------------------------------------

### Visualization

#### Q: Why do some countries appear as a single block on the map?

This is by design. If a country only reports at NUTS0 (country level),
the
[`build_display_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)
function uses the national boundary polygon. The map shows the “best
available resolution” per country:

- Countries with NUTS2 data → detailed regional polygons
- Countries with only NUTS1 → major-region polygons
- Countries with only NUTS0 → single country polygon

#### Q: How do I change the color palette?

The
[`plot_best_by_country_level()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)
function uses tmap internally. You can modify colors by passing
tmap-compatible palette arguments. For more control, build the sf object
with
[`build_display_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)
and create your own tmap or ggplot2 visualization.

#### Q: Can I create maps with ggplot2 instead of tmap?

Yes. Use
[`build_display_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)
to get the spatial data, then plot with any spatial visualization
library:

``` r
library(ggplot2)
library(sf)

sf_data <- build_display_sf(cascaded, geopolys, var = "beds", years = 2022:2022)

ggplot(sf_data) +
  geom_sf(aes(fill = beds), color = "white", size = 0.1) +
  scale_fill_viridis_c(option = "magma", na.value = "grey90") +
  theme_minimal() +
  labs(title = "Hospital Beds per 100,000 (2022)")
```

------------------------------------------------------------------------

### Export

#### Q: The GeoJSON file is very large. How can I reduce it?

Large GeoJSON files are usually caused by high-resolution geometries.
Options:

1.  Use simplified geometries (the Eurostat API supports resolution
    parameter)
2.  Export fewer years or variables
3.  Use
    [`sf::st_simplify()`](https://r-spatial.github.io/sf/reference/geos_unary.html)
    before export:

``` r
sf_data_simple <- sf::st_simplify(sf_data, dTolerance = 5000)
export_to_geojson(sf_data_simple, "output/simplified.geojson")
```

#### Q: How do I use the exported GeoJSON in Tableau?

1.  Open Tableau Desktop
2.  Connect to a *Spatial file* data source
3.  Select the `.geojson` file
4.  The enriched fields (country_name, region_name, performance_tag,
    etc.) will appear as dimensions and measures

------------------------------------------------------------------------

### Spatial Data

#### Q: I’m getting CRS (Coordinate Reference System) errors

localintel uses EPSG:4326 (WGS84) throughout, which is the standard for
web mapping and Tableau. If you’re combining with data in a different
CRS:

``` r
# Transform to match localintel's CRS
other_data <- sf::st_transform(other_data, 4326)
```

#### Q: The `sf` package won’t install

The `sf` package depends on system libraries (GDAL, GEOS, PROJ). On
Ubuntu:

``` bash
sudo apt-get install libudunits2-dev libgdal-dev libgeos-dev libproj-dev
```

On macOS with Homebrew:

``` bash
brew install gdal geos proj udunits
```

On Windows, these are bundled with the binary package from CRAN.

------------------------------------------------------------------------

### General

#### Q: Which EU countries are included?

The
[`eu27_codes()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md)
function returns the current EU27 member states (post-Brexit). Use
[`keep_eu27()`](https://mohamedhtitich1.github.io/localintel/reference/keep_eu27.md)
to filter any dataset:

``` r
eu27_codes()
# "AT" "BE" "BG" "CY" "CZ" "DE" "DK" "EE" "EL" "ES" "FI" "FR"
# "HR" "HU" "IE" "IT" "LT" "LU" "LV" "MT" "NL" "PL" "PT" "RO"
# "SE" "SI" "SK"

# Filter to EU27 + optionally include NO, CH, UK
filtered <- keep_eu27(data, extras = c("NO", "CH"))
```

#### Q: How do I cite localintel?

``` bibtex
@software{localintel,
  author = {Htitich, Mohamed},
  title = {localintel: Local Intelligence for Subnational Data Analysis},
  year = {2025},
  url = {https://github.com/MohamedHtitich1/localintel}
}
```
