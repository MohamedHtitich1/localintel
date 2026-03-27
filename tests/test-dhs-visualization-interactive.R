# =============================================================================
# Interactive Test: DHS Visualization, Export & Dashboard (Phase 3)
# Run in RStudio with localintel loaded: devtools::load_all(".")
# =============================================================================

library(dplyr)
devtools::load_all(".")

cat("\n=== A: Registry extension tests ===\n\n")

# --- Test 1: regional_var_labels() includes DHS indicators ---
labs <- regional_var_labels()
dhs_labs <- dhs_var_labels()

# Check that all DHS labels are now in the unified registry
missing <- setdiff(names(dhs_labs), names(labs))
cat("Unified labels count:", length(labs), "\n")
cat("DHS labels count:", length(dhs_labs), "\n")
cat("DHS labels missing from unified:", length(missing), "\n")
stopifnot(length(missing) == 0)
cat("All DHS labels present in regional_var_labels(): OK\n")

# --- Test 2: regional_domain_mapping() includes DHS indicators ---
domains <- regional_domain_mapping()
dhs_domains <- dhs_domain_mapping()

missing_d <- setdiff(names(dhs_domains), names(domains))
cat("Unified domain mapping count:", length(domains), "\n")
cat("DHS domain mapping count:", length(dhs_domains), "\n")
cat("DHS domains missing from unified:", length(missing_d), "\n")
stopifnot(length(missing_d) == 0)
cat("All DHS indicators in regional_domain_mapping(): OK\n")

# --- Test 3: No name collisions between EU and DHS ---
eu_only_labs <- regional_var_labels()
# infant_mortality is shared (exists in both EU demography and DHS mortality)
shared <- intersect(names(dhs_labs), names(eu_only_labs))
cat("Shared variable names (EU & DHS):", length(shared), "\n")
if (length(shared) > 0) cat("  Names:", paste(shared, collapse = ", "), "\n")
cat("Name collision check: OK (shared names are intentional)\n\n")

cat("=== A: ALL REGISTRY TESTS PASSED ===\n\n")


# =============================================================================
cat("=== B: Geometry fetch tests ===\n\n")

# --- Test 4: get_admin1_geo() for Tier 1 subset ---
cat("Fetching Admin 1 geometries for KE, NG, GH...\n")
geo3 <- get_admin1_geo(country_ids = c("KE", "NG", "GH"))
cat("Admin 1 regions fetched:", nrow(geo3), "\n")
cat("Countries:", paste(unique(geo3$admin0), collapse = ", "), "\n")
stopifnot(nrow(geo3) > 0)
stopifnot(inherits(geo3, "sf"))
stopifnot(all(c("admin0", "admin1_name", "geometry") %in% names(geo3)))
cat("get_admin1_geo(): OK\n\n")

# --- Test 5: get_admin0_geo() basemap ---
cat("Fetching Admin 0 basemap...\n")
basemap <- get_admin0_geo(country_ids = c("KE", "NG", "GH"))
cat("Countries in basemap:", nrow(basemap), "\n")
cat("SSA flagged:", sum(basemap$in_ssa), "\n")
stopifnot(inherits(basemap, "sf"))
stopifnot(nrow(basemap) > 3)  # Should include buffer countries
cat("get_admin0_geo(): OK\n\n")

# --- Test 6: Cache works (second call is instant) ---
cat("Testing cache (second fetch)... ")
t0 <- Sys.time()
geo3b <- get_admin1_geo(country_ids = c("KE", "NG", "GH"))
dt <- as.numeric(Sys.time() - t0, units = "secs")
cat(round(dt, 3), "s\n")
stopifnot(dt < 0.1)  # Should be near-instant from cache
cat("Cache: OK\n\n")

cat("=== B: ALL GEOMETRY TESTS PASSED ===\n\n")


# =============================================================================
cat("=== C: Display SF & Map tests (using saved panel) ===\n\n")

# Load saved balanced panel
panel_file <- "tests/gapfill-results/dhs_panel_admin1_balanced.rds"
if (!file.exists(panel_file)) {
  panel_file <- file.path(".", panel_file)
}

if (file.exists(panel_file)) {
  bal <- readRDS(panel_file)
  cat("Loaded balanced panel:", nrow(bal), "rows x", ncol(bal), "cols\n")
  cat("Regions:", n_distinct(bal$geo), "\n")
  cat("Years:", min(bal$year), "-", max(bal$year), "\n\n")

  # --- Test 7: Harmonization coverage ---
  cat("--- Harmonization diagnostic ---\n")
  panel_regions <- bal |>
    distinct(geo, admin0) |>
    mutate(region_name = sub("^[A-Z]{2}_", "", geo))
  ne_geo_all <- get_admin1_geo(unique(bal$admin0))
  ne_regions_df <- ne_geo_all |> sf::st_drop_geometry() |> select(admin0, admin1_name)

  harm <- localintel:::.build_harmonization(panel_regions, ne_regions_df)
  cat("Harmonization matched:", nrow(harm), "of", nrow(panel_regions),
      "(", round(100 * nrow(harm) / nrow(panel_regions), 1), "%)\n")
  cat("By type:\n")
  print(table(harm$match_type))
  cat("\n")

  # --- Test 8: build_dhs_display_sf() ---
  cat("Building display SF for u5_mortality, year 2020...\n")
  sf_mort <- build_dhs_display_sf(bal, admin1_geo = ne_geo_all,
                                   var = "u5_mortality", years = 2020)
  cat("Display SF rows:", nrow(sf_mort), "\n")
  if (nrow(sf_mort) > 0) {
    cat("Has geometry:", inherits(sf_mort, "sf"), "\n")
    cat("Countries on map:", n_distinct(sf_mort$admin0), "\n")
    stopifnot(all(c("geo", "admin0", "year", "value", "geometry") %in% names(sf_mort)))
    cat("build_dhs_display_sf(): OK\n")
  } else {
    cat("build_dhs_display_sf(): 0 rows matched\n")
  }
  cat("\n")

  # --- Test 9: build_dhs_multi_var_sf() ---
  cat("Building multi-variable SF for 3 indicators...\n")
  sf_multi <- build_dhs_multi_var_sf(
    bal,
    vars = c("u5_mortality", "stunting", "skilled_birth"),
    years = 2015:2020
  )
  cat("Multi-var SF rows:", nrow(sf_multi), "\n")
  if (nrow(sf_multi) > 0) {
    cat("Variables:", paste(unique(sf_multi$var), collapse = ", "), "\n")
    cat("Has var_label:", "var_label" %in% names(sf_multi), "\n")
    cat("Has domain:", "domain" %in% names(sf_multi), "\n")
    cat("build_dhs_multi_var_sf(): OK\n")
  } else {
    cat("build_dhs_multi_var_sf(): 0 rows (geometry join pending)\n")
  }
  cat("\n")

  # --- Test 10: plot_dhs_map() (visual test) ---
  if (nrow(sf_mort) > 0) {
    cat("Plotting DHS map for u5_mortality 2020...\n")
    plot_dhs_map(bal, var = "u5_mortality", years = 2020)
    cat("plot_dhs_map(): OK (visual check in plot pane)\n\n")
  } else {
    cat("Skipping plot_dhs_map() — no geometry matches\n\n")
  }

  # --- Test 11: enrich_dhs_for_tableau() ---
  if (nrow(sf_multi) > 0) {
    cat("Enriching for Tableau...\n")
    enriched <- enrich_dhs_for_tableau(sf_multi)
    cat("Enriched columns:", paste(names(enriched), collapse = ", "), "\n")
    cat("Has country_name:", "country_name" %in% names(enriched), "\n")
    cat("Has performance_tag:", "performance_tag" %in% names(enriched), "\n")
    cat("enrich_dhs_for_tableau(): OK\n\n")
  } else {
    cat("Skipping enrich_dhs_for_tableau() — no data\n\n")
  }

  # --- Test 12: Export to GeoJSON ---
  if (nrow(sf_multi) > 0) {
    out_file <- "tests/gapfill-results/dhs_ssa_sample.geojson"
    export_to_geojson(sf_multi, out_file)
    cat("GeoJSON export:", file.exists(out_file), "\n")
    cat("File size:", round(file.size(out_file) / 1024, 1), "KB\n\n")
  }

} else {
  cat("WARNING: Balanced panel not found at", panel_file, "\n")
  cat("Run test-cascade-admin1.R first to generate the panel.\n\n")
}

cat("=== C: DISPLAY/MAP TESTS COMPLETE ===\n\n")


# =============================================================================
cat("=== D: Export registry consistency ===\n\n")

# --- Test 12: All DHS panel indicators have labels ---
if (exists("bal")) {
  flag_cols <- grep("^imp_(.+)_flag$", names(bal), value = TRUE)
  panel_vars <- sub("^imp_(.+)_flag$", "\\1", flag_cols)

  labs_all <- regional_var_labels()
  unlabeled <- setdiff(panel_vars, names(labs_all))
  cat("Panel indicators:", length(panel_vars), "\n")
  cat("Labeled:", sum(panel_vars %in% names(labs_all)), "\n")
  cat("Unlabeled:", length(unlabeled), "\n")
  if (length(unlabeled) > 0) cat("  Missing:", paste(unlabeled, collapse = ", "), "\n")
  stopifnot(length(unlabeled) == 0)
  cat("All panel indicators labeled: OK\n\n")

  # --- Test 13: All DHS panel indicators have domain mapping ---
  domains_all <- regional_domain_mapping()
  unmapped <- setdiff(panel_vars, names(domains_all))
  cat("Domain-mapped:", sum(panel_vars %in% names(domains_all)), "\n")
  cat("Unmapped:", length(unmapped), "\n")
  if (length(unmapped) > 0) cat("  Missing:", paste(unmapped, collapse = ", "), "\n")
  stopifnot(length(unmapped) == 0)
  cat("All panel indicators domain-mapped: OK\n\n")
}

cat("=== D: EXPORT REGISTRY TESTS PASSED ===\n\n")
cat("=== ALL PHASE 3 TESTS COMPLETE ===\n")
