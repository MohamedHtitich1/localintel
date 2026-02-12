# Regional Domain Mapping (All Domains)

Returns a named vector mapping variable names to their thematic domain.
Useful for grouping variables in dashboards and Tableau exports.

## Usage

``` r
regional_domain_mapping()
```

## Value

Named character vector mapping variable names to domain names

## Examples

``` r
mapping <- regional_domain_mapping()
mapping["gdp"]
#>       gdp 
#> "Economy" 
mapping["unemployment_rate"]
#> unemployment_rate 
#>   "Labour Market" 
```
