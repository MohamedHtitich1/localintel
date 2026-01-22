#' @title Eurostat Data Fetching Functions
#' @description Functions for fetching data from the Eurostat API at various NUTS levels
#' @name data_fetch
NULL

#' Get NUTS2 Level Data from Eurostat
#'
#' Fetches data for a specific Eurostat dataset code at NUTS2 level
#'
#' @param code Character string of the Eurostat dataset code
#' @param years Integer vector of years to filter. If NULL, returns all available years.
#' @return Dataframe with NUTS2 level data
#' @export
#' @examples
#' \dontrun{
#' beds_data <- get_nuts2("hlth_rs_bdsrg2", years = 2015:2023)
#' }
get_nuts2 <- function(code, years = NULL) {
  df <- eurostat::get_eurostat(
    code,
    time_format = "raw",
    stringsAsFactors = FALSE,
    cache = TRUE
  )
  
  # Normalize time column name
  if (!"time" %in% names(df)) {
    if ("TIME_PERIOD" %in% names(df)) {
      df <- dplyr::rename(df, time = .data$TIME_PERIOD)
    } else {
      stop("No time column detected in dataset: ", code)
    }
  }
  
  # Parse year and filter to NUTS2 (4-char codes)
  df <- df %>%
    dplyr::mutate(time = as.integer(substr(as.character(.data$time), 1, 4))) %>%
    dplyr::filter(stringr::str_length(.data$geo) == 4)
  
  if (!is.null(years)) {
    df <- df %>% dplyr::filter(!is.na(.data$time) & .data$time %in% years)
  }
  
  df
}

#' Get Data at Specified NUTS Level from Eurostat
#'
#' Fetches data for a specific Eurostat dataset code at the specified NUTS level
#'
#' @param code Character string of the Eurostat dataset code
#' @param level Integer NUTS level (0, 1, 2, or 3)
#' @param years Integer vector of years to filter. If NULL, returns all available years.
#' @return Dataframe with data at the specified NUTS level
#' @export
#' @examples
#' \dontrun
#' beds_nuts1 <- get_nuts_level("hlth_rs_bdsrg2", level = 1, years = 2015:2023)
#' beds_country <- get_nuts_level("hlth_rs_bdsrg2", level = 0, years = 2015:2023)
#' }
get_nuts_level <- function(code, level = 2, years = NULL) {
  len_for_level <- c(`0` = 2, `1` = 3, `2` = 4, `3` = 5)
  stopifnot(as.character(level) %in% names(len_for_level))
  target_len <- len_for_level[as.character(level)]
  
  df <- eurostat::get_eurostat(
    code,
    time_format = "raw",
    stringsAsFactors = FALSE,
    cache = TRUE
  )
  
  # Normalize time column
  if (!"time" %in% names(df)) {
    if ("TIME_PERIOD" %in% names(df)) {
      df <- dplyr::rename(df, time = .data$TIME_PERIOD)
    } else {
      stop("No time column detected in dataset: ", code)
    }
  }
  
  # Parse year & filter by NUTS level
  df <- df %>%
    dplyr::mutate(time = as.integer(substr(as.character(.data$time), 1, 4))) %>%
    dplyr::filter(stringr::str_length(.data$geo) == target_len)
  
  if (!is.null(years)) {
    df <- df %>% dplyr::filter(!is.na(.data$time) & .data$time %in% years)
  }
  
  df
}

#' Robust NUTS Level Data Fetcher
#'
#' Fetches data with retry logic: forces cache refresh first, retries without cache on failure
#'
#' @param code Character string of the Eurostat dataset code
#' @param level Integer NUTS level (0, 1, 2, or 3)
#' @param years Integer vector of years to filter. If NULL, returns all available years.
#' @return Dataframe with data at the specified NUTS level
#' @export
#' @examples
#' \dontrun{
#' data <- get_nuts_level_robust("hlth_cd_asdr2", level = 2, years = 2010:2023)
#' }
get_nuts_level_robust <- function(code, level = 2, years = NULL) {
  len_for_level <- c(`0` = 2, `1` = 3, `2` = 4, `3` = 5)
  target_len <- len_for_level[as.character(level)]
  
  fetch <- function(cache, update) {
    eurostat::get_eurostat(
      code,
      time_format = "raw",
      stringsAsFactors = FALSE,
      cache = cache,
      update_cache = update
    )
  }
  
  df <- tryCatch(
    fetch(cache = TRUE, update = TRUE),
    error = function(e1) {
      message("Retrying ", code, " with cache=FALSE because: ", conditionMessage(e1))
      fetch(cache = FALSE, update = FALSE)
    }
  )
  
  # Normalize time column
  if (!"time" %in% names(df)) {
    if ("TIME_PERIOD" %in% names(df)) {
      df <- dplyr::rename(df, time = .data$TIME_PERIOD)
    } else {
      stop("No time column detected in dataset: ", code)
    }
  }
  
  df %>%
    dplyr::mutate(time = as.integer(substr(as.character(.data$time), 1, 4))) %>%
    dplyr::filter(stringr::str_length(.data$geo) == target_len) %>%
    {
      if (is.null(years)) . else dplyr::filter(., !is.na(.data$time) & .data$time %in% years)
    }
}

#' Safe NUTS Level Data Fetcher
#'
#' Wrapper around get_nuts_level_robust that returns empty tibble on error
#'
#' @inheritParams get_nuts_level_robust
#' @return Dataframe or empty tibble on error
#' @export
get_nuts_level_safe <- function(code, level = 2, years = NULL) {
  safe_fn <- purrr::possibly(get_nuts_level_robust, otherwise = tibble::tibble())
  safe_fn(code, level, years)
}

#' Fetch Multiple Eurostat Datasets
#'
#' Fetches multiple datasets at a specified NUTS level
#'
#' @param codes Named character vector where names are friendly names and values are Eurostat codes
#' @param level Integer NUTS level (0, 1, 2, or 3)
#' @param years Integer vector of years to filter
#' @param robust Logical, whether to use robust fetching with retry logic
#' @return Named list of dataframes
#' @export
#' @examples
#' \dontrun{
#' codes <- c(beds = "hlth_rs_bdsrg2", physicians = "hlth_rs_physreg")
#' data_list <- fetch_eurostat_batch(codes, level = 2, years = 2015:2023)
#' }
fetch_eurostat_batch <- function(codes, level = 2, years = NULL, robust = TRUE) {
  fetch_fn <- if (robust) get_nuts_level_safe else get_nuts_level
  
  purrr::imap(codes, ~ {
    message("Fetching ", .y, " (", .x, ") at NUTS", level, "...")
    fetch_fn(.x, level = level, years = years)
  })
}

#' Drop Empty Results from a List
#'
#' Removes list elements with zero rows
#'
#' @param x List of dataframes
#' @return Filtered list with only non-empty dataframes
#' @export
drop_empty <- function(x) {
 x[vapply(x, nrow, integer(1)) > 0]
}

#' Health System Dataset Codes
#'
#' Returns a named vector of common Eurostat health system dataset codes
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- health_system_codes()
#' names(codes)
health_system_codes <- function() {
  c(
    disch_inp = "hlth_co_disch2t",
    disch_day = "hlth_co_disch4t",
    hos_days = "hlth_co_hosdayt",
    los = "hlth_co_inpstt",
    beds = "hlth_rs_bdsrg2",
    physicians = "hlth_rs_physreg"
  )
}

#' Causes of Death Dataset Codes
#'
#' Returns a named vector of Eurostat causes of death dataset codes
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- causes_of_death_codes()
#' names(codes)
causes_of_death_codes <- function() {
  c(
    cod_crude_rate = "hlth_cd_acdr",
    cod_crude_rate_residence = "hlth_cd_acdr2",
    cod_standardised_rate_res = "hlth_cd_asdr2",
    cod_crude_rate_3y_res = "hlth_cd_ycdr2",
    cod_crude_rate_3y_female = "hlth_cd_ycdrf",
    cod_crude_rate_3y_male = "hlth_cd_ycdrm",
    cod_crude_rate_3y_total = "hlth_cd_ycdrt",
    cod_infant_mort_3y_occ = "hlth_cd_yinfo",
    cod_infant_mort_3y_res = "hlth_cd_yinfr",
    cod_absolute_3y_female = "hlth_cd_ynrf",
    cod_absolute_3y_male = "hlth_cd_ynrm",
    cod_absolute_3y_total = "hlth_cd_ynrt",
    cod_pyll_3y_res = "hlth_cd_ypyll",
    cod_deaths_3y_res_occ = "hlth_cd_yro",
    cod_standardised_rate_3y = "hlth_cd_ysdr1",
    cod_standardised_rate_3y_res = "hlth_cd_ysdr2"
  )
}
