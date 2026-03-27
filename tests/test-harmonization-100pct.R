# ============================================================================
# Interactive Test: 100% Geometry Match Rate Verification
# ============================================================================
# Run in RStudio — block by block (Ctrl+Enter) or source the whole file.
# Requires: geodata, sf, dplyr packages + cached GADM data.
# ============================================================================

library(dplyr)
library(sf)

# Load package
devtools::load_all(".")

# ── Block A: Lookup Table Counts ─────────────────────────────────────────────
cat("\n=== A: Lookup Table Sizes ===\n")
cat("Manual crosswalk entries:", nrow(.manual_crosswalk()), "\n")
cat("Composite split entries: ", nrow(.composite_split()), "\n")
cat("Dissolve lookup entries: ", nrow(.dissolve_lookup()), "\n")
cat("Nongeo dissolve entries: ", nrow(.nongeo_dissolve()), "\n")

# ── Block B: Load Balanced Panel ─────────────────────────────────────────────
cat("\n=== B: Panel Summary ===\n")
bal <- readRDS("tests/gapfill-results/dhs_panel_admin1_balanced.rds")
panel_regions <- bal |>
  distinct(geo, admin0) |>
  mutate(region_name = sub("^[A-Z]{2}_", "", geo))

cat("Total DHS regions:", nrow(panel_regions), "\n")
cat("Countries:", n_distinct(panel_regions$admin0), "\n")

# ── Block C: Load GADM Geometry (from cache) ─────────────────────────────────
cat("\n=== C: GADM Geometry ===\n")
gadm_dir <- "tests/gapfill-results/gadm_cache"
rds_files <- list.files(gadm_dir, pattern = "^[A-Z]{3}_[12]\\.rds$", full.names = TRUE)
cat("Cached GADM files:", length(rds_files), "\n")

combined_geo <- bind_rows(lapply(rds_files, readRDS))
cat("Total GADM admin regions:", nrow(combined_geo), "\n")
cat("Countries with geometry:", n_distinct(combined_geo$admin0), "\n")

# Per-country counts
geo_counts <- combined_geo |> st_drop_geometry() |> count(admin0, name = "gadm_n")
panel_counts <- panel_regions |> count(admin0, name = "dhs_n")
comparison <- panel_counts |>
  left_join(geo_counts, by = "admin0") |>
  mutate(gadm_n = ifelse(is.na(gadm_n), 0L, gadm_n))
print(as.data.frame(comparison), row.names = FALSE)

# ── Block D: Run Harmonization ───────────────────────────────────────────────
cat("\n=== D: Harmonization Results ===\n")
geo_regions_df <- combined_geo |>
  st_drop_geometry() |>
  select(admin0, admin1_name)

harm <- .build_harmonization(panel_regions, geo_regions_df)
matched_unique <- harm |> distinct(admin0, dhs_region)

cat("\n*** MATCH RATE:", nrow(matched_unique), "/", nrow(panel_regions),
    "(", round(100 * nrow(matched_unique) / nrow(panel_regions), 1), "%) ***\n\n")

cat("By match type:\n")
print(table(harm$match_type))

# ── Block E: Unmatched Analysis ──────────────────────────────────────────────
cat("\n=== E: Unmatched Regions ===\n")
unmatched <- panel_regions |>
  anti_join(matched_unique, by = c("admin0", "region_name" = "dhs_region"))

cat("Unmatched:", nrow(unmatched), "\n")
if (nrow(unmatched) > 0) {
  cat("\nBy country:\n")
  print(as.data.frame(unmatched |> count(admin0, sort = TRUE)), row.names = FALSE)
  cat("\nDetailed:\n")
  for (ctry in unique(unmatched$admin0)) {
    um <- unmatched |> filter(admin0 == ctry) |> pull(region_name)
    gn <- geo_regions_df |> filter(admin0 == ctry) |> pull(admin1_name)
    cat("\n", ctry, ":\n  DHS:", paste(um, collapse = " | "),
        "\n  GADM:", paste(gn, collapse = " | "), "\n")
  }
} else {
  cat("\n*** ALL 652 REGIONS MATCHED — every datapoint appears on the map! ***\n")
}

# ── Block F: Per-Country Match Rate ──────────────────────────────────────────
cat("\n=== F: Per-Country Match Rates ===\n")
country_match <- panel_regions |>
  left_join(
    matched_unique |> mutate(matched = TRUE),
    by = c("admin0", "region_name" = "dhs_region")
  ) |>
  mutate(matched = ifelse(is.na(matched), FALSE, TRUE)) |>
  group_by(admin0) |>
  summarise(
    total = n(),
    matched = sum(matched),
    pct = round(100 * matched / total, 1),
    .groups = "drop"
  ) |>
  arrange(pct)

print(as.data.frame(country_match), row.names = FALSE)

# ── Block G: Quick Map Test (single country) ─────────────────────────────────
cat("\n=== G: Quick Map Test (Kenya) ===\n")
cat("Fetching KE geometry from GADM...\n")
ke_geo <- get_admin1_geo(country_ids = "KE")
cat("KE geometry:", nrow(ke_geo), "regions\n")

ke_panel <- panel_regions |> filter(admin0 == "KE")
ke_harm <- harm |> filter(admin0 == "KE")
cat("KE panel regions:", nrow(ke_panel), "\n")
cat("KE matched:", nrow(ke_harm |> distinct(dhs_region)), "\n")
cat("KE match types:", paste(names(table(ke_harm$match_type)),
                              table(ke_harm$match_type), sep = "=", collapse = ", "), "\n")

cat("\n=== ALL TESTS COMPLETE ===\n")
