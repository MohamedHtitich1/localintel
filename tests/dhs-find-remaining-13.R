# ============================================================================
# Final search for the remaining 13 indicators
# 11 not in catalogue + 2 in catalogue but 0 records
# Strategy: search the full indicator list with broader/different terms
# ============================================================================

devtools::load_all()
library(dplyr)
library(stringr)

ind <- readRDS("tests/dhs-profile-results/dhs_all_indicators.rds")

tier1 <- c("KE", "NG", "ET", "TZ", "UG", "GH", "SN", "ML", "BF", "MW",
           "MZ", "ZM", "ZW", "RW", "CD")

# ============================================================================
# 1. Targeted catalogue searches
# ============================================================================

cat("========================================\n")
cat("TARGETED CATALOGUE SEARCHES\n")
cat("========================================\n\n")

# --- HIV testing (ever tested / tested in last 12 months) ---
cat("--- HIV TESTING ---\n")
hiv_test <- ind |>
  filter(str_detect(tolower(Label), "tested") &
         str_detect(tolower(Label), "hiv")) |>
  select(IndicatorId, Label)
print(hiv_test, n = 20)

# --- HIV comprehensive knowledge ---
cat("\n--- HIV COMPREHENSIVE KNOWLEDGE ---\n")
hiv_know <- ind |>
  filter(str_detect(tolower(Label), "comprehensive") &
         str_detect(tolower(Label), "hiv|aids")) |>
  select(IndicatorId, Label)
print(hiv_know, n = 20)

# --- Median years of schooling / education ---
cat("\n--- MEDIAN YEARS EDUCATION ---\n")
med_edu <- ind |>
  filter(str_detect(tolower(Label), "median") &
         str_detect(tolower(Label), "school|education|year")) |>
  select(IndicatorId, Label)
print(med_edu, n = 20)

# --- Women's decision-making / empowerment ---
cat("\n--- WOMEN'S DECISION-MAKING ---\n")
# Search for WE_ prefix indicators
we_indicators <- ind |>
  filter(str_detect(IndicatorId, "^WE_")) |>
  select(IndicatorId, Label)
cat("All WE_ prefix indicators:", nrow(we_indicators), "\n")
print(we_indicators, n = 30)

# --- DV emotional violence ---
cat("\n--- DV EMOTIONAL VIOLENCE ---\n")
dv_emo <- ind |>
  filter(str_detect(tolower(Label), "emotional") &
         str_detect(tolower(Label), "violence")) |>
  select(IndicatorId, Label)
print(dv_emo, n = 10)

# --- DV attitudes (wife beating justified) ---
cat("\n--- DV ATTITUDES (beating justified) ---\n")
dv_att <- ind |>
  filter(str_detect(tolower(Label), "beating|justify|justified") &
         str_detect(tolower(Label), "wife|women|husband")) |>
  select(IndicatorId, Label)
print(dv_att, n = 20)

# --- Full vaccination alternatives ---
cat("\n--- FULL VACCINATION ALTERNATIVES ---\n")
vacc_full <- ind |>
  filter(str_detect(tolower(Label), "fully") &
         str_detect(tolower(Label), "vaccin|immuniz")) |>
  select(IndicatorId, Label)
print(vacc_full, n = 10)

# --- Women earning / employment for cash ---
cat("\n--- WOMEN EARNING/EMPLOYMENT ---\n")
earn <- ind |>
  filter(str_detect(IndicatorId, "^EM_") &
         str_detect(tolower(Label), "cash|earning")) |>
  select(IndicatorId, Label)
print(earn, n = 20)


# ============================================================================
# 2. Build candidate list and test against API
# ============================================================================
cat("\n\n========================================\n")
cat("API TESTING CANDIDATES\n")
cat("========================================\n\n")

# Based on catalogue search, build candidate codes to test
candidates <- tribble(
  ~friendly_name,           ~candidate_code,
  # HIV testing - try HA_HVET (ever tested) pattern
  "hiv_test_women",         "HA_HVET_W_TLF",
  "hiv_test_women_v2",      "HA_HVET_W_T12",
  "hiv_test_men",           "HA_HVET_M_TLF",
  "hiv_test_men_v2",        "HA_HVET_M_T12",

  # HIV knowledge - try HA_KNRJ pattern
  "hiv_knowledge_women",    "HA_KNRJ_W_CRK",
  "hiv_knowledge_men",      "HA_KNRJ_M_CRK",

  # Full vaccination - try other phase codes
  "full_vaccination_v2",    "CH_VACC_C_BAS",  # already works as basic_vaccination
  "full_vaccination_v3",    "CH_VAC1_C_BAS",
  "full_vaccination_v4",    "CH_VACS_C_APP",

  # Women earning - try married women variant
  "women_earning_v2",       "EM_ERNM_W_CSH",
  "women_earning_v3",       "EM_EMPL_W_CSH",

  # DV emotional
  "dv_emotional_v1",        "DV_EXEM_W_EVR",
  "dv_emotional_v2",        "DV_EXEV_W_12M",

  # DV attitudes
  "dv_attitude_women_v1",   "DV_AATW_W_AYS",
  "dv_attitude_women_v2",   "DV_ATBW_W_YES",
  "dv_attitude_men_v1",     "DV_AATW_M_AYS",
  "dv_attitude_men_v2",     "DV_ATBW_M_YES"
)

# First: catalogue check
candidates$in_catalogue <- candidates$candidate_code %in% ind$IndicatorId

cat("Catalogue check:\n")
for (i in seq_len(nrow(candidates))) {
  status <- if (candidates$in_catalogue[i]) "YES" else " NO"
  cat(sprintf("  [%s] %-25s %s\n", status,
              candidates$friendly_name[i], candidates$candidate_code[i]))
}

# Test all that are in catalogue
in_cat <- candidates |> filter(in_catalogue)
cat("\nTesting", nrow(in_cat), "candidates against API...\n\n")

for (i in seq_len(nrow(in_cat))) {
  code <- in_cat$candidate_code[i]
  fn   <- in_cat$friendly_name[i]
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
  nc <- if (n > 0) n_distinct(result$DHS_CountryCode) else 0
  cat(sprintf(" %d records, %d countries\n", n, nc))
  Sys.sleep(0.5)
}

# Also: for codes NOT in catalogue, try them anyway
# (the catalogue might be incomplete vs what the data endpoint accepts)
not_in_cat <- candidates |> filter(!in_catalogue)
cat("\nTrying", nrow(not_in_cat), "codes NOT in catalogue (API might still have them)...\n\n")

for (i in seq_len(nrow(not_in_cat))) {
  code <- not_in_cat$candidate_code[i]
  fn   <- not_in_cat$friendly_name[i]
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
  nc <- if (n > 0) n_distinct(result$DHS_CountryCode) else 0
  cat(sprintf(" %d records, %d countries\n", n, nc))
  Sys.sleep(0.5)
}

cat("\n========================================\n")
cat("DONE — review output above to pick final codes\n")
cat("========================================\n")
