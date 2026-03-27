# ============================================================================
# Find Correct DHS Indicator Codes
# The DHS API has an /indicators endpoint that lists all available indicators.
# We'll search it for the concepts we need but had wrong codes for.
# ============================================================================

devtools::load_all()
library(dplyr)
library(stringr)

# Query the DHS indicators endpoint
cat("Fetching full DHS indicator list...\n")

req <- httr2::request("https://api.dhsprogram.com/rest/dhs") |>
  httr2::req_url_path_append("indicators") |>
  httr2::req_url_query(
    apiKey       = "MOHHTI-239797",
    returnFields = "IndicatorId,Label,Level1,Level2,ShortName,Definition",
    f            = "json",
    perPage      = 5000
  ) |>
  httr2::req_retry(max_tries = 3, backoff = ~ 2) |>
  httr2::req_timeout(120)

resp <- httr2::req_perform(req)
body <- httr2::resp_body_string(resp)
parsed <- jsonlite::fromJSON(body, flatten = TRUE)
indicators <- tibble::as_tibble(parsed$Data)

cat("Total indicators in DHS API:", nrow(indicators), "\n\n")

# Save full indicator list for reference
saveRDS(indicators, "tests/dhs-profile-results/dhs_all_indicators.rds")

# ============================================================================
# Search for each missing concept
# ============================================================================

search_terms <- list(
  # Health
  full_vaccination     = c("full", "vaccin", "immuniz"),
  skilled_birth        = c("skilled", "birth", "delivery", "attendan"),
  postnatal_mother     = c("postnatal", "mother", "PNC"),
  postnatal_newborn    = c("postnatal", "newborn", "PNC"),

  # Nutrition
  anemia_women         = c("anemia", "anaemia", "women"),
  exclusive_bf         = c("exclusive", "breastfeed"),
  early_bf             = c("early", "breastfeed", "1 hour", "one hour"),
  low_bmi_women        = c("BMI", "thin", "underweight", "women"),
  obesity_women        = c("obes", "overweight", "BMI", "women"),

  # HIV
  hiv_test_women       = c("HIV", "test", "women"),
  hiv_test_men         = c("HIV", "test", "men"),
  hiv_knowledge_women  = c("HIV", "knowledge", "comprehensive", "women"),
  hiv_knowledge_men    = c("HIV", "knowledge", "comprehensive", "men"),
  hiv_condom_women     = c("HIV", "condom", "women"),
  hiv_condom_men       = c("HIV", "condom", "men"),

  # Education
  net_attendance       = c("net", "attendance", "primary", "school"),
  median_years_women   = c("median", "years", "school", "education", "women"),
  median_years_men     = c("median", "years", "school", "education", "men"),

  # WASH
  improved_sanitation  = c("improved", "sanitation", "toilet"),
  surface_water        = c("surface", "water"),
  open_defecation      = c("open", "defecation"),

  # Wealth
  bank_account         = c("bank", "account", "financial"),

  # Gender
  women_decision_all   = c("decision", "women", "particip"),
  women_decision_health= c("decision", "health", "women"),
  women_earning        = c("earn", "cash", "women", "employment"),
  dv_physical          = c("violence", "physical", "women"),
  dv_sexual            = c("violence", "sexual", "women"),
  dv_emotional         = c("violence", "emotional", "women"),
  dv_attitude_women    = c("attitude", "violence", "beating", "women", "justify"),
  dv_attitude_men      = c("attitude", "violence", "beating", "men", "justify")
)

cat("========================================\n")
cat("SEARCHING FOR CORRECT INDICATOR CODES\n")
cat("========================================\n\n")

for (concept in names(search_terms)) {
  terms <- search_terms[[concept]]

  # Search across Label, ShortName, Definition
  matches <- indicators |>
    filter(
      rowSums(sapply(terms, function(t) {
        str_detect(tolower(Label), tolower(t)) |
        str_detect(tolower(ShortName), tolower(t)) |
        str_detect(tolower(Definition), tolower(t))
      })) >= 2  # at least 2 of the search terms must match
    )

  cat(sprintf("--- %s (searched: %s) ---\n", concept, paste(terms, collapse = ", ")))
  if (nrow(matches) > 0) {
    # Show top matches
    for (i in seq_len(min(nrow(matches), 8))) {
      cat(sprintf("  %-22s  %s\n", matches$IndicatorId[i], matches$Label[i]))
    }
    if (nrow(matches) > 8) cat(sprintf("  ... and %d more\n", nrow(matches) - 8))
  } else {
    cat("  NO MATCHES\n")
  }
  cat("\n")
}

# ============================================================================
# Also: check the Level1/Level2 categories to see what domains exist
# ============================================================================
cat("\n========================================\n")
cat("DHS INDICATOR DOMAINS (Level1 / Level2)\n")
cat("========================================\n")

domain_summary <- indicators |>
  count(Level1, Level2, name = "n_indicators") |>
  arrange(Level1, Level2)

print(domain_summary, n = 60)

cat("\n\nFull indicator list saved to: tests/dhs-profile-results/dhs_all_indicators.rds\n")
cat("You can explore with: ind <- readRDS('tests/dhs-profile-results/dhs_all_indicators.rds')\n")
