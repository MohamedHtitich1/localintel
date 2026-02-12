# Tourism Dataset Codes

Returns a named vector of Eurostat regional tourism dataset codes
covering arrivals, nights spent, and accommodation capacity at NUTS 2
level.

## Usage

``` r
tourism_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
tourism_codes()
#>              arrivals          nights_spent   nights_urbanisation 
#>       "tour_occ_arn2"       "tour_occ_nin2"      "tour_occ_nin2d" 
#>        nights_coastal        occupancy_rate        capacity_nuts2 
#>      "tour_occ_nin2c"      "tour_occ_anor2"      "tour_cap_nuts2" 
#> capacity_urbanisation      capacity_coastal 
#>     "tour_cap_nuts2d"     "tour_cap_nuts2c" 
names(tourism_codes())
#> [1] "arrivals"              "nights_spent"          "nights_urbanisation"  
#> [4] "nights_coastal"        "occupancy_rate"        "capacity_nuts2"       
#> [7] "capacity_urbanisation" "capacity_coastal"     
```
