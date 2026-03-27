# DHS Indicator Domain Mapping

Returns a named character vector mapping DHS indicator friendly names to
their thematic domain (e.g., "Maternal & Child Health", "Mortality").

## Usage

``` r
dhs_domain_mapping()
```

## Value

Named character vector with variable names as names and domains as
values.

## Examples

``` r
if (FALSE) { # \dontrun{
domains <- dhs_domain_mapping()
table(domains)
} # }
```
