# Process Poverty Rate Data

Filters regional at-risk-of-poverty rate data from Eurostat (ilc_li41)

## Usage

``` r
process_poverty_rate(df)
```

## Arguments

- df:

  Raw dataframe from Eurostat ilc_li41

## Value

Processed dataframe with geo, year, and poverty_rate columns

## Examples

``` r
if (FALSE) { # \dontrun{
poverty_data <- process_poverty_rate(raw_poverty)
} # }
```
