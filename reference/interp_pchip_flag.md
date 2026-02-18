# PCHIP Interpolation with Constant Endpoints

Performs Piecewise Cubic Hermite Interpolating Polynomial (PCHIP)
interpolation for missing values within the observed range. Uses
monotone Hermite splines (Fritsch-Carlson method) via
[`splinefun`](https://rdrr.io/r/stats/splinefun.html) which are robust
to non-linear patterns and avoid overshooting between knots. Endpoints
beyond observed data are held constant (last observation carried
forward/backward).

This function replaces the previous linear interpolation approach with a
more sophisticated method that preserves monotonicity and handles
non-linear relationships better.

## Usage

``` r
interp_pchip_flag(y)
```

## Arguments

- y:

  Numeric vector to interpolate (may contain NAs)

## Value

List with two components:

- value:

  Numeric vector with interpolated values; NA positions beyond the range
  of observed data are kept constant using the nearest observed endpoint

- flag:

  Integer vector (0/1) indicating which values were originally NA

## Examples

``` r
result <- interp_pchip_flag(c(NA, 10, NA, NA, 20, NA))
result$value
#> [1] 10.00000 10.00000 13.33333 16.66667 20.00000 20.00000
result$flag
#> [1] 1 0 1 1 0 1
```
