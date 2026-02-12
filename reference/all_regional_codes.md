# All Regional Indicator Dataset Codes

Returns a comprehensive named vector combining dataset codes from all 14
thematic domains. This is the full registry of Eurostat regional
indicators that localintel can process seamlessly.

## Usage

``` r
all_regional_codes()
```

## Value

Named character vector of all regional dataset codes

## Examples

``` r
all_codes <- all_regional_codes()
cat("Total indicators:", length(all_codes), "\n")
#> Total indicators: 127 
```
