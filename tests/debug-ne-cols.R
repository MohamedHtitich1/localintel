# Quick debug: what columns does ne_download return for admin_1?
library(rnaturalearth)
admin1 <- ne_download(scale = 50, type = "admin_1_states_provinces",
                       category = "cultural", returnclass = "sf")
cat("Columns:\n")
cat(paste(names(admin1), collapse = "\n"), "\n\n")

# Check which column has ISO country codes
cat("First 5 rows of likely ISO columns:\n")
for (col in grep("iso|adm0|sov|gu_a", names(admin1), value = TRUE, ignore.case = TRUE)) {
  cat(col, ": ", paste(head(unique(admin1[[col]]), 10), collapse = ", "), "\n")
}

# Check for Kenya specifically
cat("\nSearching for Kenya (KE):\n")
for (col in names(admin1)) {
  if (is.character(admin1[[col]]) && any(admin1[[col]] == "KE", na.rm = TRUE)) {
    cat("  Found 'KE' in column:", col, "\n")
  }
  if (is.character(admin1[[col]]) && any(admin1[[col]] == "Kenya", na.rm = TRUE)) {
    cat("  Found 'Kenya' in column:", col, "\n")
  }
}

# Also check the name column
cat("\nName column for Kenya rows:\n")
ke_rows <- admin1[grep("Kenya|KE", admin1$admin, ignore.case = TRUE), ]
if (nrow(ke_rows) > 0) {
  cat("Found", nrow(ke_rows), "rows\n")
} else {
  # Try another approach
  for (col in names(admin1)) {
    if (is.character(admin1[[col]])) {
      ke <- grepl("Kenya", admin1[[col]], ignore.case = TRUE)
      if (any(ke)) {
        cat("  Found 'Kenya' in column:", col, "—", sum(ke), "rows\n")
      }
    }
  }
}
