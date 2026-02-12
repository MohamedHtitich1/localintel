# ============================================================================
# localintel: Complete Multi-Domain Workflow Example
# ============================================================================
# This script demonstrates the full pipeline for subnational regional
# analysis using the localintel package — combining indicators from
# economy, labour, health, education, and demography into a unified
# cross-domain dashboard covering 235+ European NUTS-2 regions.
# ============================================================================

library(localintel)
library(dplyr)
library(sf)

# ============================================================================
# PART 1: EXPLORE THE INDICATOR REGISTRY
# ============================================================================

# localintel ships with curated registries for 14 Eurostat domains
n <- indicator_count()
cat(n$indicators, "indicators across", n$domains, "domains\n")
print(n$by_domain)

# View codes for specific domains
print(economy_codes())
print(labour_codes())
print(education_codes())

# Or get the entire registry at once
all_codes <- all_regional_codes()
cat("Total codes in registry:", length(all_codes), "\n")

# ============================================================================
# PART 2: DATA FETCHING (Multiple Domains)
# ============================================================================

# 2.1 Fetch economy data
econ_n2 <- fetch_eurostat_batch(economy_codes(), level = 2, years = 2010:2024, robust = TRUE)
econ_n1 <- fetch_eurostat_batch(economy_codes(), level = 1, years = 2010:2024)
econ_n0 <- fetch_eurostat_batch(economy_codes(), level = 0, years = 2010:2024)

# 2.2 Fetch labour data
lab_n2 <- fetch_eurostat_batch(labour_codes(), level = 2, years = 2010:2024)
lab_n1 <- fetch_eurostat_batch(labour_codes(), level = 1, years = 2010:2024)
lab_n0 <- fetch_eurostat_batch(labour_codes(), level = 0, years = 2010:2024)

# 2.3 Fetch health data
hlth_n2 <- fetch_eurostat_batch(health_system_codes(), level = 2, years = 2010:2024)
hlth_n1 <- fetch_eurostat_batch(health_system_codes(), level = 1, years = 2010:2024)
hlth_n0 <- fetch_eurostat_batch(health_system_codes(), level = 0, years = 2010:2024)

# 2.4 Fetch education data
educ_n2 <- fetch_eurostat_batch(education_codes(), level = 2, years = 2010:2024)

# 2.5 Drop empty
econ_n2 <- drop_empty(econ_n2); econ_n1 <- drop_empty(econ_n1); econ_n0 <- drop_empty(econ_n0)
lab_n2  <- drop_empty(lab_n2);  lab_n1  <- drop_empty(lab_n1);  lab_n0  <- drop_empty(lab_n0)
hlth_n2 <- drop_empty(hlth_n2); hlth_n1 <- drop_empty(hlth_n1); hlth_n0 <- drop_empty(hlth_n0)
educ_n2 <- drop_empty(educ_n2)

# ============================================================================
# PART 3: DATA PROCESSING (Domain-Specific + Generic)
# ============================================================================

# 3.1 Economy
gdp_n2 <- process_gdp(econ_n2$gdp_nuts2)
gdp_n1 <- process_gdp(econ_n1$gdp_nuts2)
gdp_n0 <- process_gdp(econ_n0$gdp_nuts2)

# 3.2 Labour
unemp_n2 <- process_unemployment_rate(lab_n2$unemployment_rate)
unemp_n1 <- process_unemployment_rate(lab_n1$unemployment_rate)
unemp_n0 <- process_unemployment_rate(lab_n0$unemployment_rate)

# 3.3 Health
beds_n2 <- process_beds(hlth_n2$beds)
beds_n1 <- process_beds(hlth_n1$beds)
beds_n0 <- process_beds(hlth_n0$beds)

physicians_n2 <- process_physicians(hlth_n2$physicians)
physicians_n1 <- process_physicians(hlth_n1$physicians)
physicians_n0 <- process_physicians(hlth_n0$physicians)

# 3.4 Education — using the generic processor
tertiary_n2 <- process_education_attainment(educ_n2$attain_tertiary)

# 3.5 Merge at each level and combine
all_n2 <- merge_datasets(gdp_n2, unemp_n2, beds_n2, physicians_n2, tertiary_n2)
all_n1 <- merge_datasets(gdp_n1, unemp_n1, beds_n1, physicians_n1)
all_n0 <- merge_datasets(gdp_n0, unemp_n0, beds_n0, physicians_n0)

all_data <- bind_rows(all_n2, all_n1, all_n0)

# 3.6 Filter to EU27 + extras
all_data <- keep_eu27(all_data, extra = c("NO", "IS", "CH"))

# ============================================================================
# PART 4: REFERENCE DATA
# ============================================================================

nuts2_ref   <- get_nuts2_ref(year = 2024)
geopolys    <- get_nuts_geopolys(year = 2024, levels = c(0, 1, 2))
nuts2_names <- get_nuts2_names(year = 2024)
pop_data    <- get_population_nuts2(years = 2010:2024)

# ============================================================================
# PART 5: DATA CASCADING (Generic — works for any domain)
# ============================================================================

vars <- c("gdp", "unemployment_rate", "beds", "physicians", "education_attainment")

cascaded <- cascade_to_nuts2(
  all_data,
  vars = vars,
  years = 2010:2024,
  nuts2_ref = nuts2_ref
)

# This adds src_*_level columns for every variable:
# 2 = original NUTS2 data, 1 = cascaded from NUTS1, 0 = from NUTS0
cat("Source-level distribution for GDP:\n")
print(table(cascaded$src_gdp_level, useNA = "always"))

cat("Source-level distribution for unemployment:\n")
print(table(cascaded$src_unemployment_rate_level, useNA = "always"))

# ============================================================================
# PART 6: SCORING AND TRANSFORMATION
# ============================================================================

scored_data <- cascaded %>%
  keep_eu27() %>%
  transform_and_score(list(
    gdp_tr   = "safe_log10(gdp)",
    unemp_tr = "-unemployment_rate",   # lower is better
    beds_tr  = "beds",
    educ_tr  = "education_attainment"
  ))

# Compute cross-domain composite score
scored_data <- scored_data %>%
  compute_composite(
    score_cols = c("score_gdp_tr", "score_unemp_tr", "score_beds_tr", "score_educ_tr"),
    out_col = "regional_development_score"
  )

# ============================================================================
# PART 7: VISUALIZATION
# ============================================================================

# 7.1 Map unemployment rate
plot_best_by_country_level(
  keep_eu27(cascaded),
  keep_eu27(geopolys),
  var = "unemployment_rate",
  years = 2022:2024,
  title = "Unemployment Rate (%)"
)

# 7.2 Map GDP
plot_best_by_country_level(
  keep_eu27(cascaded),
  keep_eu27(geopolys),
  var = "gdp",
  years = 2022:2024,
  title = "GDP at current market prices (million EUR)"
)

# 7.3 Map hospital beds
plot_best_by_country_level(
  keep_eu27(cascaded),
  keep_eu27(geopolys),
  var = "beds",
  years = 2022:2024,
  title = "Hospital beds per 100,000 inhabitants"
)

# ============================================================================
# PART 8: MULTI-DOMAIN EXPORT FOR TABLEAU
# ============================================================================

# 8.1 Build combined SF with all variables, labels, and domain groupings
export_vars <- c("gdp", "unemployment_rate", "beds", "physicians", "education_attainment")

sf_all <- build_multi_var_sf(
  cascaded,
  geopolys,
  vars = export_vars,
  years = 2010:2024,
  var_labels = regional_var_labels(),
  pillar_mapping = regional_domain_mapping()
)

# 8.2 Enrich with population, names, and performance tags
sf_enriched <- enrich_for_tableau(
  sf_all,
  pop_data = pop_data,
  nuts2_names = nuts2_names
)

# 8.3 Export
export_to_geojson(sf_enriched, "output/multi_domain_2010_2024.geojson")
export_to_excel(cascaded, "output/cascaded_multi_domain_2010_2024.xlsx")

# ============================================================================
# PART 9: CROSS-DOMAIN CORRELATION ANALYSIS
# ============================================================================

cor_matrix <- cascaded %>%
  keep_eu27() %>%
  select(gdp, unemployment_rate, beds, physicians, education_attainment) %>%
  as.data.frame() %>%
  cor(use = "pairwise.complete.obs", method = "spearman")

cat("\nCross-domain Spearman correlations:\n")
print(round(cor_matrix, 2))

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n=== Multi-Domain Pipeline Complete ===\n")
cat("Total NUTS2 regions:", n_distinct(cascaded$geo), "\n")
cat("Years covered:", paste(range(cascaded$year), collapse = "-"), "\n")
cat("Variables cascaded:", paste(vars, collapse = ", "), "\n")
cat("Domains covered: Economy, Labour, Health, Education\n")
cat("\nExported files:\n")
cat("  - output/multi_domain_2010_2024.geojson\n")
cat("  - output/cascaded_multi_domain_2010_2024.xlsx\n")
