# --- DHS Process Layer Tests (synthetic data) ---

# Mock raw DHS API data
mock_dhs_raw <- function() {
  tibble::tibble(
    DHS_CountryCode    = rep("KE", 10),
    CountryName        = rep("Kenya", 10),
    SurveyYear         = rep(c(2014L, 2022L), each = 5),
    SurveyId           = rep(c("KEDHS2014", "KEDHS2022"), each = 5),
    IndicatorId        = rep("CM_ECMR_C_U5M", 10),
    Indicator          = rep("Under-5 mortality rate", 10),
    CharacteristicCategory = rep("Region", 10),
    CharacteristicLabel = c(
      "Nairobi", "Central", "Coast", "Nyanza", "Western",
      "..Nairobi", "..Central", "..Coast", "..Nyanza", "..Western"
    ),
    Value              = c(44, 55, 62, 78, 71, 38, 48, 56, 65, 60),
    DenominatorWeighted = rep(1500, 10),
    CILow              = rep(NA_real_, 10),
    CIHigh             = rep(NA_real_, 10),
    IsPreferred        = rep(1L, 10),
    ByVariableLabel    = rep("", 10),
    RegionId           = paste0("KEDHS", rep(c("2014", "2022"), each = 5),
                                sprintf("%06d", 1:10))
  )
}

test_that("process_dhs deduplicates and cleans region names", {
  raw <- mock_dhs_raw()
  # Add an exact duplicate
  raw_duped <- dplyr::bind_rows(raw, raw[1, ])
  result <- process_dhs(raw_duped, out_col = "u5_mortality")

  # Should remove the duplicate
  expect_equal(nrow(result), 10)
  # Leading dots should be stripped from geo keys
  expect_false(any(grepl("_\\.+", result$geo)))
})

test_that("process_dhs constructs correct geo keys", {
  raw <- mock_dhs_raw()
  result <- process_dhs(raw, out_col = "u5_mortality")

  # geo keys should be admin0_region format
  expect_true(all(grepl("^KE_", result$geo)))
  # Nairobi should become KE_Nairobi
  expect_true("KE_Nairobi" %in% result$geo)
})

test_that("process_dhs renames year correctly", {
  raw <- mock_dhs_raw()
  result <- process_dhs(raw, out_col = "u5_mortality")

  expect_true("year" %in% names(result))
  expect_true(all(result$year %in% c(2014L, 2022L)))
})

test_that("process_dhs_batch handles multiple indicators", {
  raw1 <- mock_dhs_raw()
  raw2 <- mock_dhs_raw()
  raw2$IndicatorId <- "CN_NUTS_C_HA2"
  raw2$Value <- raw2$Value * 0.5

  batch_input <- list(u5_mortality = raw1, stunting = raw2)
  result <- process_dhs_batch(batch_input)

  expect_type(result, "list")
  expect_true(all(c("u5_mortality", "stunting") %in% names(result)))
  expect_true("u5_mortality" %in% names(result$u5_mortality))
})
