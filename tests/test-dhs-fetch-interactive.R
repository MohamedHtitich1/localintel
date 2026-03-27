# ============================================================================
# Interactive Test Script for DHS Fetching Layer (Phase 1, Week 1)
# Run this in RStudio after: devtools::load_all()
# ============================================================================

# --- Setup ---
# install.packages(c("httr2", "jsonlite"))  # if not already installed
devtools::load_all()

# ============================================================================
# 1. INDICATOR REGISTRIES
# ============================================================================
cat("\n=== 1. Indicator Registries ===\n")

cat("Health codes:", length(dhs_health_codes()), "\n")
cat("Mortality codes:", length(dhs_mortality_codes()), "\n")
cat("Nutrition codes:", length(dhs_nutrition_codes()), "\n")
cat("HIV codes:", length(dhs_hiv_codes()), "\n")
cat("Education codes:", length(dhs_education_codes()), "\n")
cat("WASH codes:", length(dhs_wash_codes()), "\n")
cat("Wealth codes:", length(dhs_wealth_codes()), "\n")
cat("Gender codes:", length(dhs_gender_codes()), "\n")

n <- dhs_indicator_count()
cat("\nTotal:", n$indicators, "indicators across", n$domains, "domains\n")
print(n$by_domain)

# ============================================================================
# 2. COUNTRIES ENDPOINT
# ============================================================================
cat("\n=== 2. SSA Countries ===\n")

ssa <- get_dhs_countries("Sub-Saharan Africa")
cat("SSA countries found:", nrow(ssa), "\n")
print(ssa[1:10, c("DHS_CountryCode", "CountryName")])

# ============================================================================
# 3. SURVEYS ENDPOINT
# ============================================================================
cat("\n=== 3. Kenya Surveys ===\n")

ke_surveys <- get_dhs_surveys(country_ids = "KE")
cat("Kenya surveys:", nrow(ke_surveys), "\n")
print(ke_surveys[, c("SurveyId", "SurveyYear", "SurveyType")])

# ============================================================================
# 4. SINGLE INDICATOR FETCH
# ============================================================================
cat("\n=== 4. Single Fetch: Kenya Under-5 Mortality (subnational) ===\n")

ke_u5m <- get_dhs_data(
  country_ids   = "KE",
  indicator_ids = "CM_ECMR_C_U5M",
  breakdown     = "subnational"
)
cat("Records:", nrow(ke_u5m), "\n")
cat("Columns:", paste(names(ke_u5m), collapse = ", "), "\n")
cat("Survey years:", paste(sort(unique(ke_u5m$SurveyYear)), collapse = ", "), "\n")
cat("Regions (latest):",
    length(unique(ke_u5m$CharacteristicLabel[ke_u5m$SurveyYear == max(ke_u5m$SurveyYear)])),
    "\n")

# Quick look at the data
print(head(ke_u5m[, c("CountryName", "SurveyYear", "CharacteristicLabel", "Value", "CILow", "CIHigh")], 10))

# ============================================================================
# 5. MULTI-COUNTRY, MULTI-INDICATOR FETCH
# ============================================================================
cat("\n=== 5. Multi-Country Fetch: KE + NG, Mortality + Stunting ===\n")

multi <- get_dhs_data(
  country_ids   = c("KE", "NG"),
  indicator_ids = c("CM_ECMR_C_U5M", "CN_NUTS_C_HA2"),
  breakdown     = "subnational"
)
cat("Total records:", nrow(multi), "\n")
cat("By country:\n")
print(table(multi$DHS_CountryCode))
cat("By indicator:\n")
print(table(multi$IndicatorId))

# ============================================================================
# 6. BATCH FETCH
# ============================================================================
cat("\n=== 6. Batch Fetch: 3 Indicators for Kenya ===\n")

codes <- c(
  u5_mortality = "CM_ECMR_C_U5M",
  stunting     = "CN_NUTS_C_HA2",
  basic_vacc   = "CH_VACC_C_BAS"
)

batch <- fetch_dhs_batch(codes, country_ids = "KE")
cat("Indicators fetched:", length(batch), "\n")
for (nm in names(batch)) {
  cat("  ", nm, ":", nrow(batch[[nm]]), "records\n")
}

# ============================================================================
# 7. YEAR FILTERING
# ============================================================================
cat("\n=== 7. Year Filtering: Kenya U5M, 2010+ only ===\n")

ke_recent <- get_dhs_data(
  country_ids   = "KE",
  indicator_ids = "CM_ECMR_C_U5M",
  years         = 2010:2025,
  breakdown     = "subnational"
)
cat("Records (2010+):", nrow(ke_recent), "\n")
cat("Survey years:", paste(sort(unique(ke_recent$SurveyYear)), collapse = ", "), "\n")

# ============================================================================
# 8. NATIONAL-LEVEL FETCH
# ============================================================================
cat("\n=== 8. National-Level: Tier 1 Countries, U5 Mortality ===\n")

tier1 <- c("KE", "NG", "ET", "TZ", "UG", "GH", "SN", "ML", "BF", "MW",
           "MZ", "ZM", "ZW", "RW", "CD")

national <- get_dhs_data(
  country_ids   = tier1,
  indicator_ids = "CM_ECMR_C_U5M",
  breakdown     = "national"
)
cat("National records:", nrow(national), "\n")
cat("Countries with data:", length(unique(national$DHS_CountryCode)), "/", length(tier1), "\n")

cat("\n=== All tests complete! ===\n")
