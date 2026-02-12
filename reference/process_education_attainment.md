# Process Education Attainment Data

Filters regional education attainment data from Eurostat (edat_lfse\_\*)

## Usage

``` r
process_education_attainment(df, sex = "T", age = "Y25-64", isced11 = "ED5-8")
```

## Arguments

- df:

  Raw dataframe from Eurostat edat_lfse_11 or similar

- sex:

  Sex filter (default: "T" for total)

- age:

  Age group filter (default: "Y25-64")

- isced11:

  Education level filter (default: "ED5-8" for tertiary)

## Value

Processed dataframe with geo, year, and education_attainment columns

## Examples

``` r
if (FALSE) { # \dontrun{
education_data <- process_education_attainment(raw_education)
} # }
```
