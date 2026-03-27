# Get Admin 0 (Country) Geometries

Fetches country (Admin 0) boundary geometries for African countries from
Natural Earth. Optionally includes all African countries as context.

## Usage

``` r
get_admin0_geo(country_ids = NULL, buffer_countries = TRUE)
```

## Arguments

- country_ids:

  Character vector of 2-letter DHS country codes. If NULL, uses
  [`ssa_codes()`](https://mohamedhtitich1.github.io/localintel/reference/ssa_codes.md).

- buffer_countries:

  Logical: if TRUE, includes all African countries for basemap context
  (default: TRUE).

## Value

An sf object with columns: admin0, name, in_ssa, geometry (in
EPSG:4326).

## Examples

``` r
if (FALSE) { # \dontrun{
geo <- get_admin0_geo(country_ids = c("KE", "NG"))
} # }
```
