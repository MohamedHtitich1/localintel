# Process Raw DHS Data

Transforms a raw DHS API response into the standard localintel
`geo / year / value` structure. Handles deduplication, reference-period
filtering, and composite key construction.

## Usage

``` r
process_dhs(df, out_col = NULL,
  ref_period = "Five years preceding the survey",
  keep_ci = FALSE, keep_denominator = FALSE, keep_metadata = FALSE)
```

## Arguments

- df:

  Raw tibble from
  [`get_dhs_data()`](https://mohamedhtitich1.github.io/localintel/reference/get_dhs_data.md)
  or
  [`fetch_dhs_batch()`](https://mohamedhtitich1.github.io/localintel/reference/fetch_dhs_batch.md).

- out_col:

  Character name for the output value column (default: `"value"`).

- ref_period:

  Character string for reference-period filtering (default:
  `"Five years preceding the survey"`).

- keep_ci:

  Logical: if TRUE, retains confidence interval columns (default:
  FALSE).

- keep_denominator:

  Logical: if TRUE, retains DenominatorWeighted (default: FALSE).

- keep_metadata:

  Logical: if TRUE, retains metadata columns (default: FALSE).

## Value

A tibble with columns: geo, year, and the value column (plus optional
CI, denominator, and metadata columns).

## Examples

``` r
if (FALSE) { # \dontrun{
raw <- get_dhs_data(
  country_ids = c("KE", "NG"),
  indicator_ids = "CM_ECMR_C_U5M",
  breakdown = "subnational"
)
processed <- process_dhs(raw, out_col = "u5_mortality")
} # }
```
