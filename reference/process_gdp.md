# Process GDP Data

Filters regional GDP data from Eurostat (nama_10r_2gdp)

## Usage

``` r
process_gdp(df, unit = "MIO_EUR")
```

## Arguments

- df:

  Raw dataframe from Eurostat nama_10r_2gdp

- unit:

  Unit filter (default: "MIO_EUR" for million EUR)

## Value

Processed dataframe with geo, year, and gdp columns

## Examples

``` r
if (FALSE) { # \dontrun{
gdp_data <- process_gdp(raw_gdp)
} # }
```
