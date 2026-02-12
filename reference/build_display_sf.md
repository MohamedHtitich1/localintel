# Visualization Functions

Functions for creating maps and visualizations of NUTS-level data.
`build_display_sf` creates an sf object selecting the best available
NUTS level for each country-year combination.

## Usage

``` r
build_display_sf(out_nuts2, geopolys, var, years = NULL, 
  skip_nuts0 = TRUE, scale = c("per_year", "global"))
lc_build_display_sf(out_nuts2, geopolys, var, years = NULL, 
  skip_nuts0 = TRUE, scale = c("per_year", "global"), keep = NULL)
plot_best_by_country_level(out_nuts2, geopolys, var, years = NULL, 
  skip_nuts0 = TRUE, scale = c("per_year", "global"), title = NULL, 
  pdf_file = paste0("Map_", var, "_country_level_scaled.pdf"), 
  bb_x = c(2400000, 7800000), bb_y = c(1320000, 5650000), 
  col_var = NULL, n_breaks = 7, breaks = NULL)
build_multi_var_sf(out_nuts2, geopolys, vars, years = 2010:2024, 
  var_labels = NULL, pillar_mapping = NULL)
level_col_for(var, special_cases = NULL)
level_cols_for(vars)
```

## Arguments

- out_nuts2:

  Dataframe with cascaded NUTS2 data

- geopolys:

  sf object with NUTS geometries

- var:

  Character string of variable to display

- vars:

  Character vector of variables

- years:

  Integer vector of years to include

- skip_nuts0:

  Logical, whether to skip NUTS0 level display

- scale:

  Character, "per_year" or "global" scaling

- keep:

  Character vector of additional columns to preserve

- title:

  Optional custom title

- pdf_file:

  Optional PDF filename for output

- bb_x:

  Numeric vector of x bounding box limits

- bb_y:

  Numeric vector of y bounding box limits

- col_var:

  Column to use for coloring

- n_breaks:

  Number of legend breaks

- breaks:

  Optional custom breaks vector

- var_labels:

  Named character vector mapping vars to display labels

- pillar_mapping:

  Named character vector mapping vars to pillars

- special_cases:

  Optional named character vector of special variable-to-column
  mappings. If NULL, uses default health indicator mappings.

## Value

sf object for mapping or printed tmap plots

## Examples

``` r
if (FALSE) { # \dontrun{
sf_data <- build_display_sf(cascaded, geopolys, var = "beds", years = 2020:2024)
plot_best_by_country_level(cascaded, geopolys, var = "beds", years = 2020:2024)
} # }
```
