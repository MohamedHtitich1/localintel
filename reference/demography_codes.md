# Demography Dataset Codes

Returns a named vector of Eurostat regional demography dataset codes
covering population, fertility, mortality, and life expectancy at NUTS 2
level.

## Usage

``` r
demography_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
demography_codes()
#>               pop_jan        pop_5yr_groups           pop_density 
#>        "demo_r_d2jan"    "demo_r_pjangroup"       "demo_r_d3dens" 
#>                births        fertility_rate     births_mother_age 
#>       "demo_r_births"       "demo_r_frate2"        "demo_r_fagec" 
#>                deaths        deaths_age_sex      infant_mortality 
#>       "demo_r_deaths"        "demo_r_magec"         "demo_r_minf" 
#> infant_mortality_rate            life_table       life_expectancy 
#>      "demo_r_minfind"        "demo_r_mlife"      "demo_r_mlifexp" 
#>            pop_change 
#>        "demo_r_gind3" 
names(demography_codes())
#>  [1] "pop_jan"               "pop_5yr_groups"        "pop_density"          
#>  [4] "births"                "fertility_rate"        "births_mother_age"    
#>  [7] "deaths"                "deaths_age_sex"        "infant_mortality"     
#> [10] "infant_mortality_rate" "life_table"            "life_expectancy"      
#> [13] "pop_change"           
```
