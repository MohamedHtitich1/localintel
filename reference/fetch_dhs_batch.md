# Batch Fetch DHS Indicators

Iterates over indicator/country combinations with rate-limit-aware
delays. Returns a named list of tibbles, one per indicator ID.

## Usage

``` r
fetch_dhs_batch(indicator_ids, country_ids = NULL, years = NULL,
  breakdown = "subnational")
```

## Arguments

- indicator_ids:

  Named character vector where names are friendly names and values are
  DHS indicator IDs.

- country_ids:

  Character vector of DHS country codes. If NULL, fetches all SSA
  countries.

- years:

  Integer vector of survey years. If NULL, returns all available.

- breakdown:

  Character: `"subnational"` (default) or `"national"`.

## Value

Named list of tibbles, one per indicator.

## Examples

``` r
if (FALSE) { # \dontrun{
codes <- c(u5_mortality = "CM_ECMR_C_U5M", stunting = "CN_NUTS_C_HA2")
data_list <- fetch_dhs_batch(codes, country_ids = c("KE", "NG"))
} # }
```
