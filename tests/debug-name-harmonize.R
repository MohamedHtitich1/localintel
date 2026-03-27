# =============================================================================
# Diagnose DHS region name ↔ Natural Earth admin1 name mismatches
# =============================================================================
library(dplyr)
devtools::load_all(".")

# Load panel
bal <- readRDS("tests/gapfill-results/dhs_panel_admin1_balanced.rds")

# Get all unique regions from panel
panel_regions <- bal |>
  distinct(geo, admin0) |>
  mutate(region_name = sub("^[A-Z]{2}_", "", geo))

cat("Panel regions:", nrow(panel_regions), "\n")
cat("Countries:", n_distinct(panel_regions$admin0), "\n\n")

# Get all Natural Earth admin1 geometries for these countries
countries <- unique(panel_regions$admin0)
ne_geo <- get_admin1_geo(countries)

cat("Natural Earth regions:", nrow(ne_geo), "\n")
cat("NE countries:", paste(sort(unique(ne_geo$admin0)), collapse = ", "), "\n\n")

# --- Country-level coverage ---
cat("=== Country-level coverage ===\n")
panel_countries <- sort(unique(panel_regions$admin0))
ne_countries <- sort(unique(ne_geo$admin0))
missing_countries <- setdiff(panel_countries, ne_countries)
cat("Panel countries:", length(panel_countries), "\n")
cat("NE countries:", length(ne_countries), "\n")
cat("Missing from NE:", length(missing_countries), "\n")
if (length(missing_countries) > 0) {
  cat("  Codes:", paste(missing_countries, collapse = ", "), "\n")
}
cat("\n")

# --- Region-level matching ---
ne_lookup <- ne_geo |>
  sf::st_drop_geometry() |>
  select(admin0, admin1_name)

# Exact match
matched <- panel_regions |>
  inner_join(ne_lookup, by = c("admin0", "region_name" = "admin1_name"))

cat("=== Region matching (exact) ===\n")
cat("Matched:", nrow(matched), "of", nrow(panel_regions),
    "(", round(100 * nrow(matched) / nrow(panel_regions), 1), "%)\n")
cat("Unmatched:", nrow(panel_regions) - nrow(matched), "\n\n")

# --- Show mismatches per country ---
unmatched <- panel_regions |>
  anti_join(ne_lookup, by = c("admin0", "region_name" = "admin1_name"))

cat("=== Unmatched regions by country ===\n")
for (ctry in sort(unique(unmatched$admin0))) {
  dhs_names <- sort(unmatched$region_name[unmatched$admin0 == ctry])
  ne_names <- sort(ne_lookup$admin1_name[ne_lookup$admin0 == ctry])

  cat("\n--- ", ctry, " (", length(dhs_names), " unmatched of ",
      sum(panel_regions$admin0 == ctry), " DHS regions, ",
      length(ne_names), " NE regions) ---\n", sep = "")

  # Show side by side for easy comparison
  cat("  DHS unmatched:\n")
  for (n in dhs_names) cat("    ", n, "\n")
  cat("  NE available:\n")
  for (n in ne_names) cat("    ", n, "\n")
}

# --- Case-insensitive matching ---
cat("\n\n=== Case-insensitive matching ===\n")
panel_regions_ci <- panel_regions |>
  mutate(region_lower = tolower(region_name))
ne_lookup_ci <- ne_lookup |>
  mutate(region_lower = tolower(admin1_name))

matched_ci <- panel_regions_ci |>
  inner_join(ne_lookup_ci, by = c("admin0", "region_lower"))

cat("Case-insensitive matched:", nrow(matched_ci), "of", nrow(panel_regions),
    "(", round(100 * nrow(matched_ci) / nrow(panel_regions), 1), "%)\n")

# --- Fuzzy matching (agrep) for remaining ---
still_unmatched <- panel_regions_ci |>
  anti_join(ne_lookup_ci, by = c("admin0", "region_lower"))

cat("\n=== Fuzzy match candidates (remaining", nrow(still_unmatched), "regions) ===\n")
fuzzy_matches <- list()
for (i in seq_len(nrow(still_unmatched))) {
  ctry <- still_unmatched$admin0[i]
  dhs_name <- still_unmatched$region_name[i]
  ne_names_ctry <- ne_lookup$admin1_name[ne_lookup$admin0 == ctry]

  # Try agrep with increasing distance
  hits <- agrep(tolower(dhs_name), tolower(ne_names_ctry),
                max.distance = 0.3, value = TRUE)

  if (length(hits) > 0) {
    # Find original case
    orig_hits <- ne_names_ctry[tolower(ne_names_ctry) %in% hits]
    cat("  ", ctry, ": '", dhs_name, "' → '", paste(orig_hits, collapse = "', '"), "'\n", sep = "")
    fuzzy_matches[[paste0(ctry, "_", dhs_name)]] <- list(
      admin0 = ctry, dhs = dhs_name, ne = orig_hits[1]
    )
  } else {
    cat("  ", ctry, ": '", dhs_name, "' → NO MATCH\n", sep = "")
  }
}

cat("\nFuzzy matched:", length(fuzzy_matches), "\n")
cat("Total potential coverage:", nrow(matched) + nrow(matched_ci) - nrow(matched) + length(fuzzy_matches),
    "of", nrow(panel_regions), "\n")
