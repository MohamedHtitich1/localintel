# Get DHS Countries for a Region

Queries the DHS countries endpoint and returns country metadata,
optionally filtered to a specific DHS region.

## Usage

``` r
get_dhs_countries(region = "Sub-Saharan Africa")
```

## Arguments

- region:

  Character string for DHS region name filter. If NULL, returns all
  countries.

## Value

A tibble with columns: DHS_CountryCode, ISO2_CountryCode, CountryName,
RegionName.

## Examples

``` r
if (FALSE) { # \dontrun{
ssa <- get_dhs_countries("Sub-Saharan Africa")
} # }
```
