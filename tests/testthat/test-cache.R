# --- Session Cache ---

test_that("cache_set and cache_get round-trip works", {
  key <- "test_key_roundtrip"
  cache_set(key, 42)
  expect_equal(cache_get(key), 42)
})

test_that("cache_get returns NULL for missing key", {
  result <- cache_get("nonexistent_key_xyz_123")
  expect_null(result)
})

test_that("cache_set overwrites existing value", {
  key <- "test_key_overwrite"
  cache_set(key, "old")
  cache_set(key, "new")
  expect_equal(cache_get(key), "new")
})

test_that("cache_key builds deterministic keys", {
  k1 <- cache_key("get_nuts2_ref", 2024, "60")
  k2 <- cache_key("get_nuts2_ref", 2024, "60")
  k3 <- cache_key("get_nuts2_ref", 2021, "60")
  expect_equal(k1, k2)
  expect_false(k1 == k3)
})

test_that("clear_localintel_cache removes all cached values", {
  cache_set("clear_test_a", 1)
  cache_set("clear_test_b", 2)
  expect_equal(cache_get("clear_test_a"), 1)
  expect_message(clear_localintel_cache(), "cache cleared")
  expect_null(cache_get("clear_test_a"))
  expect_null(cache_get("clear_test_b"))
})

test_that("cache stores complex objects", {
  key <- "test_complex_obj"
  df <- tibble::tibble(geo = c("DE11", "FR10"), val = c(1, 2))
  cache_set(key, df)
  result <- cache_get(key)
  expect_equal(result, df)
  # Clean up
  clear_localintel_cache()
})
