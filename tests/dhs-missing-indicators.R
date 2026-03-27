# ============================================================================
# Diagnose Missing DHS Indicators
# Purpose: For each of the 30 indicators that returned 0 records,
#          check: (1) does the ID exist at all? (2) national vs subnational?
#          (3) is it available for any SSA country?
# Run AFTER devtools::load_all()
# ============================================================================

devtools::load_all()
library(dplyr)

tier1 <- c("KE", "NG", "ET", "TZ", "UG", "GH", "SN", "ML", "BF", "MW",
           "MZ", "ZM", "ZW", "RW", "CD")

all_codes <- all_dhs_codes()

# The 30 indicators that returned no data in profiling
missing_ids <- c(
  "CH_VACC_C_FUL", "RH_DELP_C_SKP", "RH_PNCM_W_2DY", "RH_PNCC_C_2DY",
  "CN_ANMC_W_ANY", "CN_BRFL_C_EXB", "CN_BRFL_C_1HR", "CN_NUTS_W_THN",
  "CN_NUTS_W_OVW",
  "HA_HVTK_W_TST", "HA_HVTK_M_TST", "HA_HKCP_W_CPC", "HA_HKCP_M_CPC",
  "HA_HKSW_W_HCN", "HA_HKSW_M_HCN",
  "ED_ENRR_B_GNR", "ED_EDYR_W_MYR", "ED_EDYR_M_MYR",
  "WS_TOLT_H_IMP", "WS_SRCE_H_SFC", "WS_TOLT_H_NFC",
  "HC_HEFF_H_BNK",
  "WE_DCSN_W_ALL", "WE_DCSN_W_HLT", "WE_EARN_W_CSH",
  "DV_VIOL_W_PHY", "DV_VIOL_W_SEX", "DV_VIOL_W_EMO",
  "DV_ATBV_W_YES", "DV_ATBV_M_YES"
)

cat("Testing", length(missing_ids), "missing indicators\n")
cat("========================================\n\n")

results <- list()

for (ind_id in missing_ids) {
  friendly <- names(all_codes)[all_codes == ind_id]
  cat(sprintf("%-30s (%s)...", friendly, ind_id))

  # Test 1: Subnational, Tier 1 countries (what we already tried)
  # Test 2: National level, Tier 1 countries
  # Test 3: Subnational, ALL countries (no country filter)

  # National, Tier 1
  nat <- tryCatch(
    get_dhs_data(
      country_ids   = tier1,
      indicator_ids = ind_id,
      breakdown     = "national",
      preferred_only = FALSE
    ),
    error = function(e) tibble::tibble()
  )
  Sys.sleep(0.5)

  # Subnational, ALL countries (no filter)
  sub_all <- tryCatch(
    get_dhs_data(
      country_ids   = NULL,
      indicator_ids = ind_id,
      breakdown     = "subnational",
      preferred_only = FALSE
    ),
    error = function(e) tibble::tibble()
  )
  Sys.sleep(0.5)

  nat_n <- nrow(nat)
  sub_all_n <- nrow(sub_all)

  # Which countries have it at subnational?
  sub_countries <- if (sub_all_n > 0) {
    paste(sort(unique(sub_all$DHS_CountryCode)), collapse = ", ")
  } else {
    "none"
  }

  # Which countries at national?
  nat_countries <- if (nat_n > 0) {
    paste(sort(unique(nat$DHS_CountryCode)), collapse = ", ")
  } else {
    "none"
  }

  status <- case_when(
    sub_all_n > 0 ~ "EXISTS_SUB (not in Tier1?)",
    nat_n > 0     ~ "NATIONAL_ONLY",
    TRUE          ~ "NO_DATA_ANYWHERE"
  )

  cat(sprintf(" nat=%d, sub_all=%d => %s\n", nat_n, sub_all_n, status))

  results[[ind_id]] <- tibble::tibble(
    friendly_name  = friendly,
    indicator_id   = ind_id,
    national_tier1 = nat_n,
    subnational_all = sub_all_n,
    status         = status,
    nat_countries  = nat_countries,
    sub_countries  = sub_countries
  )

  Sys.sleep(0.5)  # be nice to the API
}

# Combine results
diag <- dplyr::bind_rows(results)

cat("\n========================================\n")
cat("SUMMARY\n")
cat("========================================\n")

cat("\nBy status:\n")
print(table(diag$status))

cat("\n--- NO_DATA_ANYWHERE ---\n")
no_data <- diag |> filter(status == "NO_DATA_ANYWHERE")
if (nrow(no_data) > 0) {
  for (i in seq_len(nrow(no_data))) {
    cat(sprintf("  %-30s %s\n", no_data$friendly_name[i], no_data$indicator_id[i]))
  }
  cat("  => These indicator IDs likely don't exist. Need alternate codes.\n")
}

cat("\n--- NATIONAL_ONLY ---\n")
nat_only <- diag |> filter(status == "NATIONAL_ONLY")
if (nrow(nat_only) > 0) {
  for (i in seq_len(nrow(nat_only))) {
    cat(sprintf("  %-30s %s  (countries: %s)\n",
                nat_only$friendly_name[i], nat_only$indicator_id[i],
                nat_only$nat_countries[i]))
  }
  cat("  => Available at national level but not subnational breakdown.\n")
}

cat("\n--- EXISTS_SUB (not in Tier1?) ---\n")
exists_sub <- diag |> filter(grepl("EXISTS_SUB", status))
if (nrow(exists_sub) > 0) {
  for (i in seq_len(nrow(exists_sub))) {
    cat(sprintf("  %-30s %s\n    countries: %s\n",
                exists_sub$friendly_name[i], exists_sub$indicator_id[i],
                exists_sub$sub_countries[i]))
  }
  cat("  => Available subnational for some countries, just not our Tier 1.\n")
}

# Save diagnostic results
out_dir <- "tests/dhs-profile-results"
saveRDS(diag, file.path(out_dir, "missing_indicator_diagnosis.rds"))

sink(file.path(out_dir, "missing-indicators-report.txt"))
cat("DHS Missing Indicator Diagnosis\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M"), "\n\n")
print(diag, n = 40, width = 200)
cat("\n\nBy status:\n")
print(table(diag$status))
sink()

cat("\nResults saved to:", out_dir, "\n")
cat("  missing_indicator_diagnosis.rds\n")
cat("  missing-indicators-report.txt\n")
