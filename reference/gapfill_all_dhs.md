# Gap-Fill All DHS Indicators Across SSA

Runs
[`gapfill_indicator()`](https://mohamedhtitich1.github.io/localintel/reference/gapfill_indicator.md)
for every indicator in the package's registries. Automatically selects
the correct transform (log for mortality/education, logit for
proportions).

## Usage

``` r
gapfill_all_dhs(country_ids = ssa_codes(), sigma_floor = 0.25,
  forecast_to = NULL, verbose = TRUE)
```

## Arguments

- country_ids:

  Character vector of DHS country codes. Defaults to
  [`ssa_codes()`](https://mohamedhtitich1.github.io/localintel/reference/ssa_codes.md).

- sigma_floor:

  Numeric: minimum prediction SE (default: 0.25).

- forecast_to:

  Integer: if set, forecasts to this year.

- verbose:

  Logical: print progress to console (default: TRUE).

## Value

A named list with `data` (named list of tibbles) and `summary`
(diagnostics).

## Examples

``` r
if (FALSE) { # \dontrun{
result <- gapfill_all_dhs(country_ids = tier1_codes())
} # }
```
