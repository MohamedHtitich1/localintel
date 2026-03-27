#' @title DHS Data Processing Functions
#' @description Functions for standardizing raw DHS API responses into the
#'   localintel \code{geo / year / value} format. Mirrors the pattern of
#'   \code{\link{process_eurostat}()} for the Eurostat pipeline.
#' @name dhs_process
NULL

# ============================================================================
# GENERIC DHS PROCESSOR
# ============================================================================

#' Process Raw DHS Data
#'
#' Transforms a raw DHS API response (from \code{\link{get_dhs_data}()}) into
#' the standard localintel \code{geo / year / value} structure. Handles:
#' \enumerate{
#'   \item Deduplication of exact API duplicates
#'   \item Reference-period filtering (mortality indicators)
#'   \item \code{ByVariableLabel} filtering (e.g., DV ever-married subset)
#'   \item Construction of a composite \code{geo} key:
#'         \code{DHS_CountryCode + "_" + CharacteristicLabel}
#'   \item Rename \code{SurveyYear} → \code{year}
#' }
#'
#' @param df Raw tibble from \code{get_dhs_data()} or \code{fetch_dhs_batch()}.
#' @param out_col Character name for the output value column.
#'   If NULL (default), uses \code{"value"}.
#' @param ref_period Character string to keep when a \code{ByVariableLabel}
#'   filter is needed. For mortality indicators, the API returns both
#'   "Five years preceding the survey" and "Ten years preceding the survey".
#'   Default: \code{"Five years preceding the survey"} (standard DHS practice).
#'   Set to \code{NULL} to skip reference-period filtering.
#' @param keep_ci Logical. If TRUE, retains \code{CILow} and \code{CIHigh}
#'   columns in the output (default: FALSE, since CIs are 90\% NA).
#' @param keep_denominator Logical. If TRUE, retains
#'   \code{DenominatorWeighted} in the output (default: FALSE).
#' @param keep_metadata Logical. If TRUE, retains \code{IndicatorId},
#'   \code{Indicator}, \code{SurveyId}, and \code{ByVariableLabel}
#'   columns (default: FALSE).
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{geo}{Composite key: \code{DHS_CountryCode + "_" + CharacteristicLabel}}
#'     \item{year}{Integer survey year}
#'     \item{[out_col]}{Numeric indicator value}
#'   }
#'   Plus optional CI, denominator, and metadata columns if requested.
#'
#' @export
#' @examples
#' \dontrun{
#' raw <- get_dhs_data(
#'   country_ids = c("KE", "NG"),
#'   indicator_ids = "CM_ECMR_C_U5M",
#'   breakdown = "subnational"
#' )
#'
#' # Basic usage
#' processed <- process_dhs(raw, out_col = "u5_mortality")
#'
#' # Keep metadata for debugging
#' processed <- process_dhs(raw, out_col = "u5_mortality",
#'                          keep_metadata = TRUE)
#'
#' # Skip reference-period filtering (non-mortality data)
#' raw_vacc <- get_dhs_data(
#'   country_ids = "KE",
#'   indicator_ids = "CH_VACC_C_BAS"
#' )
#' processed <- process_dhs(raw_vacc, out_col = "basic_vacc",
#'                          ref_period = NULL)
#' }
process_dhs <- function(df,
                        out_col = NULL,
                        ref_period = "Five years preceding the survey",
                        keep_ci = FALSE,
                        keep_denominator = FALSE,
                        keep_metadata = FALSE) {

  if (is.null(out_col)) out_col <- "value"

  # 1. Deduplicate exact API duplicates
  df <- dplyr::distinct(df)

  # 2. Reference-period filtering
  #    Mortality indicators return multiple reference periods per survey.
  #    At subnational level, DHS typically returns only one reference period
  #    (e.g., "Ten years preceding the survey"), while national-level data
  #    may have both "Five years" and "Ten years" variants.
  #
  #    Strategy: If the preferred ref_period exists, keep only those rows.

  #    If it doesn't exist but other ref periods do, keep the shortest
  #    available reference period (to get the most recent estimate).
  #    Rows with empty ByVariableLabel (non-mortality) are always kept.
  if (!is.null(ref_period) && "ByVariableLabel" %in% names(df)) {
    has_ref <- df$ByVariableLabel != ""
    if (any(has_ref)) {
      ref_labels <- unique(df$ByVariableLabel[has_ref])
      if (ref_period %in% ref_labels) {
        # Preferred period exists — use it
        df <- df |>
          dplyr::filter(
            .data$ByVariableLabel == "" |
            .data$ByVariableLabel == ref_period
          )
      } else if (length(ref_labels) > 1) {
        # Preferred period absent but multiple periods exist —
        # pick the shortest reference window to avoid double-counting
        # Priority order: "Two years" > "Five years" > "Ten years"
        priority <- c(
          "Two years preceding the survey",
          "Five years preceding the survey",
          "Ten years preceding the survey"
        )
        best <- intersect(priority, ref_labels)
        pick <- if (length(best) > 0) best[1] else ref_labels[1]
        message("Note: ref_period '", ref_period, "' not found; using '",
                pick, "'")
        df <- df |>
          dplyr::filter(
            .data$ByVariableLabel == "" |
            .data$ByVariableLabel == pick
          )
      }
      # If only one ref period exists, keep all rows (no filtering needed)
    }
  }

  # 3. Clean region names and construct composite geo key
  #    DHS API returns leading dots in CharacteristicLabel for newer surveys
  #    (e.g., "..Baringo", "....Northern(post 2022)"). Strip them.
  df <- df |>
    dplyr::mutate(
      CharacteristicLabel = sub("^\\.+", "", .data$CharacteristicLabel),
      geo = paste0(.data$DHS_CountryCode, "_", .data$CharacteristicLabel)
    )

  # 4. Rename SurveyYear → year and Value → out_col
  df <- df |>
    dplyr::mutate(year = .data$SurveyYear)

  # 5. Select output columns
  core_cols <- c("geo", "year", out_col)
  names(df)[names(df) == "Value"] <- out_col

  optional_cols <- character()
  if (keep_ci) optional_cols <- c(optional_cols, "CILow", "CIHigh")
  if (keep_denominator) optional_cols <- c(optional_cols, "DenominatorWeighted")
  if (keep_metadata) {
    optional_cols <- c(optional_cols,
                       "DHS_CountryCode", "CountryName",
                       "CharacteristicLabel", "IndicatorId",
                       "Indicator", "SurveyId", "ByVariableLabel")
  }

  # Keep only columns that exist in df
  select_cols <- intersect(c(core_cols, optional_cols), names(df))
  df <- df |>
    dplyr::select(dplyr::all_of(select_cols))

  df
}


# ============================================================================
# BATCH PROCESSOR
# ============================================================================

#' Process a Batch of DHS Indicators
#'
#' Takes the output of \code{\link{fetch_dhs_batch}()} (a named list of raw
#' tibbles) and applies \code{process_dhs()} to each, using the list names
#' as the \code{out_col}. Returns a named list of processed tibbles.
#'
#' @param batch_list Named list of raw tibbles from \code{fetch_dhs_batch()}.
#' @param ref_period Reference period filter (passed to \code{process_dhs()}).
#' @param keep_ci Passed to \code{process_dhs()}.
#' @param keep_denominator Passed to \code{process_dhs()}.
#'
#' @return Named list of processed tibbles, each with \code{geo}, \code{year},
#'   and a value column named after the list element.
#' @export
#' @examples
#' \dontrun{
#' codes <- c(u5_mortality = "CM_ECMR_C_U5M", stunting = "CN_NUTS_C_HA2")
#' raw_batch <- fetch_dhs_batch(codes, country_ids = c("KE", "NG"))
#' processed <- process_dhs_batch(raw_batch)
#' # processed$u5_mortality has columns: geo, year, u5_mortality
#' # processed$stunting has columns: geo, year, stunting
#' }
process_dhs_batch <- function(batch_list,
                              ref_period = "Five years preceding the survey",
                              keep_ci = FALSE,
                              keep_denominator = FALSE) {

  purrr::imap(batch_list, function(df, name) {
    if (nrow(df) == 0) return(df)
    process_dhs(df,
                out_col = name,
                ref_period = ref_period,
                keep_ci = keep_ci,
                keep_denominator = keep_denominator)
  })
}
