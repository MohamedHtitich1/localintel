# Labour Market Dataset Codes

Returns a named vector of Eurostat regional labour market dataset codes
covering employment, unemployment, economic activity, and labour force
participation at NUTS 2 level.

## Usage

``` r
labour_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
labour_codes()
#>         pop_15plus         active_pop      activity_rate         employment 
#>  "lfst_r_lfsd2pop"   "lfst_r_lfp2act" "lfst_r_lfp2actrt"   "lfst_r_lfe2emp" 
#>    employment_rate     empl_by_sector     empl_by_status     empl_full_part 
#> "lfst_r_lfe2emprt"   "lfst_r_lfe2en2" "lfst_r_lfe2estat" "lfst_r_lfe2eftpt" 
#>  empl_by_education         empl_hours       unemployment  unemployment_rate 
#>  "lfst_r_lfe2eedu" "lfst_r_lfe2ehour"  "lfst_r_lfu3pers"    "lfst_r_lfu3rt" 
#>    long_term_unemp 
#>   "lfst_r_lfu2ltu" 
names(labour_codes())
#>  [1] "pop_15plus"        "active_pop"        "activity_rate"    
#>  [4] "employment"        "employment_rate"   "empl_by_sector"   
#>  [7] "empl_by_status"    "empl_full_part"    "empl_by_education"
#> [10] "empl_hours"        "unemployment"      "unemployment_rate"
#> [13] "long_term_unemp"  
```
