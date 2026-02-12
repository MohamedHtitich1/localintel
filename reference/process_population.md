# Process Population Data

Filters regional population data from Eurostat (demo_r_d2jan)

## Usage

``` r
process_population(df, sex = "T", age = "TOTAL")
```

## Arguments

- df:

  Raw dataframe from Eurostat demo_r_d2jan

- sex:

  Sex filter (default: "T" for total)

- age:

  Age group filter (default: "TOTAL")

## Value

Processed dataframe with geo, year, and population columns

## Examples

``` r
if (FALSE) { # \dontrun{
population_data <- process_population(raw_population)
} # }
```
