# ============================================================================
# DHS Data Profiling Script
# Purpose: Understand data structure, granularity, missingness, and coverage
#          before building the processing layer (Phase 1, Week 2)
# ============================================================================

devtools::load_all()
library(dplyr)
library(tidyr)

tier1 <- c("KE", "NG", "ET", "TZ", "UG", "GH", "SN", "ML", "BF", "MW",
           "MZ", "ZM", "ZW", "RW", "CD")

# ============================================================================
# 1. FULL PULL: All 64 indicators × 15 Tier 1 countries
# ============================================================================
cat("\n========================================\n")
cat("1. PULLING ALL INDICATORS FOR TIER 1\n")
cat("========================================\n")

all_codes <- all_dhs_codes()
cat("Registered indicators:", length(all_codes), "\n")

# Pull by domain to avoid API timeout (8 smaller requests)
domain_fns <- list(
  health    = dhs_health_codes,
  mortality = dhs_mortality_codes,
  nutrition = dhs_nutrition_codes,
  hiv       = dhs_hiv_codes,
  education = dhs_education_codes,
  wash      = dhs_wash_codes,
  wealth    = dhs_wealth_codes,
  gender    = dhs_gender_codes
)

full_parts <- list()
for (domain in names(domain_fns)) {
  codes <- domain_fns[[domain]]()
  cat("  Fetching", domain, "(", length(codes), "indicators)...")
  part <- tryCatch(
    get_dhs_data(
      country_ids   = tier1,
      indicator_ids = unname(codes),
      breakdown     = "subnational"
    ),
    error = function(e) {
      cat(" FAILED:", conditionMessage(e), "\n")
      return(NULL)
    }
  )
  if (!is.null(part) && nrow(part) > 0) {
    cat(" ", nrow(part), "records\n")
    full_parts[[domain]] <- part
  } else {
    cat(" 0 records\n")
  }
  Sys.sleep(1)  # courtesy delay between domain pulls
}

full_data <- dplyr::bind_rows(full_parts)

cat("Total records returned:", nrow(full_data), "\n")
cat("Columns:", paste(names(full_data), collapse = ", "), "\n\n")

# ============================================================================
# 2. COLUMN STRUCTURE & TYPES
# ============================================================================
cat("\n========================================\n")
cat("2. COLUMN STRUCTURE\n")
cat("========================================\n")

for (col in names(full_data)) {
  na_count <- sum(is.na(full_data[[col]]))
  na_pct   <- round(100 * na_count / nrow(full_data), 1)
  cat(sprintf("  %-25s %-12s  NAs: %6d (%5.1f%%)\n",
              col, class(full_data[[col]])[1], na_count, na_pct))
}

# ============================================================================
# 3. VALUE FIELD ANALYSIS
# ============================================================================
cat("\n========================================\n")
cat("3. VALUE FIELD ANALYSIS\n")
cat("========================================\n")

cat("Value range:", range(full_data$Value, na.rm = TRUE), "\n")
cat("Value NAs:", sum(is.na(full_data$Value)), "\n")
cat("Zero values:", sum(full_data$Value == 0, na.rm = TRUE), "\n")
cat("Negative values:", sum(full_data$Value < 0, na.rm = TRUE), "\n")

# Check CI fields
cat("\nCI coverage:\n")
cat("  CILow NAs:", sum(is.na(full_data$CILow)), "/", nrow(full_data), "\n")
cat("  CIHigh NAs:", sum(is.na(full_data$CIHigh)), "/", nrow(full_data), "\n")
cat("  DenominatorWeighted NAs:", sum(is.na(full_data$DenominatorWeighted)), "/", nrow(full_data), "\n")

# ============================================================================
# 4. INDICATOR COVERAGE: Which of our 64 indicators actually have data?
# ============================================================================
cat("\n========================================\n")
cat("4. INDICATOR COVERAGE\n")
cat("========================================\n")

indicators_found <- unique(full_data$IndicatorId)
cat("Indicators with data:", length(indicators_found), "/", length(all_codes), "\n")

# Which are missing?
missing_ids <- setdiff(unname(all_codes), indicators_found)
if (length(missing_ids) > 0) {
  missing_names <- names(all_codes)[all_codes %in% missing_ids]
  cat("\nIndicators with NO data for Tier 1 countries:\n")
  for (i in seq_along(missing_ids)) {
    cat("  ", missing_names[i], " (", missing_ids[i], ")\n")
  }
} else {
  cat("All 64 indicators returned data!\n")
}

# Records per indicator
cat("\nRecords per indicator:\n")
ind_counts <- full_data |>
  count(IndicatorId, name = "n_records") |>
  arrange(desc(n_records))
print(ind_counts, n = 20)
cat("...\n")
cat("Min records:", min(ind_counts$n_records),
    "  Max:", max(ind_counts$n_records),
    "  Median:", median(ind_counts$n_records), "\n")

# ============================================================================
# 5. COUNTRY COVERAGE
# ============================================================================
cat("\n========================================\n")
cat("5. COUNTRY COVERAGE\n")
cat("========================================\n")

country_counts <- full_data |>
  group_by(DHS_CountryCode, CountryName) |>
  summarise(
    n_records    = n(),
    n_indicators = n_distinct(IndicatorId),
    n_surveys    = n_distinct(SurveyYear),
    year_range   = paste(min(SurveyYear), "-", max(SurveyYear)),
    n_regions    = n_distinct(CharacteristicLabel),
    .groups = "drop"
  ) |>
  arrange(desc(n_records))

print(country_counts, n = 20)

# ============================================================================
# 6. TEMPORAL STRUCTURE: Survey years & intervals
# ============================================================================
cat("\n========================================\n")
cat("6. TEMPORAL STRUCTURE\n")
cat("========================================\n")

temporal <- full_data |>
  group_by(DHS_CountryCode) |>
  summarise(
    survey_years = paste(sort(unique(SurveyYear)), collapse = ", "),
    n_rounds     = n_distinct(SurveyYear),
    first_year   = min(SurveyYear),
    last_year    = max(SurveyYear),
    .groups = "drop"
  )

for (i in seq_len(nrow(temporal))) {
  cat(sprintf("  %s: %d rounds (%d-%d): %s\n",
              temporal$DHS_CountryCode[i],
              temporal$n_rounds[i],
              temporal$first_year[i],
              temporal$last_year[i],
              temporal$survey_years[i]))
}

# Inter-survey gaps
cat("\nInter-survey gaps (years between consecutive surveys):\n")
gap_data <- full_data |>
  distinct(DHS_CountryCode, SurveyYear) |>
  arrange(DHS_CountryCode, SurveyYear) |>
  group_by(DHS_CountryCode) |>
  mutate(gap = SurveyYear - lag(SurveyYear)) |>
  filter(!is.na(gap))

cat("  Min gap:", min(gap_data$gap), "years\n")
cat("  Max gap:", max(gap_data$gap), "years\n")
cat("  Median gap:", median(gap_data$gap), "years\n")
cat("  Mean gap:", round(mean(gap_data$gap), 1), "years\n")
cat("\n  Gap distribution:\n")
print(table(gap_data$gap))

# ============================================================================
# 7. GEOGRAPHIC GRANULARITY
# ============================================================================
cat("\n========================================\n")
cat("7. GEOGRAPHIC GRANULARITY\n")
cat("========================================\n")

geo_summary <- full_data |>
  group_by(DHS_CountryCode, SurveyYear) |>
  summarise(
    n_regions = n_distinct(CharacteristicLabel),
    .groups   = "drop"
  )

cat("Regions per country-survey:\n")
cat("  Min:", min(geo_summary$n_regions), "\n")
cat("  Max:", max(geo_summary$n_regions), "\n")
cat("  Median:", median(geo_summary$n_regions), "\n")

# Do region counts change across surveys within a country?
cat("\nRegion count changes across surveys (boundary redefinitions):\n")
region_changes <- geo_summary |>
  group_by(DHS_CountryCode) |>
  summarise(
    min_regions = min(n_regions),
    max_regions = max(n_regions),
    changed = min_regions != max_regions,
    .groups = "drop"
  )
print(region_changes)

# CharacteristicCategory breakdown
cat("\nCharacteristicCategory values:\n")
print(table(full_data$CharacteristicCategory))

# ByVariableLabel breakdown
cat("\nByVariableLabel values:\n")
print(table(full_data$ByVariableLabel))

# ============================================================================
# 8. MISSINGNESS MATRIX: Indicator × Country
# ============================================================================
cat("\n========================================\n")
cat("8. INDICATOR × COUNTRY AVAILABILITY MATRIX\n")
cat("========================================\n")

avail_matrix <- full_data |>
  distinct(DHS_CountryCode, IndicatorId) |>
  mutate(available = 1) |>
  pivot_wider(
    names_from  = DHS_CountryCode,
    values_from = available,
    values_fill = 0
  )

cat("Matrix dimensions:", nrow(avail_matrix), "indicators ×",
    ncol(avail_matrix) - 1, "countries\n")

# Coverage rate per indicator
avail_matrix$coverage <- rowSums(avail_matrix[, -1]) / (ncol(avail_matrix) - 1)
low_coverage <- avail_matrix |>
  select(IndicatorId, coverage) |>
  filter(coverage < 0.8) |>
  arrange(coverage)

if (nrow(low_coverage) > 0) {
  cat("\nIndicators with <80% country coverage:\n")
  for (i in seq_len(nrow(low_coverage))) {
    ind_name <- names(all_codes)[all_codes == low_coverage$IndicatorId[i]]
    cat(sprintf("  %-30s (%s): %.0f%%\n",
                ind_name, low_coverage$IndicatorId[i],
                100 * low_coverage$coverage[i]))
  }
} else {
  cat("All indicators have ≥80% country coverage\n")
}

# Coverage rate per country
country_coverage <- full_data |>
  group_by(DHS_CountryCode) |>
  summarise(
    n_indicators = n_distinct(IndicatorId),
    pct = round(100 * n_indicators / length(all_codes), 1),
    .groups = "drop"
  ) |>
  arrange(pct)

cat("\nIndicator coverage per country:\n")
print(country_coverage, n = 20)

# ============================================================================
# 9. SUBNATIONAL MISSINGNESS: Indicator × Region within a country
# ============================================================================
cat("\n========================================\n")
cat("9. SUBNATIONAL MISSINGNESS (Kenya example)\n")
cat("========================================\n")

ke_data <- full_data |> filter(DHS_CountryCode == "KE")
ke_latest_year <- max(ke_data$SurveyYear)
ke_latest <- ke_data |> filter(SurveyYear == ke_latest_year)

cat("Kenya latest survey:", ke_latest_year, "\n")
cat("Regions in latest survey:", n_distinct(ke_latest$CharacteristicLabel), "\n")
cat("Indicators in latest survey:", n_distinct(ke_latest$IndicatorId), "\n")

# Missingness per indicator in latest survey
ke_regions <- unique(ke_latest$CharacteristicLabel)
ke_ind_coverage <- ke_latest |>
  group_by(IndicatorId) |>
  summarise(
    n_regions = n_distinct(CharacteristicLabel),
    pct = round(100 * n_regions / length(ke_regions), 1),
    .groups = "drop"
  ) |>
  arrange(pct)

cat("\nIndicator × region coverage in latest Kenya survey:\n")
print(ke_ind_coverage, n = 30)

# ============================================================================
# 10. REGIONID AND CHARACTERISTIC LABEL PATTERNS
# ============================================================================
cat("\n========================================\n")
cat("10. REGIONID / CHARACTERISTICLABEL PATTERNS\n")
cat("========================================\n")

# Sample of RegionId values
cat("Sample RegionId values:\n")
sample_regions <- full_data |>
  distinct(DHS_CountryCode, CharacteristicLabel, RegionId) |>
  slice_head(n = 15)
print(sample_regions)

# Check if RegionId is stable across surveys for same region name
cat("\nRegionId stability check (same label, different IDs across surveys?):\n")
region_stability <- full_data |>
  distinct(DHS_CountryCode, CharacteristicLabel, SurveyYear, RegionId) |>
  group_by(DHS_CountryCode, CharacteristicLabel) |>
  summarise(
    n_unique_ids = n_distinct(RegionId),
    .groups = "drop"
  ) |>
  filter(n_unique_ids > 1)

if (nrow(region_stability) > 0) {
  cat("UNSTABLE region IDs found:", nrow(region_stability), "region-country combos\n")
  print(head(region_stability, 15))
} else {
  cat("All RegionIds are stable across surveys\n")
}

# ============================================================================
# 11. ISPREFERRED AND DUPLICATES
# ============================================================================
cat("\n========================================\n")
cat("11. ISPREFERRED & DUPLICATE CHECK\n")
cat("========================================\n")

# Check for duplicates on key columns
dupes <- full_data |>
  group_by(DHS_CountryCode, IndicatorId, SurveyYear, CharacteristicLabel) |>
  filter(n() > 1) |>
  ungroup()

cat("Duplicate rows (same country/indicator/year/region):", nrow(dupes), "\n")

if (nrow(dupes) > 0) {
  cat("Sample duplicates:\n")
  print(head(dupes |> select(DHS_CountryCode, IndicatorId, SurveyYear,
                              CharacteristicLabel, Value, SurveyId), 10))
}

# IsPreferred distribution
cat("\nIsPreferred values:\n")
print(table(full_data$IsPreferred, useNA = "ifany"))

cat("\n\n========================================\n")
cat("PROFILING COMPLETE\n")
cat("========================================\n")

source("tests/dhs-profile-save.R")
