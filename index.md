# localintel

## Overview

**localintel** (Local Intelligence) is an R package for fetching,
processing, and visualizing subnational (NUTS 0/1/2) data from Eurostat.
It provides a comprehensive pipeline for health system analysis across
European regions, including:

- 📊 **Data Fetching**: Robust API wrappers for Eurostat datasets
- 🔄 **Data Cascading**: Intelligent propagation from country to
  regional levels
- 📈 **Indicator Computation**: Composite scores for health outcomes,
  enabling environment, and perceptions
- 🗺️ **Visualization**: Publication-ready maps with automatic level
  selection
- 📤 **Export**: Tableau-ready GeoJSON exports with enrichment

## Installation

``` r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("MohamedHtitich1/localintel")
```

## Quick Start

``` r
library(localintel)

# 1. Fetch health system data
codes <- health_system_codes()
data_list <- fetch_eurostat_batch(codes, level = 2, years = 2010:2024)

# 2. Process individual datasets
beds <- process_beds(data_list$beds)
physicians <- process_physicians(data_list$physicians)
los <- process_los(data_list$los)

# 3. Merge into single dataset
all_data <- merge_datasets(beds, physicians, los)

# 4. Get reference geometries
nuts2_ref <- get_nuts2_ref()
geopolys <- get_nuts_geopolys()

# 5. Cascade data to NUTS2 level with computed indicators
cascaded <- cascade_to_nuts2_and_compute(
  all_data,
  vars = c("beds", "physicians", "los"),
  nuts2_ref = nuts2_ref,
  years = 2010:2024
)

# 6. Create maps
plot_best_by_country_level(
  cascaded, 
  geopolys, 
  var = "beds",
  years = 2020:2024,
  title = "Hospital Beds per 100,000"
)

# 7. Export for Tableau
sf_data <- build_display_sf(cascaded, geopolys, var = "beds", years = 2010:2024)
export_to_geojson(sf_data, "output/beds_nuts2.geojson")
```

## Key Features

### Data Cascading

The package automatically fills missing regional data by cascading from
parent NUTS levels:

    NUTS0 (Country) → NUTS1 (Major Regions) → NUTS2 (Regions)

This ensures complete coverage while tracking the original data source
level.

### Computed Indicators

Built-in computation for key health system indicators:

| Indicator                          | Description                      | Formula                       |
|------------------------------------|----------------------------------|-------------------------------|
| **DA** (Discharge Activity)        | Hospital utilization metric      | log2(discharges) / log2(beds) |
| **rLOS** (Relative Length of Stay) | Regional vs. national comparison | regional LOS / national LOS   |

### Visualization

Automatic “best level” selection for maps - displays NUTS2 where
available, falls back to NUTS1/NUTS0:

``` r
# Global color scale (consistent across years)
plot_best_by_country_level(data, geopolys, var = "beds", scale = "global")

# Per-year color scale (highlights within-year variation)
plot_best_by_country_level(data, geopolys, var = "beds", scale = "per_year")
```

### Tableau Integration

Full support for Tableau exports with: - Country names and region
labels - Population-weighted aggregations - Performance tags (Best/Worst
by country) - Multi-variable GeoJSON exports

``` r
sf_all <- build_multi_var_sf(
  cascaded, geopolys,
  vars = c("beds", "physicians", "score_health_outcome"),
  years = 2010:2024,
  var_labels = health_var_labels(),
  pillar_mapping = health_pillar_mapping()
)

sf_enriched <- enrich_for_tableau(sf_all, pop_data, nuts2_names)
export_to_geojson(sf_enriched, "tableau_export.geojson")
```

## Data Sources

The package works with Eurostat datasets including:

**Health System Resources:** - `hlth_rs_bdsrg2` - Hospital beds -
`hlth_rs_physreg` - Physicians

**Hospital Activity:** - `hlth_co_disch2t` - In-patient discharges -
`hlth_co_disch4t` - Day-case discharges - `hlth_co_inpstt` - Length of
stay

**Health Outcomes:** - `hlth_cd_asdr2` - Standardised death rates -
`hlth_cd_ypyll` - Potential years of life lost - `hlth_cd_yinfr` -
Infant mortality

**Health Perceptions:** - `hlth_silc_08_r` - Unmet medical needs

## Related Work

This package was developed as part of research on subnational health
system analysis in Europe. Related projects:

- [w2m](https://github.com/MohamedHtitich1/w2m) - Composite indicator
  construction
- [Social Progress Index](https://www.socialprogress.org/) - Framework
  inspiration

## Contributing

Contributions are welcome! Please open an issue or submit a pull
request.

## License

MIT © Mohamed Htitich

## Citation

``` bibtex
@software{localintel,
  author = {Htitich, Mohamed},
  title = {localintel: Local Intelligence for Subnational Data Analysis},
  year = {2025},
  url = {https://github.com/MohamedHtitich1/localintel}
}
```
