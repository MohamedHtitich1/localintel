# EU27 Country Filtering and Naming Functions

Functions for filtering data to EU27 countries and adding country names.

## Usage

``` r
keep_eu27(df, extra = c("NO", "IS"))
eu27_codes()
nuts_country_names()
add_country_name(df, geo_col = "geo", out_col = "Country")
```

## Arguments

- df:

  Dataframe with a 'geo' column containing NUTS codes

- extra:

  Character vector of additional 2-letter country codes to include

- geo_col:

  Name of the geo column (default: "geo")

- out_col:

  Name of the output country column (default: "Country")

## Value

`keep_eu27`: Filtered dataframe `eu27_codes`: Character vector of EU27
country codes `nuts_country_names`: Named character vector mapping codes
to country names `add_country_name`: Dataframe with added country name
column

## Examples

``` r
eu27_codes()
#>  [1] "AT" "BE" "BG" "HR" "CY" "CZ" "DK" "EE" "FI" "FR" "DE" "EL" "HU" "IE" "IT"
#> [16] "LV" "LT" "LU" "MT" "NL" "PL" "PT" "RO" "SK" "SI" "ES" "SE"
nuts_country_names()
#>                AT                BE                BG                HR 
#>         "Austria"         "Belgium"        "Bulgaria"         "Croatia" 
#>                CY                CZ                DK                EE 
#>          "Cyprus"         "Czechia"         "Denmark"         "Estonia" 
#>                FI                FR                DE                EL 
#>         "Finland"          "France"         "Germany"          "Greece" 
#>                GR                HU                IE                IT 
#>          "Greece"         "Hungary"         "Ireland"           "Italy" 
#>                LV                LT                LU                MT 
#>          "Latvia"       "Lithuania"      "Luxembourg"           "Malta" 
#>                NL                PL                PT                RO 
#>     "Netherlands"          "Poland"        "Portugal"         "Romania" 
#>                SK                SI                ES                SE 
#>        "Slovakia"        "Slovenia"           "Spain"          "Sweden" 
#>                NO                IS                CH                UK 
#>          "Norway"         "Iceland"     "Switzerland"  "United Kingdom" 
#>                GB                RS                TR                ME 
#>  "United Kingdom"          "Serbia"         "Turkiye"      "Montenegro" 
#>                MK                AL 
#> "North Macedonia"         "Albania" 
```
