# localintel <a href="https://mohamedhtitich1.github.io/localintel/"><img src="man/figures/logo.svg" align="right" height="139" alt="localintel website" /></a>

<!-- badges: start -->
[![R-CMD-check](https://github.com/MohamedHtitich1/localintel/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/MohamedHtitich1/localintel/actions/workflows/R-CMD-check.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

## Overview

**localintel** (Local Intelligence) is an R package for fetching, processing, and visualizing subnational (NUTS 0/1/2) data from Eurostat. It provides a comprehensive pipeline for health system analysis across European regions, including:

<table>
<tr>
<td width="60" align="center">
<img src="https://api.iconify.design/lucide/database.svg?color=%237c9885" width="28" alt="fetch">
</td>
<td><strong>Data Fetching</strong> — Robust API wrappers for Eurostat datasets with retry logic and batch downloads</td>
</tr>
<tr>
<td align="center">
<img src="https://api.iconify.design/lucide/git-merge.svg?color=%237c9885" width="28" alt="cascade">
</td>
<td><strong>Data Cascading</strong> — Intelligent propagation from country (NUTS0) to regional (NUTS2) levels</td>
</tr>
<tr>
<td align="center">
<img src="https://api.iconify.design/lucide/bar-chart-3.svg?color=%237c9885" width="28" alt="indicators">
</td>
<td><strong>Indicator Computation</strong> — Composite scores for health outcomes, enabling environment, and perceptions</td>
</tr>
<tr>
<td align="center">
<img src="https://api.iconify.design/lucide/globe.svg?color=%237c9885" width="28" alt="viz">
</td>
<td><strong>Visualization</strong> — Publication-ready maps with automatic best-level selection per country</td>
</tr>
<tr>
<td align="center">
<img src="https://api.iconify.design/lucide/upload.svg?color=%237c9885" width="28" alt="export">
</td>
<td><strong>Export</strong> — Tableau-ready GeoJSON exports with enrichment, performance tags, and population weighting</td>
</tr>
</table>

## Live Demo

> **See localintel in action** — [mhtitich.com/subnational](https://mhtitich.com/subnational) is an interactive dashboard built entirely with data processed through this package. It maps health disparities across **235 European NUTS-2 regions** from 2010–2024, with live indicator switching, animated timeline playback, and AI-generated regional insights.
>
> The pipeline is fully parametrizable and can be adapted to any world subregion or indicator domain. **Interested in a custom deployment? [Get in touch.](mailto:m.ahtitich@outlook.com)**

## Installation

```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("MohamedHtitich1/localintel")
```

## Quick Start

```r
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

The package automatically fills missing regional data by cascading from parent NUTS levels:

```
NUTS0 (Country) → NUTS1 (Major Regions) → NUTS2 (Regions)
```

This ensures complete coverage while tracking the original data source level.

### Computed Indicators

Built-in computation for key health system indicators:

| Indicator | Description | Formula |
|-----------|-------------|---------|
| **DA** (Discharge Activity) | Hospital utilization metric | log2(discharges) / log2(beds) |
| **rLOS** (Relative Length of Stay) | Regional vs. national comparison | regional LOS / national LOS |

### Visualization

Automatic "best level" selection for maps - displays NUTS2 where available, falls back to NUTS1/NUTS0:

```r
# Global color scale (consistent across years)
plot_best_by_country_level(data, geopolys, var = "beds", scale = "global")

# Per-year color scale (highlights within-year variation)
plot_best_by_country_level(data, geopolys, var = "beds", scale = "per_year")
```

### Tableau Integration

Full support for Tableau exports with:
- Country names and region labels
- Population-weighted aggregations
- Performance tags (Best/Worst by country)
- Multi-variable GeoJSON exports

```r
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

**Health System Resources:**
- `hlth_rs_bdsrg2` - Hospital beds
- `hlth_rs_physreg` - Physicians

**Hospital Activity:**
- `hlth_co_disch2t` - In-patient discharges
- `hlth_co_disch4t` - Day-case discharges
- `hlth_co_inpstt` - Length of stay

**Health Outcomes:**
- `hlth_cd_asdr2` - Standardised death rates
- `hlth_cd_ypyll` - Potential years of life lost
- `hlth_cd_yinfr` - Infant mortality

**Health Perceptions:**
- `hlth_silc_08_r` - Unmet medical needs

## Related Work

This package was developed as part of research on subnational health system analysis in Europe. Related projects:

- [Subnational Health Disparities Map](https://mhtitich.com/subnational) - Interactive dashboard powered by localintel
- [w2m](https://github.com/MohamedHtitich1/w2m) - Composite indicator construction
- [Social Progress Index](https://www.socialprogress.org/) - Framework inspiration

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License
MIT © Mohamed Htitich

## Citation

```bibtex
@software{localintel,
  author = {Htitich, Mohamed},
  title = {localintel: Local Intelligence for Subnational Data Analysis},
  year = {2025},
  url = {https://github.com/MohamedHtitich1/localintel}
}
```
