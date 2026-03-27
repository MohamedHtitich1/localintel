# Full DHS Pipeline: Fetch, Process, Gap-Fill, and Cascade

Convenience wrapper that runs the complete DHS data pipeline from raw
API fetch through to a balanced analysis-ready panel.

## Usage

``` r
dhs_pipeline(country_ids = ssa_codes(), sigma_floor = 0.25,
  balance = TRUE, min_countries = 5L, min_indicators = 10L,
  include_ci = TRUE, national_fallback = TRUE, verbose = TRUE)
```

## Arguments

- country_ids:

  Character vector of DHS country codes. Defaults to
  [`ssa_codes()`](https://mohamedhtitich1.github.io/localintel/reference/ssa_codes.md).

- sigma_floor:

  Numeric: minimum prediction SE (default: 0.25).

- balance:

  Logical: apply panel balancing (default: TRUE).

- min_countries:

  Integer: minimum countries per indicator (default: 5).

- min_indicators:

  Integer: minimum indicators per region (default: 10).

- include_ci:

  Logical: include CI columns (default: TRUE).

- national_fallback:

  Logical: use national fallback (default: TRUE).

- verbose:

  Logical: print progress (default: TRUE).

## Value

A list with `panel`, `gapfill_summary`, `dropped_indicators`, and
`dropped_regions`.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- dhs_pipeline(country_ids = tier1_codes())
} # }
```
