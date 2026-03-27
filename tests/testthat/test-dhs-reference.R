# --- DHS Reference Layer Tests ---

test_that("ssa_codes returns 44 unique DHS country codes", {
  codes <- ssa_codes()
  expect_type(codes, "character")
  expect_length(codes, 44)
  expect_equal(length(unique(codes)), 44)
  # All codes should be 2-letter

  expect_true(all(nchar(codes) == 2))
})

test_that("tier1_codes is a proper subset of ssa_codes", {
  t1 <- tier1_codes()
  ssa <- ssa_codes()
  expect_length(t1, 15)
  expect_true(all(t1 %in% ssa))
})

test_that("dhs_var_labels returns named character vector for all indicators", {
  labs <- dhs_var_labels()
  expect_type(labs, "character")
  expect_true(length(labs) >= 62)
  expect_true(all(nzchar(names(labs))))
  expect_true(all(nzchar(labs)))
})

test_that("dhs_domain_mapping covers all indicator labels", {
  labs <- dhs_var_labels()
  doms <- dhs_domain_mapping()
  expect_true(length(doms) >= 62)
  # Every labeled indicator has a domain
  expect_true(all(names(labs)[names(labs) %in% names(doms)] %in% names(doms)))
})

test_that("all_dhs_codes returns all 8 domain registries", {
  all_codes <- all_dhs_codes()
  expect_type(all_codes, "character")
  expect_true(length(all_codes) >= 60)
  # Sum of domains should equal total
  domain_sum <- sum(
    length(dhs_health_codes()),
    length(dhs_mortality_codes()),
    length(dhs_nutrition_codes()),
    length(dhs_hiv_codes()),
    length(dhs_education_codes()),
    length(dhs_wash_codes()),
    length(dhs_wealth_codes()),
    length(dhs_gender_codes())
  )
  expect_equal(length(all_codes), domain_sum)
})

test_that("dhs_indicator_count matches length of all_dhs_codes", {
  expect_equal(dhs_indicator_count()$indicators, length(all_dhs_codes()))
})

test_that("keep_ssa filters to SSA countries only", {
  df <- tibble::tibble(
    geo    = c("KE_Nairobi", "NG_Lagos", "XX_Region", "US_State", "BF_Ouaga"),
    value  = 1:5
  )
  result <- keep_ssa(df)
  expect_equal(nrow(result), 3)  # KE, NG, BF
  expect_true(all(substr(result$geo, 1, 2) %in% ssa_codes()))
})
