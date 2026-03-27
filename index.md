# localintel

## Overview

**localintel** (Local Intelligence) is an R package and **inequality
mapping engine** that provides a unified pipeline for subnational
indicator analysis across two major data ecosystems:

- **Eurostat** — 150+ indicators across 14 thematic domains for 235
  European NUTS-2 regions
- **DHS (Demographic and Health Surveys)** — 50+ indicators across 8
  domains for 500+ Admin-1 regions in Sub-Saharan Africa

Any subnational dataset can be fetched, harmonized, gap-filled,
cascaded, mapped, and exported through a single consistent workflow.

[![localintel pipeline: from raw data to complete regional
maps](reference/figures/hero-map.svg)](https://mhtitich.com/subnational)

|                                                                               |                                                                                                                                           |
|:-----------------------------------------------------------------------------:|-------------------------------------------------------------------------------------------------------------------------------------------|
|   ![fetch](https://api.iconify.design/lucide/database.svg?color=%237c9885)    | **200+ Indicators** — Curated registries for Eurostat (14 domains) and DHS (8 domains) with batch download and retry logic                |
|   ![process](https://api.iconify.design/lucide/layers.svg?color=%237c9885)    | **Universal Processing** — Generic processors plus domain-specific functions for instant harmonization across both data sources           |
|  ![cascade](https://api.iconify.design/lucide/git-merge.svg?color=%237c9885)  | **Data Cascading** — Intelligent propagation from country to regional level with source-level tracking (NUTS for Europe, Admin-1 for SSA) |
| ![gapfill](https://api.iconify.design/lucide/trending-up.svg?color=%237c9885) | **Gap-Filling** — GAM-based temporal interpolation and forecasting for DHS time series, with provenance flags on every cell               |
|      ![viz](https://api.iconify.design/lucide/globe.svg?color=%237c9885)      | **Inequality Mapping** — Publication-ready maps with automatic best-level selection and DHS Admin-1 choropleth support                    |
|    ![export](https://api.iconify.design/lucide/upload.svg?color=%237c9885)    | **Export** — Tableau-ready GeoJSON, Excel, PDF maps, and RDS with enrichment and performance tags                                         |

## Live Demo

> **See the inequality mapping engine in action** — [*Where Inequality
> Lives*](https://mhtitich.com/subnational) is an interactive dashboard
> built entirely with data processed through this package. It maps
> regional disparities across **235 European NUTS-2 regions** from
> 2010–2024, with live indicator switching, animated timeline playback,
> and AI-generated regional insights powered by an indicator-aware
> narrative engine.
>
> The pipeline is fully parametrizable and can be adapted to any
> indicator domain or geography. **Interested in a custom deployment?
> [Get in touch.](mailto:m.ahtitich@outlook.com)**

## Installation

``` r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("MohamedHtitich1/localintel")
```

## Quick Start — Eurostat

Fetch one indicator, cascade it to every NUTS-2 region, and plot — in
four lines:

``` r
library(localintel)

gdp_raw  <- get_nuts_level_robust("nama_10r_2gdp", level = 2, years = 2020:2024)
gdp      <- process_gdp(gdp_raw)
cascaded <- cascade_to_nuts2(gdp, vars = "gdp", years = 2020:2024)

plot_best_by_country_level(cascaded, get_nuts_geopolys(), var = "gdp", years = 2024:2024)
```

## Quick Start — DHS (Sub-Saharan Africa)

Fetch DHS indicators, gap-fill the time series, and assemble an Admin-1
panel:

``` r
library(localintel)

# 1. Fetch & process DHS indicators for SSA
raw  <- fetch_dhs_batch(dhs_mortality_codes(), country_ids = ssa_codes())
proc <- process_dhs_batch(raw)

# 2. Gap-fill with GAM-based interpolation
gapfilled <- gapfill_all_dhs(proc)

# 3. Cascade to Admin 1 panel with national fallback
panel <- cascade_to_admin1(gapfilled)

# 4. Balance the panel (drop thin indicators/regions)
balanced <- balance_dhs_panel(panel, min_countries = 5)

# 5. Map a single indicator
plot_dhs_map(balanced$panel, var = "u5_mortality", year = 2020)
```

Or run the entire pipeline in one call:

``` r
result <- dhs_pipeline(
  country_ids = ssa_codes(),
  indicator_codes = c(dhs_mortality_codes(), dhs_nutrition_codes()),
  forecast_to = 2025
)
```

### Full Multi-Domain Workflow (Eurostat)

Once you’re comfortable, scale up to multiple domains at once:

``` r
library(localintel)

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

## Why localintel?

If you work with subnational data from Eurostat or DHS, you’ve likely
used packages like
[`eurostat`](https://cran.r-project.org/package=eurostat) or
[`rdhs`](https://cran.r-project.org/package=rdhs). They’re excellent for
downloading individual datasets — but getting from raw downloads to a
complete, analysis-ready panel is where most of the work begins.
localintel picks up where they leave off:

|                        | Raw data packages            | **localintel**                                                                                                    |
|------------------------|------------------------------|-------------------------------------------------------------------------------------------------------------------|
| **Scope**              | One dataset at a time        | 200+ indicators across Eurostat and DHS in a single batch call                                                    |
| **Processing**         | Raw data as-is               | Domain-specific processors select units, filter dimensions, and standardize columns automatically                 |
| **Gaps**               | Missing regions stay missing | Cascade fills every region from parent levels (100% geographic coverage) with source tracking                     |
| **Time series**        | Gaps remain                  | GAM interpolation (DHS) and PCHIP + ETS forecasting (Eurostat), with provenance flags on every cell               |
| **Name harmonization** | Manual                       | Automatic DHS-to-GADM name matching with 40+ country crosswalks, composite region dissolution, and fuzzy matching |
| **Output**             | Data frame                   | Maps, GeoJSON, Excel, PDF map books — all from the same pipeline                                                  |

## Domain Coverage

### Eurostat (Europe — NUTS-2 Regions)

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

### DHS (Sub-Saharan Africa — Admin-1 Regions)

| Domain        | Indicators | Key Measures                                                                     |
|---------------|------------|----------------------------------------------------------------------------------|
| **Mortality** | 8          | Under-5 mortality, infant mortality, neonatal mortality, child mortality         |
| **Nutrition** | 6          | Stunting, wasting, underweight, overweight, anemia, exclusive breastfeeding      |
| **Health**    | 8          | Vaccination coverage, ANC visits, skilled birth attendance, modern contraception |
| **WASH**      | 6          | Improved water, improved sanitation, handwashing, open defecation                |
| **Education** | 5          | Literacy, school attendance, educational attainment                              |
| **HIV**       | 5          | HIV prevalence, knowledge, testing, condom use                                   |
| **Gender**    | 4          | Women’s decision-making, attitudes toward violence, early marriage               |
| **Wealth**    | 4          | Wealth index, asset ownership, poverty headcount                                 |

Use
[`indicator_count()`](https://mohamedhtitich1.github.io/localintel/reference/indicator_count.md)
for Eurostat totals and
[`dhs_indicator_count()`](https://mohamedhtitich1.github.io/localintel/reference/dhs_indicator_count.md)
for DHS totals.

## Key Features

### Data Cascading

The package automatically fills missing regional data by cascading from
parent levels:

    Eurostat:  NUTS 0 (Country) → NUTS 1 (Major Regions) → NUTS 2 (Regions)
    DHS:       National → Admin 1 (with gap-filling and name harmonization)

Every cascaded value is tracked via `src_<variable>_level` columns,
enabling full transparency and sensitivity analysis.

### DHS Name Harmonization

Matching DHS region names to GADM administrative boundaries is
notoriously difficult. localintel handles this automatically through
four lookup tables covering 40+ SSA countries: manual crosswalks,
composite region splitting, sub-national dissolves, and fuzzy string
matching — with 100% coverage for all Tier 1 DHS countries.

### GAM-Based Gap-Filling (DHS)

DHS surveys are conducted irregularly (every 3–7 years). The gap-filling
engine uses penalized GAM splines to interpolate between surveys and
optionally forecast beyond the last observation, producing smooth
continuous time series with uncertainty bounds and provenance flags on
every value.

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

Automatic “best level” selection for maps — displays the finest
available resolution per country:

``` r
# Eurostat
plot_best_by_country_level(cascaded, geopolys, var = "unemployment_rate",
  years = 2022:2024, title = "Unemployment Rate (%)")

# DHS
plot_dhs_map(panel, var = "u5_mortality", year = 2020,
  title = "Under-5 Mortality Rate")
```

### Tableau Integration

Full support for Tableau exports with country names, region labels,
population-weighted aggregations, and performance tags:

``` r
# Eurostat
sf_enriched <- enrich_for_tableau(sf_all, pop_data, nuts2_names)
export_to_geojson(sf_enriched, "eurostat_dashboard.geojson")

# DHS
dhs_sf <- enrich_dhs_for_tableau(panel, geo_sf)
export_to_geojson(dhs_sf, "dhs_dashboard.geojson")
```

## Related Work

This package was developed as part of research on subnational regional
analysis. Related projects:

- [Where Inequality Lives](https://mhtitich.com/subnational) —
  Interactive inequality mapping engine powered by localintel
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
  title = {localintel: Inequality Mapping Engine for Subnational Data Analysis},
  year = {2025},
  url = {https://github.com/MohamedHtitich1/localintel}
}
```
