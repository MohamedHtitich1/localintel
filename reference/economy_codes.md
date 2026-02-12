# Economy and Regional Accounts Dataset Codes

Returns a named vector of Eurostat regional economic account dataset
codes covering GDP, GVA, employment, household income, and capital
formation at NUTS 2 level.

## Usage

``` r
economy_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
economy_codes()
#>         gdp_nuts2         gdp_nuts3        gdp_growth           gva_a10 
#>   "nama_10r_2gdp"   "nama_10r_3gdp" "nama_10r_2grgdp"   "nama_10r_3gva" 
#>              gfcf      compensation  employment_hours hh_primary_income 
#>  "nama_10r_2gfcf"   "nama_10r_2rem" "nama_10r_2emhrw" "nama_10r_2hhinc" 
#>    hh_disp_income    gdp_per_capita 
#>  "nama_10r_2hhdi"   "nama_10r_2gdp" 
names(economy_codes())
#>  [1] "gdp_nuts2"         "gdp_nuts3"         "gdp_growth"       
#>  [4] "gva_a10"           "gfcf"              "compensation"     
#>  [7] "employment_hours"  "hh_primary_income" "hh_disp_income"   
#> [10] "gdp_per_capita"   
```
