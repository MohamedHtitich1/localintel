# Count Available Regional Indicators

Returns the total number of Eurostat regional indicators in the
localintel registry, along with the number of thematic domains.

## Usage

``` r
indicator_count()
```

## Value

A named list with `indicators` (total count), `domains` (number of
thematic domains), and `by_domain` (count per domain)

## Examples

``` r
n <- indicator_count()
cat(n$indicators, "indicators across", n$domains, "domains\n")
#> 127 indicators across 15 domains
```
