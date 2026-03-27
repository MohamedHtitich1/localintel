# ============================================================================
# Interactive Test Script for DHS Processing & Reference Layer
# Phase 1, Week 2 — Run in RStudio after: devtools::load_all()
# ============================================================================

devtools::load_all()
library(dplyr)

# ============================================================================
# 1. REFERENCE LAYER: Country Codes
# ============================================================================
cat("\n=== 1. SSA Country Codes ===\n")
cat("SSA codes:", length(ssa_codes()), "countries\n")
cat("Tier 1 codes:", length(tier1_codes()), "countries\n")
cat("Tier 1 subset of SSA?", all(tier1_codes() %in% ssa_codes()), "\n")

# ============================================================================
# 2. SINGLE INDICATOR: process_dhs()
# ============================================================================
cat("\n=== 2. Process Single Indicator ===\n")

# Fetch Kenya U5 mortality (has reference periods)
raw_u5m <- get_dhs_data(
  country_ids   = "KE",
  indicator_ids = "CM_ECMR_C_U5M",
  breakdown     = "subnational"
)
cat("Raw records:", nrow(raw_u5m), "\n")
cat("ByVariableLabel values:\n")
print(table(raw_u5m$ByVariableLabel))

# Process with default ref_period filtering
proc_u5m <- process_dhs(raw_u5m, out_col = "u5_mortality")
cat("\nProcessed records:", nrow(proc_u5m), "\n")
cat("Columns:", paste(names(proc_u5m), collapse = ", "), "\n")
cat("Sample:\n")
print(head(proc_u5m, 10))

# Verify geo format
cat("\nGeo format check (first 5):\n")
cat(head(unique(proc_u5m$geo), 5), sep = "\n")

# ============================================================================
# 3. NON-MORTALITY INDICATOR (no ref period)
# ============================================================================
cat("\n=== 3. Non-Mortality Indicator ===\n")

raw_vacc <- get_dhs_data(
  country_ids   = "KE",
  indicator_ids = "CH_VACC_C_BAS",
  breakdown     = "subnational"
)
proc_vacc <- process_dhs(raw_vacc, out_col = "basic_vacc")
cat("Raw:", nrow(raw_vacc), "→ Processed:", nrow(proc_vacc), "\n")
cat("Columns:", paste(names(proc_vacc), collapse = ", "), "\n")

# ============================================================================
# 4. DEDUPLICATION CHECK
# ============================================================================
cat("\n=== 4. Deduplication Check ===\n")

# Fetch data known to have duplicates (KE 2014 health indicators)
raw_health <- get_dhs_data(
  country_ids   = "KE",
  indicator_ids = c("FP_CUSA_W_ANY", "FP_CUSA_W_MOD"),
  breakdown     = "subnational"
)
n_raw <- nrow(raw_health)
proc_health <- process_dhs(raw_health, out_col = "contraceptive")
n_proc <- nrow(proc_health)
cat("Raw:", n_raw, "→ Processed:", n_proc,
    "(deduped:", n_raw - n_proc, "rows)\n")

# ============================================================================
# 5. KEEP OPTIONS
# ============================================================================
cat("\n=== 5. Keep Options ===\n")

proc_full <- process_dhs(raw_u5m, out_col = "u5_mortality",
                         keep_ci = TRUE,
                         keep_denominator = TRUE,
                         keep_metadata = TRUE)
cat("Columns with all options:", paste(names(proc_full), collapse = ", "), "\n")
cat("Sample:\n")
print(head(proc_full, 3))

# ============================================================================
# 6. BATCH PROCESSING
# ============================================================================
cat("\n=== 6. Batch Processing ===\n")

codes <- c(u5_mortality = "CM_ECMR_C_U5M",
           stunting     = "CN_NUTS_C_HA2",
           basic_vacc   = "CH_VACC_C_BAS")

raw_batch <- fetch_dhs_batch(codes, country_ids = "KE")
proc_batch <- process_dhs_batch(raw_batch)

for (nm in names(proc_batch)) {
  cat(sprintf("  %s: %d rows, cols: %s\n",
              nm, nrow(proc_batch[[nm]]),
              paste(names(proc_batch[[nm]]), collapse = ", ")))
}

# ============================================================================
# 7. ADMIN 1 REFERENCE TABLE
# ============================================================================
cat("\n=== 7. Admin 1 Reference Table ===\n")

ref <- get_admin1_ref(country_ids = c("KE", "NG"))
cat("Reference table:", nrow(ref), "regions\n")
cat("Columns:", paste(names(ref), collapse = ", "), "\n")
cat("By country:\n")
print(table(ref$admin0))
cat("\nSample:\n")
print(head(ref, 10))

# ============================================================================
# 8. KEEP_SSA FILTER
# ============================================================================
cat("\n=== 8. keep_ssa() Filter ===\n")

# Process multi-country data
raw_multi <- get_dhs_data(
  country_ids   = c("KE", "NG", "ET"),
  indicator_ids = "HC_ELEC_H_ELC",
  breakdown     = "subnational"
)
proc_multi <- process_dhs(raw_multi, out_col = "electricity")
cat("All records:", nrow(proc_multi), "\n")

ssa_filtered <- keep_ssa(proc_multi)
cat("After keep_ssa:", nrow(ssa_filtered), "\n")
cat("Countries:", paste(unique(substr(ssa_filtered$geo, 1, 2)), collapse = ", "), "\n")

# ============================================================================
# 9. ADD COUNTRY NAME
# ============================================================================
cat("\n=== 9. Add Country Name ===\n")

with_names <- add_dhs_country_name(proc_multi)
cat("Columns:", paste(names(with_names), collapse = ", "), "\n")
cat("Sample:\n")
print(head(with_names |> select(geo, year, electricity, country_name), 5))

# ============================================================================
# 10. LABEL & DOMAIN REGISTRIES
# ============================================================================
cat("\n=== 10. Label & Domain Registries ===\n")

labs <- dhs_var_labels()
cat("Labels registered:", length(labs), "\n")
cat("Sample:", labs["u5_mortality"], "\n")
cat("Sample:", labs["stunting"], "\n")

domains <- dhs_domain_mapping()
cat("Domain mapping:", length(domains), "indicators across",
    length(unique(domains)), "domains\n")
print(table(domains))

# ============================================================================
# 11. VERIFY GEO KEY COMPATIBILITY WITH ADMIN1 REF
# ============================================================================
cat("\n=== 11. Geo Key Compatibility ===\n")

# Check that processed geo keys match admin1 reference geo keys
ref_ke <- get_admin1_ref(country_ids = "KE")
proc_ke <- process_dhs(
  get_dhs_data("KE", "HC_ELEC_H_ELC", breakdown = "subnational"),
  out_col = "electricity"
)

# Latest year in processed data
latest_year <- max(proc_ke$year)
proc_ke_latest <- proc_ke |> filter(year == latest_year)

in_ref <- proc_ke_latest$geo %in% ref_ke$geo
cat("Latest year:", latest_year, "\n")
cat("Processed regions:", nrow(proc_ke_latest), "\n")
cat("In reference table:", sum(in_ref), "/", nrow(proc_ke_latest), "\n")

# Older years may have regions not in latest reference
oldest_year <- min(proc_ke$year)
proc_ke_oldest <- proc_ke |> filter(year == oldest_year)
in_ref_old <- proc_ke_oldest$geo %in% ref_ke$geo
cat("Oldest year:", oldest_year, "\n")
cat("Oldest regions in ref:", sum(in_ref_old), "/", nrow(proc_ke_oldest),
    "(expected: fewer due to boundary changes)\n")

cat("\n=== All tests complete! ===\n")
