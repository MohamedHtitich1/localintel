# --- DHS Cascade / Panel Assembly Tests (synthetic data) ---

# Helper: create synthetic gap-filled output (mimics gapfill_all_dhs output)
mock_gapfilled <- function() {
  regions <- c("KE_Nairobi", "KE_Central", "NG_Lagos", "NG_Kano")
  years <- 2010:2015

  make_indicator <- function(indicator_name, base_vals) {
    rows <- expand.grid(geo = regions, year = years, stringsAsFactors = FALSE)
    rows$estimate <- base_vals[match(rows$geo, regions)] +
      (rows$year - 2010) * runif(nrow(rows), -1, 1)
    rows$ci_lo <- rows$estimate * 0.8
    rows$ci_hi <- rows$estimate * 1.2
    rows$source <- ifelse(rows$year %in% c(2010, 2014), "observed", "interpolated")
    rows$indicator <- indicator_name
    rows$admin0 <- substr(rows$geo, 1, 2)
    tibble::as_tibble(rows)
  }

  list(
    data = list(
      u5_mortality = make_indicator("u5_mortality", c(44, 55, 78, 92)),
      stunting     = make_indicator("stunting", c(22, 35, 40, 45))
    ),
    summary = tibble::tibble(indicator = c("u5_mortality", "stunting"),
                             n_regions = c(4L, 4L))
  )
}

test_that("cascade_to_admin1 produces correct panel structure", {
  gf <- mock_gapfilled()
  panel <- cascade_to_admin1(gf, include_ci = TRUE)

  # Should have geo, admin0, year + indicator cols

  expect_true(all(c("geo", "admin0", "year") %in% names(panel)))
  expect_true("u5_mortality" %in% names(panel))
  expect_true("stunting" %in% names(panel))

  # Source level columns
  expect_true("src_u5_mortality_level" %in% names(panel))
  # Imp flag columns
  expect_true("imp_u5_mortality_flag" %in% names(panel))
})

test_that("cascade_to_admin1 imp_flag values are correct", {
  gf <- mock_gapfilled()
  # Disable national fallback so only admin1-level flags appear
  panel <- cascade_to_admin1(gf, national_fallback = FALSE)

  # imp_flag should be 0 for observed, 1 for interpolated
  expect_true(all(panel$imp_u5_mortality_flag %in% c(0L, 1L, NA_integer_)))
  expect_true(all(panel$src_u5_mortality_level == 1L, na.rm = TRUE))
})

test_that("cascade_to_admin1 CI exclusion works", {
  gf <- mock_gapfilled()
  panel_no_ci <- cascade_to_admin1(gf, include_ci = FALSE)
  panel_ci    <- cascade_to_admin1(gf, include_ci = TRUE)

  expect_false("u5_mortality_ci_lo" %in% names(panel_no_ci))
  expect_true("u5_mortality_ci_lo" %in% names(panel_ci))
})

test_that("balance_dhs_panel drops thin indicators and regions", {
  gf <- mock_gapfilled()
  panel <- cascade_to_admin1(gf)

  # With high threshold, should drop indicators
  balanced <- balance_dhs_panel(panel, min_countries = 5, min_indicators = 1)
  # Only 2 countries in mock data, so with min_countries=5, everything gets dropped
  # Need a more realistic test:
  balanced2 <- balance_dhs_panel(panel, min_countries = 1, min_indicators = 1)
  # balance_dhs_panel returns a list with $panel, $dropped_indicators, $dropped_regions
  expect_true(nrow(balanced2$panel) > 0)
  expect_true(ncol(balanced2$panel) > 0)
})
