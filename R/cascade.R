#' @title Data Cascading Functions
#' @description Functions for cascading data from higher to lower NUTS levels,
#'   with optional adaptive econometric imputation for temporal gap-filling.
#' @name cascade
NULL

#' Cascade Data to NUTS2 and Compute Indicators
#'
#' Cascades data from NUTS0/NUTS1 to NUTS2 level and computes derived indicators
#' including Discharge Activity (DA) and Relative Length of Stay (rLOS).
#' Uses session-cached NUTS2 reference via \code{\link{get_nuts2_ref}()}.
#'
#' @param data Dataframe with 'geo', 'year', and variable columns
#' @param vars Character vector of variable names to cascade
#' @param years Integer vector of years to include. If NULL, uses all available years.
#' @param nuts2_ref Reference table from get_nuts2_ref(). If NULL, fetched automatically (cached).
#' @param nuts_year Integer year for NUTS classification (default: 2024)
#' @return Dataframe with cascaded values and computed indicators
#' @export
#' @examples
#' \dontrun{
#' result <- cascade_to_nuts2_and_compute(data,
#'   vars = c("beds", "physicians", "los"),
#'   years = 2010:2024)
#' }
cascade_to_nuts2_and_compute <- function(data,
                                         vars = c("disch_inp", "disch_day", "beds", "physicians", "los"),
                                         years = NULL,
                                         nuts2_ref = NULL,
                                         nuts_year = 2024) {
  # Get NUTS2 reference if not provided (uses session cache)
  if (is.null(nuts2_ref)) {
    nuts2_ref <- get_nuts2_ref(year = nuts_year)
  }

  # Ensure year column exists
  if (!"year" %in% names(data)) {
    if ("time" %in% names(data)) {
      data <- dplyr::mutate(data, year = as.integer(substr(as.character(.data$time), 1, 4)))
    } else {
      stop("Provide a 'year' or 'time' column.")
    }
  }

  stopifnot(all(c("geo", "year") %in% names(data)), all(vars %in% names(data)))
  stopifnot(all(c("geo", "nuts1", "nuts0") %in% names(nuts2_ref)))

  # Set years and create skeleton
  if (is.null(years)) {
    years <- sort(unique(data$year))
  }
  skeleton <- tidyr::expand_grid(nuts2_ref, tibble::tibble(year = years))

  # Cascade each variable
  cascade_one <- function(var) {
    d <- data %>% dplyr::select("geo", "year", !!rlang::sym(var))
    v2 <- d %>% dplyr::filter(nchar(.data$geo) == 4) %>% dplyr::rename(val2 = !!rlang::sym(var))
    v1 <- d %>% dplyr::filter(nchar(.data$geo) == 3) %>% dplyr::transmute(nuts1 = .data$geo, year = .data$year, val1 = !!rlang::sym(var))
    v0 <- d %>% dplyr::filter(nchar(.data$geo) == 2) %>% dplyr::transmute(nuts0 = .data$geo, year = .data$year, val0 = !!rlang::sym(var))

    skeleton %>%
      dplyr::left_join(v2, by = c("geo", "year")) %>%
      dplyr::left_join(v1, by = c("nuts1", "year")) %>%
      dplyr::left_join(v0, by = c("nuts0", "year")) %>%
      dplyr::mutate(
        !!var := dplyr::coalesce(.data$val2, .data$val1, .data$val0),
        !!paste0("src_", var, "_level") := dplyr::case_when(
          !is.na(.data$val2) ~ 2L,
          is.na(.data$val2) & !is.na(.data$val1) ~ 1L,
          is.na(.data$val2) & is.na(.data$val1) & !is.na(.data$val0) ~ 0L,
          TRUE ~ NA_integer_
        )
      ) %>%
      dplyr::select("geo", "year", !!rlang::sym(var), !!rlang::sym(paste0("src_", var, "_level")))
  }

  cascaded <- Reduce(
    function(a, b) dplyr::left_join(a, b, by = c("geo", "year")),
    lapply(vars, cascade_one)
  )

  # National LOS for denominator
  los_nat <- data %>%
    dplyr::filter(nchar(.data$geo) == 2) %>%
    dplyr::transmute(ctry = .data$geo, year = .data$year, los_nat = .data$los) %>%
    dplyr::distinct(.data$ctry, .data$year, .keep_all = TRUE)

  # Compute derived indicators
  out <- cascaded %>%
    dplyr::mutate(
      # DA eligibility
      elig_da_level = pmax(
        !!!rlang::syms(paste0("src_", c("disch_inp", "disch_day", "beds"), "_level")),
        na.rm = TRUE
      ),
      elig_da_level = ifelse(is.infinite(.data$elig_da_level), NA_real_, .data$elig_da_level),

      da_num = .data$disch_inp + .data$disch_day,
      da_den = .data$beds,
      da = ifelse(!is.na(.data$elig_da_level) & .data$elig_da_level >= 1, {
        nlog <- safe_log2(.data$da_num)
        dlog <- safe_log2(.data$da_den)
        ifelse(is.na(nlog) | is.na(dlog), NA_real_, nlog / dlog)
      }, NA_real_),

      physicians_log2 = safe_log2(.data$physicians),
      ctry = substr(.data$geo, 1, 2)
    ) %>%
    dplyr::left_join(los_nat, by = c("ctry" = "ctry", "year" = "year")) %>%
    dplyr::mutate(
      elig_rlos_level = .data[["src_los_level"]],
      rlos = ifelse(
        !is.na(.data$elig_rlos_level) & .data$elig_rlos_level >= 1 &
          !is.na(.data$los_nat) & .data$los_nat > 0,
        .data$los / .data$los_nat,
        NA_real_
      )
    ) %>%
    dplyr::select(-"ctry", -"da_num", -"da_den") %>%
    dplyr::arrange(.data$geo, .data$year)

  out
}

#' Cascade to NUTS2 (Light Version)
#'
#' A lighter version of cascade that simply copies values from higher NUTS levels
#' to NUTS2 without computing derived indicators.
#'
#' @param data Dataframe with 'geo', 'year', and variable columns
#' @param vars Character vector of variable names to cascade
#' @param nuts2_ref Reference table from get_nuts2_ref()
#' @param years Integer vector of years to include. If NULL, uses all available years.
#' @param agg Aggregation function for duplicates (default: dplyr::first)
#' @return Dataframe with cascaded values at NUTS2 level
#' @export
#' @examples
#' \dontrun{
#' result <- cascade_to_nuts2_light(data,
#'   vars = c("score_health_outcome", "score_ee"),
#'   nuts2_ref = nuts2_ref,
#'   years = 2010:2024)
#' }
cascade_to_nuts2_light <- function(data, vars, nuts2_ref, years = NULL, agg = dplyr::first) {
  # Ensure year column
  if (!"year" %in% names(data)) {
    if ("time" %in% names(data)) {
      data <- dplyr::mutate(data, year = as.integer(substr(as.character(.data$time), 1, 4)))
    } else {
      stop("Provide 'year' or 'time'.")
    }
  }

  stopifnot(all(c("geo", "year") %in% names(data)), all(vars %in% names(data)))
  if (is.null(years)) years <- sort(unique(data$year))

  # Keep only countries present in data
  ctries <- unique(substr(data$geo, 1, 2))
  map2 <- nuts2_ref %>%
    dplyr::filter(substr(.data$geo, 1, 2) %in% ctries) %>%
    dplyr::transmute(geo2 = .data$geo, nuts1 = .data$nuts1, nuts0 = .data$nuts0)

  cascade_var <- function(v) {
    dat <- dplyr::select(data, "geo", "year", value = dplyr::all_of(v)) %>%
      dplyr::filter(!is.na(.data$value))

    # NUTS2
    v2 <- dat %>%
      dplyr::filter(nchar(.data$geo) == 4) %>%
      dplyr::group_by(.data$geo, .data$year) %>%
      dplyr::summarise(val2 = agg(.data$value), .groups = "drop")

    # NUTS1 -> expand to NUTS2 children
    v1_agg <- dat %>%
      dplyr::filter(nchar(.data$geo) == 3) %>%
      dplyr::transmute(nuts1 = .data$geo, year = .data$year, value = .data$value) %>%
      dplyr::group_by(.data$nuts1, .data$year) %>%
      dplyr::summarise(val1 = agg(.data$value), .groups = "drop")
    v1 <- map2 %>%
      dplyr::select(geo = "geo2", "nuts1") %>%
      dplyr::inner_join(v1_agg, by = "nuts1") %>%
      dplyr::select("geo", "year", "val1")

    # NUTS0 -> expand to all NUTS2 children
    v0_agg <- dat %>%
      dplyr::filter(nchar(.data$geo) == 2) %>%
      dplyr::transmute(nuts0 = .data$geo, year = .data$year, value = .data$value) %>%
      dplyr::group_by(.data$nuts0, .data$year) %>%
      dplyr::summarise(val0 = agg(.data$value), .groups = "drop")
    v0 <- map2 %>%
      dplyr::select(geo = "geo2", "nuts0") %>%
      dplyr::inner_join(v0_agg, by = "nuts0") %>%
      dplyr::select("geo", "year", "val0")

    # Combine keys
    keys <- dplyr::bind_rows(
      dplyr::select(v2, "geo", "year"),
      dplyr::select(v1, "geo", "year"),
      dplyr::select(v0, "geo", "year")
    ) %>%
      dplyr::distinct() %>%
      dplyr::filter(.data$year %in% years)

    dplyr::left_join(keys, v2, by = c("geo", "year")) %>%
      dplyr::left_join(v1, by = c("geo", "year")) %>%
      dplyr::left_join(v0, by = c("geo", "year")) %>%
      dplyr::mutate(
        !!v := dplyr::coalesce(.data$val2, .data$val1, .data$val0),
        !!paste0("src_", v, "_level") := dplyr::case_when(
          !is.na(.data$val2) ~ 2L,
          is.na(.data$val2) & !is.na(.data$val1) ~ 1L,
          is.na(.data$val2) & is.na(.data$val1) & !is.na(.data$val0) ~ 0L,
          TRUE ~ NA_integer_
        )
      ) %>%
      dplyr::select("geo", "year", dplyr::all_of(v), dplyr::all_of(paste0("src_", v, "_level")))
  }

  res_list <- lapply(vars, cascade_var)
  Reduce(function(a, b) dplyr::left_join(a, b, by = c("geo", "year")), res_list) %>%
    dplyr::arrange(.data$geo, .data$year)
}

#' Balance Panel Data
#'
#' Ensures all geo-year combinations exist and fills missing values
#'
#' @param data Dataframe with 'geo' and 'year' columns
#' @param vars Character vector of variable names to fill
#' @param years Integer vector of years to include
#' @param fill_direction Direction for filling ("downup", "down", "up")
#' @return Balanced panel dataframe
#' @export
#' @examples
#' \dontrun{
#' balanced <- balance_panel(data, vars = c("beds", "los"), years = 2010:2024)
#' }
balance_panel <- function(data, vars, years, fill_direction = "downup") {
  data %>%
    dplyr::group_by(.data$geo) %>%
    tidyr::complete(year = years) %>%
    dplyr::arrange(.data$geo, .data$year) %>%
    tidyr::fill(dplyr::all_of(vars), .direction = fill_direction) %>%
    dplyr::ungroup()
}

#' Cascade Data to NUTS2 (Generic / Domain-Agnostic)
#'
#' Cascades data from NUTS0/NUTS1 to NUTS2 level for any set of variables
#' from any thematic domain. Unlike \code{cascade_to_nuts2_and_compute()},
#' this function performs pure cascading without computing domain-specific
#' derived indicators, making it suitable for economy, education, labour,
#' environment, or any other Eurostat domain.
#'
#' When \code{impute = TRUE} (the default), adaptive econometric imputation
#' is applied after cascading to fill temporal gaps within each region's
#' time series. This uses PCHIP interpolation for internal gaps and optionally
#' ETS autoregressive forecasting for future periods (when \code{forecast_to}
#' is specified). The best model is selected automatically via AIC.
#'
#' @param data Dataframe with 'geo', 'year', and variable columns. May contain
#'   data at mixed NUTS levels (identified by geo code length: 2=NUTS0, 3=NUTS1, 4=NUTS2).
#' @param vars Character vector of variable names to cascade
#' @param years Integer vector of years to include. If NULL, uses all available years.
#' @param nuts2_ref Reference table from \code{get_nuts2_ref()}. If NULL, fetched
#'   automatically (session-cached for instant repeated access).
#' @param nuts_year Integer year for NUTS classification (default: 2024)
#' @param impute Logical. If TRUE (default), apply adaptive econometric imputation
#'   (PCHIP + optional ETS) to fill temporal gaps after cascading.
#' @param forecast_to Integer year. If specified and greater than max(years),
#'   extend the series with ETS autoregressive forecasts up to this year.
#'   Only used when \code{impute = TRUE}.
#' @return Dataframe with cascaded values at NUTS2 level. For each variable \code{v}:
#'   \itemize{
#'     \item \code{src_v_level}: source NUTS level (2 = original NUTS2,
#'       1 = cascaded from NUTS1, 0 = cascaded from NUTS0)
#'     \item \code{imp_v_flag}: imputation flag (0 = observed/cascaded,
#'       1 = PCHIP interpolated, 2 = ETS forecasted). Only present when
#'       \code{impute = TRUE}.
#'   }
#' @export
#' @examples
#' \dontrun{
#' # Cascade with adaptive imputation (default)
#' result <- cascade_to_nuts2(
#'   all_data,
#'   vars = c("gdp", "unemployment_rate"),
#'   years = 2015:2024,
#'   impute = TRUE
#' )
#'
#' # Cascade with imputation + forecasting to 2025
#' result <- cascade_to_nuts2(
#'   all_data,
#'   vars = c("gdp", "unemployment_rate"),
#'   years = 2015:2024,
#'   impute = TRUE,
#'   forecast_to = 2025
#' )
#'
#' # Check traceability
#' table(result$src_gdp_level)   # cascade source
#' table(result$imp_gdp_flag)    # imputation method
#'
#' # Cascade without imputation (legacy behaviour)
#' result <- cascade_to_nuts2(
#'   all_data,
#'   vars = c("gdp", "unemployment_rate"),
#'   years = 2015:2024,
#'   impute = FALSE
#' )
#' }
cascade_to_nuts2 <- function(data,
                             vars,
                             years = NULL,
                             nuts2_ref = NULL,
                             nuts_year = 2024,
                             impute = TRUE,
                             forecast_to = NULL) {
  # Get NUTS2 reference if not provided (uses session cache)
  if (is.null(nuts2_ref)) {
    nuts2_ref <- get_nuts2_ref(year = nuts_year)
  }

  # Ensure year column exists
  if (!"year" %in% names(data)) {
    if ("time" %in% names(data)) {
      data <- dplyr::mutate(data, year = as.integer(substr(as.character(.data$time), 1, 4)))
    } else {
      stop("Provide a 'year' or 'time' column.")
    }
  }

  stopifnot(all(c("geo", "year") %in% names(data)), all(vars %in% names(data)))
  stopifnot(all(c("geo", "nuts1", "nuts0") %in% names(nuts2_ref)))

  # Set years and create skeleton
  if (is.null(years)) {
    years <- sort(unique(data$year))
  }
  skeleton <- tidyr::expand_grid(nuts2_ref, tibble::tibble(year = years))

  # Cascade each variable
  cascade_one <- function(var) {
    d <- data %>% dplyr::select("geo", "year", !!rlang::sym(var))
    v2 <- d %>% dplyr::filter(nchar(.data$geo) == 4) %>% dplyr::rename(val2 = !!rlang::sym(var))
    v1 <- d %>% dplyr::filter(nchar(.data$geo) == 3) %>% dplyr::transmute(nuts1 = .data$geo, year = .data$year, val1 = !!rlang::sym(var))
    v0 <- d %>% dplyr::filter(nchar(.data$geo) == 2) %>% dplyr::transmute(nuts0 = .data$geo, year = .data$year, val0 = !!rlang::sym(var))

    skeleton %>%
      dplyr::left_join(v2, by = c("geo", "year")) %>%
      dplyr::left_join(v1, by = c("nuts1", "year")) %>%
      dplyr::left_join(v0, by = c("nuts0", "year")) %>%
      dplyr::mutate(
        !!var := dplyr::coalesce(.data$val2, .data$val1, .data$val0),
        !!paste0("src_", var, "_level") := dplyr::case_when(
          !is.na(.data$val2) ~ 2L,
          is.na(.data$val2) & !is.na(.data$val1) ~ 1L,
          is.na(.data$val2) & is.na(.data$val1) & !is.na(.data$val0) ~ 0L,
          TRUE ~ NA_integer_
        )
      ) %>%
      dplyr::select("geo", "year", !!rlang::sym(var), !!rlang::sym(paste0("src_", var, "_level")))
  }

  cascaded <- Reduce(
    function(a, b) dplyr::left_join(a, b, by = c("geo", "year")),
    lapply(vars, cascade_one)
  )

  # --- Adaptive Econometric Imputation ---
  if (impute) {
    # Determine extended years if forecasting
    all_years <- sort(unique(cascaded$year))
    if (!is.null(forecast_to) && forecast_to > max(all_years)) {
      extra_years <- seq(max(all_years) + 1L, as.integer(forecast_to))
      # Expand the cascaded dataframe to include forecast years
      extra_skeleton <- tidyr::expand_grid(
        tibble::tibble(geo = unique(cascaded$geo)),
        tibble::tibble(year = extra_years)
      )
      # Add nuts1/nuts0 if present
      if ("nuts1" %in% names(cascaded)) {
        geo_ref <- cascaded %>%
          dplyr::select("geo", "nuts1", "nuts0") %>%
          dplyr::distinct()
        extra_skeleton <- extra_skeleton %>%
          dplyr::left_join(geo_ref, by = "geo")
      }
      cascaded <- dplyr::bind_rows(cascaded, extra_skeleton)
      all_years <- sort(unique(cascaded$year))
    }

    # Apply imputation per variable per region
    for (var in vars) {
      flag_col <- paste0("imp_", var, "_flag")
      cascaded[[flag_col]] <- 0L

      # Split by geo, impute, reassemble
      geos <- unique(cascaded$geo)
      for (g in geos) {
        idx <- which(cascaded$geo == g)
        if (length(idx) == 0) next

        sub <- cascaded[idx, ]
        sub <- sub[order(sub$year), ]
        y_vals <- sub[[var]]

        # Skip if all NA or no NAs to fill
        if (all(is.na(y_vals)) || !any(is.na(y_vals))) {
          cascaded[[flag_col]][idx] <- ifelse(is.na(y_vals), NA_integer_, 0L)
          next
        }

        result <- impute_series(
          y = y_vals,
          years = sub$year,
          forecast_to = forecast_to
        )

        # Write back (result length matches sub if no forecast extension,
        # or the extension was already done above)
        cascaded[[var]][idx[order(sub$year)]] <- result$value[seq_along(idx)]
        cascaded[[flag_col]][idx[order(sub$year)]] <- result$flag[seq_along(idx)]
      }
    }
  }

  cascaded %>%
    dplyr::arrange(.data$geo, .data$year)
}
