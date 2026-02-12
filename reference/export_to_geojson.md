# Export Functions

Functions for exporting data to various formats including GeoJSON for
Tableau, Excel, and RDS. Also includes helper functions for variable
labels and mappings.

## Usage

``` r
export_to_geojson(sf_data, filepath, crs = 4326)
export_to_excel(df, filepath)
export_to_rds(obj, filepath)
save_maps_to_pdf(plot_fn, filepath, width = 12, height = 8, ...)
enrich_for_tableau(sf_data, pop_data = NULL, nuts2_names = NULL, 
  var_col = "var", value_col = "value")
health_var_labels()
health_pillar_mapping()
cod_labels()
```

## Arguments

- sf_data:

  sf object to export

- df:

  Dataframe to export

- obj:

  Object to export

- filepath:

  Character path for output file

- crs:

  Integer EPSG code (default: 4326)

- plot_fn:

  Function that generates plots

- width:

  PDF width in inches

- height:

  PDF height in inches

- ...:

  Additional arguments passed to plot_fn

- pop_data:

  Population dataframe

- nuts2_names:

  Name lookup dataframe

- var_col:

  Name of the variable column

- value_col:

  Name of the value column

## Value

Invisibly returns the filepath, or named character vector for label
functions

## Examples

``` r
if (FALSE) { # \dontrun{
export_to_geojson(sf_data, "output/data.geojson")
export_to_excel(df, "output/data.xlsx")
} # }
health_var_labels()
#>                        score_cod_standardised_rate_res_tr 
#>                     "Standardized causes of death (rate)" 
#>                                  score_cod_pyll_3y_res_tr 
#>           "Potential Years of Life Lost (3-year average)" 
#>                              score_infant_mortality_rt_tr 
#>                                 "Infant mortality (rate)" 
#>                                            health_outcome 
#>                             "Health Outcomes (composite)" 
#>                                                 score_E_E 
#>                        "Enabling Environment (Composite)" 
#>                                                physicians 
#>                       "Physicians per 100000 inhabitants" 
#>                                                      beds 
#>                             "Beds per 100000 inhabitants" 
#>                                           score_TOOEFW_tr 
#>      "Too expensive or too far to travel or waiting list" 
#>                                           score_HOPING_tr 
#> "Wanted to wait and see if problem got better on its own" 
#>                                         score_NO_UNMET_tr 
#>                               "No unmet needs to declare" 
#>                                       score_health_percep 
#>                           "Health Perception (Composite)" 
health_pillar_mapping()
#>          score_cod_standardised_rate_res_tr 
#>                           "Health Outcomes" 
#>                    score_cod_pyll_3y_res_tr 
#>                           "Health Outcomes" 
#>                score_infant_mortality_rt_tr 
#>                           "Health Outcomes" 
#>                              health_outcome 
#>                           "Health Outcomes" 
#>                                   score_E_E 
#>                      "Enabling Environment" 
#>                                  physicians 
#>                      "Enabling Environment" 
#>                                        beds 
#>                      "Enabling Environment" 
#>                             score_TOOEFW_tr 
#> "Health Perception (Reason of unmet needs)" 
#>                             score_HOPING_tr 
#> "Health Perception (Reason of unmet needs)" 
#>                           score_NO_UNMET_tr 
#> "Health Perception (Reason of unmet needs)" 
#>                         score_health_percep 
#> "Health Perception (Reason of unmet needs)" 
```
