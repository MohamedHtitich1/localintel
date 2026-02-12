# Safe Logarithm and Scaling Functions

Utility functions for safe logarithm transformations and min-max
scaling. `safe_log10` and `safe_log2` return NA for non-positive values.
`scale_0_100` (alias `rescale_minmax`) scales values to 0-100 range.

## Usage

``` r
safe_log10(x)
safe_log2(x)
scale_0_100(x)
rescale_minmax(x)
```

## Arguments

- x:

  Numeric vector

## Value

Numeric vector with transformed values

## Examples

``` r
safe_log10(c(1, 10, 100, 0, -5, NA))
#> Warning: NaNs produced
#> [1]  0  1  2 NA NA NA
safe_log2(c(1, 2, 4, 0, -5, NA))
#> Warning: NaNs produced
#> [1]  0  1  2 NA NA NA
scale_0_100(c(10, 20, 30, 40, 50))
#> [1]   0  25  50  75 100
```
