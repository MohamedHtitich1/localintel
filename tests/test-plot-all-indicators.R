# ============================================================================
# Interactive Test: Plot All 60 Indicators - SSA Continent Maps
# ============================================================================
# Generates one choropleth map per indicator (latest available year)
# showing all 652 DHS Admin 1 regions across Sub-Saharan Africa.
#
# Run in RStudio: source this file or run block by block (Ctrl+Enter).
# Output: PDF saved to tests/gapfill-results/ssa_all_indicators.pdf
# ============================================================================

library(dplyr)
library(sf)
library(tmap)

# Load package
devtools::load_all(".")

# ── Block A: Load data ───────────────────────────────────────────────────────
cat("Loading balanced panel...\n")
bal <- readRDS("tests/gapfill-results/dhs_panel_admin1_balanced.rds")

cat("Panel:", nrow(bal), "rows x", ncol(bal), "cols\n")
cat("Regions:", n_distinct(bal$geo), "| Countries:", n_distinct(bal$admin0),
    "| Years:", min(bal$year), "-", max(bal$year), "\n")

# Detect all indicator columns
flag_cols <- grep("^imp_(.+)_flag$", names(bal), value = TRUE)
all_vars <- sub("^imp_(.+)_flag$", "\\1", flag_cols)
cat("Indicators:", length(all_vars), "\n\n")

# ── Block B: Load GADM geometry from cache ───────────────────────────────────
cat("Loading GADM geometry from cache...\n")
gadm_dir <- "tests/gapfill-results/gadm_cache"
rds_files <- list.files(gadm_dir, pattern = "^[A-Z]{3}_[12]\\.rds$", full.names = TRUE)
combined_geo <- bind_rows(lapply(rds_files, readRDS))
cat("GADM regions:", nrow(combined_geo), "across", n_distinct(combined_geo$admin0), "countries\n\n")

# ── Block C: Load admin0 basemap ─────────────────────────────────────────────
cat("Loading country borders basemap...\n")
admin0 <- get_admin0_geo(unique(bal$admin0))
cat("Admin0 polygons:", nrow(admin0), "\n\n")

# ── Block D: Find BEST year per indicator (max region coverage) ───────────────
cat("Finding best year per indicator (max region coverage)...\n")
best_years <- sapply(all_vars, function(v) {
  if (!v %in% names(bal)) return(NA_integer_)
  region_counts <- tapply(!is.na(bal[[v]]), bal$year, sum)
  as.integer(names(which.max(region_counts)))
})
best_counts <- sapply(seq_along(all_vars), function(i) {
  v <- all_vars[i]; yr <- best_years[i]
  if (is.na(yr)) return(0L)
  sum(!is.na(bal[[v]][bal$year == yr]))
})
cat("Best years range:", min(best_years, na.rm = TRUE), "-", max(best_years, na.rm = TRUE), "\n")
cat("Region coverage range:", min(best_counts), "-", max(best_counts), "\n\n")

# ── Block E: Generate all maps to PDF ────────────────────────────────────────
pdf_file <- "tests/gapfill-results/ssa_all_indicators.pdf"
cat("Generating", length(all_vars), "maps to:", pdf_file, "\n")
cat("This may take several minutes...\n\n")

# Get labels and domains
labs <- dhs_var_labels()
domains <- dhs_domain_mapping()

tmap_mode("plot")

pdf(pdf_file, width = 12, height = 10)

for (idx in seq_along(all_vars)) {
  v <- all_vars[idx]
  yr <- best_years[idx]

  if (is.na(yr) || !is.finite(yr)) {
    cat(sprintf("  [%02d/%02d] %s - SKIPPED (no data)\n", idx, length(all_vars), v))
    next
  }

  # Get label and domain
  label <- if (v %in% names(labs)) labs[[v]] else v
  domain <- if (v %in% names(domains)) domains[[v]] else "Other"

  cat(sprintf("  [%02d/%02d] %s (%s) - year %d ... ", idx, length(all_vars), v, domain, yr))

  tryCatch({
    # Build display sf
    sf_data <- build_dhs_display_sf(bal, combined_geo, var = v, years = yr)

    if (nrow(sf_data) == 0) {
      cat("EMPTY\n")
      next
    }

    # Compute breaks
    rng <- range(sf_data$value, na.rm = TRUE)
    if (!is.finite(rng[1]) || !is.finite(rng[2])) {
      cat("NO FINITE VALUES\n")
      next
    }
    if (rng[1] == rng[2]) rng <- c(rng[1] - 0.5, rng[2] + 0.5)
    brks <- pretty(rng, n = 7)

    # Determine palette based on domain
    pal <- switch(domain,
      "Mortality" = "-RdYlGn",
      "HIV/AIDS" = "-RdYlGn",
      "Nutrition" = "-RdYlGn",
      "Maternal & Child Health" = "YlGnBu",
      "Education" = "YlGnBu",
      "Water & Sanitation" = "YlGnBu",
      "Wealth & Assets" = "YlOrRd",
      "Gender" = "PuBuGn",
      "viridis"
    )

    # Title
    title_text <- paste0(label, " - ", yr)
    n_ctries <- n_distinct(sf_data$admin0)
    subtitle_text <- paste0("[", domain, "] | ", n_ctries, "/35 countries, ",
                            nrow(sf_data), "/652 regions with data")

    # Build map (tmap v4 syntax)
    bbox <- sf::st_bbox(c(xmin = -18, ymin = -36, xmax = 52, ymax = 18), crs = st_crs(4326))

    # Detect tmap version
    tmap_v4 <- utils::packageVersion("tmap") >= "4.0"

    if (tmap_v4) {
      p <- tm_shape(admin0, bbox = bbox) +
        tm_polygons(fill = "grey95", col = "grey80", lwd = 0.4) +
        tm_shape(sf_data) +
        tm_polygons(
          fill = "value",
          fill.scale = tm_scale_intervals(breaks = brks, values = pal),
          fill.legend = tm_legend(title = label),
          col = "white",
          lwd = 0.2
        ) +
        tm_title(title_text) +
        tm_layout(frame = FALSE, inner.margins = c(0.02, 0.02, 0.02, 0.02)) +
        tm_credits(subtitle_text, position = c("left", "top"), size = 0.6) +
        tm_credits("Source: DHS Program | localintel v0.3.0",
                    position = c("left", "bottom"), size = 0.5)
    } else {
      p <- tm_shape(admin0, bbox = bbox) +
        tm_polygons(col = "grey95", lwd = 0.4, border.col = "grey80") +
        tm_shape(sf_data) +
        tm_polygons(
          "value",
          style = "fixed",
          breaks = brks,
          palette = pal,
          title = label,
          border.col = "white",
          lwd = 0.2,
          legend.show = TRUE
        ) +
        tm_layout(
          main.title = title_text,
          main.title.size = 1.1,
          legend.outside = TRUE,
          frame = FALSE
        ) +
        tm_credits("Source: DHS Program | localintel v0.3.0",
                    position = c("left", "bottom"), size = 0.5)
    }

    print(p)
    cat(nrow(sf_data), "regions OK\n")

  }, error = function(e) {
    cat("ERROR:", e$message, "\n")
  })
}

dev.off()
cat("\n=== DONE ===\n")
cat("PDF saved to:", normalizePath(pdf_file), "\n")
cat("Total indicators plotted:", length(all_vars), "\n")
