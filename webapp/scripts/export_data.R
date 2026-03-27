# ============================================================================
# Export balanced panel and geometries for webapp ingestion
# Run in RStudio after devtools::load_all()
# ============================================================================

library(sf)
library(dplyr)
devtools::load_all()

out_dir <- "webapp/data"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- 1. Copy balanced panel ---
panel_src <- "tests/gapfill-results/dhs_panel_admin1_balanced.rds"
panel_dst <- file.path(out_dir, "dhs_panel_admin1_balanced.rds")
file.copy(panel_src, panel_dst, overwrite = TRUE)
cat("Copied panel to:", panel_dst, "\n")

# --- 2. Export geometries as GeoJSON ---
cat("\nBuilding Admin 1 geometries...\n")
bal <- readRDS(panel_src)
geo_codes <- unique(bal$geo)
admin0_codes <- unique(bal$admin0)

# Use get_admin1_geo() which handles GADM + harmonization
all_geo <- list()
for (ctry in admin0_codes) {
  cat("  ", ctry, "...")
  g <- tryCatch(get_admin1_geo(ctry), error = function(e) NULL)
  if (!is.null(g)) {
    all_geo[[ctry]] <- g
    cat(nrow(g), "regions\n")
  } else {
    cat("FAILED\n")
  }
}

combined <- do.call(rbind, all_geo)
cat("\nTotal geometries:", nrow(combined), "\n")

# Save as RDS for Python ingestion
geo_dst <- file.path(out_dir, "gadm_combined_geo.rds")
saveRDS(combined, geo_dst)
cat("Saved geometries to:", geo_dst, "\n")

# Also export as GeoJSON for direct frontend use
geojson_dst <- file.path(out_dir, "ssa_admin1.geojson")
sf::st_write(combined, geojson_dst, driver = "GeoJSON", delete_dsn = TRUE)
cat("Saved GeoJSON to:", geojson_dst, "\n")

# --- 3. Export simplified SVG-ready GeoJSON ---
cat("\nSimplifying geometries for web...\n")
simplified <- sf::st_simplify(combined, preserveTopology = TRUE, dTolerance = 0.01)
simplified_dst <- file.path(out_dir, "ssa_admin1_simplified.geojson")
sf::st_write(simplified, simplified_dst, driver = "GeoJSON", delete_dsn = TRUE)
cat("Saved simplified GeoJSON to:", simplified_dst, "\n")

cat("\nExport complete!\n")
cat("Files in", out_dir, ":\n")
cat(paste(" ", list.files(out_dir), collapse = "\n"), "\n")
