devtools::load_all()
library(dplyr)
library(mgcv)

# ==================================================================
# V3: FMM spline (local, no edge overshoot) + GAM uncertainty
# ==================================================================
gapfill_v3 <- function(years, values, target_years = NULL,
                       transform = c("log", "logit"), level = 0.95) {
  transform <- match.arg(transform)
  n <- length(years)
  if (n == 0) return(NULL)
  if (is.null(target_years)) target_years <- seq(min(years), max(years))

  if (transform == "log") {
    y_t <- log(values); inv <- function(x) exp(x)
  } else {
    p <- pmax(pmin(values / 100, 0.999), 0.001)
    y_t <- log(p / (1 - p)); inv <- function(x) 100 / (1 + exp(-x))
  }
  z <- qnorm(1 - (1 - level) / 2)

  if (n == 1) return(tibble(year = years, estimate = values,
    ci_lo = NA_real_, ci_hi = NA_real_, source = "observed"))

  if (n == 2) {
    pred <- approx(years, y_t, xout = target_years, rule = 1)$y
    dist <- sapply(target_years, function(yr) min(abs(yr - years)))
    se <- abs(diff(y_t)) / diff(years) * dist * 0.5
    return(tibble(year = target_years, estimate = inv(pred),
      ci_lo = inv(pred - z * se), ci_hi = inv(pred + z * se),
      source = ifelse(target_years %in% years, "observed", "interpolated")
    ) |> filter(!is.na(estimate)))
  }

  # Point estimates: FMM spline (local, stable at edges)
  spfun <- splinefun(years, y_t, method = "fmm")
  est_t <- spfun(target_years)

  # Uncertainty: GAM standard errors
  k <- if (n >= 5) min(n - 1, 7) else 3
  gam_fit <- gam(y ~ s(year, k = k, bs = "tp"),
                 data = data.frame(year = years, y = y_t), method = "REML")
  gam_pred <- predict(gam_fit, newdata = data.frame(year = target_years),
                      se.fit = TRUE)

  tibble(year = target_years, estimate = inv(est_t),
    ci_lo = inv(est_t - z * gam_pred$se.fit),
    ci_hi = inv(est_t + z * gam_pred$se.fit),
    source = ifelse(target_years %in% years, "observed", "interpolated"))
}

# V1: pure GAM (for comparison)
gapfill_v1 <- function(years, values, target_years = NULL,
                       transform = "log", level = 0.95) {
  n <- length(years)
  if (is.null(target_years)) target_years <- seq(min(years), max(years))
  y_t <- log(values); inv <- function(x) exp(x)
  z <- qnorm(1 - (1 - level) / 2)
  if (n <= 2) return(gapfill_v3(years, values, target_years, transform, level))
  k <- if (n >= 5) min(n - 1, 7) else 3
  gam_fit <- gam(y ~ s(year, k = k, bs = "tp"),
                 data = data.frame(year = years, y = y_t), method = "REML")
  pred <- predict(gam_fit, newdata = data.frame(year = target_years), se.fit = TRUE)
  tibble(year = target_years, estimate = inv(pred$fit),
    ci_lo = inv(pred$fit - z * pred$se.fit),
    ci_hi = inv(pred$fit + z * pred$se.fit),
    source = ifelse(target_years %in% years, "observed", "interpolated"))
}

raw <- get_dhs_data("KE", "CM_ECMR_C_U5M", breakdown = "subnational") |>
  process_dhs(out_col = "u5_mortality")

# === Exact fit check ===
cat("=== V3: FMM spline — exact fit check (Nyanza) ===\n")
nyanza <- raw |> filter(geo == "KE_Nyanza") |> arrange(year)
r3 <- gapfill_v3(nyanza$year, nyanza$u5_mortality, transform = "log")
r3 |> filter(source == "observed") |>
  left_join(nyanza |> select(year, observed = u5_mortality), by = "year") |>
  mutate(diff = round(estimate - observed, 4)) |> print()

# === Full trajectory ===
cat("\n=== V3: Full annual trajectory ===\n")
print(r3, n = 40)

# === Nairobi stunting reversal ===
cat("\n=== V3: Nairobi stunting reversal ===\n")
raw_st <- get_dhs_data("KE", "CN_NUTS_C_HA2", breakdown = "subnational") |>
  process_dhs(out_col = "stunting")
nrb <- raw_st |> filter(geo == "KE_Nairobi") |> arrange(year)
r3s <- gapfill_v3(nrb$year, nrb$stunting, transform = "logit")
cat("Observed: 23.5 (2003) -> 28.5 (2008) -> 17.2 (2014)\n")
r3s |> filter(year >= 2001 & year <= 2016) |> print()

# === LOO CV: V1 vs V3 ===
cat("\n=== LOO CV: V1 (pure GAM) vs V3 (FMM + GAM SE) ===\n")
ke_provinces <- raw |> group_by(geo) |> filter(n() >= 5) |> ungroup()
regions <- unique(ke_provinces$geo)

all_cv <- list()
for (rgn in regions) {
  series <- ke_provinces |> filter(geo == rgn) |> arrange(year)
  for (i in seq_len(nrow(series))) {
    train_y <- series$year[-i]; train_v <- series$u5_mortality[-i]
    test_yr <- series$year[i]; test_val <- series$u5_mortality[i]
    is_edge <- i == 1 || i == nrow(series)

    for (ver in c("V1", "V3")) {
      fn <- if (ver == "V1") gapfill_v1 else gapfill_v3
      pred <- tryCatch(fn(train_y, train_v, target_years = test_yr)$estimate,
                       error = function(e) NA)
      all_cv[[length(all_cv) + 1]] <- data.frame(
        version = ver, region = rgn, year = test_yr,
        observed = test_val, predicted = pred,
        pct_error = abs(pred - test_val) / test_val * 100,
        position = ifelse(is_edge, "edge", "interior")
      )
    }
  }
}
cv <- bind_rows(all_cv)

cat("\n--- OVERALL ---\n")
cv |> group_by(version) |>
  summarise(MAE = round(mean(abs(predicted - observed), na.rm = TRUE), 1),
            MAPE = round(mean(pct_error, na.rm = TRUE), 1),
            MedAPE = round(median(pct_error, na.rm = TRUE), 1),
            .groups = "drop") |> print()

cat("\n--- INTERIOR ONLY (interpolation — what we actually do) ---\n")
cv |> filter(position == "interior") |>
  group_by(version) |>
  summarise(MAE = round(mean(abs(predicted - observed), na.rm = TRUE), 1),
            MAPE = round(mean(pct_error, na.rm = TRUE), 1),
            MedAPE = round(median(pct_error, na.rm = TRUE), 1),
            n = n(), .groups = "drop") |> print()

cat("\n--- EDGE ONLY (extrapolation — we don't do this) ---\n")
cv |> filter(position == "edge") |>
  group_by(version) |>
  summarise(MAE = round(mean(abs(predicted - observed), na.rm = TRUE), 1),
            MAPE = round(mean(pct_error, na.rm = TRUE), 1),
            MedAPE = round(median(pct_error, na.rm = TRUE), 1),
            n = n(), .groups = "drop") |> print()

cat("\n--- V3 Worst 5 INTERIOR predictions ---\n")
cv |> filter(version == "V3", position == "interior") |>
  arrange(desc(pct_error)) |> head(5) |> print()

cat("\n=== COMPARISON COMPLETE ===\n")
