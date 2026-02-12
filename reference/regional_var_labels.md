# Regional Variable Labels (All Domains)

Returns a comprehensive named vector of display labels for variables
across all thematic domains. Extends health-specific labels with
economy, education, labour, demography, tourism, and other domains.

## Usage

``` r
regional_var_labels()
```

## Value

Named character vector mapping variable names to display labels

## Examples

``` r
labels <- regional_var_labels()
labels["gdp"]
#>                                          gdp 
#> "GDP at current market prices (million EUR)" 
```
