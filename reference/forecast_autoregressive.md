# Autoregressive Forecast for Future Observations

Applies exponential smoothing state space model (ETS) for forecasting
beyond the last observed value. The method is autoregressive and
automatically selects optimal smoothing parameters via
[`ets`](https://pkg.robjhyndman.com/forecast/reference/ets.html). Falls
back to Holt's linear trend extrapolation if the forecast package is
unavailable.

Any NA values in the input series are first interpolated using
[`interp_pchip_flag`](https://mohamedhtitich1.github.io/localintel/reference/interp_pchip_flag.md).

## Usage

``` r
forecast_autoregressive(y, h = 3, method = "ets")
```

## Arguments

- y:

  Numeric vector of observed values (may contain NAs which are
  interpolated first)

- h:

  Integer number of periods to forecast (default: 3)

- method:

  Character string: `"ets"` (default) for exponential smoothing via
  forecast package, or `"holt_linear"` for manual Holt's linear trend
  fallback

## Value

List with four components:

- forecast:

  Numeric vector of length h with point forecasts

- lower:

  Numeric vector of length h with lower 80% confidence interval bounds

- upper:

  Numeric vector of length h with upper 80% confidence interval bounds

- method:

  Character string indicating which method was used

## Details

When method = `"ets"`, the function attempts to use
[`ets`](https://pkg.robjhyndman.com/forecast/reference/ets.html) to fit
an exponential smoothing model with automatically selected components
(error, trend, seasonal). If the forecast package is not available, it
falls back to Holt's linear trend method.

Holt's linear trend method fits y_t = l_t + t_t where l_t is the level
and t_t is the trend, using standard smoothing parameters (alpha = 0.3,
beta = 0.1).

## Examples

``` r
if (FALSE) { # \dontrun{
y <- c(10, 12, 14, 16, 18, 20)
result <- forecast_autoregressive(y, h = 3)
result$forecast
} # }
```
