library(rnaturalearth)
admin1 <- ne_download(scale = 50, type = "admin_1_states_provinces",
                       category = "cultural", returnclass = "sf")

# Check iso_3166_2 for Kenya
cat("iso_3166_2 values containing 'KE':\n")
ke_iso <- admin1$iso_3166_2[grepl("KE", admin1$iso_3166_2, ignore.case = TRUE)]
cat(paste(head(ke_iso, 5), collapse = ", "), "\n")
cat("Count:", length(ke_iso), "\n\n")

# Check ALL columns that contain "KE" or "Kenya" for any row
cat("Columns containing 'KE' or 'Kenya' values:\n")
for (col in names(admin1)) {
  if (col == "geometry") next
  vals <- admin1[[col]]
  if (!is.character(vals)) next
  ke_match <- vals == "KE" | vals == "Kenya" | grepl("^KE-", vals) | grepl("^KE$", vals)
  if (any(ke_match, na.rm = TRUE)) {
    cat("  ", col, ": ", sum(ke_match, na.rm = TRUE), " rows, sample: ",
        paste(head(unique(vals[ke_match]), 3), collapse = ", "), "\n")
  }
}

# Also check admin column
cat("\nUnique 'admin' values for Africa (sample):\n")
cat(paste(head(unique(admin1$admin[grepl("Kenya|Nigeria|Ghana", admin1$admin)]), 10), collapse = ", "), "\n")

# Check adm0_a3 for KEN
cat("\nadm0_a3 containing 'KEN':\n")
cat(sum(admin1$adm0_a3 == "KEN", na.rm = TRUE), "rows\n")

# Show a sample row for Kenya
ke_rows <- admin1[admin1$adm0_a3 == "KEN", ]
if (nrow(ke_rows) > 0) {
  cat("\nSample Kenya row columns:\n")
  r <- ke_rows[1, ]
  for (col in c("name", "iso_3166_2", "iso_a2", "adm0_a3", "admin", "postal")) {
    cat("  ", col, ":", as.character(r[[col]]), "\n")
  }
}
