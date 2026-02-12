# Eurostat Data Fetching Functions

Functions for fetching data from the Eurostat API at various NUTS
levels. `get_nuts_level_robust` includes retry logic for failed
requests. `fetch_eurostat_batch` fetches multiple datasets at once.

## Usage

``` r
get_nuts2(code, years = NULL)
get_nuts_level(code, level = 2, years = NULL)
get_nuts_level_robust(code, level = 2, years = NULL)
get_nuts_level_safe(code, level = 2, years = NULL)
fetch_eurostat_batch(codes, level = 2, years = NULL, robust = TRUE)
drop_empty(x)
```

## Arguments

- code:

  Character string of the Eurostat dataset code

- codes:

  Named character vector of Eurostat dataset codes

- level:

  Integer NUTS level (0, 1, 2, or 3)

- years:

  Integer vector of years to filter

- robust:

  Logical, whether to use robust fetching with retry logic

- x:

  List of dataframes

## Value

Dataframe or list of dataframes with Eurostat data

## Examples

``` r
if (FALSE) { # \dontrun{
beds_data <- get_nuts2("hlth_rs_bdsrg2", years = 2015:2023)
data_list <- fetch_eurostat_batch(health_system_codes(), level = 2)
} # }
```
