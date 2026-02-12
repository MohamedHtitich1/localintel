# Process Unemployment Rate Data

Filters regional unemployment rate data from Eurostat (lfst_r_lfu3rt)

## Usage

``` r
process_unemployment_rate(df, sex = "T", age = "Y15-74")
```

## Arguments

- df:

  Raw dataframe from Eurostat lfst_r_lfu3rt

- sex:

  Sex filter (default: "T" for total)

- age:

  Age group filter (default: "Y15-74")

## Value

Processed dataframe with geo, year, and unemployment_rate columns

## Examples

``` r
if (FALSE) { # \dontrun{
unemployment_data <- process_unemployment_rate(raw_unemployment)
} # }
```
