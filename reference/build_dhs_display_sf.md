# Build Display SF for DHS Admin 1 Data

Creates an sf object for visualization by joining the DHS panel data to
Admin 1 geometries.

## Usage

``` r
build_dhs_display_sf(panel, admin1_geo = NULL, var, years = NULL)
```

## Arguments

- panel:

  Dataframe from
  [`cascade_to_admin1()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_admin1.md),
  with columns `geo`, `admin0`, `year`, and indicator columns.

- admin1_geo:

  sf object from
  [`get_admin1_geo()`](https://mohamedhtitich1.github.io/localintel/reference/get_admin1_geo.md).
  If NULL, fetched automatically.

- var:

  Character string of variable to display.

- years:

  Integer vector of years to include. If NULL, uses all available.

## Value

sf object with columns: geo, admin0, year, value, geometry.

## Examples

``` r
if (FALSE) { # \dontrun{
sf_data <- build_dhs_display_sf(panel, var = "u5_mortality", years = 2020)
} # }
```
