# ============================================================================
# Export balanced panel as CSV for Python ingestion
# Drops any non-atomic columns (list, matrix, etc.)
# Run in RStudio from the localintel package root
# ============================================================================

out_dir <- "webapp/data"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

cat("Reading balanced panel...\n")
bal <- readRDS("tests/gapfill-results/dhs_panel_admin1_balanced.rds")
cat("  Shape:", nrow(bal), "x", ncol(bal), "\n")

# Identify non-atomic columns (list, matrix, etc.)
is_atomic_col <- sapply(bal, function(x) is.atomic(x) && !is.matrix(x))
bad_cols <- names(bal)[!is_atomic_col]
cat("  Non-atomic columns found:", length(bad_cols), "\n")
if (length(bad_cols) > 0) {
  cat("  Examples:", paste(head(bad_cols, 6), collapse=", "), "\n")
  bal <- bal[, is_atomic_col, drop = FALSE]
}

cat("  Final shape:", nrow(bal), "x", ncol(bal), "\n")

dst <- file.path(out_dir, "panel.csv.gz")
cat("Writing compressed CSV...\n")
data.table::fwrite(bal, dst, compress = "gzip")
cat("Saved to:", dst, "\n")
cat("  Size:", round(file.size(dst) / 1024 / 1024, 1), "MB\n")

# Summary
flag_cols <- grep("^imp_.*_flag$", names(bal), value = TRUE)
cat("  Indicator count:", length(flag_cols), "\n")
cat("  Years:", paste(range(bal$year), collapse = "-"), "\n")
cat("  Regions:", length(unique(bal$geo)), "\n")
