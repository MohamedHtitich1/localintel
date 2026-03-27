#' @title DHS Reference Data Functions
#' @description Reference data for the DHS pipeline: SSA country codes,
#'   Admin 1 region reference tables, country name lookups, and geographic
#'   boundary fetching. Mirrors the Eurostat reference layer
#'   (\code{eu27_codes}, \code{get_nuts2_ref}, etc.).
#' @name dhs_reference
NULL

# ============================================================================
# SSA COUNTRY CODES
# ============================================================================

#' Sub-Saharan Africa DHS Country Codes
#'
#' Returns a character vector of 2-letter DHS country codes for Sub-Saharan
#' Africa. These are the DHS-assigned codes (which match ISO 3166-1 alpha-2
#' for most countries). Mirrors \code{\link{eu27_codes}()} for the Eurostat
#' pipeline.
#'
#' The full list of 44 SSA countries is sourced from the DHS API
#' \code{/countries} endpoint filtered by region = "Sub-Saharan Africa".
#'
#' @return Character vector of 2-letter DHS country codes
#' @export
#' @examples
#' ssa_codes()
#' length(ssa_codes())  # 44
ssa_codes <- function() {
  c("AO", "BF", "BJ", "BT", "BU", "CD", "CF", "CG", "CI", "CM",
    "CV", "EK", "ER", "ET", "GA", "GH", "GM", "GN", "KE", "KM",
    "LB", "LS", "MD", "ML", "MR", "MW", "MZ", "NG", "NI", "NM",
    "OS", "RW", "SD", "SL", "SN", "ST", "SZ", "TD", "TG", "TZ",
    "UG", "ZA", "ZM", "ZW")
}

#' Tier 1 DHS Country Codes
#'
#' Returns a character vector of 15 Tier 1 validation countries for the
#' SSA expansion. These countries have 5+ survey rounds and represent
#' ~70\% of SSA population.
#'
#' @return Character vector of 15 DHS country codes
#' @export
#' @examples
#' tier1_codes()
tier1_codes <- function() {
  c("KE", "NG", "ET", "TZ", "UG", "GH", "SN", "ML", "BF", "MW",
    "MZ", "ZM", "ZW", "RW", "CD")
}


# ============================================================================
# SSA COUNTRY FILTER
# ============================================================================

#' Filter to SSA Countries
#'
#' Filters a dataframe to rows belonging to Sub-Saharan African countries.
#' Expects the dataframe to have a \code{geo} column in the format
#' \code{CC_RegionName} (as produced by \code{\link{process_dhs}()}).
#' Mirrors \code{\link{keep_eu27}()} for the Eurostat pipeline.
#'
#' @param df Dataframe with a \code{geo} column containing DHS composite keys
#'   (\code{DHS_CountryCode + "_" + CharacteristicLabel}).
#' @param extra Character vector of additional 2-letter country codes to keep
#'   (default: NULL, no extras).
#'
#' @return Filtered dataframe with only SSA country rows
#' @export
#' @examples
#' \dontrun{
#' processed <- process_dhs(raw_data, out_col = "u5_mortality")
#' ssa_only <- keep_ssa(processed)
#' }
keep_ssa <- function(df, extra = NULL) {
  keep <- ssa_codes()
  if (!is.null(extra)) keep <- union(keep, extra)

  df |>
    dplyr::mutate(
      .ctry = substr(.data$geo, 1, 2)
    ) |>
    dplyr::filter(.data$.ctry %in% keep) |>
    dplyr::select(-".ctry")
}


# ============================================================================
# ADMIN 1 REFERENCE TABLE
# ============================================================================

#' Get Admin 1 Reference Table
#'
#' Builds a reference table mapping DHS Admin 1 regions to their parent
#' countries. This is the DHS equivalent of \code{\link{get_nuts2_ref}()},
#' mapping subnational regions to country-level codes.
#'
#' The table is built from actual API data for the specified countries,
#' using the most recent survey round for each country. Results are
#' cached within the R session.
#'
#' @param country_ids Character vector of DHS country codes.
#'   If NULL (default), uses \code{tier1_codes()}.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{geo}{Composite key: \code{DHS_CountryCode + "_" + CharacteristicLabel}}
#'     \item{admin0}{2-letter DHS country code}
#'     \item{country_name}{Full country name}
#'     \item{region_label}{Admin 1 region name (CharacteristicLabel)}
#'   }
#' @export
#' @examples
#' \dontrun{
#' ref <- get_admin1_ref()
#' head(ref)
#' # Filter to Kenya only
#' ref_ke <- get_admin1_ref(country_ids = "KE")
#' }
get_admin1_ref <- function(country_ids = NULL) {
  if (is.null(country_ids)) country_ids <- tier1_codes()

  key <- cache_key("get_admin1_ref", paste(sort(country_ids), collapse = ","))
  cached <- cache_get(key)
  if (!is.null(cached)) return(cached)

  # Fetch a single lightweight indicator to discover regions
  # Use electricity (HC_ELEC_H_ELC) — available for all countries, dense coverage
  raw <- get_dhs_data(
    country_ids   = country_ids,
    indicator_ids = "HC_ELEC_H_ELC",
    breakdown     = "subnational"
  )

  if (nrow(raw) == 0) {
    warning("No data returned for Admin 1 reference table", call. = FALSE)
    return(tibble::tibble(
      geo          = character(),
      admin0       = character(),
      country_name = character(),
      region_label = character()
    ))
  }

  # For each country, keep only the most recent survey's regions
  # (most current boundary definitions)
  # Clean leading dots from CharacteristicLabel (DHS API artifact in newer surveys)
  result <- raw |>
    dplyr::mutate(
      CharacteristicLabel = sub("^\\.+", "", .data$CharacteristicLabel)
    ) |>
    dplyr::group_by(.data$DHS_CountryCode) |>
    dplyr::filter(.data$SurveyYear == max(.data$SurveyYear)) |>
    dplyr::ungroup() |>
    dplyr::distinct(
      .data$DHS_CountryCode,
      .data$CountryName,
      .data$CharacteristicLabel
    ) |>
    dplyr::transmute(
      geo          = paste0(.data$DHS_CountryCode, "_", .data$CharacteristicLabel),
      admin0       = .data$DHS_CountryCode,
      country_name = .data$CountryName,
      region_label = .data$CharacteristicLabel
    ) |>
    dplyr::arrange(.data$admin0, .data$region_label)

  cache_set(key, result)
  result
}


# ============================================================================
# COUNTRY NAME LOOKUP
# ============================================================================

#' Add DHS Country Name
#'
#' Joins a full country name column to a processed DHS dataframe.
#' Extracts the 2-letter country code from the \code{geo} column and
#' looks up the name from the DHS countries endpoint.
#' Mirrors \code{\link{add_country_name}()} for the Eurostat pipeline.
#'
#' @param df Dataframe with a \code{geo} column in DHS composite format.
#' @param col_name Name of the new column (default: \code{"country_name"}).
#'
#' @return Dataframe with an additional country name column.
#' @export
#' @examples
#' \dontrun{
#' processed <- process_dhs(raw_data, out_col = "stunting")
#' with_names <- add_dhs_country_name(processed)
#' }
add_dhs_country_name <- function(df, col_name = "country_name") {

  key <- cache_key("dhs_country_lookup")
  lookup <- cache_get(key)

  if (is.null(lookup)) {
    countries <- get_dhs_countries(region = NULL)  # all countries
    lookup <- countries |>
      dplyr::select("DHS_CountryCode", "CountryName") |>
      dplyr::distinct()
    cache_set(key, lookup)
  }

  df |>
    dplyr::mutate(.ctry = substr(.data$geo, 1, 2)) |>
    dplyr::left_join(
      lookup |> dplyr::rename(.ctry = "DHS_CountryCode",
                               !!col_name := "CountryName"),
      by = ".ctry"
    ) |>
    dplyr::select(-".ctry")
}


# ============================================================================
# DHS INDICATOR LABEL & DOMAIN REGISTRIES
# ============================================================================

#' DHS Indicator Variable Labels
#'
#' Returns a named character vector mapping DHS indicator friendly names
#' (as used in processed data) to human-readable labels for visualization
#' and export. Mirrors \code{\link{regional_var_labels}()} for Eurostat.
#'
#' @return Named character vector: names are variable names, values are labels.
#' @export
#' @examples
#' labs <- dhs_var_labels()
#' labs["u5_mortality"]
dhs_var_labels <- function() {
  c(
    # Health
    basic_vaccination    = "Basic vaccination coverage (%)",
    full_vaccination     = "Full vaccination - national schedule (%)",
    anc_4plus            = "4+ antenatal care visits (%)",
    skilled_birth        = "Skilled birth attendance (%)",
    postnatal_mother     = "Postnatal checkup for mother (%)",
    postnatal_newborn    = "Postnatal checkup for newborn (%)",
    contraceptive_modern = "Modern contraceptive use (%)",
    contraceptive_any    = "Any contraceptive use (%)",
    unmet_need_fp        = "Unmet need for family planning (%)",
    fever_treatment      = "Fever treatment with antimalarials (%)",
    diarrhea_ort         = "Diarrhea treated with ORT (%)",

    # Mortality
    u5_mortality         = "Under-5 mortality rate (per 1,000)",
    infant_mortality     = "Infant mortality rate (per 1,000)",
    neonatal_mortality   = "Neonatal mortality rate (per 1,000)",
    perinatal_mortality  = "Perinatal mortality rate (per 1,000)",
    child_mortality      = "Child mortality rate (per 1,000)",

    # Nutrition
    stunting             = "Stunting prevalence (%)",
    wasting              = "Wasting prevalence (%)",
    underweight          = "Underweight prevalence (%)",
    overweight_child     = "Child overweight prevalence (%)",
    anemia_children      = "Child anemia prevalence (%)",
    anemia_women         = "Women with anemia (%)",
    exclusive_bf         = "Exclusive breastfeeding (%)",
    early_bf             = "Early breastfeeding initiation (%)",
    low_bmi_women        = "Women with low BMI (%)",
    obesity_women        = "Women overweight/obese (%)",

    # HIV
    hiv_prevalence       = "HIV prevalence (%)",
    hiv_test_women       = "Women ever tested for HIV (%)",
    hiv_test_men         = "Men ever tested for HIV (%)",
    hiv_knowledge_women  = "Comprehensive HIV knowledge - women (%)",
    hiv_knowledge_men    = "Comprehensive HIV knowledge - men (%)",
    hiv_condom_women     = "HIV prevention: condom knowledge - women (%)",
    hiv_condom_men       = "HIV prevention: condom knowledge - men (%)",

    # Education
    literacy_women       = "Female literacy rate (%)",
    literacy_men         = "Male literacy rate (%)",
    net_attendance_primary = "Net primary attendance rate (%)",
    secondary_completion_women = "Female secondary completion (%)",
    secondary_completion_men   = "Male secondary completion (%)",
    median_years_women   = "Median years of education - women",
    median_years_men     = "Median years of education - men",
    no_education_women   = "Women with no education (%)",
    no_education_men     = "Men with no education (%)",

    # WASH
    improved_water       = "Improved water source (%)",
    improved_sanitation  = "Improved sanitation (%)",
    piped_water          = "Piped water (%)",
    surface_water        = "Surface water use (%)",
    open_defecation      = "Open defecation (%)",
    handwashing_facility = "Basic handwashing facility (%)",

    # Wealth
    wealth_lowest        = "Wealth quintile: lowest (%)",
    wealth_second        = "Wealth quintile: second (%)",
    wealth_middle        = "Wealth quintile: middle (%)",
    wealth_fourth        = "Wealth quintile: fourth (%)",
    wealth_highest       = "Wealth quintile: highest (%)",
    electricity          = "Electricity access (%)",
    mobile_phone         = "Mobile phone ownership (%)",
    bank_account         = "Women with bank account (%)",

    # Gender
    women_earning        = "Women deciding own earnings (%)",
    dv_physical          = "Physical violence prevalence (%)",
    dv_sexual            = "Sexual violence prevalence (%)",
    dv_emotional         = "Emotional violence by partner (%)",
    dv_attitude_women    = "Women justifying wife-beating (%)",
    dv_attitude_men      = "Men justifying wife-beating (%)"
  )
}

#' DHS Indicator Domain Mapping
#'
#' Returns a named character vector mapping DHS indicator friendly names
#' to their thematic domain. Mirrors \code{\link{regional_domain_mapping}()}
#' for the Eurostat pipeline.
#'
#' @return Named character vector: names are variable names, values are domains.
#' @export
#' @examples
#' domains <- dhs_domain_mapping()
#' table(domains)
dhs_domain_mapping <- function() {
  codes_list <- list(
    `Maternal & Child Health` = names(dhs_health_codes()),
    `Mortality`              = names(dhs_mortality_codes()),
    `Nutrition`              = names(dhs_nutrition_codes()),
    `HIV/AIDS`               = names(dhs_hiv_codes()),
    `Education`              = names(dhs_education_codes()),
    `Water & Sanitation`     = names(dhs_wash_codes()),
    `Wealth & Assets`        = names(dhs_wealth_codes()),
    `Gender`                 = names(dhs_gender_codes())
  )

  # Flatten to named vector: indicator_name → domain
  result <- character()
  for (domain in names(codes_list)) {
    vars <- codes_list[[domain]]
    named <- stats::setNames(rep(domain, length(vars)), vars)
    result <- c(result, named)
  }
  result
}
