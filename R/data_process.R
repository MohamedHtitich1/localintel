#' @title Data Processing Functions
#' @description Functions for processing and transforming Eurostat health data
#' @name data_process
NULL

#' Process Health System Discharges Data
#'
#' Filters and prepares in-patient discharge data from Eurostat
#'
#' @param df Raw dataframe from Eurostat hlth_co_disch2t
#' @param unit Unit filter (default: c("P_HTHAB", "P100TH") for per 100k)
#' @param icd10 ICD-10 filter (default: "A-T_Z_XNB" for all causes)
#' @param age Age group filter (default: "TOTAL")
#' @param sex Sex filter (default: "T" for total)
#' @return Processed dataframe with geo, year, and disch_inp columns
#' @export
process_disch_inp <- function(df,
                              unit = c("P_HTHAB", "P100TH"),
                              icd10 = "A-T_Z_XNB",
                              age = "TOTAL",
                              sex = "T") {
  df %>%
    dplyr::filter(
      .data$unit %in% !!unit,
      .data$icd10 %in% !!icd10,
      .data$age == !!age,
      .data$sex == !!sex
    ) %>%
    dplyr::select("geo", year = "time", disch_inp = "values")
}

#' Process Day-Case Discharges Data
#'
#' Filters and prepares day-case discharge data from Eurostat
#'
#' @inheritParams process_disch_inp
#' @param df Raw dataframe from Eurostat hlth_co_disch4t
#' @return Processed dataframe with geo, year, and disch_day columns
#' @export
process_disch_day <- function(df,
                              unit = c("P_HTHAB", "P100TH"),
                              icd10 = "A-T_Z_XNB",
                              age = "TOTAL",
                              sex = "T") {
  df %>%
    dplyr::filter(
      .data$unit %in% !!unit,
      .data$icd10 %in% !!icd10,
      .data$age == !!age,
      .data$sex == !!sex
    ) %>%
    dplyr::select("geo", year = "time", disch_day = "values")
}

#' Process Hospital Days Data
#'
#' Filters and prepares hospital days data from Eurostat
#'
#' @inheritParams process_disch_inp
#' @param df Raw dataframe from Eurostat hlth_co_hosdayt
#' @return Processed dataframe with geo, year, and hos_days columns
#' @export
process_hos_days <- function(df,
                             unit = "NR",
                             icd10 = "A-T_Z_XNB",
                             age = "TOTAL",
                             sex = "T") {
  df %>%
    dplyr::filter(
      .data$unit %in% !!unit,
      .data$icd10 %in% !!icd10,
      .data$age == !!age,
      .data$sex == !!sex
    ) %>%
    dplyr::select("geo", year = "time", hos_days = "values")
}

#' Process Length of Stay Data
#'
#' Filters and prepares average length of stay data from Eurostat
#'
#' @inheritParams process_disch_inp
#' @param df Raw dataframe from Eurostat hlth_co_inpstt
#' @return Processed dataframe with geo, year, and los columns
#' @export
process_los <- function(df,
                        unit = "NR",
                        icd10 = "A-T_Z_XNB",
                        age = "TOTAL",
                        sex = "T") {
  df %>%
    dplyr::filter(
      .data$unit %in% !!unit,
      .data$icd10 %in% !!icd10,
      .data$age == !!age,
      .data$sex == !!sex
    ) %>%
    dplyr::select("geo", year = "time", los = "values")
}

#' Process Hospital Beds Data
#'
#' Filters and prepares hospital beds data from Eurostat
#'
#' @param df Raw dataframe from Eurostat hlth_rs_bdsrg2
#' @param unit Unit filter (default: "P_HTHAB" for per 100k)
#' @return Processed dataframe with geo, year, and beds columns
#' @export
process_beds <- function(df, unit = "P_HTHAB") {
  df %>%
    dplyr::filter(.data$unit %in% !!unit) %>%
    dplyr::select("geo", year = "time", beds = "values")
}

#' Process Physicians Data
#'
#' Filters and prepares physicians data from Eurostat
#'
#' @param df Raw dataframe from Eurostat hlth_rs_physreg
#' @param unit Unit filter (default: "P_HTHAB" for per 100k)
#' @return Processed dataframe with geo, year, and physicians columns
#' @export
process_physicians <- function(df, unit = "P_HTHAB") {
  df %>%
    dplyr::filter(.data$unit %in% !!unit) %>%
    dplyr::select("geo", year = "time", physicians = "values")
}

#' Process Causes of Death Data
#'
#' Filters and prepares causes of death data from Eurostat
#'
#' @param df Raw dataframe from Eurostat COD datasets
#' @param unit Unit filter (default: "RT" for rate)
#' @param icd10 ICD-10 filter (default: "A-R_V-Y")
#' @param age Age group filter (default: "TOTAL")
#' @param sex Sex filter (default: "T" for total)
#' @param out_col Name of output value column
#' @return Processed dataframe with geo, year, and value column
#' @export
process_cod <- function(df,
                        unit = "RT",
                        icd10 = "A-R_V-Y",
                        age = "TOTAL",
                        sex = "T",
                        out_col = "cod_rate") {
  df %>%
    dplyr::filter(
      .data$unit %in% !!unit,
      .data$icd10 %in% !!icd10,
      .data$age == !!age,
      .data$sex == !!sex
    ) %>%
    dplyr::select("geo", year = "time", !!out_col := "values")
}

#' Process Health Perceptions Data
#'
#' Filters and reshapes health perceptions survey data from Eurostat
#'
#' @param df Raw dataframe from Eurostat hlth_silc_08_r
#' @param years_full Integer vector of years to include
#' @return Wide-format dataframe with one column per reason
#' @export
process_health_perceptions <- function(df, years_full = 2008:2024) {
  data <- df %>%
    dplyr::transmute(
      geo = .data$geo,
      year = as.integer(substr(as.character(.data$time), 1, 4)),
      reason = .data$reason,
      values = .data$values
    ) %>%
    dplyr::group_by(.data$geo, .data$year, .data$reason) %>%
    dplyr::summarise(values = dplyr::first(.data$values), .groups = "drop") %>%
    tidyr::spread(.data$reason, .data$values) %>%
    dplyr::group_by(.data$geo) %>%
    dplyr::arrange(.data$year, .by_group = TRUE) %>%
    tidyr::complete(year = years_full) %>%
    dplyr::ungroup()
  
  # Get reason columns
  reason_cols <- setdiff(names(data), c("geo", "year"))
  
  # Apply interpolation
  tmp <- lapply(data[reason_cols], interp_const_ends_flag)
  vals <- tibble::as_tibble(lapply(tmp, `[[`, "value"))
  flags <- tibble::as_tibble(lapply(tmp, `[[`, "flag"))
  names(flags) <- paste0("imp_", names(flags))
  
  dplyr::bind_cols(data[c("geo", "year")], vals, flags)
}

#' Merge Multiple Processed Datasets
#'
#' Combines multiple processed datasets into a single dataframe
#'
#' @param ... Named dataframes to merge
#' @param by Character vector of join columns (default: c("geo", "year"))
#' @param join_type Type of join: "full", "left", "inner" (default: "full")
#' @return Merged dataframe
#' @export
#' @examples
#' \dontrun{
#' merged <- merge_datasets(beds_df, physicians_df, los_df)
#' }
merge_datasets <- function(..., by = c("geo", "year"), join_type = "full") {
  dfs <- list(...)
  
  join_fn <- switch(
    join_type,
    "full" = dplyr::full_join,
    "left" = dplyr::left_join,
    "inner" = dplyr::inner_join,
    dplyr::full_join
  )
  
  Reduce(function(a, b) join_fn(a, b, by = by), dfs)
}

#' Compute Composite Score
#'
#' Computes a simple average composite score from multiple indicator scores
#'
#' @param df Dataframe containing score columns
#' @param score_cols Character vector of column names to average
#' @param out_col Name of output composite column
#' @return Dataframe with added composite score column
#' @export
#' @examples
#' \dontrun{
#' df <- compute_composite(df, c("score_a", "score_b", "score_c"), "score_composite")
#' }
compute_composite <- function(df, score_cols, out_col = "composite_score") {
  df %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      !!out_col := mean(dplyr::c_across(dplyr::all_of(score_cols)), na.rm = TRUE)
    ) %>%
    dplyr::ungroup()
}

#' Transform and Score Variables
#'
#' Applies transformations (negation, log) and scales to 0-100
#'
#' @param df Dataframe with raw variables
#' @param transforms Named list where names are new column names and values are
#'   expressions (as strings) for transformation
#' @return Dataframe with transformed and scored columns
#' @export
#' @examples
#' \dontrun{
#' df <- transform_and_score(df, list(
#'   los_tr = "-los",
#'   pyll_tr = "-safe_log10(pyll)"
#' ))
#' }
transform_and_score <- function(df, transforms) {
  for (new_col in names(transforms)) {
    expr <- transforms[[new_col]]
    df <- df %>%
      dplyr::mutate(!!new_col := eval(parse(text = expr)))
  }

  # Score all _tr columns
  tr_cols <- grep("_tr$", names(df), value = TRUE)

  df %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(tr_cols),
        scale_0_100,
        .names = "score_{.col}"
      )
    )
}

# ============================================================================
# GENERIC EUROSTAT PROCESSOR
# ============================================================================

#' Process Any Eurostat Dataset
#'
#' A generic processor that filters any Eurostat dataset by arbitrary
#' dimension values and returns a standardized geo/year/value tibble.
#' This is the universal building block for processing indicators from
#' any domain — economy, education, labour, tourism, etc.
#'
#' @param df Raw dataframe from any Eurostat dataset
#' @param filters Named list of dimension filters. Each name is a column
#'   and each value is a character vector of accepted values. Example:
#'   \code{list(unit = "PC", sex = "T", age = "TOTAL")}
#' @param value_col Name of the value column in the raw data (default: "values")
#' @param out_col Name of the output value column. If NULL, defaults to
#'   the first filter value or "value".
#' @return Processed tibble with columns: geo, year, and the named value column
#' @export
#' @examples
#' \dontrun{
#' # GDP at current market prices
#' gdp <- process_eurostat(raw_gdp, filters = list(unit = "MIO_EUR"), out_col = "gdp")
#'
#' # Unemployment rate, total, 15-74
#' unemp <- process_eurostat(raw_unemp,
#'   filters = list(sex = "T", age = "Y15-74", unit = "PC"),
#'   out_col = "unemployment_rate")
#'
#' # Tertiary education attainment
#' educ <- process_eurostat(raw_educ,
#'   filters = list(sex = "T", age = "Y25-64", isced11 = "ED5-8"),
#'   out_col = "tertiary_attainment")
#' }
process_eurostat <- function(df, filters = list(), value_col = "values", out_col = NULL) {
  if (is.null(out_col)) out_col <- "value"

  # Apply filters

  for (col_name in names(filters)) {
    if (col_name %in% names(df)) {
      df <- df %>%
        dplyr::filter(.data[[col_name]] %in% filters[[col_name]])
    }
  }

  # Standardize time column
  if ("time" %in% names(df)) {
    df <- df %>%
      dplyr::mutate(year = as.integer(substr(as.character(.data$time), 1, 4)))
  } else if ("TIME_PERIOD" %in% names(df)) {
    df <- df %>%
      dplyr::mutate(year = as.integer(substr(as.character(.data$TIME_PERIOD), 1, 4)))
  } else if (!"year" %in% names(df)) {
    stop("No time/TIME_PERIOD/year column found in data")
  }

  df %>%
    dplyr::select("geo", "year", !!out_col := dplyr::all_of(value_col))
}

# ============================================================================
# DOMAIN-SPECIFIC CONVENIENCE PROCESSORS
# ============================================================================

#' Process GDP Data
#'
#' Filters regional GDP data from Eurostat (nama_10r_2gdp)
#'
#' @param df Raw dataframe from Eurostat nama_10r_2gdp
#' @param unit Unit filter (default: "MIO_EUR" for million EUR)
#' @return Processed dataframe with geo, year, and gdp columns
#' @export
process_gdp <- function(df, unit = "MIO_EUR") {
  process_eurostat(df, filters = list(unit = unit), out_col = "gdp")
}

#' Process Employment Data
#'
#' Filters regional employment data from Eurostat LFS datasets
#'
#' @param df Raw dataframe from Eurostat lfst_r_lfe2emp or similar
#' @param unit Unit filter (default: "THS" for thousands)
#' @param sex Sex filter (default: "T" for total)
#' @param age Age group filter (default: "Y15-64")
#' @return Processed dataframe with geo, year, and employment columns
#' @export
process_employment <- function(df, unit = "THS", sex = "T", age = "Y15-64") {
  process_eurostat(df,
    filters = list(unit = unit, sex = sex, age = age),
    out_col = "employment")
}

#' Process Unemployment Rate Data
#'
#' Filters regional unemployment rate data from Eurostat (lfst_r_lfu3rt)
#'
#' @param df Raw dataframe from Eurostat lfst_r_lfu3rt
#' @param sex Sex filter (default: "T" for total)
#' @param age Age group filter (default: "Y15-74")
#' @return Processed dataframe with geo, year, and unemployment_rate columns
#' @export
process_unemployment_rate <- function(df, sex = "T", age = "Y15-74") {
  process_eurostat(df,
    filters = list(sex = sex, age = age),
    out_col = "unemployment_rate")
}

#' Process Population Data
#'
#' Filters regional population data from Eurostat (demo_r_d2jan)
#'
#' @param df Raw dataframe from Eurostat demo_r_d2jan
#' @param sex Sex filter (default: "T" for total)
#' @param age Age group filter (default: "TOTAL")
#' @return Processed dataframe with geo, year, and population columns
#' @export
process_population <- function(df, sex = "T", age = "TOTAL") {
  process_eurostat(df,
    filters = list(sex = sex, age = age),
    out_col = "population")
}

#' Process Life Expectancy Data
#'
#' Filters regional life expectancy data from Eurostat (demo_r_mlifexp)
#'
#' @param df Raw dataframe from Eurostat demo_r_mlifexp
#' @param sex Sex filter (default: "T" for total)
#' @param age Age at which expectancy is computed (default: "Y_LT1" for at birth)
#' @return Processed dataframe with geo, year, and life_expectancy columns
#' @export
process_life_expectancy <- function(df, sex = "T", age = "Y_LT1") {
  process_eurostat(df,
    filters = list(sex = sex, age = age),
    out_col = "life_expectancy")
}

#' Process Tourism Nights Spent Data
#'
#' Filters regional tourism data from Eurostat (tour_occ_nin2)
#'
#' @param df Raw dataframe from Eurostat tour_occ_nin2
#' @param unit Unit filter (default: "NR" for number)
#' @param nace_r2 NACE sector filter (default: "I551-I553" for accommodation)
#' @param c_resid Residence filter (default: "TOTAL")
#' @return Processed dataframe with geo, year, and nights_spent columns
#' @export
process_tourism_nights <- function(df, unit = "NR", nace_r2 = "I551-I553", c_resid = "TOTAL") {
  process_eurostat(df,
    filters = list(unit = unit, nace_r2 = nace_r2, c_resid = c_resid),
    out_col = "nights_spent")
}

#' Process R&D Expenditure Data
#'
#' Filters regional R&D expenditure data from Eurostat (rd_e_gerdreg)
#'
#' @param df Raw dataframe from Eurostat rd_e_gerdreg
#' @param unit Unit filter (default: "PC_GDP" for percentage of GDP)
#' @param sectperf Sector of performance (default: "TOTAL")
#' @return Processed dataframe with geo, year, and rd_expenditure columns
#' @export
process_rd_expenditure <- function(df, unit = "PC_GDP", sectperf = "TOTAL") {
  process_eurostat(df,
    filters = list(unit = unit, sectperf = sectperf),
    out_col = "rd_expenditure")
}

#' Process Education Attainment Data
#'
#' Filters regional education attainment data from Eurostat (edat_lfse_*)
#'
#' @param df Raw dataframe from Eurostat edat_lfse_11 or similar
#' @param sex Sex filter (default: "T" for total)
#' @param age Age group filter (default: "Y25-64")
#' @param isced11 Education level filter (default: "ED5-8" for tertiary)
#' @return Processed dataframe with geo, year, and education_attainment columns
#' @export
process_education_attainment <- function(df, sex = "T", age = "Y25-64", isced11 = "ED5-8") {
  process_eurostat(df,
    filters = list(sex = sex, age = age, isced11 = isced11),
    out_col = "education_attainment")
}

#' Process Poverty Rate Data
#'
#' Filters regional at-risk-of-poverty rate data from Eurostat (ilc_li41)
#'
#' @param df Raw dataframe from Eurostat ilc_li41
#' @return Processed dataframe with geo, year, and poverty_rate columns
#' @export
process_poverty_rate <- function(df) {
  process_eurostat(df, filters = list(), out_col = "poverty_rate")
}

#' Process Municipal Waste Data
#'
#' Filters regional municipal waste data from Eurostat (env_rwas_gen)
#'
#' @param df Raw dataframe from Eurostat env_rwas_gen
#' @param unit Unit filter (default: "KG_HAB" for kg per inhabitant)
#' @return Processed dataframe with geo, year, and municipal_waste columns
#' @export
process_waste <- function(df, unit = "KG_HAB") {
  process_eurostat(df,
    filters = list(unit = unit),
    out_col = "municipal_waste")
}
