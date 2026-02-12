# Information Society Dataset Codes

Returns a named vector of Eurostat regional information society dataset
codes covering internet access, broadband, e-commerce, and e-government
at NUTS 2 level.

## Usage

``` r
information_society_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
information_society_codes()
#>     internet_access           broadband never_used_computer        internet_use 
#>     "isoc_r_iacc_h"    "isoc_r_broad_h"      "isoc_r_cux_i"     "isoc_r_iuse_i" 
#>            egov_use           ecommerce 
#>      "isoc_r_gov_i"    "isoc_r_blt12_i" 
names(information_society_codes())
#> [1] "internet_access"     "broadband"           "never_used_computer"
#> [4] "internet_use"        "egov_use"            "ecommerce"          
```
