#' @title DHS Cascade & Panel Assembly Functions
#' @description Assembles gap-filled DHS indicator data into a harmonised
#'   analysis-ready panel aligned to the Admin 1 reference skeleton. This is
#'   the DHS counterpart of the Eurostat \code{\link{cascade_to_nuts2}()} layer.
#'
#'   **Key difference from Eurostat**: DHS data is collected directly at Admin 1,
#'   so there is no multi-level hierarchy to cascade (NUTS0 → NUTS1 → NUTS2).
#'   Instead, this layer performs:
#'   \enumerate{
#'     \item Reference alignment — ensures every region × year cell exists
#'     \item Format harmonisation — mirrors Eurostat output columns:
#'       \code{<var>}, \code{src_<var>_level}, \code{imp_<var>_flag}
#'     \item Panel balancing — optionally drops thin indicators/regions
#'   }
#'
#'   The output is suitable for direct merge with the Eurostat panel
#'   for comparative analysis.
#' @name dhs_cascade
NULL


# ============================================================================
# CORE PANEL ASSEMBLY
# ============================================================================

#' Assemble DHS Gap-Filled Data into Admin 1 Panel
#'
#' Takes the output of \code{\link{gapfill_all_dhs}()} and reshapes it into a
#' single wide-format panel aligned to the Admin 1 reference skeleton. The
#' output format mirrors \code{\link{cascade_to_nuts2}()}: one row per
#' region × year, with columns \code{<var>}, \code{src_<var>_level}, and
#' \code{imp_<var>_flag} per indicator.
#'
#' Since DHS data comes directly from Admin 1 surveys (no parent-level
#' aggregates to cascade), \code{src_<var>_level} is always \code{1L}
#' (Admin 1 direct) for non-missing cells.
#'
#' @param gapfill_result Output of \code{\link{gapfill_all_dhs}()}: a list
#'   with \code{$data} (named list of tibbles per indicator) and
#'   \code{$summary} (diagnostics tibble).
#' @param admin1_ref Admin 1 reference table from \code{\link{get_admin1_ref}()}.
#'   If NULL (default), built automatically from the countries present in the
#'   gap-filled data.
#' @param years Integer vector of years to include. If NULL (default), uses
#'   the year range observed across all indicators.
#' @param include_ci Logical: if TRUE (default), includes \code{<var>_ci_lo}
#'   and \code{<var>_ci_hi} columns for each indicator.
#' @param national_fallback Logical: if TRUE (default), fills NA cells with
#'   national-level DHS values where available. These are marked with
#'   \code{imp_<var>_flag = 3L} and \code{src_<var>_level = 0L}.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{geo}{Composite key: \code{DHS_CountryCode + "_" + Region}}
#'     \item{admin0}{2-letter DHS country code}
#'     \item{year}{Integer year}
#'     \item{<var>}{Point estimate for each indicator}
#'     \item{<var>_ci_lo}{Lower 95\% CI bound (if \code{include_ci = TRUE})}
#'     \item{<var>_ci_hi}{Upper 95\% CI bound (if \code{include_ci = TRUE})}
#'     \item{src_<var>_level}{Integer source level: \code{0L} = national
#'       fallback, \code{1L} = Admin 1 direct, \code{NA} = no data}
#'     \item{imp_<var>_flag}{Integer imputation flag: \code{0L} = observed
#'       (DHS survey value), \code{1L} = interpolated (gap-filled between
#'       surveys), \code{2L} = forecasted (ETS), \code{3L} = national-level
#'       fallback, \code{NA} = no data}
#'   }
#'
#' @details
#' **Comparison with Eurostat pipeline:**
#' \tabular{lll}{
#'   Feature \tab Eurostat (NUTS2) \tab DHS (Admin 1) \cr
#'   Hierarchy \tab 3-level (0→1→2) \tab 1-level (direct) \cr
#'   Cascading \tab Coalesce NUTS0/1 to NUTS2 \tab None needed \cr
#'   src_level values \tab 0, 1, 2 \tab 0, 1 (0 = national fallback) \cr
#'   Interpolation \tab PCHIP (monotone Hermite) \tab FMM spline (calibrated) \cr
#'   Forecasting \tab ETS autoregressive \tab None (interpolation only) \cr
#'   imp_flag values \tab 0, 1, 2 \tab 0, 1, 2, 3 \cr
#'   Uncertainty \tab None \tab GAM SE + sigma_floor \cr
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' # Full pipeline: fetch → process → gapfill → cascade
#' gf <- gapfill_all_dhs(country_ids = tier1_codes())
#' panel <- cascade_to_admin1(gf)
#'
#' # Check dimensions
#' dim(panel)
#' names(panel)
#'
#' # Filter to one country
#' panel |> dplyr::filter(admin0 == "KE")
#' }
cascade_to_admin1 <- function(gapfill_result,
                               admin1_ref = NULL,
                               years = NULL,
                               include_ci = TRUE,
                               national_fallback = TRUE) {

  data_list <- gapfill_result$data
  if (length(data_list) == 0) {
    warning("No gap-filled data to assemble", call. = FALSE)
    return(tibble::tibble(geo = character(), admin0 = character(),
                          year = integer()))
  }

  # --- Discover countries from data ---
  all_geos <- unique(unlist(lapply(data_list, function(d) d$geo)))
  country_ids <- unique(substr(all_geos, 1, 2))

  # --- Build reference skeleton ---
  if (is.null(admin1_ref)) {
    admin1_ref <- get_admin1_ref(country_ids)
  }

  # --- Determine year range ---
  if (is.null(years)) {
    all_years <- unlist(lapply(data_list, function(d) d$year))
    years <- seq(min(all_years), max(all_years))
  }

  # --- Create skeleton: every region × year ---
  skeleton <- tidyr::expand_grid(
    admin1_ref |> dplyr::select("geo", "admin0"),
    tibble::tibble(year = years)
  )

  # Also include regions from data that might not be in admin1_ref

  # (reference is built from a single indicator; data may have more regions)
  data_regions <- tibble::tibble(
    geo = all_geos,
    admin0 = substr(all_geos, 1, 2)
  ) |> dplyr::distinct()

  extra_regions <- dplyr::anti_join(data_regions, admin1_ref,
                                     by = "geo")
  if (nrow(extra_regions) > 0) {
    extra_skeleton <- tidyr::expand_grid(
      extra_regions,
      tibble::tibble(year = years)
    )
    skeleton <- dplyr::bind_rows(skeleton, extra_skeleton)
  }

  # --- Join each indicator to the skeleton ---
  join_one <- function(ind_name, ind_data) {
    # Reshape indicator data to one row per region × year
    wide <- ind_data |>
      dplyr::select("geo", "year", "estimate", "ci_lo", "ci_hi", "source")

    # Build output columns
    out <- skeleton |>
      dplyr::left_join(wide, by = c("geo", "year")) |>
      dplyr::mutate(
        # Source level: 1L = Admin 1 direct, NA = no data
        !!paste0("src_", ind_name, "_level") := dplyr::if_else(
          !is.na(.data$estimate), 1L, NA_integer_
        ),
        # Imputation flag: 0 = observed, 1 = interpolated, 2 = forecasted
        !!paste0("imp_", ind_name, "_flag") := dplyr::case_when(
          is.na(.data$source) ~ NA_integer_,
          .data$source == "observed" ~ 0L,
          .data$source == "interpolated" ~ 1L,
          .data$source == "forecasted" ~ 2L,
          TRUE ~ NA_integer_
        )
      )

    # Rename estimate → indicator name
    out <- out |>
      dplyr::rename(!!ind_name := "estimate")

    # CI columns
    if (include_ci) {
      out <- out |>
        dplyr::rename(
          !!paste0(ind_name, "_ci_lo") := "ci_lo",
          !!paste0(ind_name, "_ci_hi") := "ci_hi"
        )
    } else {
      out <- out |> dplyr::select(-"ci_lo", -"ci_hi")
    }

    # Drop the source column (encoded in imp_flag now)
    out |> dplyr::select(-"source")
  }

  # Process all indicators
  indicator_names <- names(data_list)
  joined_list <- lapply(indicator_names, function(nm) {
    join_one(nm, data_list[[nm]])
  })

  # Reduce-join all indicator panels on (geo, admin0, year)
  panel <- Reduce(
    function(a, b) {
      # b has geo, admin0, year + indicator columns
      # Drop geo/admin0 duplication from b
      b_cols <- setdiff(names(b), c("geo", "admin0", "year"))
      dplyr::left_join(a, b |> dplyr::select("geo", "year", dplyr::all_of(b_cols)),
                        by = c("geo", "year"))
    },
    joined_list
  )

  # --- National-level fallback ---
  # For regions where admin1 data is NA, fill with national-level DHS values.
  # Marked with imp_flag = 3 (national fallback), src_level = 0 (country level).
  if (national_fallback) {
    panel <- .apply_national_fallback(panel, indicator_names, country_ids)
  }

  panel |> dplyr::arrange(.data$admin0, .data$geo, .data$year)
}


# ============================================================================
# NATIONAL-LEVEL FALLBACK (INTERNAL)
# ============================================================================

#' Apply National-Level Fallback to Admin 1 Panel
#'
#' For cells where admin1 data is NA, fetches national-level DHS values and
#' fills them in. Uses \code{imp_flag = 3L} (national fallback) and
#' \code{src_level = 0L} (country level) to distinguish from admin1 data.
#'
#' @param panel Tibble from cascade_to_admin1() assembly step.
#' @param indicator_names Character vector of indicator column names.
#' @param country_ids Character vector of DHS country codes.
#' @return Updated panel tibble with national fallback values.
#' @keywords internal
.apply_national_fallback <- function(panel, indicator_names, country_ids) {
  # Get indicator code→name mapping from registries
  all_codes <- c(
    dhs_mortality_codes(), dhs_nutrition_codes(), dhs_health_codes(),
    dhs_wash_codes(), dhs_education_codes(), dhs_hiv_codes(),
    dhs_gender_codes(), dhs_wealth_codes()
  )
  # Build reverse lookup: panel name → DHS API code
  name_to_code <- stats::setNames(unname(all_codes), names(all_codes))

  # Fetch national-level data for all indicators
  codes_to_fetch <- unname(name_to_code[indicator_names])
  codes_to_fetch <- codes_to_fetch[!is.na(codes_to_fetch)]

  if (length(codes_to_fetch) == 0) return(panel)

  message("  Fetching national-level fallback data...")
  national_raw <- tryCatch(
    get_dhs_data(
      indicator_ids = codes_to_fetch,
      country_ids = country_ids,
      breakdown = "national"
    ),
    error = function(e) {
      warning("National fallback fetch failed: ", e$message, call. = FALSE)
      return(NULL)
    }
  )

  if (is.null(national_raw) || nrow(national_raw) == 0) {
    message("  No national-level data available, skipping fallback")
    return(panel)
  }

  # Build lookup: admin0 × year × indicator_code → value
  # Map DHS codes back to panel column names
  code_to_name <- stats::setNames(names(name_to_code),
                                   unname(name_to_code))
  national_raw$panel_name <- code_to_name[national_raw$IndicatorId]

  # Keep only records with valid panel names
  national_raw <- national_raw[!is.na(national_raw$panel_name), ]

  n_filled <- 0L

  for (ind_name in indicator_names) {
    flag_col <- paste0("imp_", ind_name, "_flag")
    src_col <- paste0("src_", ind_name, "_level")

    if (!ind_name %in% names(panel) || !flag_col %in% names(panel)) next

    # National values for this indicator
    nat_ind <- national_raw[national_raw$panel_name == ind_name, ]
    if (nrow(nat_ind) == 0) next

    # Build lookup: admin0_year → value
    nat_lookup <- stats::setNames(
      nat_ind$Value,
      paste0(nat_ind$DHS_CountryCode, "_", nat_ind$SurveyYear)
    )

    # Find NA cells for this indicator
    na_mask <- is.na(panel[[ind_name]])
    if (!any(na_mask)) next

    # For each NA cell, look up the national value by admin0 × nearest survey year
    na_rows <- which(na_mask)
    for (idx in na_rows) {
      admin0 <- panel$admin0[idx]
      yr <- panel$year[idx]

      # Exact year match first
      key <- paste0(admin0, "_", yr)
      if (key %in% names(nat_lookup)) {
        panel[[ind_name]][idx] <- nat_lookup[[key]]
        panel[[flag_col]][idx] <- 3L
        panel[[src_col]][idx] <- 0L
        n_filled <- n_filled + 1L
        next
      }

      # Nearest survey year within ±5 years
      admin0_keys <- names(nat_lookup)[startsWith(names(nat_lookup),
                                                    paste0(admin0, "_"))]
      if (length(admin0_keys) > 0) {
        admin0_years <- as.integer(sub(".*_", "", admin0_keys))
        nearest_idx <- which.min(abs(admin0_years - yr))
        if (abs(admin0_years[nearest_idx] - yr) <= 5) {
          panel[[ind_name]][idx] <- nat_lookup[[admin0_keys[nearest_idx]]]
          panel[[flag_col]][idx] <- 3L
          panel[[src_col]][idx] <- 0L
          n_filled <- n_filled + 1L
        }
      }
    }
  }

  message("  National fallback: filled ", n_filled, " cells across ",
          length(indicator_names), " indicators")
  panel
}


# ============================================================================
# PANEL BALANCING
# ============================================================================

#' Balance DHS Admin 1 Panel
#'
#' Drops indicators or regions with insufficient coverage from the panel.
#' Mirrors \code{\link{balance_panel}()} for the Eurostat pipeline.
#'
#' Balancing is performed in two passes:
#' \enumerate{
#'   \item **Indicator pass**: drops indicators where fewer than
#'     \code{min_countries} have data.
#'   \item **Region pass**: drops regions where fewer than
#'     \code{min_indicators} have any non-NA value.
#' }
#'
#' @param panel Tibble from \code{\link{cascade_to_admin1}()}.
#' @param indicators Character vector of indicator column names to check.
#'   If NULL (default), auto-detected from columns with a matching
#'   \code{imp_<name>_flag} column.
#' @param min_countries Integer: minimum number of countries an indicator
#'   must cover to be retained (default: 5).
#' @param min_indicators Integer: minimum number of non-NA indicators a
#'   region must have in at least one year to be retained (default: 10).
#' @param verbose Logical: print diagnostics (default: TRUE).
#'
#' @return A list with:
#'   \describe{
#'     \item{panel}{Balanced tibble.}
#'     \item{dropped_indicators}{Character vector of dropped indicator names.}
#'     \item{dropped_regions}{Character vector of dropped region geo codes.}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' gf <- gapfill_all_dhs()
#' raw_panel <- cascade_to_admin1(gf)
#' balanced <- balance_dhs_panel(raw_panel)
#' balanced$panel
#' }
balance_dhs_panel <- function(panel,
                               indicators = NULL,
                               min_countries = 5L,
                               min_indicators = 10L,
                               verbose = TRUE) {

  # Auto-detect indicator columns from imp_*_flag pattern

  if (is.null(indicators)) {
    flag_cols <- grep("^imp_(.+)_flag$", names(panel), value = TRUE)
    indicators <- sub("^imp_(.+)_flag$", "\\1", flag_cols)
  }

  if (length(indicators) == 0) {
    warning("No indicators found in panel", call. = FALSE)
    return(list(panel = panel, dropped_indicators = character(),
                dropped_regions = character()))
  }

  # --- Pass 1: Drop thin indicators ---
  ind_coverage <- vapply(indicators, function(v) {
    if (!v %in% names(panel)) return(0L)
    rows_with_data <- panel[!is.na(panel[[v]]), , drop = FALSE]
    length(unique(rows_with_data$admin0))
  }, integer(1))

  keep_ind <- names(ind_coverage[ind_coverage >= min_countries])
  drop_ind <- setdiff(indicators, keep_ind)

  if (verbose && length(drop_ind) > 0) {
    message("Dropping ", length(drop_ind), " indicators with < ",
            min_countries, " countries: ",
            paste(head(drop_ind, 5), collapse = ", "),
            if (length(drop_ind) > 5) "..." else "")
  }

  # Remove dropped indicator columns
  if (length(drop_ind) > 0) {
    drop_cols <- c(
      drop_ind,
      paste0(drop_ind, "_ci_lo"),
      paste0(drop_ind, "_ci_hi"),
      paste0("src_", drop_ind, "_level"),
      paste0("imp_", drop_ind, "_flag")
    )
    drop_cols <- intersect(drop_cols, names(panel))
    panel <- panel |> dplyr::select(-dplyr::all_of(drop_cols))
  }

  # --- Pass 2: Drop thin regions ---
  # Count how many indicators have at least one non-NA value per region
  # (avoid dplyr grouping complexity — use base R split)
  keep_ind_present <- intersect(keep_ind, names(panel))
  if (length(keep_ind_present) == 0) {
    # Nothing left after indicator pass
    return(list(panel = panel[0, ], dropped_indicators = drop_ind,
                dropped_regions = unique(panel$geo)))
  }

  region_counts <- vapply(split(panel, panel$geo), function(sub) {
    sum(vapply(keep_ind_present, function(v) any(!is.na(sub[[v]])),
               logical(1)))
  }, integer(1))
  region_coverage <- tibble::tibble(
    geo = names(region_counts),
    n_ind = unname(region_counts)
  )

  keep_geo <- region_coverage |>
    dplyr::filter(.data$n_ind >= min_indicators) |>
    dplyr::pull("geo")
  drop_geo <- setdiff(unique(panel$geo), keep_geo)

  if (verbose && length(drop_geo) > 0) {
    message("Dropping ", length(drop_geo), " regions with < ",
            min_indicators, " indicators")
  }

  panel <- panel |> dplyr::filter(.data$geo %in% keep_geo)

  if (verbose) {
    message("Balanced panel: ",
            dplyr::n_distinct(panel$geo), " regions x ",
            dplyr::n_distinct(panel$year), " years x ",
            length(keep_ind), " indicators")
  }

  list(
    panel = panel,
    dropped_indicators = drop_ind,
    dropped_regions = drop_geo
  )
}


# ============================================================================
# FULL PIPELINE WRAPPER
# ============================================================================

#' Full DHS Pipeline: Fetch → Process → Gap-Fill → Cascade
#'
#' Convenience wrapper that runs the complete DHS data pipeline from raw
#' API fetch through to a balanced analysis-ready panel. Calls
#' \code{\link{gapfill_all_dhs}()} and \code{\link{cascade_to_admin1}()}
#' in sequence.
#'
#' @param country_ids Character vector of DHS country codes.
#'   Defaults to \code{\link{ssa_codes}()}.
#' @param sigma_floor Numeric: minimum prediction SE for gap-filling
#'   (default: 0.25). Passed to \code{\link{gapfill_all_dhs}()}.
#' @param balance Logical: if TRUE (default), applies
#'   \code{\link{balance_dhs_panel}()} to the output.
#' @param min_countries Integer: for panel balancing (default: 5).
#' @param min_indicators Integer: for panel balancing (default: 10).
#' @param include_ci Logical: include CI columns (default: TRUE).
#' @param verbose Logical: print progress (default: TRUE).
#'
#' @return A list with:
#'   \describe{
#'     \item{panel}{The assembled (optionally balanced) panel tibble.}
#'     \item{gapfill_summary}{Diagnostics from \code{gapfill_all_dhs()}.}
#'     \item{dropped_indicators}{Indicators removed by balancing (if applied).}
#'     \item{dropped_regions}{Regions removed by balancing (if applied).}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' # Full SSA pipeline (takes ~15 minutes)
#' result <- dhs_pipeline(country_ids = ssa_codes())
#' dim(result$panel)
#'
#' # Tier 1 only (faster)
#' result_t1 <- dhs_pipeline(country_ids = tier1_codes())
#' }
dhs_pipeline <- function(country_ids = ssa_codes(),
                          sigma_floor = 0.25,
                          balance = TRUE,
                          min_countries = 5L,
                          min_indicators = 10L,
                          include_ci = TRUE,
                          national_fallback = TRUE,
                          verbose = TRUE) {

  # Step 1: Gap-fill all indicators
  if (verbose) message("=== Step 1/3: Gap-filling ===")
  gf <- gapfill_all_dhs(
    country_ids = country_ids,
    sigma_floor = sigma_floor,
    verbose = verbose
  )

  # Step 2: Assemble into panel
  if (verbose) message("\n=== Step 2/3: Assembling panel ===")
  panel <- cascade_to_admin1(
    gapfill_result = gf,
    include_ci = include_ci,
    national_fallback = national_fallback
  )

  if (verbose) {
    message("Raw panel: ",
            dplyr::n_distinct(panel$geo), " regions x ",
            dplyr::n_distinct(panel$year), " years x ",
            ncol(panel), " columns")
  }

  # Step 3: Balance (optional)
  dropped_ind <- character()
  dropped_geo <- character()

  if (balance) {
    if (verbose) message("\n=== Step 3/3: Balancing panel ===")
    bal <- balance_dhs_panel(
      panel,
      min_countries = min_countries,
      min_indicators = min_indicators,
      verbose = verbose
    )
    panel <- bal$panel
    dropped_ind <- bal$dropped_indicators
    dropped_geo <- bal$dropped_regions
  } else {
    if (verbose) message("\n=== Step 3/3: Skipping balance (balance = FALSE) ===")
  }

  if (verbose) {
    message("\n=== Pipeline complete ===")
  }

  list(
    panel = panel,
    gapfill_summary = gf$summary,
    dropped_indicators = dropped_ind,
    dropped_regions = dropped_geo
  )
}
