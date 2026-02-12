# Process R&D Expenditure Data

Filters regional R&D expenditure data from Eurostat (rd_e_gerdreg)

## Usage

``` r
process_rd_expenditure(df, unit = "PC_GDP", sectperf = "TOTAL")
```

## Arguments

- df:

  Raw dataframe from Eurostat rd_e_gerdreg

- unit:

  Unit filter (default: "PC_GDP" for percentage of GDP)

- sectperf:

  Sector of performance (default: "TOTAL")

## Value

Processed dataframe with geo, year, and rd_expenditure columns

## Examples

``` r
if (FALSE) { # \dontrun{
rd_data <- process_rd_expenditure(raw_rd)
} # }
```
