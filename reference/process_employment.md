# Process Employment Data

Filters regional employment data from Eurostat LFS datasets

## Usage

``` r
process_employment(df, unit = "THS", sex = "T", age = "Y15-64")
```

## Arguments

- df:

  Raw dataframe from Eurostat lfst_r_lfe2emp or similar

- unit:

  Unit filter (default: "THS" for thousands)

- sex:

  Sex filter (default: "T" for total)

- age:

  Age group filter (default: "Y15-64")

## Value

Processed dataframe with geo, year, and employment columns

## Examples

``` r
if (FALSE) { # \dontrun{
employment_data <- process_employment(raw_employment)
} # }
```
