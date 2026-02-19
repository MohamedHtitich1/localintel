# --- process_eurostat ---

test_that("process_eurostat filters and renames correctly", {
  df <- tibble::tibble(
    geo    = c("DE11", "DE11", "DE12", "DE12"),
    time   = c("2020", "2020", "2021", "2021"),
    unit   = c("PC",   "NR",   "PC",   "NR"),
    sex    = c("T",    "T",    "T",    "T"),
    values = c(10,     100,    20,     200)
  )
  result <- process_eurostat(df, filters = list(unit = "PC"), out_col = "my_var")
  expect_equal(nrow(result), 2)
  expect_true(all(c("geo", "year", "my_var") %in% names(result)))
  expect_equal(result$my_var, c(10, 20))
})

test_that("process_eurostat handles TIME_PERIOD column", {
  df <- tibble::tibble(
    geo         = c("FR10", "FR10"),
    TIME_PERIOD = c("2019", "2020"),
    values      = c(5, 10)
  )
  result <- process_eurostat(df, out_col = "val")
  expect_equal(result$year, c(2019L, 2020L))
})

test_that("process_eurostat handles year column", {
  df <- tibble::tibble(
    geo    = c("DE11"),
    year   = c(2020L),
    values = c(42)
  )
  result <- process_eurostat(df, out_col = "v")
  expect_equal(result$v, 42)
})

test_that("process_eurostat errors without time column", {
  df <- tibble::tibble(geo = "DE11", values = 10)
  expect_error(process_eurostat(df), "No time")
})

test_that("process_eurostat with multiple filters", {
  df <- tibble::tibble(
    geo    = rep("DE11", 4),
    time   = rep("2020", 4),
    sex    = c("T", "M", "T", "M"),
    age    = c("Y25-64", "Y25-64", "Y15-24", "Y15-24"),
    values = c(50, 60, 70, 80)
  )
  result <- process_eurostat(df,
    filters = list(sex = "T", age = "Y25-64"),
    out_col = "rate")
  expect_equal(nrow(result), 1)
  expect_equal(result$rate, 50)
})

# --- merge_datasets ---

test_that("merge_datasets combines by geo and year", {
  df1 <- tibble::tibble(geo = c("DE11", "DE12"), year = c(2020L, 2020L), a = c(1, 2))
  df2 <- tibble::tibble(geo = c("DE11", "DE12"), year = c(2020L, 2020L), b = c(10, 20))
  result <- merge_datasets(df1, df2)
  expect_equal(nrow(result), 2)
  expect_true(all(c("a", "b") %in% names(result)))
  expect_equal(result$a, c(1, 2))
  expect_equal(result$b, c(10, 20))
})

test_that("merge_datasets full join keeps all rows", {
  df1 <- tibble::tibble(geo = "DE11", year = 2020L, a = 1)
  df2 <- tibble::tibble(geo = "FR10", year = 2020L, b = 2)
  result <- merge_datasets(df1, df2, join_type = "full")
  expect_equal(nrow(result), 2)
})

test_that("merge_datasets inner join keeps matching rows", {
  df1 <- tibble::tibble(geo = c("DE11", "FR10"), year = c(2020L, 2020L), a = c(1, 2))
  df2 <- tibble::tibble(geo = "DE11", year = 2020L, b = 10)
  result <- merge_datasets(df1, df2, join_type = "inner")
  expect_equal(nrow(result), 1)
  expect_equal(result$geo, "DE11")
})

# --- compute_composite ---

test_that("compute_composite averages score columns", {
  df <- tibble::tibble(
    geo   = "DE11",
    s1    = 80,
    s2    = 60,
    s3    = 40
  )
  result <- compute_composite(df, c("s1", "s2", "s3"), "comp")
  expect_equal(result$comp, 60)
})

test_that("compute_composite handles NAs", {
  df <- tibble::tibble(
    geo = "DE11",
    s1  = 100,
    s2  = NA_real_
  )
  result <- compute_composite(df, c("s1", "s2"), "comp")
  expect_equal(result$comp, 100)
})

# --- Domain-specific processors ---

test_that("process_gdp filters by unit", {
  df <- tibble::tibble(
    geo    = c("DE11", "DE11"),
    time   = c("2020", "2020"),
    unit   = c("MIO_EUR", "EUR_HAB"),
    values = c(500, 30000)
  )
  result <- process_gdp(df)
  expect_equal(nrow(result), 1)
  expect_equal(result$gdp, 500)
})

test_that("process_beds filters by unit", {
  df <- tibble::tibble(
    geo    = c("DE11", "DE11"),
    time   = c("2020", "2020"),
    unit   = c("P_HTHAB", "NR"),
    values = c(600, 50000)
  )
  result <- process_beds(df)
  expect_equal(nrow(result), 1)
  expect_equal(result$beds, 600)
})
