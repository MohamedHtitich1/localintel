# Get Admin 1 Reference Table

Builds a reference table mapping DHS Admin 1 regions to their parent
countries. This is the DHS equivalent of
[`get_nuts2_ref()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md),
mapping subnational regions to country-level codes.

## Usage

``` r
get_admin1_ref(country_ids = NULL)
```

## Arguments

- country_ids:

  Character vector of DHS country codes. If NULL (default), uses
  [`tier1_codes()`](https://mohamedhtitich1.github.io/localintel/reference/tier1_codes.md).

## Value

A tibble with columns:

- geo:

  Composite key: `DHS_CountryCode + "_" + CharacteristicLabel`

- admin0:

  2-letter DHS country code

- country_name:

  Full country name

- region_label:

  Admin 1 region name

## Examples

``` r
if (FALSE) { # \dontrun{
ref <- get_admin1_ref()
ref_ke <- get_admin1_ref(country_ids = "KE")
} # }
```
