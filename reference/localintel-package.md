# Local Intelligence for Subnational Data Analysis

A comprehensive pipeline for fetching, processing, and visualizing
subnational (NUTS 0/1/2) data from Eurostat. The package provides tools
for data fetching, cascading from higher to lower NUTS levels, computing
composite health indicators, creating publication-ready maps, and
exporting data for Tableau and other visualization tools.

## Details

**Main Functions:**

Data Fetching:
[`get_nuts2`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md),
[`get_nuts_level`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md),
[`fetch_eurostat_batch`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2.md)

Reference Data:
[`get_nuts2_ref`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md),
[`get_nuts_geopolys`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md),
[`get_population_nuts2`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md)

Data Cascading:
[`cascade_to_nuts2_and_compute`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md),
[`cascade_to_nuts2_light`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md)

Visualization:
[`build_display_sf`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md),
[`plot_best_by_country_level`](https://mohamedhtitich1.github.io/localintel/reference/build_display_sf.md)

Export:
[`export_to_geojson`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md),
[`enrich_for_tableau`](https://mohamedhtitich1.github.io/localintel/reference/export_to_geojson.md)

## Author

Mohamed Htitich <m.ahtitich@outlook.com>
