# ============================================================================
# Re-gapfill balanced panel with ETS forecasting (forecast_to = 2024)
# Run in RStudio after devtools::load_all()
# ============================================================================

library(dplyr)
library(sf)
devtools::load_all()

# --- Configuration ---
forecast_to <- 2024L
panel_file  <- "tests/gapfill-results/dhs_panel_admin1_balanced.rds"

# --- Load existing panel ---
bal <- readRDS(panel_file)
cat("Loaded panel:", nrow(bal), "rows x", ncol(bal), "cols\n")
cat("Regions:", n_distinct(bal$geo), "| Countries:", n_distinct(bal$admin0), "\n")
cat("Year range:", min(bal$year), "-", max(bal$year), "\n\n")

# --- Identify indicators and transforms ---
flag_cols <- grep("^imp_(.+)_flag$", names(bal), value = TRUE)
all_vars  <- sub("^imp_(.+)_flag$", "\\1", flag_cols)
domains   <- dhs_domain_mapping()
mortality_names <- names(domains[domains == "Mortality"])
log_extras <- c("median_years_women", "median_years_men")

cat("Processing", length(all_vars), "indicators with forecast_to =", forecast_to, "\n")
cat("This takes ~10-15 minutes for all 60 indicators x 652 regions...\n\n")

total_fcast <- 0L
t0 <- Sys.time()

for (idx in seq_along(all_vars)) {
  v <- all_vars[idx]
  flag_col <- paste0("imp_", v, "_flag")
  tr <- if (v %in% mortality_names || v %in% log_extras) "log" else "logit"

  # Get observed-only data for this indicator
  obs_data <- bal |>
    filter(.data[[flag_col]] == 0L) |>
    select(geo, admin0, year, value = !!sym(v))

  if (nrow(obs_data) == 0) {
    cat(sprintf("  [%02d/%02d] %-30s SKIP (no observed data)\n", idx, length(all_vars), v))
    next
  }

  regions <- unique(obs_data$geo)
  n_fcast <- 0L

  for (rgn in regions) {
    series <- obs_data |> filter(geo == rgn) |> arrange(year)
    if (nrow(series) < 1) next
    if (max(series$year) >= forecast_to) next

    gf <- tryCatch(
      suppressWarnings(gapfill_series(
        series$year, series$value,
        transform = tr, forecast_to = forecast_to
      )),
      error = function(e) NULL
    )
    if (is.null(gf)) next

    fv <- gf |> filter(source == "forecasted")
    if (nrow(fv) == 0) next

    for (j in seq_len(nrow(fv))) {
      ri <- which(bal$geo == rgn & bal$year == fv$year[j])
      if (length(ri) == 1 && is.na(bal[[v]][ri])) {
        bal[[v]][ri]                              <- fv$estimate[j]
        bal[[paste0(v, "_ci_lo")]][ri]            <- fv$ci_lo[j]
        bal[[paste0(v, "_ci_hi")]][ri]            <- fv$ci_hi[j]
        bal[[flag_col]][ri]                       <- 2L
        bal[[paste0("src_", v, "_level")]][ri]    <- 1L
        n_fcast <- n_fcast + 1L
      }
    }
  }

  total_fcast <- total_fcast + n_fcast
  elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
  cat(sprintf("  [%02d/%02d] %-30s +%5d forecasted  (%.1f min)\n",
              idx, length(all_vars), v, n_fcast, elapsed))
}

cat("\n===== SUMMARY =====\n")
cat("Total forecasted values added:", total_fcast, "\n")
cat("Time:", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min\n\n")

# --- Save updated panel ---
saveRDS(bal, panel_file)
cat("Saved to:", panel_file, "\n\n")

# --- Coverage comparison ---
cat("=== Coverage improvement (2015) ===\n")
for (v in c("u5_mortality", "stunting", "anc_4plus", "literacy_women")) {
  n_total <- sum(!is.na(bal[[v]]) & bal$year == 2015)
  n_ctries <- n_distinct(bal$admin0[!is.na(bal[[v]]) & bal$year == 2015])
  flag_col <- paste0("imp_", v, "_flag")
  n_obs <- sum(bal[[flag_col]] == 0L & bal$year == 2015, na.rm = TRUE)
  n_int <- sum(bal[[flag_col]] == 1L & bal$year == 2015, na.rm = TRUE)
  n_fct <- sum(bal[[flag_col]] == 2L & bal$year == 2015, na.rm = TRUE)
  cat(sprintf("  %-25s %d/35 ctries | %3d obs + %3d interp + %3d fcast = %d regions\n",
              v, n_ctries, n_obs, n_int, n_fct, n_total))
}

cat("\n=== imp_flag distribution (all years) ===\n")
for (v in c("u5_mortality", "stunting", "hiv_prevalence", "bank_account")) {
  flag_col <- paste0("imp_", v, "_flag")
  tab <- table(bal[[flag_col]], useNA = "ifany")
  cat(sprintf("  %-25s 0(obs)=%s, 1(interp)=%s, 2(fcast)=%s, NA=%s\n",
              v,
              if ("0" %in% names(tab)) tab["0"] else "0",
              if ("1" %in% names(tab)) tab["1"] else "0",
              if ("2" %in% names(tab)) tab["2"] else "0",
              if (any(is.na(names(tab)))) tab[is.na(names(tab))] else "0"))
}
