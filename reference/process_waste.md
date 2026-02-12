# Process Municipal Waste Data

Filters regional municipal waste data from Eurostat (env_rwas_gen)

## Usage

``` r
process_waste(df, unit = "KG_HAB")
```

## Arguments

- df:

  Raw dataframe from Eurostat env_rwas_gen

- unit:

  Unit filter (default: "KG_HAB" for kg per inhabitant)

## Value

Processed dataframe with geo, year, and municipal_waste columns

## Examples

``` r
if (FALSE) { # \dontrun{
waste_data <- process_waste(raw_waste)
} # }
```
