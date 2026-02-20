test_that("safe_log10 handles edge cases", {
  expect_equal(safe_log10(100), log10(100))
  expect_equal(safe_log10(1), 0)
  expect_true(is.na(safe_log10(0)))
  expect_true(is.na(safe_log10(-5)))
  expect_true(is.na(safe_log10(NA)))
})

test_that("safe_log2 handles edge cases", {
  expect_equal(safe_log2(8), 3)
  expect_equal(safe_log2(1), 0)
  expect_true(is.na(safe_log2(0)))
  expect_true(is.na(safe_log2(-1)))
  expect_true(is.na(safe_log2(NA)))
})

test_that("scale_0_100 normalizes correctly", {
  x <- c(0, 25, 50, 75, 100)
  result <- scale_0_100(x)
  expect_equal(min(result, na.rm = TRUE), 0)
  expect_equal(max(result, na.rm = TRUE), 100)
  expect_equal(result[3], 50)
})

test_that("scale_0_100 handles NA and constant", {
  expect_true(all(is.na(scale_0_100(c(NA, NA)))))
  # Constant input
  result <- scale_0_100(c(5, 5, 5))
  expect_true(all(result == 0 | is.na(result)))
})

test_that("interp_const_ends_flag interpolates linearly", {
  y <- c(10, NA, NA, 40, NA)
  result <- interp_const_ends_flag(y)
  expect_equal(result$value[1], 10)
  expect_equal(result$value[4], 40)
  # Linear interpolation between 10 and 40
  expect_equal(result$value[2], 20)
  expect_equal(result$value[3], 30)
  # Flags
  expect_equal(result$flag[1], 0)
  expect_equal(result$flag[2], 1)
  expect_equal(result$flag[3], 1)
  expect_equal(result$flag[4], 0)
})

test_that("interp_const_ends_flag handles all NA", {
  y <- c(NA, NA, NA)
  result <- interp_const_ends_flag(y)
  expect_true(all(is.na(result$value)))
  expect_equal(result$flag, c(1, 1, 1))
})

test_that("keep_eu27 filters correctly", {
  df <- data.frame(geo = c("AT11", "DE21", "US01", "FR10", "XX99"), stringsAsFactors = FALSE)
  result <- keep_eu27(df)
  expect_true("AT11" %in% result$geo)
  expect_true("DE21" %in% result$geo)
  expect_true("FR10" %in% result$geo)
  expect_false("US01" %in% result$geo)
  expect_false("XX99" %in% result$geo)
})

test_that("add_country_name adds correct names", {
  df <- data.frame(geo = c("AT11", "DE21", "FR10"), stringsAsFactors = FALSE)
  result <- add_country_name(df)
  expect_true("Country" %in% names(result))
  expect_equal(result$Country[result$geo == "AT11"], "Austria")
  expect_equal(result$Country[result$geo == "DE21"], "Germany")
  expect_equal(result$Country[result$geo == "FR10"], "France")
})

test_that("eu27_codes returns 27 codes", {
  codes <- eu27_codes()
  expect_equal(length(codes), 27)
  expect_true("DE" %in% codes)
  expect_true("FR" %in% codes)
  expect_false("UK" %in% codes)
})

test_that("normalize_eurostat_cols renames geo\\TIME_PERIOD to geo", {
  df <- data.frame(`geo\\TIME_PERIOD` = c("DE11", "FR10"), values = c(1, 2),
                   check.names = FALSE, stringsAsFactors = FALSE)
  result <- normalize_eurostat_cols(df)
  expect_true("geo" %in% names(result))
  expect_equal(result$geo, c("DE11", "FR10"))
})

test_that("normalize_eurostat_cols renames TIME_PERIOD to time", {
  df <- data.frame(geo = "DE11", TIME_PERIOD = "2020", values = 1,
                   stringsAsFactors = FALSE)
  result <- normalize_eurostat_cols(df)
  expect_true("time" %in% names(result))
  expect_false("TIME_PERIOD" %in% names(result))
})

test_that("normalize_eurostat_cols is a no-op when columns are standard", {
  df <- data.frame(geo = "DE11", time = "2020", values = 1,
                   stringsAsFactors = FALSE)
  result <- normalize_eurostat_cols(df)
  expect_identical(names(result), names(df))
})

test_that("nuts_country_names returns named vector", {
  nms <- nuts_country_names()
  expect_true(is.character(nms))
  expect_true(length(names(nms)) > 0)
  expect_equal(unname(nms["DE"]), "Germany")
})
