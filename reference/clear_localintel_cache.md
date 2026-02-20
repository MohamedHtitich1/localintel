# Clear Session Cache

Removes all cached data from the localintel session cache. Useful when
you want to force fresh data fetches from Eurostat, for example after a
NUTS classification update.

## Usage

``` r
clear_localintel_cache()
```

## Value

Invisible NULL

## Examples

``` r
if (FALSE) { # \dontrun{
# Force refresh of all cached geometries and references
clear_localintel_cache()
} # }
```
