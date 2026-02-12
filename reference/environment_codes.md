# Environment and Energy Dataset Codes

Returns a named vector of Eurostat regional environment and energy
dataset codes covering waste, water, land use, energy consumption, and
contaminated sites at NUTS 2 level.

## Usage

``` r
environment_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
environment_codes()
#>       municipal_waste        waste_coverage    contaminated_sites 
#>        "env_rwas_gen"        "env_rwas_cov"             "env_rlu" 
#>    energy_consumption      transport_params  heating_degree_month 
#>            "env_rpep"             "env_rtr"         "nrg_esdgr_m" 
#> heating_degree_annual 
#>         "nrg_esdgr_a" 
names(environment_codes())
#> [1] "municipal_waste"       "waste_coverage"        "contaminated_sites"   
#> [4] "energy_consumption"    "transport_params"      "heating_degree_month" 
#> [7] "heating_degree_annual"
```
