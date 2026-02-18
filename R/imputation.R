#' @title Econometric Imputation Functions
#' @description Advanced interpolation and forecasting for time series data
#' @name imputation
NULL

#' PCHIP Interpolation with Constant Endpoints
#'
#' Performs Piecewise Cubic Hermite Interpolating Polynomial (PCHIP)
#' interpolation for missing values within the observed range.
#' Uses monotone Hermite splines (Fritsch-Carlson method) via [stats::splinefun()]
#' which are robust to non-linear patterns and avoid overshooting between knots.
#' Endpoints beyond observed data are held constant (last observation carried forward/backward).
#'
#' This function replaces the previous linear interpolation approach with a more
#' sophisticated method that preserves monotonicity and handles non-linear relationships better.
#'
#' @param y Numeric vector to interpolate (may contain NAs)
#'
#' @return List with two components:
#'   \item{value}{Numeric vector with interpolated values; NA positions beyond the
#'     range of observed data are kept constant using the nearest observed endpoint}
#'   \item{flag}{Integer vector (0/1) indicating which values were originally NA}
#'
#' @export
#' @examples
#' result <- interp_pchip_flag(c(NA, 10, NA, NA, 20, NA))
#' result$value
#' result$flag
interp_pchip_flag <- function(y) {
  n <- length(y)
  idx <- which(!is.na(y))
  was_na <- is.na(y)

  # All missing: return as-is
  if (!length(idx)) {
    return(list(value = y, flag = as.integer(was_na)))
  }

  # Only one observed value: replicate it
  if (length(idx) == 1) {
    return(list(value = rep(y[idx], n), flag = as.integer(was_na)))
  }

  # Create PCHIP interpolation function using monotone Hermite splines
  # method = "monoH.FC" is Fritsch-Carlson monotone spline
  f_interp <- stats::splinefun(x = idx, y = y[idx], method = "monoH.FC")

  # Interpolate across entire range
  v <- f_interp(seq_len(n))

  # Handle endpoints: positions outside observed range should use constant endpoint values
  # Positions before first observed index: use first observed value
  v[seq_len(idx[1] - 1)] <- y[idx[1]]

  # Positions after last observed index: use last observed value
  if (idx[length(idx)] < n) {
    v[(idx[length(idx)] + 1):n] <- y[idx[length(idx)]]
  }

  list(value = v, flag = as.integer(was_na))
}

#' Autoregressive Forecast for Future Observations
#'
#' Applies exponential smoothing state space model (ETS) for forecasting beyond
#' the last observed value. The method is autoregressive and automatically selects
#' optimal smoothing parameters via [forecast::ets()]. Falls back to Holt's linear
#' trend extrapolation if the forecast package is unavailable.
#'
#' Any NA values in the input series are first interpolated using [interp_pchip_flag()].
#'
#' @param y Numeric vector of observed values (may contain NAs which are interpolated first)
#' @param h Integer number of periods to forecast (default: 3)
#' @param method Character string: "ets" (default) for exponential smoothing via
#'   forecast package, or "holt_linear" for manual Holt's linear trend fallback
#'
#' @return List with three components:
#'   \item{forecast}{Numeric vector of length h with point forecasts}
#'   \item{lower}{Numeric vector of length h with lower 80% confidence interval bounds}
#'   \item{upper}{Numeric vector of length h with upper 80% confidence interval bounds}
#'   \item{method}{Character string indicating which method was used}
#'
#' @details
#' When method = "ets", the function attempts to use [forecast::ets()] to fit an
#' exponential smoothing model with automatically selected components (error, trend, seasonal).
#' If the forecast package is not available, it falls back to Holt's linear trend method.
#'
#' Holt's linear trend method fits y_t = l_t + t_t where l_t is the level and t_t
#' is the trend, using standard smoothing parameters (alpha = 0.3, beta = 0.1).
#'
#' @export
#' @importFrom stats lm coef
#' @examples
#' \dontrun{
#' y <- c(10, 12, 14, 16, 18, 20)
#' result <- forecast_autoregressive(y, h = 3)
#' result$forecast
#' }
forecast_autoregressive <- function(y, h = 3, method = "ets") {
  # Interpolate any missing values first
  y_clean <- interp_pchip_flag(y)$value

  # Remove remaining NAs if any (edge case)
  if (any(is.na(y_clean))) {
    y_clean <- y_clean[!is.na(y_clean)]
  }

  if (length(y_clean) < 2) {
    # Not enough data: return constant forecast
    last_val <- if (length(y_clean) > 0) y_clean[length(y_clean)] else NA_real_
    return(list(
      forecast = rep(last_val, h),
      lower = rep(last_val, h),
      upper = rep(last_val, h),
      method = "constant"
    ))
  }

  # Try ETS method first if requested
  if (method == "ets" && requireNamespace("forecast", quietly = TRUE)) {
    tryCatch(
      {
        fit <- forecast::ets(y_clean, ic = "aicc", allow.multiplicative.trend = TRUE)
        fcast <- forecast::forecast(fit, h = h, level = 80)

        return(list(
          forecast = as.numeric(fcast$mean),
          lower = as.numeric(fcast$lower[, 1]),
          upper = as.numeric(fcast$upper[, 1]),
          method = "ets"
        ))
      },
      error = function(e) {
        # Fall back to Holt's linear trend if ETS fails
        holt_linear_fallback(y_clean, h)
      }
    )
  } else {
    # Use Holt's linear trend
    holt_linear_fallback(y_clean, h)
  }
}

#' Holt's Linear Trend Fallback (Internal)
#'
#' Helper function implementing Holt's linear trend extrapolation.
#' Used as fallback when forecast package is unavailable or ETS fails.
#'
#' @param y Numeric vector of clean (non-NA) observations
#' @param h Integer number of periods to forecast
#'
#' @return List with forecast, lower, upper, and method components
#'
#' @keywords internal
holt_linear_fallback <- function(y, h) {
  n <- length(y)

  # Initialize level and trend
  # Level: average of first few points
  l0 <- mean(y[1:min(3, n)])
  # Trend: simple difference from start to end divided by period
  t0 <- (y[n] - y[1]) / (n - 1)

  # Smoothing parameters
  alpha <- 0.3
  beta <- 0.1

  # Iterate through observations
  l <- l0
  t <- t0

  for (i in seq_len(n)) {
    l_new <- alpha * y[i] + (1 - alpha) * (l + t)
    t <- beta * (l_new - l) + (1 - beta) * t
    l <- l_new
  }

  # Generate forecasts
  fcasts <- l + t * seq_len(h)

  # Estimate standard error from residuals
  fitted <- numeric(n)
  l_temp <- l0
  t_temp <- t0

  for (i in seq_len(n)) {
    fitted[i] <- l_temp + t_temp
    l_new <- alpha * y[i] + (1 - alpha) * (l_temp + t_temp)
    t_temp <- beta * (l_new - l_temp) + (1 - beta) * t_temp
    l_temp <- l_new
  }

  residuals <- y - fitted
  se <- stats::sd(residuals, na.rm = TRUE)

  # 80% CI: ±1.282 standard errors
  z80 <- 1.282

  list(
    forecast = fcasts,
    lower = fcasts - z80 * se * sqrt(seq_len(h)),
    upper = fcasts + z80 * se * sqrt(seq_len(h)),
    method = "holt_linear"
  )
}

#' Full Imputation Pipeline
#'
#' Combines PCHIP interpolation (for gaps within observed range) with
#' autoregressive forecasting (for future periods beyond observed data).
#' This is the recommended entry point for complete time series imputation.
#'
#' @param y Numeric vector with potential NAs
#' @param years Integer vector of corresponding years (length must equal length of y)
#' @param forecast_to Integer: the last year to forecast to. If NULL (default),
#'   no forecasting is performed. If provided and greater than max(years),
#'   the series is extended with autoregressive forecasts.
#'
#' @return List with four components:
#'   \item{value}{Numeric vector containing the complete imputed and/or
#'     forecasted series (extended if forecast_to > max(years))}
#'   \item{years}{Integer vector of years corresponding to the returned values}
#'   \item{flag}{Integer vector (0/1/2) where 0 = observed, 1 = interpolated gap,
#'     2 = forecasted future value}
#'   \item{method}{Character string describing which methods were applied}
#'
#' @export
#' @importFrom rlang .data
#' @examples
#' \dontrun{
#' y <- c(10, NA, NA, 20, 22, 24)
#' years <- 2018:2023
#'
#' # Impute internal gaps only
#' result1 <- impute_series(y, years)
#'
#' # Impute and forecast to 2025
#' result2 <- impute_series(y, years, forecast_to = 2025)
#' }
impute_series <- function(y, years, forecast_to = NULL) {
  if (length(y) != length(years)) {
    stop("Length of y and years must be equal", call. = FALSE)
  }

  # Step 1: PCHIP interpolation for internal gaps
  interp_result <- interp_pchip_flag(y)
  v_interp <- interp_result$value
  flag_interp <- interp_result$flag

  # Initialize output
  v_out <- v_interp
  years_out <- years
  flag_out <- flag_interp
  methods_used <- "pchip_interpolation"

  # Step 2: Forecast if needed
  if (!is.null(forecast_to)) {
    max_year <- max(years, na.rm = TRUE)

    if (forecast_to > max_year) {
      # Determine number of periods to forecast
      h <- forecast_to - max_year

      # Forecast using autoregressive method
      fcast_result <- forecast_autoregressive(v_interp, h = h, method = "ets")

      # Append forecasts
      v_out <- c(v_interp, fcast_result$forecast)
      years_out <- c(years, max_year + seq_len(h))
      flag_out <- c(flag_interp, rep(2L, h))  # 2 = forecasted

      methods_used <- paste0(
        "pchip_interpolation + ",
        fcast_result$method,
        "_forecasting"
      )
    }
  }

  list(
    value = v_out,
    years = years_out,
    flag = flag_out,
    method = methods_used
  )
}
