# --- DHS Fetch Layer Tests (offline — no API calls) ---

test_that("get_dhs_data validates indicator_ids", {
  expect_error(get_dhs_data(indicator_ids = NULL), "non-empty character")
  expect_error(get_dhs_data(indicator_ids = character(0)), "non-empty character")
  expect_error(get_dhs_data(indicator_ids = 123), "character vector")
})

test_that(".dhs_api_key returns a non-empty string", {
  # Internal function, access via :::
  key_fn <- localintel:::.dhs_api_key
  key <- key_fn()
  expect_type(key, "character")
  expect_true(nzchar(key))
})

test_that(".dhs_api_key respects DHS_API_KEY environment variable", {
  # Set a custom key
  old <- Sys.getenv("DHS_API_KEY", unset = NA)
  Sys.setenv(DHS_API_KEY = "TEST-KEY-12345")
  on.exit({
    if (is.na(old)) Sys.unsetenv("DHS_API_KEY") else Sys.setenv(DHS_API_KEY = old)
  })

  key_fn <- localintel:::.dhs_api_key
  expect_equal(key_fn(), "TEST-KEY-12345")
})

test_that("indicator code registries have valid DHS format", {
  # DHS codes follow pattern: XX_XXXX_X_XXX (2 + 4 + 1 + 3, separated by _)
  all_codes <- all_dhs_codes()
  for (code in all_codes) {
    parts <- strsplit(code, "_")[[1]]
    expect_true(length(parts) >= 3,
                info = paste("Code", code, "has fewer than 3 underscore-delimited parts"))
  }
})

test_that("fetch_dhs_batch validates inputs", {
  # Should fail gracefully with empty indicator list
  expect_error(
    fetch_dhs_batch(country_ids = "KE", indicator_list = list()),
    regexp = NULL  # any error is acceptable
  )
})
