# Test: can we get 10m admin1 via ne_download instead of ne_states?
library(rnaturalearth)

cat("Trying ne_download with scale=10 for admin_1...\n")
admin1_10m <- ne_download(
  scale = 10,
  type = "admin_1_states_provinces",
  category = "cultural",
  returnclass = "sf"
)

cat("Rows:", nrow(admin1_10m), "\n")
cat("Columns:", paste(head(names(admin1_10m), 20), collapse = ", "), "\n\n")

# Check for Kenya
for (col in names(admin1_10m)) {
  if (col == "geometry") next
  vals <- admin1_10m[[col]]
  if (!is.character(vals)) next
  ke_match <- grepl("Kenya|^KE$|^KE-|^KEN$", vals, ignore.case = FALSE)
  if (any(ke_match, na.rm = TRUE)) {
    cat("Found Kenya in column '", col, "': ", sum(ke_match, na.rm = TRUE), " rows\n", sep = "")
    cat("  Sample: ", paste(head(unique(vals[ke_match]), 3), collapse = ", "), "\n")
  }
}
