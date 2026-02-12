# Data Cascading Functions

Functions for cascading data from NUTS0/NUTS1 to NUTS2 level.
`cascade_to_nuts2_and_compute` also computes derived indicators (DA,
rLOS). `cascade_to_nuts2_light` is a simpler version for pre-computed
scores. `balance_panel` ensures all geo-year combinations exist.

## Usage

``` r
cascade_to_nuts2_and_compute(data, vars = c("disch_inp", "disch_day", 
  "beds", "physicians", "los"), years = NULL, nuts2_ref = NULL, 
  nuts_year = 2024)
cascade_to_nuts2_light(data, vars, nuts2_ref, years = NULL, agg = dplyr::first)
balance_panel(data, vars, years, fill_direction = "downup")
```

## Arguments

- data:

  Dataframe with 'geo', 'year', and variable columns

- vars:

  Character vector of variable names to cascade

- years:

  Integer vector of years to include

- nuts2_ref:

  Reference table from get_nuts2_ref()

- nuts_year:

  Integer year for NUTS classification

- agg:

  Aggregation function for duplicates

- fill_direction:

  Direction for filling ("downup", "down", "up")

## Value

Dataframe with cascaded values at NUTS2 level

## Examples

``` r
if (FALSE) { # \dontrun{
cascaded <- cascade_to_nuts2_and_compute(all_data, nuts2_ref = nuts2_ref)
} # }
```
