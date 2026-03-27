# Gap-Fill All Regions for One Indicator

Fetches raw DHS data for a set of countries and a single indicator,
processes it, and applies
[`gapfill_series()`](https://mohamedhtitich1.github.io/localintel/reference/gapfill_series.md)
to every region that has at least `min_obs` observations.

## Usage

``` r
gapfill_indicator(country_ids, ind_code, ind_name, transform,
  min_obs = 2L, sigma_floor = 0.25, forecast_to = NULL)
```

## Arguments

- country_ids:

  Character vector of DHS country codes.

- ind_code:

  Character: DHS indicator ID.

- ind_name:

  Character: output column name for the indicator.

- transform:

  Character: `"log"` or `"logit"`.

- min_obs:

  Integer: minimum observations per region (default: 2).

- sigma_floor:

  Numeric: minimum prediction SE (default: 0.25).

- forecast_to:

  Integer: if set, forecasts to this year.

## Value

A named list with `gapfilled` (tibble), `raw` (tibble), `n_regions`,
`n_errors`, `n_warnings`, and `error_regions`.

## Examples

``` r
if (FALSE) { # \dontrun{
res <- gapfill_indicator(
  country_ids = c("KE", "NG"),
  ind_code = "CM_ECMR_C_U5M",
  ind_name = "u5_mortality",
  transform = "log"
)
} # }
```
