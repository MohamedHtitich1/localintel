# ============================================================================
# Save DHS Profiling Results
# Run this AFTER sourcing dhs-data-profile.R (objects must be in environment)
# ============================================================================

out_dir <- "tests/dhs-profile-results"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --- 1. Console output as text ---
sink(file.path(out_dir, "profiling-output.txt"))
cat("DHS Data Profiling — Tier 1 Countries\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M"), "\n")
cat("========================================\n\n")

cat("Total records:", nrow(full_data), "\n")
cat("Columns:", paste(names(full_data), collapse = ", "), "\n\n")

cat("--- COLUMN STRUCTURE ---\n")
for (col in names(full_data)) {
  na_count <- sum(is.na(full_data[[col]]))
  na_pct   <- round(100 * na_count / nrow(full_data), 1)
  cat(sprintf("  %-25s %-12s  NAs: %6d (%5.1f%%)\n",
              col, class(full_data[[col]])[1], na_count, na_pct))
}

cat("\n--- VALUE FIELD ---\n")
cat("Range:", range(full_data$Value, na.rm = TRUE), "\n")
cat("Value NAs:", sum(is.na(full_data$Value)), "\n")
cat("Zeros:", sum(full_data$Value == 0, na.rm = TRUE), "\n")
cat("Negatives:", sum(full_data$Value < 0, na.rm = TRUE), "\n")
cat("CILow NAs:", sum(is.na(full_data$CILow)), "/", nrow(full_data), "\n")
cat("CIHigh NAs:", sum(is.na(full_data$CIHigh)), "/", nrow(full_data), "\n")
cat("DenominatorWeighted NAs:", sum(is.na(full_data$DenominatorWeighted)), "/", nrow(full_data), "\n")

cat("\n--- INDICATOR COVERAGE ---\n")
all_codes <- all_dhs_codes()
indicators_found <- unique(full_data$IndicatorId)
cat("Indicators with data:", length(indicators_found), "/", length(all_codes), "\n")
missing_ids <- setdiff(unname(all_codes), indicators_found)
if (length(missing_ids) > 0) {
  cat("Missing:\n")
  for (mid in missing_ids) {
    cat("  ", names(all_codes)[all_codes == mid], " (", mid, ")\n")
  }
}

cat("\nRecords per indicator:\n")
ind_counts <- full_data |>
  dplyr::count(IndicatorId, name = "n_records") |>
  dplyr::arrange(dplyr::desc(n_records))
print(ind_counts, n = 70)

cat("\n--- COUNTRY COVERAGE ---\n")
print(country_counts, n = 20)

cat("\n--- TEMPORAL STRUCTURE ---\n")
for (i in seq_len(nrow(temporal))) {
  cat(sprintf("  %s: %d rounds (%d-%d): %s\n",
              temporal$DHS_CountryCode[i],
              temporal$n_rounds[i],
              temporal$first_year[i],
              temporal$last_year[i],
              temporal$survey_years[i]))
}
cat("\nInter-survey gaps:\n")
cat("  Min:", min(gap_data$gap), " Max:", max(gap_data$gap),
    " Median:", median(gap_data$gap), " Mean:", round(mean(gap_data$gap), 1), "\n")
cat("Gap distribution:\n")
print(table(gap_data$gap))

cat("\n--- GEOGRAPHIC GRANULARITY ---\n")
cat("Regions per country-survey — Min:", min(geo_summary$n_regions),
    " Max:", max(geo_summary$n_regions),
    " Median:", median(geo_summary$n_regions), "\n")
cat("\nRegion count changes across surveys:\n")
print(region_changes)
cat("\nCharacteristicCategory:\n")
print(table(full_data$CharacteristicCategory))
cat("\nByVariableLabel:\n")
print(table(full_data$ByVariableLabel))

cat("\n--- INDICATOR x COUNTRY MATRIX ---\n")
low_cov <- avail_matrix |>
  dplyr::select(IndicatorId, coverage) |>
  dplyr::filter(coverage < 1) |>
  dplyr::arrange(coverage)
if (nrow(low_cov) > 0) {
  cat("Indicators with <100% Tier 1 coverage:\n")
  for (i in seq_len(nrow(low_cov))) {
    ind_name <- names(all_codes)[all_codes == low_cov$IndicatorId[i]]
    cat(sprintf("  %-30s (%s): %.0f%%\n",
                ind_name, low_cov$IndicatorId[i], 100 * low_cov$coverage[i]))
  }
}
cat("\nIndicator coverage per country:\n")
print(country_coverage, n = 20)

cat("\n--- SUBNATIONAL MISSINGNESS (Kenya latest) ---\n")
cat("Latest survey:", ke_latest_year, "\n")
cat("Regions:", dplyr::n_distinct(ke_latest$CharacteristicLabel), "\n")
cat("Indicators:", dplyr::n_distinct(ke_latest$IndicatorId), "\n")
print(ke_ind_coverage, n = 70)

cat("\n--- REGIONID PATTERNS ---\n")
print(sample_regions)
cat("\nUnstable RegionIds:", nrow(region_stability), "combos\n")
if (nrow(region_stability) > 0) print(head(region_stability, 20))

cat("\n--- DUPLICATES ---\n")
cat("Duplicate rows:", nrow(dupes), "\n")
if (nrow(dupes) > 0) {
  print(head(dupes |> dplyr::select(DHS_CountryCode, IndicatorId, SurveyYear,
                                     CharacteristicLabel, Value, SurveyId), 10))
}

sink()
cat("Console output saved to:", file.path(out_dir, "profiling-output.txt"), "\n")

# --- 2. R objects as .rds ---
saveRDS(full_data,         file.path(out_dir, "full_data.rds"))
saveRDS(country_counts,    file.path(out_dir, "country_counts.rds"))
saveRDS(temporal,          file.path(out_dir, "temporal.rds"))
saveRDS(gap_data,          file.path(out_dir, "gap_data.rds"))
saveRDS(geo_summary,       file.path(out_dir, "geo_summary.rds"))
saveRDS(region_changes,    file.path(out_dir, "region_changes.rds"))
saveRDS(avail_matrix,      file.path(out_dir, "avail_matrix.rds"))
saveRDS(country_coverage,  file.path(out_dir, "country_coverage.rds"))
saveRDS(ke_ind_coverage,   file.path(out_dir, "ke_ind_coverage.rds"))
saveRDS(region_stability,  file.path(out_dir, "region_stability.rds"))
saveRDS(ind_counts,        file.path(out_dir, "ind_counts.rds"))
saveRDS(dupes,             file.path(out_dir, "dupes.rds"))

cat("R objects saved to:", out_dir, "\n")
cat("Files:\n")
cat(paste(" ", list.files(out_dir), collapse = "\n"), "\n")
