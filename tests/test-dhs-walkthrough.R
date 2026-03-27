# ============================================================
# DHS Processing & Reference Layer — Interactive Walkthrough
# Run this in RStudio line-by-line or block-by-block
# ============================================================

devtools::load_all()
library(dplyr)

# ============================================================
# PART A: What raw DHS API data looks like
# ============================================================

cat("\n=== A1: Raw API response for Kenya U5 mortality ===\n")
raw_u5m <- get_dhs_data("KE", "CM_ECMR_C_U5M", breakdown = "subnational")
cat("Dimensions:", nrow(raw_u5m), "rows x", ncol(raw_u5m), "cols\n")
cat("Column names:\n")
names(raw_u5m)

# Look at key columns
raw_u5m |>
  select(DHS_CountryCode, SurveyYear, CharacteristicLabel,
         Value, ByVariableLabel, CILow, CIHigh) |>
  head(10)

# Survey years available
cat("\nSurvey years:", sort(unique(raw_u5m$SurveyYear)), "\n")

# Reference period — this is why filtering matters
cat("\nByVariableLabel (reference periods):\n")
table(raw_u5m$ByVariableLabel)


# ============================================================
# PART B: process_dhs() — the transformation
# ============================================================

cat("\n=== B1: Basic processing (minimal output) ===\n")
proc <- process_dhs(raw_u5m, out_col = "u5_mortality")
proc |> head(10)
cat("Cols:", paste(names(proc), collapse = ", "), "\n")

cat("\n=== B2: With confidence intervals & metadata ===\n")
proc_full <- process_dhs(raw_u5m, out_col = "u5_mortality",
                         keep_ci = TRUE, keep_denominator = TRUE,
                         keep_metadata = TRUE)
proc_full |> head(5)
cat("Cols:", paste(names(proc_full), collapse = ", "), "\n")


# ============================================================
# PART C: Batch fetch + process (multiple indicators)
# ============================================================

cat("\n=== C1: Fetch 3 indicators at once ===\n")
codes <- c(
  u5_mortality = "CM_ECMR_C_U5M",
  stunting     = "CN_NUTS_C_HA2",
  electricity  = "HC_ELEC_H_ELC"
)
batch_raw <- fetch_dhs_batch(codes, country_ids = "KE")
cat("Returned a list with names:", paste(names(batch_raw), collapse = ", "), "\n")
cat("Rows per indicator:\n")
sapply(batch_raw, nrow)

cat("\n=== C2: Process the batch ===\n")
batch_proc <- process_dhs_batch(batch_raw)
for (nm in names(batch_proc)) {
  cat(" ", nm, ":", nrow(batch_proc[[nm]]), "rows →",
      paste(names(batch_proc[[nm]]), collapse = ", "), "\n")
}
batch_proc$stunting |> head(5)


# ============================================================
# PART D: Reference functions
# ============================================================

cat("\n=== D1: SSA country codes ===\n")
cat("All SSA (", length(ssa_codes()), "):", head(ssa_codes(), 20), "...\n")
cat("Tier 1 (", length(tier1_codes()), "):", tier1_codes(), "\n")
cat("Tier 1 is subset of SSA?", all(tier1_codes() %in% ssa_codes()), "\n")

cat("\n=== D2: Admin 1 reference table (KE + NG) ===\n")
ref <- get_admin1_ref(c("KE", "NG"))
cat("Total regions:", nrow(ref), "\n")
cat("By country:\n")
table(ref$admin0)
ref |> head(10)

cat("\n=== D3: keep_ssa() filter ===\n")
# Simulate mixed data with a non-SSA country
mixed <- bind_rows(
  proc |> head(5),
  tibble(geo = c("FR_Paris", "FR_Lyon"), year = 2020L, u5_mortality = c(3, 4))
)
cat("Before filter:", nrow(mixed), "rows\n")
cat("Countries:", unique(substr(mixed$geo, 1, 2)), "\n")
filtered <- keep_ssa(mixed)
cat("After keep_ssa:", nrow(filtered), "rows\n")
cat("Countries:", unique(substr(filtered$geo, 1, 2)), "\n")

cat("\n=== D4: Add country names ===\n")
proc |>
  head(5) |>
  add_dhs_country_name()

cat("\n=== D5: Variable labels ===\n")
labels <- dhs_var_labels()
cat("Total labels:", length(labels), "\n")
cat("Sample:\n")
labels[c("u5_mortality", "stunting", "electricity", "hiv_prevalence")]

cat("\n=== D6: Domain mapping ===\n")
domains <- dhs_domain_mapping()
cat("Indicators per domain:\n")
table(domains)


# ============================================================
# PART E: Geo key compatibility check
# ============================================================

cat("\n=== E1: Do processed data geo keys match the reference table? ===\n")
ke_data <- get_dhs_data("KE", "HC_ELEC_H_ELC", breakdown = "subnational") |>
  process_dhs(out_col = "electricity")

# Latest survey
latest <- ke_data |> filter(year == max(year))
ref_ke <- get_admin1_ref("KE")
cat("Latest data year:", max(ke_data$year), "\n")
cat("Data regions:", nrow(latest), "\n")
cat("Reference regions:", nrow(ref_ke), "\n")
cat("Match:", sum(latest$geo %in% ref_ke$geo), "/", nrow(latest), "\n")

# Older surveys (boundary changes!)
oldest <- ke_data |> filter(year == min(year))
cat("\nOldest data year:", min(ke_data$year), "\n")
cat("Oldest regions:", nrow(oldest), "\n")
cat("In current reference:", sum(oldest$geo %in% ref_ke$geo), "/", nrow(oldest), "\n")
cat("(Fewer matches expected — boundaries changed over time)\n")

cat("\n\n=== WALKTHROUGH COMPLETE ===\n")

