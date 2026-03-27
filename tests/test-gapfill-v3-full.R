# ==================================================================
# Gap-Fill V3 (Calibrated): Full Test — ALL SSA x ALL 62 Indicators
# ==================================================================
# Uses the package functions from R/dhs_gapfill.R:
#   gapfill_series(), gapfill_indicator(), gapfill_all_dhs()
# ==================================================================

devtools::load_all()
library(dplyr)
library(tidyr)

# --- Output folder ---
out_dir <- "tests/gapfill-results"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ==================================================================
# ALL 44 SSA countries x ALL 62 indicators
# ==================================================================
countries <- ssa_codes()
cat("Testing with ALL", length(countries), "SSA countries x 62 indicators\n\n")

# ==================================================================
# TEST A: All indicators x All SSA countries
# ==================================================================
cat("=== A: Gap-fill all indicators x all SSA countries ===\n\n")

result <- gapfill_all_dhs(country_ids = countries, sigma_floor = 0.25,
                          verbose = TRUE)

all_gapfilled <- result$data
summary_tbl <- result$summary

# ==================================================================
# SUMMARY TABLE
# ==================================================================
cat("\n=== SUMMARY TABLE ===\n")
print(summary_tbl |> select(indicator, transform, countries, regions,
                            errors, observed, interpolated, total, bounds_ok),
      n = 70, width = 130)

cat("\n--- TOTALS ---\n")
cat("  Indicators with data:", nrow(summary_tbl), "/", 62, "\n")
cat("  Countries covered:", max(summary_tbl$countries), "\n")
cat("  Total regions:", sum(summary_tbl$regions), "\n")
cat("  Total observed:", sum(summary_tbl$observed), "\n")
cat("  Total interpolated:", sum(summary_tbl$interpolated), "\n")
cat("  Total annual estimates:", sum(summary_tbl$total), "\n")
cat("  All bounds OK?", all(summary_tbl$bounds_ok), "\n")
cat("  Total fit errors:", sum(summary_tbl$errors), "\n")
cat("  Total fit warnings:", sum(summary_tbl$warnings), "\n")


# ==================================================================
# TEST B: Country breakdown for U5 mortality
# ==================================================================
cat("\n=== B: Country breakdown — U5 mortality ===\n")
if ("u5_mortality" %in% names(all_gapfilled)) {
  all_gapfilled[["u5_mortality"]] |>
    mutate(cc = substr(geo, 1, 2)) |>
    group_by(cc) |>
    summarise(
      regions = n_distinct(geo),
      obs = sum(source == "observed"),
      interp = sum(source == "interpolated"),
      year_range = paste(min(year), "-", max(year)),
      .groups = "drop"
    ) |> print(n = 50)
}


# ==================================================================
# TEST C: LOO CV — all countries with 5+ obs series
# ==================================================================
cat("\n=== C: LOO CV — all countries with 5+ obs series ===\n")
if ("u5_mortality" %in% names(all_gapfilled)) {
  raw_u5m <- get_dhs_data(countries, "CM_ECMR_C_U5M",
                          breakdown = "subnational") |>
    process_dhs(out_col = "u5_mortality")

  long_series <- raw_u5m |> group_by(geo) |>
    filter(n() >= 5) |> ungroup()

  cv_regions <- unique(long_series$geo)
  cat("Regions with 5+ obs:", length(cv_regions), "\n")

  cv_results <- list()
  for (rgn in cv_regions) {
    series <- long_series |> filter(geo == rgn) |> arrange(year)
    for (i in 2:(nrow(series) - 1)) {
      train_y <- series$year[-i]; train_v <- series$u5_mortality[-i]
      test_yr <- series$year[i]; test_val <- series$u5_mortality[i]
      res <- tryCatch(
        suppressWarnings(
          gapfill_series(train_y, train_v, target_years = test_yr,
                         transform = "log")
        ),
        error = function(e) NULL
      )
      if (!is.null(res)) {
        cv_results[[length(cv_results) + 1]] <- data.frame(
          region = rgn, year = test_yr,
          observed = test_val, predicted = res$estimate,
          ci_lo = res$ci_lo, ci_hi = res$ci_hi,
          abs_error = abs(res$estimate - test_val),
          pct_error = abs(res$estimate - test_val) / test_val * 100,
          covered = test_val >= res$ci_lo & test_val <= res$ci_hi
        )
      }
    }
  }
  cv <- bind_rows(cv_results)
  cat("Total LOO predictions:", nrow(cv), "\n")
  cat("MAE:", round(mean(cv$abs_error, na.rm = TRUE), 1), "\n")
  cat("MAPE:", round(mean(cv$pct_error, na.rm = TRUE), 1), "%\n")
  cat("Median APE:", round(median(cv$pct_error, na.rm = TRUE), 1), "%\n")
  cat("95% CI coverage:", round(mean(cv$covered, na.rm = TRUE) * 100, 1), "%\n")

  cat("\nBy country:\n")
  cv |>
    mutate(cc = substr(region, 1, 2)) |>
    group_by(cc) |>
    summarise(
      n = n(),
      MAE = round(mean(abs_error, na.rm = TRUE), 1),
      MAPE = round(mean(pct_error, na.rm = TRUE), 1),
      coverage = round(mean(covered, na.rm = TRUE) * 100, 1),
      .groups = "drop"
    ) |> print(n = 50)
}


# ==================================================================
# SAVE DATASETS
# ==================================================================
cat("\n=== Saving datasets ===\n")

saveRDS(all_gapfilled, file.path(out_dir, "all_gapfilled_ssa.rds"))
cat("Saved: all_gapfilled_ssa.rds\n")

if (exists("cv")) {
  saveRDS(cv, file.path(out_dir, "loo_cv_all_countries.rds"))
  cat("Saved: loo_cv_all_countries.rds\n")
}

saveRDS(summary_tbl, file.path(out_dir, "summary_table.rds"))
cat("Saved: summary_table.rds\n")

cat("\nAll datasets saved to:", out_dir, "\n")
cat("\n=== ALL TESTS COMPLETE ===\n")
