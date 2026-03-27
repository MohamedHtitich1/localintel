# Gap-Fill a Single Region-Indicator Time Series

Interpolates annual values between DHS survey observations for a single
region-indicator series. Uses FMM cubic spline for point estimates and
penalized GAM for calibrated uncertainty intervals.

## Usage

``` r
gapfill_series(years, values, target_years = NULL,
  transform = c("log", "logit"), level = 0.95,
  sigma_floor = 0.25, forecast_to = NULL)
```

## Arguments

- years:

  Integer vector of survey years (the observed time points).

- values:

  Numeric vector of observed indicator values.

- target_years:

  Integer vector of years at which to predict. Defaults to annual
  sequence from min to max observed year.

- transform:

  Character: `"log"` for rates or `"logit"` for proportions.

- level:

  Numeric confidence level for prediction intervals (default: 0.95).

- sigma_floor:

  Numeric minimum prediction SE (default: 0.25).

- forecast_to:

  Integer: if set, forecasts forward to this year using ETS.

## Value

A tibble with columns: year, estimate, ci_lo, ci_hi, source.

## Examples

``` r
if (FALSE) { # \dontrun{
gf <- gapfill_series(c(2005, 2010, 2015), c(90, 85, 80),
  transform = "log")
} # }
```
