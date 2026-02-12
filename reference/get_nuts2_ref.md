# NUTS Reference Data Functions

Functions for fetching NUTS reference geometries, lookup tables, and
population data.

## Usage

``` r
get_nuts2_ref(year = 2024, resolution = "60")
get_nuts_geo(level, year = 2024, resolution = "60", crs = 4326)
get_nuts_geopolys(year = 2024, resolution = "60", crs = 4326, levels = c(0, 1, 2))
get_nuts2_names(year = 2024, resolution = "60", countries = NULL)
get_population_nuts2(years = 2000:2024, countries = NULL, fill_gaps = TRUE)
```

## Arguments

- year:

  Integer year for NUTS classification (default: 2024)

- resolution:

  Character resolution code ("60", "20", "10", "03", "01")

- level:

  Integer NUTS level (0, 1, 2, or 3)

- levels:

  Integer vector of NUTS levels to include

- crs:

  Integer EPSG code for coordinate reference system

- countries:

  Optional character vector of 2-letter country codes to filter

- years:

  Integer vector of years

- fill_gaps:

  Logical, whether to fill gaps using forward/backward fill

## Value

Dataframe or sf object with NUTS reference data

## Examples

``` r
if (FALSE) { # \dontrun{
nuts2_ref <- get_nuts2_ref()
geopolys <- get_nuts_geopolys()
pop <- get_population_nuts2(years = 2010:2024)
} # }
```
