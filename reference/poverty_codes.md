# Poverty and Social Exclusion Dataset Codes

Returns a named vector of Eurostat regional poverty and social exclusion
dataset codes at NUTS 2 level.

## Usage

``` r
poverty_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
poverty_codes()
#> at_risk_poverty_exclusion        low_work_intensity      material_deprivation 
#>              "ilc_peps11"              "ilc_lvhl21"              "ilc_mddd21" 
#>      at_risk_poverty_rate 
#>                "ilc_li41" 
names(poverty_codes())
#> [1] "at_risk_poverty_exclusion" "low_work_intensity"       
#> [3] "material_deprivation"      "at_risk_poverty_rate"     
```
