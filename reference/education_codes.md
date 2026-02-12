# Education Dataset Codes

Returns a named vector of Eurostat regional education dataset codes
covering students, educational attainment, training, early leavers, and
NEET rates at NUTS 2 level.

## Usage

``` r
education_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
education_codes()
#>       students_level         students_age      educ_indicators 
#>      "educ_renrlrg1"      "educ_renrlrg3"        "educ_regind" 
#>        training_rate     attain_lower_sec     attain_upper_sec 
#>       "trng_lfse_04"       "edat_lfse_09"       "edat_lfse_10" 
#>      attain_tertiary    attain_tert_30_34 attain_upper_or_tert 
#>       "edat_lfse_11"       "edat_lfse_12"       "edat_lfse_13" 
#>        early_leavers            neet_rate 
#>       "edat_lfse_16"       "edat_lfse_22" 
names(education_codes())
#>  [1] "students_level"       "students_age"         "educ_indicators"     
#>  [4] "training_rate"        "attain_lower_sec"     "attain_upper_sec"    
#>  [7] "attain_tertiary"      "attain_tert_30_34"    "attain_upper_or_tert"
#> [10] "early_leavers"        "neet_rate"           
```
