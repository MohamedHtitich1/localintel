# Normalize Eurostat Column Names

Detects and renames non-standard column names that Eurostat's bulk
download sometimes returns, such as `"geo\TIME_PERIOD"` instead of a
proper `"geo"` column, or `"TIME_PERIOD"` instead of `"time"`. Call this
immediately after
[`eurostat::get_eurostat()`](https://ropengov.github.io/eurostat/reference/get_eurostat.html)
to ensure downstream code can rely on standard column names.

## Usage

``` r
normalize_eurostat_cols(df)
```

## Arguments

- df:

  Dataframe freshly returned from Eurostat

## Value

Dataframe with normalized column names (`geo`, `time`)

## Examples

``` r
if (FALSE) { # \dontrun{
df <- eurostat::get_eurostat("hlth_rs_bdsrg2") %>% normalize_eurostat_cols()
} # }
```
