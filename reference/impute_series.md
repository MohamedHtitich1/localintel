# Full Imputation Pipeline

Combines PCHIP interpolation (for gaps within observed range) with
autoregressive forecasting (for future periods beyond observed data).
This is the recommended entry point for complete time series imputation.

## Usage

``` r
impute_series(y, years, forecast_to = NULL)
```

## Arguments

- y:

  Numeric vector with potential NAs

- years:

  Integer vector of corresponding years (length must equal length of y)

- forecast_to:

  Integer: the last year to forecast to. If `NULL` (default), no
  forecasting is performed. If provided and greater than `max(years)`,
  the series is extended with autoregressive forecasts.

## Value

List with four components:

- value:

  Numeric vector containing the complete imputed and/or forecasted
  series (extended if forecast_to \> max(years))

- years:

  Integer vector of years corresponding to the returned values

- flag:

  Integer vector (0/1/2) where 0 = observed, 1 = interpolated gap, 2 =
  forecasted future value

- method:

  Character string describing which methods were applied

## Examples

``` r
if (FALSE) { # \dontrun{
y <- c(10, NA, NA, 20, 22, 24)
years <- 2018:2023

# Impute internal gaps only
result1 <- impute_series(y, years)

# Impute and forecast to 2025
result2 <- impute_series(y, years, forecast_to = 2025)
} # }
```
