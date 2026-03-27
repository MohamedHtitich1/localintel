# Add DHS Country Name

Joins a full country name column to a processed DHS dataframe. Extracts
the 2-letter country code from the `geo` column and looks up the name
from the DHS countries endpoint.

## Usage

``` r
add_dhs_country_name(df, col_name = "country_name")
```

## Arguments

- df:

  Dataframe with a `geo` column in DHS composite format.

- col_name:

  Name of the new column (default: `"country_name"`).

## Value

Dataframe with an additional country name column.

## Examples

``` r
if (FALSE) { # \dontrun{
processed <- process_dhs(raw_data, out_col = "stunting")
with_names <- add_dhs_country_name(processed)
} # }
```
