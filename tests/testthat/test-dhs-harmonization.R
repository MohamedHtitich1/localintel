# --- DHS Harmonization Lookup Table Consistency Tests ---
# These tests verify internal consistency of the lookup tables without
# requiring GADM downloads or API access.

test_that("manual_crosswalk has no duplicate DHS entries per country", {
  xw <- localintel:::.manual_crosswalk()
  dupes <- xw |>
    dplyr::group_by(admin0, dhs_region) |>
    dplyr::filter(dplyr::n() > 1) |>
    dplyr::ungroup()
  expect_equal(nrow(dupes), 0,
    info = paste("Duplicate crosswalk entries:",
                 paste(dupes$admin0, dupes$dhs_region, sep = ":", collapse = ", ")))
})

test_that("dissolve_lookup entries all reference valid SSA countries", {
  dl <- localintel:::.dissolve_lookup()
  expect_true(all(dl$admin0 %in% ssa_codes()),
    info = paste("Non-SSA codes in dissolve_lookup:",
                 paste(setdiff(dl$admin0, ssa_codes()), collapse = ", ")))
})

test_that("composite_split entries have at least 2 components each", {
  cs <- localintel:::.composite_split()
  counts <- cs |>
    dplyr::group_by(admin0, dhs_region) |>
    dplyr::summarise(n_components = dplyr::n(), .groups = "drop")
  too_few <- counts |> dplyr::filter(n_components < 2)
  expect_equal(nrow(too_few), 0,
    info = paste("Composite splits with <2 components:",
                 paste(too_few$admin0, too_few$dhs_region, sep = ":", collapse = ", ")))
})

test_that("nongeo_dissolve entries all reference valid SSA countries", {
  ngd <- localintel:::.nongeo_dissolve()
  expect_true(all(ngd$admin0 %in% ssa_codes()),
    info = paste("Non-SSA codes in nongeo_dissolve:",
                 paste(setdiff(ngd$admin0, ssa_codes()), collapse = ", ")))
})

test_that("all four lookup tables have required columns", {
  xw  <- localintel:::.manual_crosswalk()
  dl  <- localintel:::.dissolve_lookup()
  cs  <- localintel:::.composite_split()
  ngd <- localintel:::.nongeo_dissolve()

  expect_true(all(c("admin0", "dhs_region", "ne_region") %in% names(xw)))
  expect_true(all(c("admin0", "gadm_admin1", "dhs_parent") %in% names(dl)))
  expect_true(all(c("admin0", "dhs_region", "component") %in% names(cs)))
  expect_true(all(c("admin0", "dhs_region", "component") %in% names(ngd)))
})

test_that("no NA values in lookup table keys", {
  tables <- list(
    crosswalk = localintel:::.manual_crosswalk(),
    dissolve  = localintel:::.dissolve_lookup(),
    composite = localintel:::.composite_split(),
    nongeo    = localintel:::.nongeo_dissolve()
  )
  # Each table has admin0 as a key column
  for (nm in names(tables)) {
    tbl <- tables[[nm]]
    expect_false(any(is.na(tbl$admin0)),
      info = paste("NA admin0 in", nm))
  }
  # Table-specific key columns
  expect_false(any(is.na(tables$crosswalk$dhs_region)),
    info = "NA dhs_region in crosswalk")
  expect_false(any(is.na(tables$crosswalk$ne_region)),
    info = "NA ne_region in crosswalk")
  expect_false(any(is.na(tables$dissolve$gadm_admin1)),
    info = "NA gadm_admin1 in dissolve")
  expect_false(any(is.na(tables$dissolve$dhs_parent)),
    info = "NA dhs_parent in dissolve")
  expect_false(any(is.na(tables$composite$dhs_region)),
    info = "NA dhs_region in composite")
  expect_false(any(is.na(tables$composite$component)),
    info = "NA component in composite")
  expect_false(any(is.na(tables$nongeo$dhs_region)),
    info = "NA dhs_region in nongeo")
  expect_false(any(is.na(tables$nongeo$component)),
    info = "NA component in nongeo")
})

test_that("dhs_to_iso3_map covers all SSA codes", {
  iso3_map <- localintel:::.dhs_to_iso3_map()
  ssa <- ssa_codes()
  missing <- setdiff(ssa, names(iso3_map))
  expect_equal(length(missing), 0,
    info = paste("SSA codes missing from ISO3 map:",
                 paste(missing, collapse = ", ")))
})

test_that("dhs_to_iso3_map values are valid 3-letter ISO codes", {
  iso3_map <- localintel:::.dhs_to_iso3_map()
  expect_true(all(nchar(iso3_map) == 3),
    info = "All ISO3 codes should be exactly 3 characters")
  expect_true(all(grepl("^[A-Z]{3}$", iso3_map)),
    info = "All ISO3 codes should be uppercase letters only")
})

test_that("unified label and domain registries cover all DHS indicators", {
  all_codes <- all_dhs_codes()
  labs <- regional_var_labels()
  doms <- regional_domain_mapping()

  # Every DHS indicator code should have a label
  dhs_labels <- dhs_var_labels()
  for (short_name in names(dhs_labels)) {
    expect_true(short_name %in% names(labs),
      info = paste("DHS indicator", short_name, "missing from unified labels"))
    expect_true(short_name %in% names(doms),
      info = paste("DHS indicator", short_name, "missing from unified domains"))
  }
})
