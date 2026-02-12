# Process Any Eurostat Dataset

A generic processor that filters any Eurostat dataset by arbitrary
dimension values and returns a standardized geo/year/value tibble. This
is the universal building block for processing indicators from any
domain — economy, education, labour, tourism, etc.

## Usage

``` r
process_eurostat(df, filters = list(), value_col = "values", out_col = NULL)
```

## Arguments

- df:

  Raw dataframe from any Eurostat dataset

- filters:

  Named list of dimension filters. Each name is a column and each value
  is a character vector of accepted values. Example:
  `list(unit = "PC", sex = "T", age = "TOTAL")`

- value_col:

  Name of the value column in the raw data (default: "values")

- out_col:

  Name of the output value column. If NULL, defaults to the first filter
  value or "value".

## Value

Processed tibble with columns: geo, year, and the named value column

## Examples

``` r
if (FALSE) { # \dontrun{
# GDP at current market prices
gdp <- process_eurostat(raw_gdp, filters = list(unit = "MIO_EUR"), out_col = "gdp")

# Unemployment rate, total, 15-74
unemp <- process_eurostat(raw_unemp,
  filters = list(sex = "T", age = "Y15-74", unit = "PC"),
  out_col = "unemployment_rate")

# Tertiary education attainment
educ <- process_eurostat(raw_educ,
  filters = list(sex = "T", age = "Y25-64", isced11 = "ED5-8"),
  out_col = "tertiary_attainment")
} # }
```
