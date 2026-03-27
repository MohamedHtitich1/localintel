# Process a Batch of DHS Indicators

Takes the output of
[`fetch_dhs_batch()`](https://mohamedhtitich1.github.io/localintel/reference/fetch_dhs_batch.md)
(a named list of raw tibbles) and applies
[`process_dhs()`](https://mohamedhtitich1.github.io/localintel/reference/process_dhs.md)
to each, using the list names as the `out_col`. Returns a named list of
processed tibbles.

## Usage

``` r
process_dhs_batch(batch_list,
  ref_period = "Five years preceding the survey",
  keep_ci = FALSE, keep_denominator = FALSE)
```

## Arguments

- batch_list:

  Named list of raw tibbles from
  [`fetch_dhs_batch()`](https://mohamedhtitich1.github.io/localintel/reference/fetch_dhs_batch.md).

- ref_period:

  Reference period filter (passed to
  [`process_dhs()`](https://mohamedhtitich1.github.io/localintel/reference/process_dhs.md)).

- keep_ci:

  Passed to
  [`process_dhs()`](https://mohamedhtitich1.github.io/localintel/reference/process_dhs.md).

- keep_denominator:

  Passed to
  [`process_dhs()`](https://mohamedhtitich1.github.io/localintel/reference/process_dhs.md).

## Value

Named list of processed tibbles, each with `geo`, `year`, and a value
column named after the list element.

## Examples

``` r
if (FALSE) { # \dontrun{
codes <- c(u5_mortality = "CM_ECMR_C_U5M", stunting = "CN_NUTS_C_HA2")
raw_batch <- fetch_dhs_batch(codes, country_ids = c("KE", "NG"))
processed <- process_dhs_batch(raw_batch)
} # }
```
