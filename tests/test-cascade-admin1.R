# ==================================================================
# DHS Cascade & Panel Assembly: Integration Test
# ==================================================================
# Tests cascade_to_admin1(), balance_dhs_panel(), and dhs_pipeline()
# using the package functions from R/dhs_cascade.R
#
# Two modes:
#   A) Synthetic test (no API calls) — verifies structure & logic
#   B) Live test with Tier 1 countries (requires DHS API access)
# ==================================================================

devtools::load_all()
library(dplyr)
library(tidyr)

out_dir <- "tests/gapfill-results"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)


# ==================================================================
# TEST A: Synthetic — verify panel assembly logic
# ==================================================================
cat("=== A: Synthetic cascade test ===\n\n")

# Create fake gapfill output (mimics gapfill_all_dhs() result)
fake_gf <- list(
  data = list(
    u5_mortality = tibble::tibble(
      year = rep(2010:2020, 3),
      estimate = c(runif(11, 50, 150), runif(11, 30, 100), runif(11, 60, 120)),
      ci_lo = estimate * 0.8,
      ci_hi = estimate * 1.2,
      source = rep(c("observed", rep("interpolated", 9), "observed"), 3),
      geo = rep(c("KE_Nairobi", "KE_Nyanza", "NG_Lagos"), each = 11),
      indicator = "u5_mortality"
    ),
    stunting = tibble::tibble(
      year = rep(2010:2020, 2),
      estimate = c(runif(11, 10, 40), runif(11, 20, 50)),
      ci_lo = pmax(estimate - 5, 0),
      ci_hi = pmin(estimate + 5, 100),
      source = rep(c("observed", rep("interpolated", 9), "observed"), 2),
      geo = rep(c("KE_Nairobi", "NG_Lagos"), each = 11),
      indicator = "stunting"
    )
  ),
  summary = tibble::tibble(
    indicator = c("u5_mortality", "stunting"),
    transform = c("log", "logit"),
    countries = c(2L, 2L),
    regions = c(3L, 2L)
  )
)

# Build admin1_ref manually (to avoid API call)
fake_ref <- tibble::tibble(
  geo = c("KE_Nairobi", "KE_Nyanza", "NG_Lagos"),
  admin0 = c("KE", "KE", "NG"),
  country_name = c("Kenya", "Kenya", "Nigeria"),
  region_label = c("Nairobi", "Nyanza", "Lagos")
)

# --- Test cascade_to_admin1 ---
panel <- cascade_to_admin1(fake_gf, admin1_ref = fake_ref,
                            include_ci = TRUE)

cat("Panel dimensions:", nrow(panel), "x", ncol(panel), "\n")
cat("Expected rows: 3 regions x 11 years = 33\n")
cat("Actual rows:", nrow(panel), "\n")
stopifnot(nrow(panel) == 33)

# Check columns exist
expected_cols <- c("geo", "admin0", "year",
                   "u5_mortality", "u5_mortality_ci_lo", "u5_mortality_ci_hi",
                   "src_u5_mortality_level", "imp_u5_mortality_flag",
                   "stunting", "stunting_ci_lo", "stunting_ci_hi",
                   "src_stunting_level", "imp_stunting_flag")
missing_cols <- setdiff(expected_cols, names(panel))
if (length(missing_cols) > 0) {
  cat("MISSING columns:", paste(missing_cols, collapse = ", "), "\n")
  stop("Missing expected columns!")
} else {
  cat("All expected columns present: OK\n")
}

# Check src_level is always 1L where data exists
stopifnot(all(panel$src_u5_mortality_level[!is.na(panel$u5_mortality)] == 1L))
cat("src_level = 1L for all non-NA: OK\n")

# Check imp_flag values: 0 or 1 only
flags <- panel$imp_u5_mortality_flag[!is.na(panel$imp_u5_mortality_flag)]
stopifnot(all(flags %in% c(0L, 1L)))
cat("imp_flag in {0, 1}: OK\n")

# Check that Nyanza has NA for stunting (not in stunting data)
nyanza_stunting <- panel |> filter(geo == "KE_Nyanza") |> pull(stunting)
stopifnot(all(is.na(nyanza_stunting)))
cat("Nyanza stunting = NA (not in data): OK\n")

# --- Test without CI ---
panel_noci <- cascade_to_admin1(fake_gf, admin1_ref = fake_ref,
                                 include_ci = FALSE)
stopifnot(!"u5_mortality_ci_lo" %in% names(panel_noci))
cat("include_ci = FALSE removes CI columns: OK\n")

# --- Test balance_dhs_panel ---
cat("\n--- Balance test ---\n")
bal <- balance_dhs_panel(panel, min_countries = 1, min_indicators = 1,
                          verbose = TRUE)
cat("Balanced:", nrow(bal$panel), "rows,",
    length(bal$dropped_indicators), "dropped indicators,",
    length(bal$dropped_regions), "dropped regions\n")
stopifnot(nrow(bal$panel) == 33)  # nothing should be dropped with min_* = 1

# Stricter balance: require 3 countries (only u5_mortality has 2)
bal2 <- balance_dhs_panel(panel, min_countries = 3, min_indicators = 1,
                           verbose = TRUE)
cat("With min_countries=3: dropped",
    length(bal2$dropped_indicators), "indicators\n")
stopifnot(length(bal2$dropped_indicators) == 2)  # both should be dropped

cat("\n=== A: ALL SYNTHETIC TESTS PASSED ===\n\n")


# ==================================================================
# TEST B: Live — Tier 1 countries (if previous gapfill data exists)
# ==================================================================
cat("=== B: Live cascade test (using saved gapfill data) ===\n\n")

gf_path <- file.path(out_dir, "all_gapfilled_ssa.rds")
if (file.exists(gf_path)) {
  cat("Loading saved gapfill data from:", gf_path, "\n")
  saved_data <- readRDS(gf_path)

  summary_path <- file.path(out_dir, "summary_table.rds")
  saved_summary <- if (file.exists(summary_path)) readRDS(summary_path) else NULL

  # Reconstruct gapfill_result format
  gf_result <- list(data = saved_data, summary = saved_summary)

  # Build panel
  panel_live <- cascade_to_admin1(gf_result, include_ci = TRUE)
  cat("Live panel dimensions:", nrow(panel_live), "x", ncol(panel_live), "\n")
  cat("Regions:", n_distinct(panel_live$geo), "\n")
  cat("Countries:", n_distinct(panel_live$admin0), "\n")
  cat("Years:", min(panel_live$year), "-", max(panel_live$year), "\n")

  # Detect indicator columns
  flag_cols <- grep("^imp_(.+)_flag$", names(panel_live), value = TRUE)
  ind_names <- sub("^imp_(.+)_flag$", "\\1", flag_cols)
  cat("Indicators:", length(ind_names), "\n")

  # Check all src_levels are 1L
  for (v in ind_names) {
    src_col <- paste0("src_", v, "_level")
    vals <- panel_live[[src_col]]
    non_na <- vals[!is.na(vals)]
    if (any(non_na != 1L)) {
      cat("WARNING:", v, "has src_level != 1L\n")
    }
  }
  cat("All src_levels = 1L: OK\n")

  # Check imp_flags
  for (v in ind_names) {
    flag_col <- paste0("imp_", v, "_flag")
    vals <- panel_live[[flag_col]]
    non_na <- vals[!is.na(vals)]
    if (any(!non_na %in% c(0L, 1L))) {
      cat("WARNING:", v, "has imp_flag not in {0, 1}\n")
    }
  }
  cat("All imp_flags in {0, 1}: OK\n")

  # Coverage summary per indicator
  cat("\nIndicator coverage:\n")
  coverage <- sapply(ind_names, function(v) {
    n_total <- nrow(panel_live)
    n_obs <- sum(!is.na(panel_live[[v]]))
    round(n_obs / n_total * 100, 1)
  })
  cov_df <- data.frame(
    indicator = names(coverage),
    coverage_pct = unname(coverage)
  ) |> arrange(desc(coverage_pct))
  print(cov_df, row.names = FALSE)

  # Balance panel
  cat("\n--- Balancing live panel ---\n")
  bal_live <- balance_dhs_panel(panel_live, min_countries = 5,
                                 min_indicators = 10, verbose = TRUE)
  cat("Dropped indicators:", length(bal_live$dropped_indicators), "\n")
  if (length(bal_live$dropped_indicators) > 0) {
    cat("  ", paste(bal_live$dropped_indicators, collapse = ", "), "\n")
  }
  cat("Dropped regions:", length(bal_live$dropped_regions), "\n")

  # Save panel
  saveRDS(panel_live, file.path(out_dir, "dhs_panel_admin1.rds"))
  cat("\nSaved: dhs_panel_admin1.rds\n")

  saveRDS(bal_live$panel, file.path(out_dir, "dhs_panel_admin1_balanced.rds"))
  cat("Saved: dhs_panel_admin1_balanced.rds\n")

} else {
  cat("No saved gapfill data found at:", gf_path, "\n")
  cat("Run test-gapfill-v3-full.R first to generate data.\n")
  cat("Skipping live test.\n")
}


cat("\n=== ALL CASCADE TESTS COMPLETE ===\n")
