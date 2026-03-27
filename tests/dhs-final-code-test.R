# ============================================================================
# Final round: test the EXACT codes found in the catalogue search
# These are the codes that appeared in the targeted searches above
# ============================================================================

devtools::load_all()
library(dplyr)

tier1 <- c("KE", "NG", "ET", "TZ", "UG", "GH", "SN", "ML", "BF", "MW",
           "MZ", "ZM", "ZW", "RW", "CD")

final_candidates <- tribble(
  ~friendly_name,            ~code,
  # HIV testing — from catalogue
  "hiv_test_women",          "HA_CPHT_W_ETR",   # ever tested, received results
  "hiv_test_men",            "HA_CPHT_M_ETR",   # ever tested, received results

  # HIV comprehensive knowledge — from catalogue
  "hiv_knowledge_women",     "HA_CKNA_W_CKA",   # comprehensive correct knowledge
  "hiv_knowledge_men",       "HA_CKNA_M_CKA",

  # Median years education — from catalogue
  "median_years_women",      "ED_EDAT_W_MYR",   # median years female
  "median_years_men",        "ED_EDAT_M_MYR",   # median years male
  "median_years_women_v2",   "ED_EDUC_W_MYR",   # alternate code
  "median_years_men_v2",     "ED_EDUC_M_MYR",   # alternate code

  # Women's decision-making — from WE_ prefix search
  "women_decision_health",   "WE_DKHC_W_OWN",   # guess based on WE_ pattern
  "women_decision_3",        "WE_DMAL_W_A3D",   # guess
  # Try the actual decision-making patterns from DHS STATcompiler
  "women_decision_v2",       "WE_DCID_W_3DC",   # 3 decisions
  "women_decision_v3",       "WE_DCID_W_OHC",   # own health care

  # DV emotional — from catalogue
  "dv_emotional",            "DV_FSVL_W_EMO",   # emotional violence
  "dv_emotional_v2",         "DV_SPVL_W_EMT",   # emotional by husband/partner

  # DV attitudes — from catalogue (WE_ prefix, not DV_!)
  "dv_attitude_women",       "WE_AWBT_W_AGR",   # justified for ≥1 reason [Women]
  "dv_attitude_men",         "WE_AWBT_M_AGR",   # justified for ≥1 reason [Men]

  # Full vaccination — CH_VACC_C_BAS already works (= basic_vaccination)
  # So full_vaccination is redundant. But try the APP variant:
  "full_vaccination_natl",   "CH_VACC_C_APP",   # according to national schedule

  # Women earning — try employment-related
  "women_earning",           "EM_WERN_W_WIF",   # women who decide own earnings
  "women_earning_v2",        "EM_EMPL_W_EMP",   # women employed
  "women_employment",        "EM_EMPT_W_EMP"    # women currently employed
)

cat("Testing", nrow(final_candidates), "final candidates\n")
cat("========================================\n\n")

results <- list()
for (i in seq_len(nrow(final_candidates))) {
  fn   <- final_candidates$friendly_name[i]
  code <- final_candidates$code[i]
  cat(sprintf("  %-28s (%s)...", fn, code))

  result <- tryCatch(
    get_dhs_data(
      country_ids   = tier1,
      indicator_ids = code,
      breakdown     = "subnational"
    ),
    error = function(e) tibble::tibble()
  )

  n  <- nrow(result)
  nc <- if (n > 0) n_distinct(result$DHS_CountryCode) else 0

  cat(sprintf(" %d records, %d countries\n", n, nc))

  results[[i]] <- tibble::tibble(
    friendly_name = fn, code = code, n_records = n, n_countries = nc
  )

  Sys.sleep(0.5)
}

res_df <- bind_rows(results)

cat("\n========================================\n")
cat("WORKING:\n")
working <- res_df |> filter(n_records > 0)
for (i in seq_len(nrow(working))) {
  cat(sprintf("  %-28s %-18s %5d records, %2d countries\n",
              working$friendly_name[i], working$code[i],
              working$n_records[i], working$n_countries[i]))
}

cat("\nNOT WORKING:\n")
not_working <- res_df |> filter(n_records == 0)
for (i in seq_len(nrow(not_working))) {
  cat(sprintf("  %-28s %s\n", not_working$friendly_name[i], not_working$code[i]))
}

saveRDS(res_df, "tests/dhs-profile-results/final_code_test.rds")
cat("\nSaved to tests/dhs-profile-results/final_code_test.rds\n")
