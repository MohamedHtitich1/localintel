# Count Available DHS Indicators

Returns the total number of DHS indicators in the localintel registry,
along with the number of thematic domains.

## Usage

``` r
dhs_indicator_count()
```

## Value

A named list with `indicators` (total count), `domains` (number of
domains), and `by_domain` (counts per domain).

## Examples

``` r
if (FALSE) { # \dontrun{
n <- dhs_indicator_count()
cat(n$indicators, "DHS indicators across", n$domains, "domains")
} # }
```
