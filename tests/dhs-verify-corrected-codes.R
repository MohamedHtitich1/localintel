# ============================================================================
# Verify Corrected DHS Indicator Codes
# Maps wrong codes → likely correct codes, then tests each against the API
# ============================================================================

devtools::load_all()
library(dplyr)

tier1 <- c("KE", "NG", "ET", "TZ", "UG", "GH", "SN", "ML", "BF", "MW",
           "MZ", "ZM", "ZW", "RW", "CD")

# Load full indicator list from previous step
ind <- readRDS("tests/dhs-profile-results/dhs_all_indicators.rds")

# ============================================================================
# Corrected code mapping: old_wrong_code → new_candidate_code
# ============================================================================

corrections <- tribble(
  ~friendly_name,           ~old_code,          ~new_code,             ~source,
  # Health — typos / wrong code structure
  "full_vaccination",       "CH_VACC_C_FUL",    "CH_VACS_C_BAS",      "Fully vaccinated (8 basic antigens) - phase 7",
  "skilled_birth",          "RH_DELP_C_SKP",    "RH_DELA_C_SKP",      "Skilled birth attendance - try DELA",
  "postnatal_mother",       "RH_PNCM_W_2DY",    "RH_PCMT_W_TOT",      "Mother postnatal checkup: Total",
  "postnatal_newborn",      "RH_PNCC_C_2DY",    "RH_PCCT_C_TOT",      "Newborn postnatal checkup: Total",

  # Nutrition — wrong prefix (CN_ should be AN_ for adult nutrition)
  "anemia_women",           "CN_ANMC_W_ANY",     "AN_ANEM_W_ANY",      "Women with any anemia (AN_ prefix)",
  "exclusive_bf",           "CN_BRFL_C_EXB",     "CN_BFSS_C_EBF",      "Children exclusively breastfeeding",
  "early_bf",               "CN_BRFL_C_1HR",     "CN_BRFI_C_1HR",      "Breastfeeding within 1 hour (BRFI not BRFL)",
  "low_bmi_women",          "CN_NUTS_W_THN",     "AN_NUTS_W_THN",      "Women thin by BMI (AN_ prefix)",
  "obesity_women",          "CN_NUTS_W_OVW",     "AN_NUTS_W_OWT",      "Women overweight/obese by BMI (AN_ + OWT)",

  # HIV — try common DHS HIV testing codes
  "hiv_test_women",         "HA_HVTK_W_TST",     "HA_HVST_W_EVR",      "Women ever tested for HIV",
  "hiv_test_men",           "HA_HVTK_M_TST",     "HA_HVST_M_EVR",      "Men ever tested for HIV",
  "hiv_knowledge_women",    "HA_HKCP_W_CPC",     "HA_HKCN_W_CRK",      "Comprehensive knowledge of HIV: Women",
  "hiv_knowledge_men",      "HA_HKCP_M_CPC",     "HA_HKCN_M_CRK",      "Comprehensive knowledge of HIV: Men",
  "hiv_condom_women",       "HA_HKSW_W_HCN",     "HA_KHVP_W_CND",      "HIV prevention: condom use (Women)",
  "hiv_condom_men",         "HA_HKSW_M_HCN",     "HA_KHVP_M_CND",      "HIV prevention: condom use (Men)",

  # Education
  "net_attendance_primary", "ED_ENRR_B_GNR",     "ED_NARP_B_BTH",      "Net primary attendance rate: Total",
  "median_years_women",     "ED_EDYR_W_MYR",     "ED_MDIA_W_MYR",      "Median years of education: Women",
  "median_years_men",       "ED_EDYR_M_MYR",     "ED_MDIA_M_MYR",      "Median years of education: Men",

  # WASH — TOLT should be TLET, SFC should be SRF
  "improved_sanitation",    "WS_TOLT_H_IMP",     "WS_TLET_H_IMP",      "Improved sanitation (TLET not TOLT)",
  "surface_water",          "WS_SRCE_H_SFC",     "WS_SRCE_H_SRF",      "Surface water (SRF not SFC)",
  "open_defecation",        "WS_TOLT_H_NFC",     "WS_TLET_H_NFC",      "Open defecation (TLET not TOLT)",

  # Wealth
  "bank_account",           "HC_HEFF_H_BNK",     "CO_MOBB_W_BNK",      "Women with bank account (CO_ prefix)",

  # Gender — Women's empowerment
  "women_decision_all",     "WE_DCSN_W_ALL",     "WE_PPFA_W_A3P",      "Women participating in 3 decisions",
  "women_decision_health",  "WE_DCSN_W_HLT",     "WE_PPFA_W_OHC",      "Women participating in own health care decisions",
  "women_earning",          "WE_EARN_W_CSH",      "EM_EMPT_W_CSH",      "Women who worked for cash (EM_ prefix)",

  # Domestic violence
  "dv_physical",            "DV_VIOL_W_PHY",     "DV_EXPV_W_EVR",      "Ever experienced physical violence",
  "dv_sexual",              "DV_VIOL_W_SEX",     "DV_EXSV_W_EVR",      "Ever experienced sexual violence",
  "dv_emotional",           "DV_VIOL_W_EMO",     "DV_EXEV_W_EVR",      "Ever experienced emotional violence",
  "dv_attitude_women",      "DV_ATBV_W_YES",     "DV_AATB_W_AYS",      "Women who agree wife beating is justified",
  "dv_attitude_men",        "DV_ATBV_M_YES",     "DV_AATB_M_AYS",      "Men who agree wife beating is justified"
)

cat("Testing", nrow(corrections), "corrected indicator codes\n")
cat("========================================\n\n")

# First check: does the new code exist in the indicator catalogue?
corrections$in_catalogue <- corrections$new_code %in% ind$IndicatorId

cat("--- CATALOGUE CHECK ---\n")
for (i in seq_len(nrow(corrections))) {
  status <- if (corrections$in_catalogue[i]) "YES" else " NO"
  cat(sprintf("  [%s] %-25s %s → %s\n",
              status,
              corrections$friendly_name[i],
              corrections$old_code[i],
              corrections$new_code[i]))
}

not_in_cat <- corrections |> filter(!in_catalogue)
if (nrow(not_in_cat) > 0) {
  cat("\n", nrow(not_in_cat), "codes NOT in catalogue. Searching for alternatives...\n\n")

  # For codes not found, search the catalogue more specifically
  for (i in seq_len(nrow(not_in_cat))) {
    fn <- not_in_cat$friendly_name[i]
    # Extract the prefix pattern (first 2 segments)
    prefix <- sub("^([A-Z]{2}_[A-Z]{4}).*", "\\1", not_in_cat$new_code[i])
    matches <- ind |> filter(grepl(prefix, IndicatorId, fixed = TRUE))
    cat(sprintf("  %s — prefix '%s' has %d matches:\n", fn, prefix, nrow(matches)))
    if (nrow(matches) > 0) {
      for (j in seq_len(min(nrow(matches), 5))) {
        cat(sprintf("    %-22s  %s\n", matches$IndicatorId[j], matches$Label[j]))
      }
    }
    cat("\n")
  }
}

# Now test codes that ARE in catalogue against the API (subnational, Tier 1)
valid_codes <- corrections |> filter(in_catalogue)
cat("\n--- API TEST (subnational, Tier 1) ---\n")

api_results <- list()
for (i in seq_len(nrow(valid_codes))) {
  code <- valid_codes$new_code[i]
  fn   <- valid_codes$friendly_name[i]
  cat(sprintf("  %-25s (%s)...", fn, code))

  result <- tryCatch(
    get_dhs_data(
      country_ids   = tier1,
      indicator_ids = code,
      breakdown     = "subnational"
    ),
    error = function(e) tibble::tibble()
  )

  n <- nrow(result)
  n_countries <- if (n > 0) n_distinct(result$DHS_CountryCode) else 0
  cat(sprintf(" %d records, %d countries\n", n, n_countries))

  api_results[[fn]] <- tibble::tibble(
    friendly_name = fn,
    new_code      = code,
    n_records     = n,
    n_countries   = n_countries
  )

  Sys.sleep(0.5)
}

api_df <- bind_rows(api_results)

cat("\n--- SUMMARY ---\n")
cat("In catalogue:", sum(corrections$in_catalogue), "/", nrow(corrections), "\n")
cat("API returns data:", sum(api_df$n_records > 0), "/", nrow(api_df), "\n")

cat("\nWorking corrections:\n")
working <- api_df |> filter(n_records > 0)
for (i in seq_len(nrow(working))) {
  cat(sprintf("  %-25s %s  (%d records, %d countries)\n",
              working$friendly_name[i], working$new_code[i],
              working$n_records[i], working$n_countries[i]))
}

cat("\nStill failing (in catalogue but 0 records):\n")
failing <- api_df |> filter(n_records == 0)
if (nrow(failing) > 0) {
  for (i in seq_len(nrow(failing))) {
    cat(sprintf("  %-25s %s\n", failing$friendly_name[i], failing$new_code[i]))
  }
}

# Save results
out_dir <- "tests/dhs-profile-results"
saveRDS(corrections, file.path(out_dir, "code_corrections.rds"))
saveRDS(api_df, file.path(out_dir, "corrected_codes_api_test.rds"))

sink(file.path(out_dir, "corrected-codes-report.txt"))
cat("DHS Indicator Code Corrections\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M"), "\n\n")
cat("Corrections table:\n")
print(corrections, n = 40, width = 200)
cat("\n\nAPI test results:\n")
print(api_df, n = 40, width = 200)
sink()

cat("\nResults saved to:", out_dir, "\n")
