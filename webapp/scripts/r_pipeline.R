#!/usr/bin/env Rscript
# ──────────────────────────────────────────────────────────────────────────────
# LocalIntel — R Data Pipeline
#
# Automated DHS data refresh: fetch → process → gapfill → cascade → export
#
# Called by scripts/pipeline.py or run standalone:
#   Rscript scripts/r_pipeline.R
#
# Requires: localintel package installed + DHS_API_KEY env var set
# ──────────────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages({
    library(localintel)
    library(data.table)
})

cat("╔══════════════════════════════════════╗\n")
cat("║  LocalIntel R Data Pipeline           ║\n")
cat("╚══════════════════════════════════════╝\n\n")

t0 <- Sys.time()

# ── Configuration ────────────────────────────────────────────────────────────

COUNTRIES <- ssa_codes()           # All 44 SSA countries
FORECAST_TO <- as.integer(format(Sys.Date(), "%Y"))  # Current year
OUTPUT_DIR <- normalizePath("data", mustWork = FALSE)
PANEL_PATH <- file.path(OUTPUT_DIR, "panel.csv.gz")

cat(sprintf("Countries: %d SSA countries\n", length(COUNTRIES)))
cat(sprintf("Forecast to: %d\n", FORECAST_TO))
cat(sprintf("Output: %s\n\n", PANEL_PATH))

# ── Step 1: Full DHS Pipeline ────────────────────────────────────────────────

cat("Step 1: Running DHS pipeline (fetch → process → gapfill → cascade)...\n")
cat("  This may take 20-40 minutes depending on API speed.\n\n")

panel <- tryCatch({
    dhs_pipeline(
        countries = COUNTRIES,
        forecast_to = FORECAST_TO,
        min_countries = 5,
        min_indicators = 10,
        include_ci = TRUE,
        national_fallback = TRUE,
        verbose = TRUE
    )
}, error = function(e) {
    cat(sprintf("\nERROR in DHS pipeline: %s\n", e$message))
    quit(status = 1)
})

cat(sprintf("\nPanel assembled: %d rows × %d columns\n", nrow(panel), ncol(panel)))
cat(sprintf("  Countries: %d\n", length(unique(panel$admin0))))
cat(sprintf("  Regions: %d\n", length(unique(panel$geo))))
cat(sprintf("  Year range: %d–%d\n", min(panel$year), max(panel$year)))

# ── Step 2: Export CSV ───────────────────────────────────────────────────────

cat("\nStep 2: Exporting panel CSV...\n")

if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)

# Use data.table for robust CSV export (handles non-atomic columns)
dt <- as.data.table(panel)

# Flatten any list columns
for (col_name in names(dt)) {
    if (is.list(dt[[col_name]])) {
        dt[, (col_name) := sapply(get(col_name), function(x) {
            if (is.null(x) || length(x) == 0) NA_real_ else as.numeric(x[1])
        })]
    }
}

fwrite(dt, PANEL_PATH, compress = "gzip")
file_size <- file.size(PANEL_PATH) / 1024^2
cat(sprintf("  Exported: %s (%.1f MB)\n", PANEL_PATH, file_size))

# ── Summary ──────────────────────────────────────────────────────────────────

elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
cat(sprintf("\nR pipeline completed in %.1f minutes\n", elapsed))

# Detect indicators
flag_cols <- grep("^imp_.*_flag$", names(panel), value = TRUE)
indicator_codes <- sub("^imp_", "", sub("_flag$", "", flag_cols))
cat(sprintf("  Indicators: %d\n", length(indicator_codes)))

# Count observed vs interpolated vs forecasted
for (code in indicator_codes[1:min(5, length(indicator_codes))]) {
    fc <- paste0("imp_", code, "_flag")
    if (fc %in% names(panel)) {
        flags <- panel[[fc]]
        n_obs <- sum(flags == 0, na.rm = TRUE)
        n_int <- sum(flags == 1, na.rm = TRUE)
        n_fct <- sum(flags == 2, na.rm = TRUE)
        n_nat <- sum(flags == 3, na.rm = TRUE)
        cat(sprintf("  %s: %d obs / %d interp / %d fcast / %d natl\n", code, n_obs, n_int, n_fct, n_nat))
    }
}
cat("  ...\n")
