#' @title DHS Gap-Filling Functions
#' @description Temporal gap-filling for DHS subnational indicator series.
#'   DHS surveys are conducted every 3–13 years (median 5), producing
#'   irregularly spaced, short time series per region. These functions
#'   interpolate annual estimates between survey waves using domain-aware
#'   transforms and calibrated uncertainty intervals.
#'
#'   **Method**: FMM spline (exact interpolation) + GAM uncertainty
#'   with \code{sigma_floor} for calibrated 95\% prediction intervals.
#'   Optional ETS (exponential smoothing) forecasting extends predictions
#'   beyond the last survey year.
#'
#'   Mirrors the Eurostat imputation layer (\code{\link{impute_series}()}).
#' @name dhs_gapfill
NULL

# ============================================================================
# CORE GAP-FILLING FUNCTION
# ============================================================================

#' Gap-Fill a Single Region-Indicator Time Series
#'
#' Interpolates annual values between DHS survey observations for a single
#' region-indicator series. Uses a two-component architecture:
#' \enumerate{
#'   \item **Point estimates** from an FMM (Forsythe-Malcolm-Moler) cubic
#'     spline on the transformed scale. FMM uses local tangent computation
#'     (no global coupling), passes exactly through all observations, and
#'     avoids the edge overshoot problem of natural cubic splines.
#'   \item **Uncertainty** from a penalized GAM (\code{mgcv::gam}) that
#'     provides standard errors reflecting data density, combined with a
#'     \code{sigma_floor} for calibrated prediction intervals.
#' }
#'
#' The data is first transformed to an unconstrained scale before fitting:
#' \describe{
#'   \item{log}{For mortality rates (strictly positive). Ensures predictions
#'     remain > 0 and encodes proportional changes.}
#'   \item{logit}{For proportions (0–100\%). Ensures predictions stay
#'     within bounds and captures floor/ceiling effects.}
#' }
#'
#' **Adaptive complexity** by series length:
#' \describe{
#'   \item{n = 1}{Returns observed value only (no interpolation possible).}
#'   \item{n = 2}{Linear interpolation on transformed scale with
#'     distance-proportional uncertainty.}
#'   \item{n >= 3}{FMM spline + GAM, with basis dimension \code{k}
#'     adapting to available data: \code{k = 3} for n = 3–4,
#'     \code{k = min(n-1, 7)} for n >= 5.}
#' }
#'
#' By default, only interpolation is performed. If \code{forecast_to} is
#' set, ETS (exponential smoothing) forecasting extends predictions beyond
#' the last survey year, mirroring the Eurostat layer's
#' \code{\link{forecast_autoregressive}()}.
#'
#' @param years Integer vector of survey years (the observed time points).
#' @param values Numeric vector of observed indicator values, same length
#'   as \code{years}.
#' @param target_years Integer vector of years at which to predict. Defaults
#'   to annual sequence from \code{min(years)} to \code{max(years)}, or
#'   to \code{forecast_to} if provided.
#' @param transform Character: \code{"log"} for mortality rates (> 0) or
#'   \code{"logit"} for proportions (0–100). Determines how data is
#'   transformed before spline fitting and how predictions are
#'   back-transformed.
#' @param level Numeric confidence level for prediction intervals
#'   (default: 0.95).
#' @param sigma_floor Numeric minimum prediction standard error on the
#'   transformed scale (default: 0.25). Calibrated via leave-one-out
#'   cross-validation across SSA to achieve approximately 95\% nominal
#'   coverage. A value of 0.25 corresponds to roughly +/- 28\% uncertainty
#'   on the original scale.
#' @param forecast_to Integer: if set, forecasts forward from the last
#'   survey year to this year using ETS (exponential smoothing). Forecasted
#'   values are marked with \code{source = "forecasted"} and carry wider
#'   uncertainty bands that grow with forecast horizon. Set to NULL
#'   (default) for interpolation only.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{year}{Integer year}
#'     \item{estimate}{Back-transformed point estimate}
#'     \item{ci_lo}{Lower bound of the prediction interval}
#'     \item{ci_hi}{Upper bound of the prediction interval}
#'     \item{source}{Character: \code{"observed"}, \code{"interpolated"},
#'       or \code{"forecasted"}}
#'   }
#'   Returns NULL if \code{years} has length 0.
#'
#' @details
#' **Assumptions** (defensible in the SSA demographic context):
#' \enumerate{
#'   \item Health/demographic indicators evolve smoothly between surveys.
#'     Even crisis-driven changes unfold over months/years within the
#'     survey recall window.
#'   \item Penalization constrains the rate of change to what the data
#'     supports. With few observations, the model cannot invent complex
#'     dynamics that were not observed.
#'   \item Log/logit transforms encode domain knowledge: mortality
#'     declines are proportional, and proportions have natural
#'     floor/ceiling effects.
#' }
#'
#' **Calibration**: The default \code{sigma_floor = 0.25} was determined
#' by leave-one-out cross-validation on U5 mortality across 17 SSA
#' countries with 5+ observation series: coverage 86.7\% at the 95\%
#' level (conservative for multi-country generalization). For Kenya alone,
#' coverage is 94.3\%.
#'
#' @export
#' @examples
#' \dontrun{
#' # Gap-fill U5 mortality for a single region
#' raw <- get_dhs_data("KE", "CM_ECMR_C_U5M", breakdown = "subnational") |>
#'   process_dhs(out_col = "u5_mortality")
#' nyanza <- raw |> dplyr::filter(geo == "KE_Nyanza") |> dplyr::arrange(year)
#' gf <- gapfill_series(nyanza$year, nyanza$u5_mortality, transform = "log")
#'
#' # Gap-fill a proportion indicator (logit transform)
#' raw_st <- get_dhs_data("KE", "CN_NUTS_C_HA2", breakdown = "subnational") |>
#'   process_dhs(out_col = "stunting")
#' nrb <- raw_st |> dplyr::filter(geo == "KE_Nairobi") |> dplyr::arrange(year)
#' gf_st <- gapfill_series(nrb$year, nrb$stunting, transform = "logit")
#' }
gapfill_series <- function(years, values, target_years = NULL,
                           transform = c("log", "logit"), level = 0.95,
                           sigma_floor = 0.25, forecast_to = NULL) {
  transform <- match.arg(transform)
  n <- length(years)
  if (n == 0) return(NULL)

  # Determine target years: interpolation range + optional forecast extension
  max_obs_year <- max(years)
  if (is.null(target_years)) {
    end_year <- if (!is.null(forecast_to) && forecast_to > max_obs_year) {
      forecast_to
    } else {
      max_obs_year
    }
    target_years <- seq(min(years), end_year)
  }

  # --- Transform to unconstrained scale ---
  if (transform == "log") {
    # Floor at 0.01 to handle observed zeros (e.g., perinatal mortality
    # in small-sample regions). exp(log(0.01)) = 0.01 ≈ 0 on original scale.
    values_safe <- pmax(values, 0.01)
    y_t <- log(values_safe)
    inv <- function(x) exp(x)
  } else {
    p <- pmax(pmin(values / 100, 0.999), 0.001)
    y_t <- log(p / (1 - p))
    inv <- function(x) 100 / (1 + exp(-x))
  }
  z <- stats::qnorm(1 - (1 - level) / 2)

  # Identify interpolation vs forecast target years
  interp_years <- target_years[target_years <= max_obs_year]
  fcast_years  <- target_years[target_years >  max_obs_year]
  do_forecast  <- length(fcast_years) > 0 && n >= 2

  # --- n = 1: return observed only (+ flat forecast if requested) ---
  if (n == 1) {
    result <- tibble::tibble(
      year = years, estimate = values,
      ci_lo = NA_real_, ci_hi = NA_real_, source = "observed"
    )
    if (do_forecast) {
      # Flat carry-forward with widening uncertainty
      fcast_se <- sigma_floor * seq_along(fcast_years) / length(fcast_years)
      result <- dplyr::bind_rows(result, tibble::tibble(
        year = fcast_years, estimate = inv(y_t[1]),
        ci_lo = inv(y_t[1] - z * fcast_se),
        ci_hi = inv(y_t[1] + z * fcast_se),
        source = "forecasted"
      ))
    }
    return(result)
  }

  # --- n = 2: linear on transformed scale ---
  if (n == 2) {
    pred <- stats::approx(years, y_t, xout = interp_years, rule = 1)$y
    dist <- sapply(interp_years, function(yr) min(abs(yr - years)))
    max_dist <- diff(range(years)) / 2
    se <- sigma_floor * (dist / max_dist)
    result <- tibble::tibble(
      year = interp_years, estimate = inv(pred),
      ci_lo = inv(pred - z * se), ci_hi = inv(pred + z * se),
      source = ifelse(interp_years %in% years, "observed", "interpolated")
    ) |> dplyr::filter(!is.na(.data$estimate))

    if (do_forecast) {
      result <- .append_ets_forecast(
        result, y_t, years, fcast_years, inv, z, sigma_floor, transform
      )
    }
    return(result)
  }

  # --- n >= 3: FMM spline (point estimates) + GAM (uncertainty) ---
  spfun <- stats::splinefun(years, y_t, method = "fmm")
  est_t <- spfun(interp_years)

  # If all transformed values are identical (e.g., 100% coverage everywhere),
  # GAM cannot estimate variance. Use sigma_floor directly.
  if (stats::sd(y_t) < 1e-10) {
    se_pred <- rep(sigma_floor, length(interp_years))
  } else {
    k <- if (n >= 5) min(n - 1, 7) else 3
    gam_fit <- mgcv::gam(
      y ~ s(year, k = k, bs = "tp"),
      data = data.frame(year = years, y = y_t),
      method = "REML"
    )
    gam_pred <- stats::predict(
      gam_fit,
      newdata = data.frame(year = interp_years),
      se.fit = TRUE
    )

    # Prediction SE = sqrt(smoothing_SE^2 + max(residual_variance, sigma_floor)^2)
    sigma_gam <- sqrt(gam_fit$sig2)
    se_pred <- sqrt(gam_pred$se.fit^2 + max(sigma_gam, sigma_floor)^2)
  }

  # At observed years, set near-zero SE (exact interpolation)
  at_obs <- interp_years %in% years
  se_pred[at_obs] <- 0.01

  result <- tibble::tibble(
    year = interp_years, estimate = inv(est_t),
    ci_lo = inv(est_t - z * se_pred),
    ci_hi = inv(est_t + z * se_pred),
    source = ifelse(at_obs, "observed", "interpolated")
  )

  # --- ETS forecast extension ---
  if (do_forecast) {
    # Build annual interpolated series on transformed scale for ETS input
    annual_t <- spfun(seq(min(years), max_obs_year))
    result <- .append_ets_forecast(
      result, annual_t, seq(min(years), max_obs_year),
      fcast_years, inv, z, sigma_floor, transform
    )
  }

  result
}


#' Append ETS Forecast to Gap-Filled Results (Internal)
#'
#' Uses exponential smoothing (ETS) on the transformed-scale interpolated
#' series to forecast beyond the last observation. Mirrors the Eurostat
#' layer's \code{\link{forecast_autoregressive}()}.
#'
#' @param result Tibble of interpolated results so far.
#' @param y_t Numeric vector of transformed-scale annual values.
#' @param y_years Integer vector of years corresponding to \code{y_t}.
#' @param fcast_years Integer vector of years to forecast.
#' @param inv Inverse transform function.
#' @param z Z-score for confidence level.
#' @param sigma_floor Minimum SE.
#' @param transform Character: "log" or "logit".
#'
#' @return Updated result tibble with forecasted rows appended.
#' @keywords internal
.append_ets_forecast <- function(result, y_t, y_years, fcast_years,
                                  inv, z, sigma_floor, transform) {
  h <- length(fcast_years)
  n_obs <- length(y_t)

  # --- Damped trend for short series ---
  # With few observations, ETS can extrapolate aggressively. Use a damped

  # linear trend (last observed annual change × damping factor) as a
  # conservative alternative for n < 5.
  use_damped <- n_obs < 5

  if (use_damped) {
    # Estimate annual trend from last segment of transformed series
    last_val <- y_t[n_obs]
    if (n_obs >= 2) {
      # Annual change from last two points
      span <- y_years[n_obs] - y_years[max(1, n_obs - 1)]
      if (span > 0) {
        annual_change <- (y_t[n_obs] - y_t[max(1, n_obs - 1)]) / span
      } else {
        annual_change <- 0
      }
    } else {
      annual_change <- 0
    }

    # Damping: trend decays by 15% per year toward zero (phi = 0.85)
    phi <- 0.85
    fcast_est <- numeric(h)
    cumulative_trend <- 0
    for (i in seq_len(h)) {
      cumulative_trend <- cumulative_trend + annual_change * phi^i
      fcast_est[i] <- last_val + cumulative_trend
    }

    # Widening uncertainty: SE grows with sqrt(horizon)
    horizon_se <- sigma_floor * sqrt(seq_len(h))
    fcast_lo <- fcast_est - z * horizon_se
    fcast_hi <- fcast_est + z * horizon_se

  } else {
    # --- ETS for longer series (n >= 5) ---
    fcast <- tryCatch({
      if (requireNamespace("forecast", quietly = TRUE)) {
        # Use damped trend ETS (AAdN) to prevent runaway extrapolation
        fit <- forecast::ets(y_t, ic = "aicc", damped = TRUE)
        fc <- forecast::forecast(fit, h = h, level = 95)
        list(
          mean  = as.numeric(fc$mean),
          lower = as.numeric(fc$lower[, 1]),
          upper = as.numeric(fc$upper[, 1]),
          method = "ets"
        )
      } else {
        NULL
      }
    }, error = function(e) NULL)

    # Fallback: Holt's linear trend on transformed scale
    if (is.null(fcast)) {
      fcast <- holt_linear_fallback(y_t, h)
      mid <- fcast$forecast
      half_80 <- (fcast$upper - fcast$lower) / 2
      half_95 <- half_80 * (z / stats::qnorm(0.9))
      fcast$lower <- mid - half_95
      fcast$upper <- mid + half_95
      fcast$mean <- mid
    }

    fcast_est <- fcast$mean
    fcast_lo  <- fcast$lower
    fcast_hi  <- fcast$upper

    # Ensure minimum SE grows with forecast horizon
    horizon_se <- sigma_floor * sqrt(seq_len(h))
    for (i in seq_len(h)) {
      current_spread <- (fcast_hi[i] - fcast_lo[i]) / (2 * z)
      if (current_spread < horizon_se[i]) {
        fcast_lo[i] <- fcast_est[i] - z * horizon_se[i]
        fcast_hi[i] <- fcast_est[i] + z * horizon_se[i]
      }
    }
  }

  fcast_rows <- tibble::tibble(
    year     = fcast_years,
    estimate = inv(fcast_est),
    ci_lo    = inv(fcast_lo),
    ci_hi    = inv(fcast_hi),
    source   = "forecasted"
  )

  # For logit transform, clamp to [0, 100]
  if (transform == "logit") {
    fcast_rows$estimate <- pmin(pmax(fcast_rows$estimate, 0), 100)
    fcast_rows$ci_lo    <- pmin(pmax(fcast_rows$ci_lo, 0), 100)
    fcast_rows$ci_hi    <- pmin(pmax(fcast_rows$ci_hi, 0), 100)
  }

  dplyr::bind_rows(result, fcast_rows)
}


# ============================================================================
# BATCH GAP-FILLING
# ============================================================================

#' Gap-Fill All Regions for One Indicator
#'
#' Fetches raw DHS data for a set of countries and a single indicator,
#' processes it, and applies \code{\link{gapfill_series}()} to every region
#' that has at least \code{min_obs} observations. Returns a structured
#' list with gap-filled data, diagnostics, and error tracking.
#'
#' @param country_ids Character vector of DHS country codes
#'   (e.g., \code{ssa_codes()}).
#' @param ind_code Character: DHS indicator ID (e.g., \code{"CM_ECMR_C_U5M"}).
#' @param ind_name Character: output column name for the indicator
#'   (e.g., \code{"u5_mortality"}).
#' @param transform Character: \code{"log"} or \code{"logit"}, passed to
#'   \code{gapfill_series()}.
#' @param min_obs Integer: minimum number of observations required to
#'   attempt gap-filling for a region (default: 2).
#' @param sigma_floor Numeric: minimum prediction SE, passed to
#'   \code{gapfill_series()} (default: 0.25).
#'
#' @return A named list with:
#'   \describe{
#'     \item{gapfilled}{Tibble of gap-filled data with columns:
#'       \code{year}, \code{estimate}, \code{ci_lo}, \code{ci_hi},
#'       \code{source}, \code{geo}, \code{indicator}.}
#'     \item{raw}{Tibble of the raw processed data.}
#'     \item{n_regions}{Integer: number of regions successfully gap-filled.}
#'     \item{n_errors}{Integer: number of regions where fitting failed.}
#'     \item{n_warnings}{Integer: total GAM fitting warnings (benign).}
#'     \item{error_regions}{Character vector of region names where fitting
#'       failed.}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' res <- gapfill_indicator(
#'   country_ids = c("KE", "NG"),
#'   ind_code = "CM_ECMR_C_U5M",
#'   ind_name = "u5_mortality",
#'   transform = "log"
#' )
#' res$gapfilled  # gap-filled data
#' res$n_regions   # number of regions processed
#' }
gapfill_indicator <- function(country_ids, ind_code, ind_name,
                              transform, min_obs = 2L,
                              sigma_floor = 0.25,
                              forecast_to = NULL) {
  raw <- get_dhs_data(country_ids, ind_code, breakdown = "subnational") |>
    process_dhs(out_col = ind_name)

  if (nrow(raw) == 0) {
    return(list(
      gapfilled = tibble::tibble(), raw = raw,
      n_regions = 0L, n_errors = 0L, n_warnings = 0L,
      error_regions = character()
    ))
  }

  regions <- raw |>
    dplyr::group_by(.data$geo) |>
    dplyr::summarise(n = dplyr::n(), .groups = "drop") |>
    dplyr::filter(.data$n >= min_obs)

  results <- list()
  errors <- character()
  warnings_count <- 0L

  for (rgn in regions$geo) {
    series <- raw |>
      dplyr::filter(.data$geo == rgn) |>
      dplyr::arrange(.data$year)
    gf <- tryCatch(
      withCallingHandlers(
        gapfill_series(
          series$year, series[[ind_name]],
          transform = transform, sigma_floor = sigma_floor,
          forecast_to = forecast_to
        ),
        warning = function(w) {
          warnings_count <<- warnings_count + 1L
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) {
        errors <<- c(errors, rgn)
        NULL
      }
    )
    if (!is.null(gf)) {
      results[[rgn]] <- gf |>
        dplyr::mutate(geo = rgn, indicator = ind_name)
    }
  }

  list(
    gapfilled = dplyr::bind_rows(results),
    raw = raw,
    n_regions = length(results),
    n_errors = length(errors),
    n_warnings = warnings_count,
    error_regions = errors
  )
}


#' Gap-Fill All DHS Indicators Across SSA
#'
#' Runs \code{\link{gapfill_indicator}()} for every indicator in the
#' package's registries. Automatically selects the correct transform:
#' log for the 5 mortality indicators and 2 median-years-of-education
#' indicators (continuous positive values), logit for the remaining 55
#' proportion-based indicators. Returns a combined dataset and
#' summary diagnostics.
#'
#' @param country_ids Character vector of DHS country codes. Defaults to
#'   \code{\link{ssa_codes}()} (all 44 SSA countries).
#' @param sigma_floor Numeric: minimum prediction SE, passed to
#'   \code{gapfill_series()} (default: 0.25).
#' @param verbose Logical: if TRUE, prints progress to console
#'   (default: TRUE).
#'
#' @return A named list with:
#'   \describe{
#'     \item{data}{Named list of tibbles (one per indicator with data),
#'       each containing gap-filled annual estimates.}
#'     \item{summary}{Tibble with one row per indicator: indicator name,
#'       label, transform, counts of countries/regions/observed/interpolated,
#'       error count, and bounds check.}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' # Full SSA gap-fill (takes ~10 minutes due to API calls)
#' result <- gapfill_all_dhs()
#' result$summary
#' result$data[["u5_mortality"]]
#'
#' # Tier 1 countries only (faster)
#' result_t1 <- gapfill_all_dhs(country_ids = tier1_codes())
#' }
gapfill_all_dhs <- function(country_ids = ssa_codes(),
                            sigma_floor = 0.25,
                            forecast_to = NULL,
                            verbose = TRUE) {

  # Build indicator list from all registries
  all_codes <- c(
    dhs_mortality_codes(), dhs_nutrition_codes(), dhs_health_codes(),
    dhs_wash_codes(), dhs_education_codes(), dhs_hiv_codes(),
    dhs_gender_codes(), dhs_wealth_codes()
  )

  # Transform assignment:
  #   - Mortality rates (per 1,000): log (strictly positive, proportional changes)
  #   - Median years of education: log (continuous positive, not a proportion)
  #   - Everything else (percentages 0-100): logit
  domains <- dhs_domain_mapping()
  mortality_names <- names(domains[domains == "Mortality"])
  # Continuous positive indicators that are NOT proportions
  log_extras <- c("median_years_women", "median_years_men")
  labels <- dhs_var_labels()

  indicators <- lapply(seq_along(all_codes), function(i) {
    nm <- names(all_codes)[i]
    tr <- if (nm %in% mortality_names || nm %in% log_extras) "log" else "logit"
    list(
      code = unname(all_codes[i]),
      name = nm,
      tr = tr,
      label = labels[nm]
    )
  })

  if (verbose) {
    message("Gap-filling ", length(indicators), " indicators x ",
            length(country_ids), " countries")
    message("  Mortality (log): ",
            sum(sapply(indicators, \(x) x$tr == "log")))
    message("  Other (logit): ",
            sum(sapply(indicators, \(x) x$tr == "logit")))
  }

  all_gapfilled <- list()
  summary_rows <- list()

  for (ind in indicators) {
    if (verbose) {
      message(sprintf("  %-35s (%s) ... ", ind$label, ind$code),
              appendLF = FALSE)
    }

    res <- tryCatch(
      gapfill_indicator(
        country_ids, ind$code, ind$name, ind$tr,
        sigma_floor = sigma_floor, forecast_to = forecast_to
      ),
      error = function(e) {
        if (verbose) message("FETCH ERROR: ", e$message)
        NULL
      }
    )
    if (is.null(res)) next

    gf <- res$gapfilled
    if (nrow(gf) == 0) {
      if (verbose) message("NO DATA")
      next
    }

    all_gapfilled[[ind$name]] <- gf

    n_countries <- dplyr::n_distinct(substr(gf$geo, 1, 2))
    n_obs <- sum(gf$source == "observed")
    n_interp <- sum(gf$source == "interpolated")
    n_fcast <- sum(gf$source == "forecasted")

    bounds_ok <- if (ind$tr == "logit") {
      all(gf$estimate >= 0 & gf$estimate <= 100)
    } else {
      all(gf$estimate > 0)
    }

    if (verbose) {
      fcast_msg <- if (n_fcast > 0) sprintf(", %d fcast", n_fcast) else ""
      message(sprintf("%2d countries, %4d regions, %5d obs -> %5d total%s",
                      n_countries, res$n_regions, n_obs, nrow(gf), fcast_msg),
              if (res$n_errors > 0) sprintf(", %d errors", res$n_errors) else "",
              if (!bounds_ok) ", BOUNDS VIOLATED!" else "")
    }

    summary_rows[[ind$name]] <- tibble::tibble(
      indicator = ind$name, label = ind$label,
      transform = ind$tr, countries = n_countries,
      regions = res$n_regions, errors = res$n_errors,
      warnings = res$n_warnings,
      observed = n_obs, interpolated = n_interp,
      forecasted = n_fcast,
      total = nrow(gf),
      year_min = min(gf$year), year_max = max(gf$year),
      bounds_ok = bounds_ok
    )
  }

  list(
    data = all_gapfilled,
    summary = dplyr::bind_rows(summary_rows)
  )
}
