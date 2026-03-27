# Get Admin 1 Geometries for SSA Countries

Fetches Admin 1 (state/province/region) boundary geometries for
Sub-Saharan African countries. Uses GADM as the primary source with
Natural Earth fallback. Automatically harmonizes region names and
handles special cases.

## Usage

``` r
get_admin1_geo(country_ids = NULL)
```

## Arguments

- country_ids:

  Character vector of 2-letter DHS country codes. If NULL, uses
  [`ssa_codes()`](https://mohamedhtitich1.github.io/localintel/reference/ssa_codes.md).

## Value

An sf object with columns: admin0, admin1_name, geometry (MULTIPOLYGON
in EPSG:4326).

## Examples

``` r
if (FALSE) { # \dontrun{
geo <- get_admin1_geo(country_ids = c("KE", "NG"))
plot(geo["admin1_name"])
} # }
```
