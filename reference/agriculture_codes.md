# Agriculture Dataset Codes

Returns a named vector of Eurostat regional agriculture dataset codes
covering crop production, livestock, land use, and milk production at
NUTS 2 level.

## Usage

``` r
agriculture_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
agriculture_codes()
#>      animal_pop crop_production        land_use milk_production   agri_accounts 
#>  "agr_r_animal"   "agr_r_crops" "agr_r_landuse"  "agr_r_milkpr"   "agr_r_accts" 
names(agriculture_codes())
#> [1] "animal_pop"      "crop_production" "land_use"        "milk_production"
#> [5] "agri_accounts"  
```
