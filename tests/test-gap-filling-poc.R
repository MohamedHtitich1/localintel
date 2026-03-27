# ==================================================================
# DHS Gap-Filling: Proof of Concept
# ==================================================================
#
# METHOD: Penalized spline on transformed scale
#
# WHY THIS METHOD:
#
# The DHS data has specific properties that rule out naive approaches:
#
#   1. IRREGULAR SPACING — surveys every 3-13 years (median 5)
#   2. SHORT SERIES — median 3 observations per region
#   3. NON-MONOTONIC — 45-85% of series have reversals
#   4. BOUNDED VALUES — proportions (0-100), rates (>0)
#   5. UNCERTAINTY MATTERS — gaps of 5-13 years mean real ignorance
#
# The approach:
#
#   a) TRANSFORM the data to respect natural bounds:
#      - Mortality rates (>0): log transform
#      - Proportions (0-100): logit transform (log(p/(100-p)))
#      Both ensure predictions can never violate domain constraints.
#
#   b) FIT a penalized regression spline (mgcv::gam) on the
#      transformed scale. The penalty controls smoothness —
#      with few observations, it pulls toward simpler curves
#      (preventing overfitting). The basis dimension k adapts
#      to series length:
#        n >= 5 → k = min(n-1, 7)  [flexible]
#        n = 3-4 → k = 3           [quadratic-like]
#        n = 2   → log/logit-linear [only defensible option]
#        n = 1   → no interpolation [return observed only]
#
#   c) PREDICT at annual frequency with standard errors, then
#      back-transform. Confidence intervals naturally widen
#      between observed points — encoding honest uncertainty.
#
# ASSUMPTIONS (defensible in SSA demographic context):
#
#   - Health/demographic indicators evolve smoothly between surveys.
#     There are no instantaneous jumps (no indicator goes from
#     30% to 80% overnight — even crisis-driven changes unfold
#     over months/years within the survey recall window).
#
#   - Penalization constrains the rate of change to what the data
#     supports. With only 3 points, the model cannot invent
#     complex dynamics that weren't observed.
#
#   - Log/logit transforms encode domain knowledge: mortality
#     declines are proportional (a region at 200/1000 doesn't
#     drop by the same absolute amount as one at 20/1000),
#     and proportions have natural floor/ceiling effects.
#
#   - We only INTERPOLATE (between first and last survey).
#     No extrapolation beyond the observed time window.
#
# ==================================================================

devtools::load_all()
library(dplyr)
library(tidyr)

# ------------------------------------------------------------------
# Core function: gap-fill a single region-indicator series
# ------------------------------------------------------------------
gapfill_series <- function(years, values, target_years = NULL,
                           transform = c("log", "logit"),
                           level = 0.95) {

  transform <- match.arg(transform)
  n <- length(years)
  if (n == 0) return(NULL)

  # Default: annual sequence between first and last observation
  if (is.null(target_years)) {
    target_years <- seq(min(years), max(years))
  }

  # --- Transform ---
  if (transform == "log") {
    # For mortality rates (strictly positive)
    y_t <- log(values)
    inv <- function(x) exp(x)
  } else {
    # For proportions (0-100), use logit
    # Clamp to avoid log(0) or log(Inf)
    p <- pmax(pmin(values / 100, 0.999), 0.001)
    y_t <- log(p / (1 - p))
    inv <- function(x) 100 / (1 + exp(-x))
  }

  z <- qnorm(1 - (1 - level) / 2)

  # --- n = 1: return observed only ---
  if (n == 1) {
    return(tibble(
      year = years,
      estimate = values,
      ci_lo = NA_real_,
      ci_hi = NA_real_,
      source = "observed"
    ))
  }

  # --- n = 2: linear on transformed scale ---
  if (n == 2) {
    pred <- approx(years, y_t, xout = target_years, rule = 1)$y
    # Approximate SE based on distance from observations
    max_gap <- diff(range(years)) / 2
    dist_to_nearest <- sapply(target_years, function(yr) {
      min(abs(yr - years))
    })
    # SE grows linearly with distance, scaled by residual
    se_approx <- abs(diff(y_t)) / diff(years) * dist_to_nearest * 0.5
    return(tibble(
      year = target_years,
      estimate = inv(pred),
      ci_lo = inv(pred - z * se_approx),
      ci_hi = inv(pred + z * se_approx),
      source = ifelse(target_years %in% years, "observed", "interpolated")
    ) |> filter(!is.na(estimate)))
  }

  # --- n >= 3: penalized spline via GAM ---
  k <- if (n >= 5) min(n - 1, 7) else 3
  df <- data.frame(year = years, y = y_t)
  fit <- mgcv::gam(y ~ s(year, k = k, bs = "tp"), data = df, method = "REML")

  pred <- predict(fit, newdata = data.frame(year = target_years), se.fit = TRUE)

  tibble(
    year = target_years,
    estimate = inv(pred$fit),
    ci_lo = inv(pred$fit - z * pred$se.fit),
    ci_hi = inv(pred$fit + z * pred$se.fit),
    source = ifelse(target_years %in% years, "observed", "interpolated")
  )
}


# ==================================================================
# TEST 1: Long series — Kenya Nyanza U5 mortality (7 obs, reversals)
# ==================================================================
cat("=== TEST 1: Kenya Nyanza U5 mortality (7 observations) ===\n")
raw <- get_dhs_data("KE", "CM_ECMR_C_U5M", breakdown = "subnational") |>
  process_dhs(out_col = "u5_mortality")

nyanza <- raw |> filter(geo == "KE_Nyanza") |> arrange(year)
cat("Observed:\n")
print(nyanza)

result1 <- gapfill_series(
  nyanza$year, nyanza$u5_mortality,
  transform = "log"
)
cat("\nGap-filled (annual, with 95% CI):\n")
print(result1, n = 40)

# Check: observed values should be reproduced exactly
cat("\nObserved vs fitted at survey years:\n")
check <- result1 |> filter(source == "observed") |>
  left_join(nyanza |> select(year, observed = u5_mortality), by = "year")
print(check)

# ==================================================================
# TEST 2: Short series — Nigeria Lagos U5M (3 observations)
# ==================================================================
cat("\n\n=== TEST 2: Nigeria Lagos U5 mortality (3 observations) ===\n")
raw_ng <- get_dhs_data("NG", "CM_ECMR_C_U5M", breakdown = "subnational") |>
  process_dhs(out_col = "u5_mortality")
lagos <- raw_ng |> filter(geo == "NG_Lagos") |> arrange(year)
cat("Observed:\n")
print(lagos)

result2 <- gapfill_series(lagos$year, lagos$u5_mortality, transform = "log")
cat("\nGap-filled:\n")
print(result2, n = 20)

# ==================================================================
# TEST 3: Proportion indicator — Kenya stunting (logit transform)
# ==================================================================
cat("\n\n=== TEST 3: Kenya Nairobi stunting — logit transform ===\n")
raw_st <- get_dhs_data("KE", "CN_NUTS_C_HA2", breakdown = "subnational") |>
  process_dhs(out_col = "stunting")
nairobi_st <- raw_st |> filter(geo == "KE_Nairobi") |> arrange(year)
cat("Observed:\n")
print(nairobi_st)

result3 <- gapfill_series(
  nairobi_st$year, nairobi_st$stunting,
  transform = "logit"
)
cat("\nGap-filled (logit transform, bounded 0-100):\n")
print(result3, n = 40)
cat("All values in [0,100]?", all(result3$estimate >= 0 & result3$estimate <= 100), "\n")

# ==================================================================
# TEST 4: Leave-one-out cross-validation on longer series
# ==================================================================
cat("\n\n=== TEST 4: Leave-one-out CV — Kenya provinces U5M ===\n")
ke_provinces <- raw |>
  group_by(geo) |>
  filter(n() >= 5) |>
  ungroup()

regions <- unique(ke_provinces$geo)
all_errors <- list()

for (rgn in regions) {
  series <- ke_provinces |> filter(geo == rgn) |> arrange(year)
  for (i in seq_len(nrow(series))) {
    train_y <- series$year[-i]
    train_v <- series$u5_mortality[-i]
    test_yr <- series$year[i]
    test_val <- series$u5_mortality[i]

    pred <- tryCatch({
      res <- gapfill_series(train_y, train_v,
                            target_years = test_yr,
                            transform = "log")
      res$estimate
    }, error = function(e) NA)

    all_errors[[length(all_errors) + 1]] <- data.frame(
      region = rgn, year = test_yr,
      observed = test_val, predicted = pred,
      error = abs(pred - test_val),
      pct_error = abs(pred - test_val) / test_val * 100
    )
  }
}
cv <- bind_rows(all_errors)
cat("Regions tested:", length(regions), "\n")
cat("Total predictions:", nrow(cv), "\n")
cat("MAE:", round(mean(cv$error, na.rm = TRUE), 1), "\n")
cat("MAPE:", round(mean(cv$pct_error, na.rm = TRUE), 1), "%\n")
cat("Median APE:", round(median(cv$pct_error, na.rm = TRUE), 1), "%\n")

# Worst predictions
cat("\nWorst 5 predictions:\n")
cv |> arrange(desc(pct_error)) |> head(5) |> print()

# ==================================================================
# TEST 5: 2-observation series (boundary)
# ==================================================================
cat("\n\n=== TEST 5: 2-observation series ===\n")
# Simulate: only 2 points
two_pts <- data.frame(year = c(2013, 2024), val = c(96, 46))
result5 <- gapfill_series(two_pts$year, two_pts$val, transform = "log")
cat("2-point series gap-fill:\n")
print(result5, n = 15)

cat("\n\n=== ALL TESTS COMPLETE ===\n")

