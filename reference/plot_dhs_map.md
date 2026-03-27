# Plot DHS Indicator as Choropleth Map

Creates choropleth maps of DHS indicator data at Admin 1 level across
Sub-Saharan Africa using tmap.

## Usage

``` r
plot_dhs_map(panel, admin1_geo = NULL, var, years = NULL,
  title = NULL, palette = "viridis", n_breaks = 7, breaks = NULL,
  bb_x = c(-18, 52), bb_y = c(-36, 18), basemap = TRUE,
  pdf_file = NULL)
```

## Arguments

- panel:

  Dataframe from
  [`cascade_to_admin1()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_admin1.md).

- admin1_geo:

  sf object from
  [`get_admin1_geo()`](https://mohamedhtitich1.github.io/localintel/reference/get_admin1_geo.md).
  If NULL, fetched automatically.

- var:

  Character string of variable to plot.

- years:

  Integer vector of years to plot. If NULL, uses most recent.

- title:

  Optional custom title. If NULL, uses DHS variable label.

- palette:

  Character: tmap/viridis palette (default: "viridis").

- n_breaks:

  Integer: number of legend breaks (default: 7).

- breaks:

  Optional custom breaks vector.

- bb_x:

  Numeric vector of longitude limits (default: Africa extent).

- bb_y:

  Numeric vector of latitude limits (default: Africa extent).

- basemap:

  Logical: draw country borders (default: TRUE).

- pdf_file:

  Optional PDF filename for output.

## Value

Prints tmap objects for each year.

## Examples

``` r
if (FALSE) { # \dontrun{
plot_dhs_map(panel, var = "u5_mortality", years = 2020)
} # }
```
