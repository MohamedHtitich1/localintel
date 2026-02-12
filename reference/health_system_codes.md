# Eurostat Dataset Code Lists

Returns named vectors of common Eurostat dataset codes for health system
resources and causes of death.

## Usage

``` r
health_system_codes()
causes_of_death_codes()
```

## Value

Named character vector of Eurostat dataset codes

## Examples

``` r
health_system_codes()
#>         disch_inp         disch_day          hos_days               los 
#> "hlth_co_disch2t" "hlth_co_disch4t" "hlth_co_hosdayt"  "hlth_co_inpstt" 
#>              beds        physicians 
#>  "hlth_rs_bdsrg2" "hlth_rs_physreg" 
causes_of_death_codes()
#>               cod_crude_rate     cod_crude_rate_residence 
#>               "hlth_cd_acdr"              "hlth_cd_acdr2" 
#>    cod_standardised_rate_res        cod_crude_rate_3y_res 
#>              "hlth_cd_asdr2"              "hlth_cd_ycdr2" 
#>     cod_crude_rate_3y_female       cod_crude_rate_3y_male 
#>              "hlth_cd_ycdrf"              "hlth_cd_ycdrm" 
#>      cod_crude_rate_3y_total       cod_infant_mort_3y_occ 
#>              "hlth_cd_ycdrt"              "hlth_cd_yinfo" 
#>       cod_infant_mort_3y_res       cod_absolute_3y_female 
#>              "hlth_cd_yinfr"               "hlth_cd_ynrf" 
#>         cod_absolute_3y_male        cod_absolute_3y_total 
#>               "hlth_cd_ynrm"               "hlth_cd_ynrt" 
#>              cod_pyll_3y_res        cod_deaths_3y_res_occ 
#>              "hlth_cd_ypyll"                "hlth_cd_yro" 
#>     cod_standardised_rate_3y cod_standardised_rate_3y_res 
#>              "hlth_cd_ysdr1"              "hlth_cd_ysdr2" 
```
