# Process Life Expectancy Data

Filters regional life expectancy data from Eurostat (demo_r_mlifexp)

## Usage

``` r
process_life_expectancy(df, sex = "T", age = "Y_LT1")
```

## Arguments

- df:

  Raw dataframe from Eurostat demo_r_mlifexp

- sex:

  Sex filter (default: "T" for total)

- age:

  Age at which expectancy is computed (default: "Y_LT1" for at birth)

## Value

Processed dataframe with geo, year, and life_expectancy columns

## Examples

``` r
if (FALSE) { # \dontrun{
life_expectancy_data <- process_life_expectancy(raw_life_expectancy)
} # }
```
