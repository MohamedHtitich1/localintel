# Business Statistics Dataset Codes

Returns a named vector of Eurostat regional structural business
statistics and business demography dataset codes at NUTS 2 level.

## Usage

``` r
business_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
business_codes()
#>         sbs_nace2  sbs_distributive       local_units    bd_high_growth 
#> "sbs_r_nuts06_r2"  "sbs_r_3k_my_r2"    "sbs_cre_rreg"   "bd_hgnace2_r3" 
#>     bd_size_class          bd_nace2 
#>      "bd_size_r3"    "bd_enace2_r3" 
names(business_codes())
#> [1] "sbs_nace2"        "sbs_distributive" "local_units"      "bd_high_growth"  
#> [5] "bd_size_class"    "bd_nace2"        
```
