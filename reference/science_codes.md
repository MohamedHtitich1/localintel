# Science and Technology Dataset Codes

Returns a named vector of Eurostat regional science and technology
dataset codes covering R&D expenditure, personnel, patents, HRST, and
high-tech employment at NUTS 2 level.

## Usage

``` r
science_codes()
```

## Value

Named character vector of dataset codes

## Examples

``` r
science_codes()
#>      rd_expenditure        rd_personnel      hrst_subgroups            hrst_sex 
#>      "rd_e_gerdreg"      "rd_p_persreg"      "hrst_st_rcat"      "hrst_st_rsex" 
#>            hrst_age hightech_employment       patents_total         patents_ipc 
#>      "hrst_st_rage"     "htec_emp_reg2"       "pat_ep_rtot"       "pat_ep_ripc" 
#>    patents_hightech         patents_ict     patents_biotech 
#>       "pat_ep_rtec"       "pat_ep_rict"       "pat_ep_rbio" 
names(science_codes())
#>  [1] "rd_expenditure"      "rd_personnel"        "hrst_subgroups"     
#>  [4] "hrst_sex"            "hrst_age"            "hightech_employment"
#>  [7] "patents_total"       "patents_ipc"         "patents_hightech"   
#> [10] "patents_ict"         "patents_biotech"    
```
