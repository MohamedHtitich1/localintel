# --- cascade_to_nuts2 ---

# Mock NUTS2 reference table
mock_nuts2_ref <- function() {
  tibble::tibble(
    geo   = c("DE11", "DE12", "DE21", "FR10", "FR20"),
    nuts1 = c("DE1",  "DE1",  "DE2",  "FR1",  "FR2"),
    nuts0 = c("DE",   "DE",   "DE",   "FR",   "FR")
  )
}

test_that("cascade_to_nuts2 picks NUTS2 first, then NUTS1, then NUTS0", {
  ref <- mock_nuts2_ref()
  data <- tibble::tibble(
    geo  = c("DE11", "DE1", "FR"),
    year = c(2020L, 2020L, 2020L),
    gdp  = c(100,    200,   300)
  )
  result <- cascade_to_nuts2(data, vars = "gdp", years = 2020L,
                             nuts2_ref = ref, impute = FALSE)

  # DE11 has own NUTS2 value

  expect_equal(result$gdp[result$geo == "DE11" & result$year == 2020], 100)
  expect_equal(result$src_gdp_level[result$geo == "DE11" & result$year == 2020], 2L)

  # DE12 inherits from NUTS1 (DE1)
  expect_equal(result$gdp[result$geo == "DE12" & result$year == 2020], 200)
  expect_equal(result$src_gdp_level[result$geo == "DE12" & result$year == 2020], 1L)

  # FR10 inherits from NUTS0 (FR)
  expect_equal(result$gdp[result$geo == "FR10" & result$year == 2020], 300)
  expect_equal(result$src_gdp_level[result$geo == "FR10" & result$year == 2020], 0L)
})

test_that("cascade_to_nuts2 creates skeleton for all geo-year combos", {
  ref <- mock_nuts2_ref()
  data <- tibble::tibble(
    geo  = c("DE11", "DE11"),
    year = c(2020L,  2021L),
    x    = c(10,     20)
  )
  result <- cascade_to_nuts2(data, vars = "x", years = 2020:2021,
                             nuts2_ref = ref, impute = FALSE)
  # Should have 5 regions x 2 years = 10 rows

  expect_equal(nrow(result), 10)
  # DE11 has values, others are NA (no cascade source)
  expect_false(is.na(result$x[result$geo == "DE11" & result$year == 2020]))
  expect_true(is.na(result$x[result$geo == "FR20" & result$year == 2020]))
})

test_that("cascade_to_nuts2 with impute=TRUE fills gaps", {
  ref <- mock_nuts2_ref()
  # DE11 has a gap at 2021
  data <- tibble::tibble(
    geo  = c("DE11", "DE11", "DE11"),
    year = c(2020L,  2021L,  2022L),
    x    = c(10,     NA,     30)
  )
  result <- cascade_to_nuts2(data, vars = "x", years = 2020:2022,
                             nuts2_ref = ref, impute = TRUE)
  de11 <- result[result$geo == "DE11", ]
  de11 <- de11[order(de11$year), ]
  # Gap should be filled
  expect_false(is.na(de11$x[de11$year == 2021]))
  # Imputation flag should be 1 for interpolated
  expect_equal(de11$imp_x_flag[de11$year == 2021], 1L)
  # Observed values flagged 0
  expect_equal(de11$imp_x_flag[de11$year == 2020], 0L)
  expect_equal(de11$imp_x_flag[de11$year == 2022], 0L)
})

test_that("cascade_to_nuts2 with impute=FALSE produces no imp_flag columns", {
  ref <- mock_nuts2_ref()
  data <- tibble::tibble(
    geo  = c("DE11"),
    year = c(2020L),
    x    = c(10)
  )
  result <- cascade_to_nuts2(data, vars = "x", years = 2020L,
                             nuts2_ref = ref, impute = FALSE)
  expect_false("imp_x_flag" %in% names(result))
})

test_that("cascade_to_nuts2 with forecast_to extends series", {
  ref <- mock_nuts2_ref()
  data <- tibble::tibble(
    geo  = rep("DE11", 5),
    year = 2018:2022,
    x    = c(10, 20, 30, 40, 50)
  )
  result <- cascade_to_nuts2(data, vars = "x", years = 2018:2022,
                             nuts2_ref = ref, impute = TRUE, forecast_to = 2024)
  de11 <- result[result$geo == "DE11", ]
  de11 <- de11[order(de11$year), ]
  # Should include years up to 2024
  expect_true(2024 %in% de11$year)
  expect_true(2023 %in% de11$year)
  # Forecasted values should have flag = 2
  expect_equal(de11$imp_x_flag[de11$year == 2023], 2L)
  expect_equal(de11$imp_x_flag[de11$year == 2024], 2L)
  # Forecasted values should not be NA
  expect_false(is.na(de11$x[de11$year == 2023]))
  expect_false(is.na(de11$x[de11$year == 2024]))
})

test_that("cascade_to_nuts2 handles multiple variables", {
  ref <- mock_nuts2_ref()
  data <- tibble::tibble(
    geo  = c("DE11", "DE11"),
    year = c(2020L,  2021L),
    a    = c(10,     20),
    b    = c(100,    200)
  )
  result <- cascade_to_nuts2(data, vars = c("a", "b"), years = 2020:2021,
                             nuts2_ref = ref, impute = FALSE)
  expect_true("a" %in% names(result))
  expect_true("b" %in% names(result))
  expect_true("src_a_level" %in% names(result))
  expect_true("src_b_level" %in% names(result))
})

test_that("cascade_to_nuts2 errors on bad input", {
  ref <- mock_nuts2_ref()
  data <- tibble::tibble(geo = "DE11", year = 2020L, x = 10)
  # Missing variable

  expect_error(
    cascade_to_nuts2(data, vars = "nonexistent", years = 2020L, nuts2_ref = ref),
    "are not TRUE"
  )
})

# --- balance_panel ---

test_that("balance_panel fills missing years", {
  data <- tibble::tibble(
    geo  = c("DE11", "DE11"),
    year = c(2020L,  2022L),
    x    = c(10,     30)
  )
  result <- balance_panel(data, vars = "x", years = 2020:2022)
  expect_equal(nrow(result), 3)
  # 2021 should be filled
  expect_false(is.na(result$x[result$year == 2021]))
})
