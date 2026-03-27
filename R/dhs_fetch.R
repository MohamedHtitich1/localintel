#' @title DHS Program Data Fetching Functions
#' @description Functions for fetching subnational indicator data from the
#'   DHS Program Indicator Data API (api.dhsprogram.com). Uses httr2 for
#'   direct HTTP access with the registered partner API key.
#' @name dhs_fetch
NULL

# ============================================================================
# INTERNAL CONSTANTS
# ============================================================================

#' DHS API Base URL (Internal)
#' @keywords internal
.dhs_base_url <- "https://api.dhsprogram.com/rest/dhs"

#' DHS API Key (Internal)
#'
#' Reads from the \code{DHS_API_KEY} environment variable. Falls back to the
#' package maintainer's partner key if not set.
#' @keywords internal
.dhs_api_key <- function() {
  key <- Sys.getenv("DHS_API_KEY", unset = "")
  if (nzchar(key)) return(key)
  # Fallback: package maintainer partner key (register your own at

  # https://api.dhsprogram.com for production use)
  "MOHHTI-239797"
}

# ============================================================================
# CORE FETCHING FUNCTIONS
# ============================================================================

#' Fetch Data from DHS Program API
#'
#' Single-query wrapper for the DHS Indicator Data API. Constructs the
#' appropriate URL, sends the request with the partner API key, parses
#' the JSON response, and returns a standardized tibble.
#'
#' @param country_ids Character vector of DHS 2-letter country codes
#'   (e.g., \code{c("KE", "NG", "ET")}). If NULL, fetches all available.
#' @param indicator_ids Character vector of DHS indicator IDs
#'   (e.g., \code{c("CM_ECMR_C_U5M", "CN_NUTS_C_HA2")}). Required.
#' @param years Integer vector of survey years to include. If NULL,
#'   returns all available survey years.
#' @param breakdown Character string specifying geographic breakdown.
#'   One of \code{"subnational"} (default, Admin 1 regions) or
#'   \code{"national"} (country-level only).
#' @param preferred_only Logical. If TRUE (default), filters to
#'   \code{IsPreferred == 1} to return only the most recent/preferred
#'   estimate for each indicator-region-year combination.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{CountryName}{Full country name}
#'     \item{DHS_CountryCode}{2-letter DHS country code}
#'     \item{SurveyYear}{Year the survey was conducted}
#'     \item{SurveyId}{Unique DHS survey identifier}
#'     \item{IndicatorId}{DHS indicator code}
#'     \item{Indicator}{Human-readable indicator name}
#'     \item{CharacteristicCategory}{Disaggregation category (e.g., "Region")}
#'     \item{CharacteristicLabel}{Region or characteristic label}
#'     \item{Value}{Numeric indicator value}
#'     \item{DenominatorWeighted}{Weighted denominator for the estimate}
#'     \item{CILow}{Lower bound of 95\% confidence interval}
#'     \item{CIHigh}{Upper bound of 95\% confidence interval}
#'     \item{IsPreferred}{Whether this is the preferred estimate (1/0)}
#'     \item{ByVariableLabel}{Variable used for disaggregation}
#'     \item{RegionId}{DHS region identifier string}
#'   }
#'   Returns an empty tibble (with correct column types) if no data is found.
#'
#' @export
#' @examples
#' \dontrun{
#' # Under-5 mortality for Kenya, subnational
#' ke_u5m <- get_dhs_data(
#'   country_ids = "KE",
#'   indicator_ids = "CM_ECMR_C_U5M",
#'   breakdown = "subnational"
#' )
#'
#' # Multiple indicators, multiple countries
#' data <- get_dhs_data(
#'   country_ids = c("KE", "NG", "ET"),
#'   indicator_ids = c("CM_ECMR_C_U5M", "CN_NUTS_C_HA2"),
#'   years = 2010:2023,
#'   breakdown = "subnational"
#' )
#' }
get_dhs_data <- function(country_ids = NULL,
                         indicator_ids,
                         years = NULL,
                         breakdown = c("subnational", "national"),
                         preferred_only = TRUE) {

  breakdown <- match.arg(breakdown)

  # Validate indicator_ids
  if (missing(indicator_ids) || is.null(indicator_ids) || length(indicator_ids) == 0) {
    stop("'indicator_ids' must be a non-empty character vector of DHS indicator codes.",
         call. = FALSE)
  }
  if (!is.character(indicator_ids)) {
    stop("'indicator_ids' must be a character vector, got ", class(indicator_ids)[1],
         call. = FALSE)
  }

  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("'httr2' package is required for DHS API access.\n",
         "Install it with: install.packages('httr2')",
         call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("'jsonlite' package is required for DHS API access.\n",
         "Install it with: install.packages('jsonlite')",
         call. = FALSE)
  }

  # Build request
  req <- httr2::request(.dhs_base_url) |>
    httr2::req_url_path_append("data") |>
    httr2::req_url_query(
      apiKey           = .dhs_api_key(),
      indicatorIds     = paste(indicator_ids, collapse = ","),
      breakdown        = breakdown,
      returnFields     = paste(
        "CountryName", "DHS_CountryCode", "SurveyYear", "SurveyId",
        "IndicatorId", "Indicator", "CharacteristicCategory",
        "CharacteristicLabel", "Value", "DenominatorWeighted",
        "CILow", "CIHigh", "IsPreferred", "ByVariableLabel", "RegionId",
        sep = ","
      ),
      f                = "json",
      perPage          = 5000
    ) |>
    httr2::req_retry(max_tries = 3, backoff = ~ 2) |>
    httr2::req_timeout(120)

  # Add country filter if provided
  if (!is.null(country_ids)) {
    req <- req |>
      httr2::req_url_query(countryIds = paste(country_ids, collapse = ","))
  }

  # Add survey year filter if provided
  if (!is.null(years)) {
    req <- req |>
      httr2::req_url_query(surveyYear = paste(years, collapse = ","))
  }

  # Paginated fetch: collect all pages
  all_data <- list()
  page <- 1

  repeat {
    req_page <- req |>
      httr2::req_url_query(page = page)

    resp <- tryCatch(
      httr2::req_perform(req_page),
      error = function(e) {
        warning("DHS API request failed: ", conditionMessage(e), call. = FALSE)
        return(NULL)
      }
    )

    if (is.null(resp)) break

    body <- httr2::resp_body_string(resp)
    parsed <- jsonlite::fromJSON(body, flatten = TRUE)

    # The DHS API wraps data in a "Data" element
    if (is.null(parsed$Data) || length(parsed$Data) == 0) break

    page_df <- tibble::as_tibble(parsed$Data)
    all_data <- append(all_data, list(page_df))

    # Check if there are more pages
    total_pages <- if (is.null(parsed$TotalPages)) 1 else parsed$TotalPages
    if (page >= total_pages) break
    page <- page + 1

    # Rate-limit courtesy delay
    Sys.sleep(0.25)
  }

  # Combine all pages
  if (length(all_data) == 0) {
    return(.empty_dhs_tibble())
  }

  result <- dplyr::bind_rows(all_data)

  # Ensure correct types
  type_map <- list(
    Value               = as.numeric,
    SurveyYear          = as.integer,
    IsPreferred         = as.integer,
    CILow               = as.numeric,
    CIHigh              = as.numeric,
    RegionId            = as.character,
    DenominatorWeighted = as.numeric,
    DHS_CountryCode     = as.character
  )
  for (col in names(type_map)) {
    if (col %in% names(result)) {
      old_na <- sum(is.na(result[[col]]))
      result[[col]] <- suppressWarnings(type_map[[col]](result[[col]]))
      new_na <- sum(is.na(result[[col]])) - old_na
      if (new_na > 0) {
        warning("Type coercion of '", col, "' introduced ", new_na,
                " new NA value(s).", call. = FALSE)
      }
    }
  }

  # Filter to preferred estimates only

  if (preferred_only && "IsPreferred" %in% names(result)) {
    result <- result |>
      dplyr::filter(.data$IsPreferred == 1L)
  }

  # Filter by years if specified (belt-and-suspenders with API param)
  if (!is.null(years) && "SurveyYear" %in% names(result)) {
    result <- result |>
      dplyr::filter(.data$SurveyYear %in% years)
  }

  result
}

#' Batch Fetch DHS Indicators
#'
#' Iterates over indicator/country combinations with rate-limit-aware
#' delays. Returns a named list of tibbles, one per indicator ID.
#' Mirrors the pattern of \code{\link{fetch_eurostat_batch}()} for
#' the Eurostat pipeline.
#'
#' @param indicator_ids Named character vector where names are friendly
#'   names and values are DHS indicator IDs. Example:
#'   \code{c(u5_mortality = "CM_ECMR_C_U5M", stunting = "CN_NUTS_C_HA2")}
#' @param country_ids Character vector of DHS country codes. If NULL,
#'   fetches all SSA countries.
#' @param years Integer vector of survey years to include. If NULL,
#'   returns all available.
#' @param breakdown Character string: \code{"subnational"} (default) or
#'   \code{"national"}.
#'
#' @return Named list of tibbles, one per indicator. Names correspond
#'   to the names of \code{indicator_ids}.
#' @export
#' @examples
#' \dontrun{
#' codes <- c(u5_mortality = "CM_ECMR_C_U5M", stunting = "CN_NUTS_C_HA2")
#' data_list <- fetch_dhs_batch(codes, country_ids = c("KE", "NG"))
#' }
fetch_dhs_batch <- function(indicator_ids,
                            country_ids = NULL,
                            years = NULL,
                            breakdown = "subnational") {

  purrr::imap(indicator_ids, function(ind_id, friendly_name) {
    message("Fetching DHS: ", friendly_name, " (", ind_id, ")...")
    result <- tryCatch(
      get_dhs_data(
        country_ids   = country_ids,
        indicator_ids = ind_id,
        years         = years,
        breakdown     = breakdown
      ),
      error = function(e) {
        warning("Failed to fetch ", friendly_name, ": ", conditionMessage(e),
                call. = FALSE)
        .empty_dhs_tibble()
      }
    )
    # Courtesy delay between batched API calls
    Sys.sleep(0.5)
    result
  })
}

#' Get DHS Countries for a Region
#'
#' Queries the DHS \code{/rest/dhs/countries} endpoint and returns
#' country metadata, optionally filtered to a specific DHS region
#' (e.g., "Sub-Saharan Africa").
#'
#' @param region Character string for DHS region name filter. Common
#'   values: \code{"Sub-Saharan Africa"}, \code{"South Asia"},
#'   \code{"North Africa/West Asia/Europe"}. If NULL, returns all countries.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{DHS_CountryCode}{2-letter DHS country code}
#'     \item{ISO2_CountryCode}{2-letter ISO country code}
#'     \item{CountryName}{Full country name}
#'     \item{RegionName}{DHS region name}
#'   }
#' @export
#' @examples
#' \dontrun{
#' ssa <- get_dhs_countries("Sub-Saharan Africa")
#' ssa$ISO2_CountryCode
#' }
get_dhs_countries <- function(region = "Sub-Saharan Africa") {

  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("'httr2' package is required for DHS API access.\n",
         "Install it with: install.packages('httr2')",
         call. = FALSE)
  }

  req <- httr2::request(.dhs_base_url) |>
    httr2::req_url_path_append("countries") |>
    httr2::req_url_query(
      apiKey       = .dhs_api_key(),
      returnFields = "DHS_CountryCode,ISO2_CountryCode,CountryName,RegionName",
      f            = "json"
    ) |>
    httr2::req_retry(max_tries = 3, backoff = ~ 2) |>
    httr2::req_timeout(30)

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_string(resp)
  parsed <- jsonlite::fromJSON(body, flatten = TRUE)

  result <- tibble::as_tibble(parsed$Data)

  if (!is.null(region) && "RegionName" %in% names(result)) {
    result <- result |>
      dplyr::filter(.data$RegionName == region)
  }

  result
}

#' Get Available DHS Surveys for Countries
#'
#' Queries the DHS \code{/rest/dhs/surveys} endpoint to discover
#' which surveys exist for given countries. Useful for understanding
#' temporal coverage before fetching indicator data.
#'
#' @param country_ids Character vector of DHS country codes.
#'   If NULL, returns surveys for all countries.
#'
#' @return A tibble with survey metadata including SurveyId,
#'   CountryName, SurveyYear, SurveyType, and SurveyStatus.
#' @export
#' @examples
#' \dontrun{
#' ke_surveys <- get_dhs_surveys(country_ids = "KE")
#' ke_surveys
#' }
get_dhs_surveys <- function(country_ids = NULL) {

  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("'httr2' package is required for DHS API access.\n",
         "Install it with: install.packages('httr2')",
         call. = FALSE)
  }

  req <- httr2::request(.dhs_base_url) |>
    httr2::req_url_path_append("surveys") |>
    httr2::req_url_query(
      apiKey       = .dhs_api_key(),
      returnFields = paste(
        "SurveyId", "CountryName", "SurveyYear", "SurveyType",
        "SurveyStatus", "ISO2_CountryCode",
        sep = ","
      ),
      f            = "json"
    ) |>
    httr2::req_retry(max_tries = 3, backoff = ~ 2) |>
    httr2::req_timeout(30)

  if (!is.null(country_ids)) {
    req <- req |>
      httr2::req_url_query(countryIds = paste(country_ids, collapse = ","))
  }

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_string(resp)
  parsed <- jsonlite::fromJSON(body, flatten = TRUE)

  result <- tibble::as_tibble(parsed$Data)

  if ("SurveyYear" %in% names(result)) {
    result$SurveyYear <- as.integer(result$SurveyYear)
  }

  result
}

# ============================================================================
# DHS INDICATOR REGISTRIES
# ============================================================================

#' DHS Health Indicator Codes
#'
#' Returns a named vector of DHS indicator IDs for maternal and child health.
#' Covers antenatal care, skilled birth attendance, vaccination,
#' postnatal care, and contraceptive use.
#'
#' @return Named character vector of DHS indicator IDs
#' @export
#' @examples
#' codes <- dhs_health_codes()
#' names(codes)
dhs_health_codes <- function() {
  c(
    basic_vaccination    = "CH_VACC_C_BAS",
    full_vaccination     = "CH_VACC_C_APP",
    anc_4plus            = "RH_ANCN_W_N4P",
    skilled_birth        = "RH_DELA_C_SKP",
    postnatal_mother     = "RH_PCMT_W_TOT",
    postnatal_newborn    = "RH_PCCT_C_TOT",
    contraceptive_modern = "FP_CUSA_W_MOD",
    contraceptive_any    = "FP_CUSA_W_ANY",
    unmet_need_fp        = "FP_NADA_W_UNT",
    fever_treatment      = "CH_FEVT_C_AML",
    diarrhea_ort         = "CH_DIAT_C_ORT"
  )
}

#' DHS Mortality Indicator Codes
#'
#' Returns a named vector of DHS indicator IDs for child and infant mortality.
#' Covers under-5, infant, neonatal, and perinatal mortality rates.
#'
#' @return Named character vector of DHS indicator IDs
#' @export
#' @examples
#' codes <- dhs_mortality_codes()
#' names(codes)
dhs_mortality_codes <- function() {
  c(
    u5_mortality         = "CM_ECMR_C_U5M",
    infant_mortality     = "CM_ECMR_C_IMR",
    neonatal_mortality   = "CM_ECMR_C_NNR",
    perinatal_mortality  = "CM_ECMR_C_PNR",
    child_mortality      = "CM_ECMR_C_CMR"
  )
}

#' DHS Nutrition Indicator Codes
#'
#' Returns a named vector of DHS indicator IDs for child and maternal
#' nutrition. Covers stunting, wasting, underweight, anemia, obesity,
#' and breastfeeding indicators.
#'
#' @return Named character vector of DHS indicator IDs
#' @export
#' @examples
#' codes <- dhs_nutrition_codes()
#' names(codes)
dhs_nutrition_codes <- function() {
  c(
    stunting             = "CN_NUTS_C_HA2",
    wasting              = "CN_NUTS_C_WH2",
    underweight          = "CN_NUTS_C_WA2",
    overweight_child     = "CN_NUTS_C_WH3",
    anemia_children      = "CN_ANMC_C_ANY",
    anemia_women         = "AN_ANEM_W_ANY",
    exclusive_bf         = "CN_BFSS_C_EBF",
    early_bf             = "CN_BRFI_C_1HR",
    low_bmi_women        = "AN_NUTS_W_THN",
    obesity_women        = "AN_NUTS_W_OWT"
  )
}

#' DHS HIV/AIDS Indicator Codes
#'
#' Returns a named vector of DHS indicator IDs for HIV/AIDS prevalence,
#' testing, knowledge, and treatment.
#'
#' @return Named character vector of DHS indicator IDs
#' @export
#' @examples
#' codes <- dhs_hiv_codes()
#' names(codes)
dhs_hiv_codes <- function() {
  c(
    hiv_prevalence       = "HA_HIVP_B_HIV",
    hiv_test_women       = "HA_CPHT_W_ETR",
    hiv_test_men         = "HA_CPHT_M_ETR",
    hiv_knowledge_women  = "HA_CKNA_W_CKA",
    hiv_knowledge_men    = "HA_CKNA_M_CKA",
    hiv_condom_women     = "HA_KHVP_W_CND",
    hiv_condom_men       = "HA_KHVP_M_CND"
  )
}

#' DHS Education Indicator Codes
#'
#' Returns a named vector of DHS indicator IDs for education and
#' literacy. Covers literacy rates, school attendance, and educational
#' attainment for women and men.
#'
#' @return Named character vector of DHS indicator IDs
#' @export
#' @examples
#' codes <- dhs_education_codes()
#' names(codes)
dhs_education_codes <- function() {
  c(
    literacy_women       = "ED_LITR_W_LIT",
    literacy_men         = "ED_LITR_M_LIT",
    net_attendance_primary = "ED_NARP_B_BTH",
    secondary_completion_women = "ED_EDAT_W_CSC",
    secondary_completion_men   = "ED_EDAT_M_CSC",
    median_years_women   = "ED_EDAT_W_MYR",
    median_years_men     = "ED_EDAT_M_MYR",
    no_education_women   = "ED_EDAT_W_NED",
    no_education_men     = "ED_EDAT_M_NED"
  )
}

#' DHS Water, Sanitation & Hygiene (WASH) Indicator Codes
#'
#' Returns a named vector of DHS indicator IDs for water and sanitation.
#' Covers improved water source, improved sanitation, and handwashing
#' facilities.
#'
#' @return Named character vector of DHS indicator IDs
#' @export
#' @examples
#' codes <- dhs_wash_codes()
#' names(codes)
dhs_wash_codes <- function() {
  c(
    improved_water       = "WS_SRCE_H_IMP",
    improved_sanitation  = "WS_TLET_H_IMP",
    piped_water          = "WS_SRCE_H_PIP",
    surface_water        = "WS_SRCE_H_SRF",
    open_defecation      = "WS_TLET_H_NFC",
    handwashing_facility = "WS_HNDW_H_BAS"
  )
}

#' DHS Wealth and Asset Indicator Codes
#'
#' Returns a named vector of DHS indicator IDs for household wealth
#' and asset ownership. Covers wealth quintile distribution and
#' key asset indicators.
#'
#' @return Named character vector of DHS indicator IDs
#' @export
#' @examples
#' codes <- dhs_wealth_codes()
#' names(codes)
dhs_wealth_codes <- function() {
  c(
    wealth_lowest        = "HC_WIXQ_P_LOW",
    wealth_second        = "HC_WIXQ_P_2ND",
    wealth_middle        = "HC_WIXQ_P_MID",
    wealth_fourth        = "HC_WIXQ_P_4TH",
    wealth_highest       = "HC_WIXQ_P_HGH",
    electricity          = "HC_ELEC_H_ELC",
    mobile_phone         = "HC_HEFF_H_MPH",
    bank_account         = "CO_MOBB_W_BNK"
  )
}

#' DHS Gender Indicator Codes
#'
#' Returns a named vector of DHS indicator IDs for gender-related
#' indicators. Covers women's earnings autonomy, domestic violence
#' experience (physical, sexual, emotional), and attitudes towards
#' wife-beating.
#'
#' @return Named character vector of DHS indicator IDs
#' @export
#' @examples
#' codes <- dhs_gender_codes()
#' names(codes)
dhs_gender_codes <- function() {
  c(
    women_earning        = "EM_WERN_W_WIF",
    dv_physical          = "DV_EXPV_W_EVR",
    dv_sexual            = "DV_EXSV_W_EVR",
    dv_emotional         = "DV_SPVL_W_EMT",
    dv_attitude_women    = "WE_AWBT_W_AGR",
    dv_attitude_men      = "WE_AWBT_M_AGR"
  )
}

#' All DHS Indicator Codes
#'
#' Returns a comprehensive named vector combining indicator codes from
#' all 8 DHS thematic domains. This is the full registry of DHS
#' subnational indicators that localintel can process. Mirrors the
#' pattern of \code{\link{all_regional_codes}()} for Eurostat.
#'
#' @return Named character vector of all DHS indicator IDs
#' @export
#' @examples
#' all_codes <- all_dhs_codes()
#' cat("Total DHS indicators:", length(all_codes), "\n")
all_dhs_codes <- function() {
  c(
    dhs_health_codes(),
    dhs_mortality_codes(),
    dhs_nutrition_codes(),
    dhs_hiv_codes(),
    dhs_education_codes(),
    dhs_wash_codes(),
    dhs_wealth_codes(),
    dhs_gender_codes()
  )
}

#' Count Available DHS Indicators
#'
#' Returns the total number of DHS indicators in the localintel
#' registry, along with the number of thematic domains.
#'
#' @return A named list with \code{indicators} (total count) and
#'   \code{domains} (number of thematic domains)
#' @export
#' @examples
#' n <- dhs_indicator_count()
#' cat(n$indicators, "DHS indicators across", n$domains, "domains\n")
dhs_indicator_count <- function() {
  domain_fns <- list(
    `Maternal & Child Health` = dhs_health_codes,
    `Mortality`              = dhs_mortality_codes,
    `Nutrition`              = dhs_nutrition_codes,
    `HIV/AIDS`               = dhs_hiv_codes,
    `Education`              = dhs_education_codes,
    `Water & Sanitation`     = dhs_wash_codes,
    `Wealth & Assets`        = dhs_wealth_codes,
    `Gender`                 = dhs_gender_codes
  )
  counts <- vapply(domain_fns, function(fn) length(fn()), integer(1))
  list(
    indicators = sum(counts),
    domains    = length(counts),
    by_domain  = counts
  )
}

# ============================================================================
# INTERNAL HELPERS
# ============================================================================

#' Empty DHS Tibble (Internal)
#'
#' Returns an empty tibble with the standard DHS column structure.
#' Used as fallback when API returns no data.
#'
#' @return Empty tibble with correct column types
#' @keywords internal
.empty_dhs_tibble <- function() {
  tibble::tibble(
    CountryName            = character(),
    DHS_CountryCode        = character(),
    SurveyYear             = integer(),
    SurveyId               = character(),
    IndicatorId            = character(),
    Indicator              = character(),
    CharacteristicCategory = character(),
    CharacteristicLabel    = character(),
    Value                  = numeric(),
    DenominatorWeighted    = numeric(),
    CILow                  = numeric(),
    CIHigh                 = numeric(),
    IsPreferred            = integer(),
    ByVariableLabel        = character(),
    RegionId               = character()
  )
}
