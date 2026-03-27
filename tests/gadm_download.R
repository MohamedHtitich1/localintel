#!/usr/bin/env Rscript
# Step 1: Download GADM geometry for all 35 countries and save as RDS
suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
  library(terra)
})

setwd("/home/mohamed/Nextcloud2/localintel/main/localintel")
devtools::load_all(".", quiet = TRUE)

# Persistent cache dir for GADM
gadm_dir <- "/home/mohamed/Nextcloud2/localintel/main/localintel/tests/gapfill-results/gadm_cache"
dir.create(gadm_dir, showWarnings = FALSE, recursive = TRUE)

# Check what's already been downloaded
bal <- readRDS("tests/gapfill-results/dhs_panel_admin1_balanced.rds")
panel_countries <- sort(unique(bal$admin0))
dhs_to_iso3 <- localintel:::.dhs_to_iso3_map()

all_geo <- list()
for (ctry in panel_countries) {
  iso3 <- if (ctry %in% names(dhs_to_iso3)) dhs_to_iso3[[ctry]] else ctry
  level <- localintel:::.gadm_level_override(iso3)

  # Check if we already have this saved
  cache_file <- file.path(gadm_dir, paste0(iso3, "_", level, ".rds"))

  if (file.exists(cache_file)) {
    geo_sf <- readRDS(cache_file)
    cat(ctry, "(", iso3, "): loaded from cache,", nrow(geo_sf), "regions\n")
  } else {
    tryCatch({
      geom <- geodata::gadm(iso3, level = level, path = gadm_dir)
      geo_sf <- st_as_sf(geom)
      admin1_col <- if (level == 1) "NAME_1" else "NAME_2"
      geo_sf <- geo_sf |>
        transmute(admin0 = ctry, admin1_name = .data[[admin1_col]]) |>
        st_make_valid() |>
        st_transform(4326)
      saveRDS(geo_sf, cache_file)
      cat(ctry, "(", iso3, "):", nrow(geo_sf), "regions - downloaded\n")
    }, error = function(e) {
      cat(ctry, "(", iso3, "): FAILED -", e$message, "\n")
    })
  }

  if (exists("geo_sf") && !is.null(geo_sf)) {
    all_geo[[ctry]] <- geo_sf
  }
}

if (length(all_geo) > 0) {
  combined <- bind_rows(all_geo)
  saveRDS(combined, "tests/gapfill-results/gadm_combined_geo.rds")
  cat("\nSaved combined geometry:", nrow(combined), "regions,",
      n_distinct(combined$admin0), "countries\n")
}
