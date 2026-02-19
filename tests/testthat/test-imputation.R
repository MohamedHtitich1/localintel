# --- interp_pchip_flag ---

test_that("interp_pchip_flag fills internal gaps", {
  y <- c(10, NA, NA, 40, 50)
  result <- interp_pchip_flag(y)
  expect_length(result$value, 5)
  expect_length(result$flag, 5)
  # Observed values preserved

  expect_equal(result$value[1], 10)
  expect_equal(result$value[4], 40)
  expect_equal(result$value[5], 50)
  # Interpolated values are between endpoints
  expect_true(result$value[2] > 10 && result$value[2] < 40)
  expect_true(result$value[3] > 10 && result$value[3] < 40)
  # Flags correct
  expect_equal(result$flag, c(0, 1, 1, 0, 0))
})

test_that("interp_pchip_flag handles all NA", {
  y <- c(NA, NA, NA)
  result <- interp_pchip_flag(y)
  expect_true(all(is.na(result$value)))
  expect_equal(result$flag, c(1, 1, 1))
})

test_that("interp_pchip_flag handles single observed", {
  y <- c(NA, 5, NA)
  result <- interp_pchip_flag(y)
  expect_equal(result$value, c(5, 5, 5))
  expect_equal(result$flag, c(1, 0, 1))
})

test_that("interp_pchip_flag holds endpoints constant", {
  y <- c(NA, NA, 10, 20, NA, NA)
  result <- interp_pchip_flag(y)
  # Before first observed: constant at 10
  expect_equal(result$value[1], 10)
  expect_equal(result$value[2], 10)
  # After last observed: constant at 20
  expect_equal(result$value[5], 20)
  expect_equal(result$value[6], 20)
})

test_that("interp_pchip_flag no NAs returns unchanged", {
  y <- c(1, 2, 3, 4, 5)
  result <- interp_pchip_flag(y)
  expect_equal(result$value, y)
  expect_equal(result$flag, rep(0, 5))
})

# --- forecast_autoregressive ---

test_that("forecast_autoregressive produces h forecasts", {
  y <- c(10, 12, 14, 16, 18, 20)
  result <- forecast_autoregressive(y, h = 3)
  expect_length(result$forecast, 3)
  expect_length(result$lower, 3)
  expect_length(result$upper, 3)
  expect_true(result$method %in% c("ets", "holt_linear", "constant"))
})

test_that("forecast_autoregressive handles short series", {
  y <- c(5)
  result <- forecast_autoregressive(y, h = 2)
  expect_equal(result$forecast, c(5, 5))
  expect_equal(result$method, "constant")
})

test_that("forecast_autoregressive handles NAs via PCHIP", {
  y <- c(10, NA, 20, 25, 30)
  result <- forecast_autoregressive(y, h = 2)
  expect_length(result$forecast, 2)
  expect_false(any(is.na(result$forecast)))
})

# --- impute_series ---

test_that("impute_series fills gaps without forecasting", {
  y <- c(10, NA, NA, 40, 50)
  years <- 2018:2022
  result <- impute_series(y, years)
  expect_length(result$value, 5)
  expect_equal(result$years, years)
  expect_false(any(is.na(result$value)))
  # Observed values preserved
  expect_equal(result$value[1], 10)
  expect_equal(result$value[4], 40)
  expect_equal(result$value[5], 50)
  # Flags: 0 for observed, 1 for interpolated
  expect_equal(result$flag[1], 0)
  expect_equal(result$flag[2], 1)
  expect_equal(result$flag[3], 1)
  expect_equal(result$flag[4], 0)
  expect_equal(result$flag[5], 0)
  expect_true(grepl("pchip", result$method))
})

test_that("impute_series extends with forecasting", {
  y <- c(10, 20, 30, 40, 50)
  years <- 2018:2022
  result <- impute_series(y, years, forecast_to = 2024)
  expect_length(result$value, 7)
  expect_equal(result$years, 2018:2024)
  # Last two are forecasted
  expect_equal(result$flag[6], 2)
  expect_equal(result$flag[7], 2)
  expect_true(grepl("forecasting", result$method))
})

test_that("impute_series with no forecast_to needed", {
  y <- c(10, 20, 30)
  years <- 2020:2022
  result <- impute_series(y, years, forecast_to = 2022)
  # No extension needed
  expect_length(result$value, 3)
  expect_equal(result$flag, c(0, 0, 0))
})

test_that("impute_series errors on length mismatch", {
  expect_error(impute_series(c(1, 2), 2020:2022), "Length")
})
