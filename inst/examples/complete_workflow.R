# ============================================================================
# localintel: Complete Workflow Example
# ============================================================================
# This script demonstrates the full pipeline for subnational health data
# analysis using the localintel package.
# ============================================================================

library(localintel)
library(dplyr)
library(sf)

# ============================================================================
# PART 1: DATA FETCHING
# ============================================================================

# 1.1 Get predefined dataset codes
codes_health <- health_system_codes()
codes_cod <- causes_of_death_codes()

print(codes_health)
# disch_inp  disch_day   hos_days        los       beds physicians 
# "hlth_co_disch2t" "hlth_co_disch4t" "hlth_co_hosdayt" "hlth_co_inpstt" "hlth_rs_bdsrg2" "hlth_rs_physreg"

# 1.2 Fetch data at NUTS2 level
data_nuts2 <- fetch_eurostat_batch(
  codes_health, 
  level = 2, 
  years = 2010:2024,
  robust = TRUE
)

# 1.3 Fetch data at NUTS1 and NUTS0 for cascading
data_nuts1 <- fetch_eurostat_batch(codes_health, level = 1, years = 2010:2024)
data_nuts0 <- fetch_eurostat_batch(codes_health, level = 0, years = 2010:2024)

# 1.4 Drop empty results
data_nuts2 <- drop_empty(data_nuts2)
data_nuts1 <- drop_empty(data_nuts1)
data_nuts0 <- drop_empty(data_nuts0)

# ============================================================================
# PART 2: DATA PROCESSING
# ============================================================================

# 2.1 Process NUTS2 data
beds_n2 <- process_beds(data_nuts2$beds)
physicians_n2 <- process_physicians(data_nuts2$physicians)
los_n2 <- process_los(data_nuts2$los)
disch_inp_n2 <- process_disch_inp(data_nuts2$disch_inp)
disch_day_n2 <- process_disch_day(data_nuts2$disch_day)

# 2.2 Process NUTS1 data
beds_n1 <- process_beds(data_nuts1$beds)
physicians_n1 <- process_physicians(data_nuts1$physicians)
los_n1 <- process_los(data_nuts1$los)
disch_inp_n1 <- process_disch_inp(data_nuts1$disch_inp)
disch_day_n1 <- process_disch_day(data_nuts1$disch_day)

# 2.3 Process NUTS0 data
beds_n0 <- process_beds(data_nuts0$beds)
physicians_n0 <- process_physicians(data_nuts0$physicians)
los_n0 <- process_los(data_nuts0$los)
disch_inp_n0 <- process_disch_inp(data_nuts0$disch_inp)
disch_day_n0 <- process_disch_day(data_nuts0$disch_day)

# 2.4 Merge datasets at each level
all_n2 <- merge_datasets(beds_n2, physicians_n2, los_n2, disch_inp_n2, disch_day_n2)
all_n1 <- merge_datasets(beds_n1, physicians_n1, los_n1, disch_inp_n1, disch_day_n1)
all_n0 <- merge_datasets(beds_n0, physicians_n0, los_n0, disch_inp_n0, disch_day_n0)

# 2.5 Combine all levels
all_data <- bind_rows(all_n2, all_n1, all_n0)

# 2.6 Balance panel and fill gaps
vars <- c("beds", "physicians", "los", "disch_inp", "disch_day")
all_data <- balance_panel(all_data, vars = vars, years = 2010:2024)

# 2.7 Filter to EU27 + extras
all_data <- keep_eu27(all_data, extra = c("NO", "IS", "CH"))

# ============================================================================
# PART 3: REFERENCE DATA
# ============================================================================

# 3.1 Get NUTS2 reference table (for cascading)
nuts2_ref <- get_nuts2_ref(year = 2024)

# 3.2 Get geometries for mapping
geopolys <- get_nuts_geopolys(year = 2024, levels = c(0, 1, 2))

# 3.3 Get NUTS2 names for labeling
nuts2_names <- get_nuts2_names(year = 2024)

# 3.4 Get population data for weighting
pop_data <- get_population_nuts2(years = 2010:2024)

# ============================================================================
# PART 4: DATA CASCADING
# ============================================================================

# 4.1 Cascade with indicator computation
cascaded <- cascade_to_nuts2_and_compute(
  all_data,
  vars = c("disch_inp", "disch_day", "beds", "physicians", "los"),
  years = 2010:2024,
  nuts2_ref = nuts2_ref
)

# This adds:
# - src_*_level columns showing data source (2=NUTS2, 1=NUTS1, 0=NUTS0)
# - da: Discharge Activity indicator
# - rlos: Relative Length of Stay
# - physicians_log2: Log-transformed physicians

print(names(cascaded))

# ============================================================================
# PART 5: SCORING AND TRANSFORMATION
# ============================================================================

# 5.1 Apply transformations for scoring (higher = better)
scored_data <- cascaded %>%
  keep_eu27() %>%
  mutate(
    los_tr = -los,  # Negative because lower LOS is better
    da_tr = case_when(
      da > 2.16 ~ 2.2,  # Cap outliers
      TRUE ~ da
    )
  ) %>%
  mutate(across(ends_with("_tr"), scale_0_100, .names = "score_{.col}")) %>%
  mutate(score_E_E = (score_los_tr + score_da_tr) / 2)

# 5.2 Alternative using transform_and_score helper
# scored_data <- transform_and_score(cascaded, list(
#   los_tr = "-los",
#   da_tr = "pmin(da, 2.2)"
# ))

# ============================================================================
# PART 6: CASCADING SCORES (Light Version)
# ============================================================================

# For pre-computed scores, use the light cascade function
score_vars <- c("score_E_E", "score_los_tr", "score_da_tr")

scored_cascaded <- cascade_to_nuts2_light(
  scored_data,
  vars = score_vars,
  nuts2_ref = nuts2_ref,
  years = 2010:2024
)

# ============================================================================
# PART 7: VISUALIZATION
# ============================================================================

# 7.1 Build display SF for a single variable
sf_beds <- build_display_sf(
  cascaded,
  geopolys,
  var = "beds",
  years = 2010:2024,
  scale = "global"
)

# 7.2 Plot maps (prints one map per year)
plot_best_by_country_level(
  keep_eu27(cascaded),
  keep_eu27(geopolys),
  var = "beds",
  years = 2020:2024,
  title = "Hospital Beds per 100,000 inhabitants"
)

# 7.3 Save maps to PDF
save_maps_to_pdf(
  plot_best_by_country_level,
  filepath = "output/beds_maps_2020_2024.pdf",
  out_nuts2 = keep_eu27(cascaded),
  geopolys = keep_eu27(geopolys),
  var = "beds",
  years = 2020:2024,
  title = "Hospital Beds per 100,000"
)

# ============================================================================
# PART 8: MULTI-VARIABLE EXPORT FOR TABLEAU
# ============================================================================

# 8.1 Define variables to export
export_vars <- c("beds", "physicians", "score_E_E")

# 8.2 Build combined SF with all variables
sf_all <- build_multi_var_sf(
  scored_cascaded,
  geopolys,
  vars = export_vars,
  years = 2010:2024,
  var_labels = health_var_labels(),
  pillar_mapping = health_pillar_mapping()
)

# 8.3 Enrich with metadata for Tableau
sf_enriched <- enrich_for_tableau(
  sf_all,
  pop_data = pop_data,
  nuts2_names = nuts2_names
)

# 8.4 Export to GeoJSON
export_to_geojson(sf_enriched, "output/health_indicators_2010_2024.geojson")

# 8.5 Also export to Excel (without geometry)
export_to_excel(sf_enriched, "output/health_indicators_2010_2024.xlsx")

# ============================================================================
# PART 9: CORRELATION ANALYSIS
# ============================================================================

# 9.1 Check correlations between indicators
cor_matrix <- scored_data %>%
  select(los, da, beds, physicians) %>%
  as.data.frame() %>%
  cor(use = "pairwise.complete.obs", method = "spearman")

print(cor_matrix)

# ============================================================================
# PART 10: LIFE COURSE ANALYSIS (with Age groups)
# ============================================================================

# For data with additional grouping variables like Age
# Use lc_build_display_sf which preserves these columns

# life_course_sf <- lc_build_display_sf(
#   life_course_data,
#   geopolys,
#   var = "mortality_rate",
#   years = 2013:2024,
#   keep = "Age"  # Preserve Age column
# )

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n=== Pipeline Complete ===\n")
cat("Total NUTS2 regions:", n_distinct(cascaded$geo), "\n
")
cat("Years covered:", paste(range(cascaded$year), collapse = "-"), "\n")
cat("Variables cascaded:", paste(names(cascaded)[3:7], collapse = ", "), "\n")
cat("Computed indicators: da, rlos, physicians_log2\n")
cat("\nExported files:\n")
cat("  - output/health_indicators_2010_2024.geojson\n")
cat("  - output/health_indicators_2010_2024.xlsx\n")
cat("  - output/beds_maps_2020_2024.pdf\n")
