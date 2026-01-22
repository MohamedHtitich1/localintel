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
