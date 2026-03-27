# Enrich DHS Data for Tableau Export

Enriches DHS sf data with country names and domain metadata for
Tableau-ready exports.

## Usage

``` r
enrich_dhs_for_tableau(sf_data, var_col = "var", value_col = "value")
```

## Arguments

- sf_data:

  sf object from
  [`build_dhs_display_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_dhs_display_sf.md)
  or
  [`build_dhs_multi_var_sf()`](https://mohamedhtitich1.github.io/localintel/reference/build_dhs_multi_var_sf.md).

- var_col:

  Name of the variable column (default: "var").

- value_col:

  Name of the value column (default: "value").

## Value

Enriched sf object with country names and performance tags.

## Examples

``` r
if (FALSE) { # \dontrun{
sf_enriched <- enrich_dhs_for_tableau(sf_multi)
} # }
```
