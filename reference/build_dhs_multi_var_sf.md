# Build Multi-Indicator SF for DHS Data

Creates an sf object containing multiple DHS indicators suitable for
export to geospatial formats like GeoJSON.

## Usage

``` r
build_dhs_multi_var_sf(panel, admin1_geo = NULL, vars = NULL,
  years = NULL, var_labels = NULL, domain_mapping = NULL)
```

## Arguments

- panel:

  Dataframe from
  [`cascade_to_admin1()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_admin1.md).

- admin1_geo:

  sf object from
  [`get_admin1_geo()`](https://mohamedhtitich1.github.io/localintel/reference/get_admin1_geo.md).
  If NULL, fetched automatically.

- vars:

  Character vector of variables to include. If NULL, auto-detected from
  imp\_\*\_flag columns.

- years:

  Integer vector of years to include. If NULL, uses all.

- var_labels:

  Named character vector of variable labels. If NULL, uses
  [`dhs_var_labels()`](https://mohamedhtitich1.github.io/localintel/reference/dhs_var_labels.md).

- domain_mapping:

  Named character vector of domain assignments. If NULL, uses
  [`dhs_domain_mapping()`](https://mohamedhtitich1.github.io/localintel/reference/dhs_domain_mapping.md).

## Value

sf object with columns: geo, admin0, year, value, var, var_label,
domain, geometry.

## Examples

``` r
if (FALSE) { # \dontrun{
sf_all <- build_dhs_multi_var_sf(panel)
} # }
```
