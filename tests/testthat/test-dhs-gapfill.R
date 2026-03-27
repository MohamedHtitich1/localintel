# --- DHS Gap-Fill Layer Tests (synthetic data) ---

test_that("gapfill_series handles n=1 (single observation)", {
  result <- gapfill_series(
    years  = 2014,
    values = 55.0,
    transform = "logit"
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$estimate, 55.0)
  expect_equal(result$source, "observed")
})

test_that("gapfill_series handles n=2 (linear interpolation)", {
  result <- gapfill_series(
    years  = c(2010, 2020),
    values = c(80, 60),
    transform = "logit"
  )
  # Should have 11 rows: 2010-2020
  expect_equal(nrow(result), 11)
  # Endpoints should be exact
  expect_equal(result$estimate[result$year == 2010], 80)
  expect_equal(result$estimate[result$year == 2020], 60)
  # Midpoint should be interpolated (roughly 70 on logit scale, not exactly)
  mid <- result$estimate[result$year == 2015]
  expect_true(mid > 65 && mid < 75)
  # All values should be in [0, 100] for logit transform
  expect_true(all(result$estimate >= 0 & result$estimate <= 100))
})

test_that("gapfill_series n>=3 passes through observed values exactly", {
  yrs <- c(2005, 2010, 2015, 2020)
  vals <- c(120, 95, 75, 50)
  result <- gapfill_series(
    years  = yrs,
    values = vals,
    transform = "log"
  )
  # Observed years should match exactly
  for (i in seq_along(yrs)) {
    obs_row <- result[result$year == yrs[i], ]
    expect_equal(obs_row$estimate, vals[i], tolerance = 0.01,
                 info = paste("Year", yrs[i]))
    expect_equal(obs_row$source, "observed")
  }
  # All values should be positive for log transform
  expect_true(all(result$estimate > 0))
})

test_that("gapfill_series with forecast_to extends beyond last survey", {
  result <- gapfill_series(
    years  = c(2005, 2010, 2015),
    values = c(100, 80, 60),
    transform = "log",
    forecast_to = 2020
  )
  # Should have rows through 2020
  expect_true(max(result$year) >= 2020)
  # Forecasted rows should be flagged
  fcast <- result[result$year > 2015, ]
  expect_true(all(fcast$source == "forecasted"))
  # Values should remain positive
  expect_true(all(result$estimate > 0))
})

test_that("gapfill_series confidence intervals contain observed values", {
  yrs <- c(2005, 2010, 2015)
  vals <- c(80, 65, 50)
  result <- gapfill_series(
    years  = yrs,
    values = vals,
    transform = "logit"
  )
  # At observed points, CI should contain the value (or be NA for n=1/2)
  for (y in yrs) {
    row <- result[result$year == y, ]
    if (!is.na(row$ci_lo) && !is.na(row$ci_hi)) {
      expect_true(row$estimate >= row$ci_lo && row$estimate <= row$ci_hi,
                  info = paste("Year", y, "CI does not contain estimate"))
    }
  }
})
