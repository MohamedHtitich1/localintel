# localintel

## Overview

**localintel** (Local Intelligence) is an R package that provides a
unified pipeline for **150+ subnational indicators across 14 thematic
domains** from Eurostat. Any Eurostat regional dataset — economy,
health, education, labour, demographics, tourism, transport,
environment, and more — can be fetched, harmonized, cascaded to NUTS 2,
scored, mapped, and exported through a single consistent workflow.

|                                                                             |                                                                                                                                                                                                 |
|:---------------------------------------------------------------------------:|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|  ![fetch](https://api.iconify.design/lucide/database.svg?color=%237c9885)   | **150+ Indicators** — Curated registries for 14 Eurostat domains with batch download and retry logic                                                                                            |
|  ![process](https://api.iconify.design/lucide/layers.svg?color=%237c9885)   | **Universal Processing** — Generic [`process_eurostat()`](https://mohamedhtitich1.github.io/localintel/reference/process_eurostat.md) plus domain-specific processors for instant harmonization |
| ![cascade](https://api.iconify.design/lucide/git-merge.svg?color=%237c9885) | **Data Cascading** — Intelligent propagation from country (NUTS 0) to regional (NUTS 2) with source-level tracking                                                                              |
|     ![viz](https://api.iconify.design/lucide/globe.svg?color=%237c9885)     | **Visualization** — Publication-ready maps with automatic best-level selection per country                                                                                                      |
|   ![export](https://api.iconify.design/lucide/upload.svg?color=%237c9885)   | **Export** — Tableau-ready GeoJSON, Excel, PDF maps, and RDS with enrichment and performance tags                                                                                               |

## Live Demo

> **See localintel in action** —
> [mhtitich.com/subnational](https://mhtitich.com/subnational) is an
> interactive dashboard built entirely with data processed through this
> package. It maps regional disparities across **235 European NUTS-2
> regions** from 2010–2024, with live indicator switching, animated
> timeline playback, and AI-generated regional insights.
>
> The pipeline is fully parametrizable and can be adapted to any
> indicator domain. **Interested in a custom deployment? [Get in
> touch.](mailto:m.ahtitich@outlook.com)**

## Installation

``` r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("MohamedHtitich1/localintel")
```

## Quick Start

``` r
library(localintel)

# See the full indicator registry
n <- indicator_count()
cat(n$indicators, "indicators across", n$domains, "domains\n")

# 1. Fetch data from multiple domains
econ  <- fetch_eurostat_batch(economy_codes(), level = 2, years = 2015:2024)
hlth  <- fetch_eurostat_batch(health_system_codes(), level = 2, years = 2015:2024)
lab   <- fetch_eurostat_batch(labour_codes(), level = 2, years = 2015:2024)

# 2. Process with domain-specific or generic processors
gdp       <- process_gdp(econ$gdp_nuts2)
beds      <- process_beds(hlth$beds)
unemp     <- process_unemployment_rate(lab$unemployment_rate)

# 3. Merge, cascade to NUTS2, and impute temporal gaps
all_data <- merge_datasets(gdp, beds, unemp)
cascaded <- cascade_to_nuts2(
  all_data,
  vars = c("gdp", "beds", "unemployment_rate"),
  years = 2015:2024,
  impute = TRUE,        # adaptive econometric imputation (PCHIP + ETS)
  forecast_to = 2025    # extend series with AIC-selected forecasts
)

# Check traceability
table(cascaded$src_gdp_level)  # 2=NUTS2, 1=NUTS1, 0=NUTS0
table(cascaded$imp_gdp_flag)   # 0=observed, 1=interpolated, 2=forecasted

# 4. Visualize
geopolys <- get_nuts_geopolys()
plot_best_by_country_level(cascaded, geopolys, var = "gdp", years = 2022:2024)

# 5. Export for Tableau
sf_all <- build_multi_var_sf(
  cascaded, geopolys,
  vars = c("gdp", "beds", "unemployment_rate"),
  years = 2015:2024,
  var_labels = regional_var_labels(),
  pillar_mapping = regional_domain_mapping()
)
export_to_geojson(sf_all, "output/multi_domain_nuts2.geojson")
```

## Domain Coverage

| Domain                   | Indicators | Key Datasets                                                     |
|--------------------------|------------|------------------------------------------------------------------|
| **Economy**              | 10         | GDP, GVA, gross fixed capital formation, household income        |
| **Demography**           | 13         | Population, life expectancy, fertility, mortality                |
| **Education**            | 11         | Attainment, students, training, early leavers, NEET              |
| **Labour Market**        | 13         | Employment, unemployment, activity rates, long-term unemployment |
| **Health System**        | 6          | Hospital beds, physicians, discharges, length of stay            |
| **Causes of Death**      | 16         | Standardised death rates, PYLL, infant mortality                 |
| **Tourism**              | 8          | Arrivals, nights spent, accommodation capacity                   |
| **Transport**            | 10         | Road, rail, air, maritime infrastructure and traffic             |
| **Environment**          | 7          | Municipal waste, energy, contaminated sites                      |
| **Science & Technology** | 11         | R&D expenditure, patents, HRST, high-tech employment             |
| **Poverty & Exclusion**  | 4          | At-risk-of-poverty, material deprivation, low work intensity     |
| **Agriculture**          | 5          | Crops, livestock, land use, milk production                      |
| **Business**             | 6          | SBS, business demography, local units                            |
| **Information Society**  | 6          | Internet access, broadband, e-commerce, e-government             |
| **Crime**                | 1          | Crimes recorded by police                                        |

Use
[`indicator_count()`](https://mohamedhtitich1.github.io/localintel/reference/indicator_count.md)
to get the exact total and per-domain breakdown.

## Key Features

### Data Cascading

The package automatically fills missing regional data by cascading from
parent NUTS levels:

    NUTS 0 (Country) → NUTS 1 (Major Regions) → NUTS 2 (Regions)

Every cascaded value is tracked via `src_<variable>_level` columns (2 =
original NUTS 2, 1 = from NUTS 1, 0 = from NUTS 0), enabling full
transparency and sensitivity analysis.

### Generic Processing

The
[`process_eurostat()`](https://mohamedhtitich1.github.io/localintel/reference/process_eurostat.md)
function handles **any** Eurostat dataset with flexible dimension
filtering:

``` r
# Custom indicator with arbitrary filters
custom <- process_eurostat(raw_data,
  filters = list(unit = "PC", sex = "T", age = "Y25-64"),
  out_col = "my_indicator"
)
```

### Visualization

Automatic “best level” selection for maps — displays NUTS 2 where
available, falls back to NUTS 1 / NUTS 0:

``` r
plot_best_by_country_level(cascaded, geopolys, var = "unemployment_rate",
  years = 2022:2024, title = "Unemployment Rate (%)", scale = "global")
```

### Tableau Integration

Full support for Tableau exports with country names, region labels,
population-weighted aggregations, and performance tags (Best/Worst by
country):

``` r
sf_enriched <- enrich_for_tableau(sf_all, pop_data, nuts2_names)
export_to_geojson(sf_enriched, "dashboard_export.geojson")
```

## Related Work

This package was developed as part of research on subnational regional
analysis in Europe. Related projects:

- [Subnational Health Disparities Map](https://mhtitich.com/subnational)
  — Interactive dashboard powered by localintel
- [w2m](https://github.com/MohamedHtitich1/w2m) — Composite indicator
  construction

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
