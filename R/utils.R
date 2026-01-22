#' @title Utility Functions for localintel
#' @description Helper functions used across the package
#' @name utils
NULL

#' Safe Log10 Transformation
#'
#' Computes log10 while handling NA and non-positive values
#'
#' @param x Numeric vector
#' @return Numeric vector with log10 values, NA for invalid inputs
#' @export
#' @examples
#' safe_log10(c(1, 10, 100, 0, -5, NA))
safe_log10 <- function(x) {
  ifelse(is.na(x) | x <= 0, NA_real_, log10(x))
}

#' Safe Log2 Transformation
#'
#' Computes log2 while handling NA and non-positive values
#'
#' @param x Numeric vector
#' @return Numeric vector with log2 values, NA for invalid inputs
#' @export
#' @examples
#' safe_log2(c(1, 2, 4, 0, -5, NA))
safe_log2 <- function(x) {
  ifelse(is.na(x) | x <= 0, NA_real_, log2(x))
}

#' Scale Values to 0-100 Range
#'
#' Min-max normalization to scale values between 0 and 100
#'
#' @param x Numeric vector
#' @return Numeric vector scaled to 0-100
#' @export
#' @examples
#' scale_0_100(c(10, 20, 30, 40, 50))
scale_0_100 <- function(x) {
  r <- range(x, na.rm = TRUE)
  if (!is.finite(r[1]) || !is.finite(r[2]) || r[1] == r[2]) {
    return(rep(NA_real_, length(x)))
  }
  (x - r[1]) / (r[2] - r[1]) * 100
}

#' Rescale to Min-Max (0-100)
#'
#' Alternative name for scale_0_100 for backward compatibility
#'
#' @inheritParams scale_0_100
#' @return Numeric vector scaled to 0-100
#' @export
rescale_minmax <- scale_0_100

#' Linear Interpolation with Constant Endpoints and Flag
#'
#' Performs linear interpolation within gaps and repeats endpoints.
#' Also returns a flag indicating which values were originally NA.
#'
#' @param y Numeric vector to interpolate
#' @return List with 'value' (interpolated values) and 'flag' (1 if was NA, 0 otherwise)
#' @export
#' @examples
#' result <- interp_const_ends_flag(c(NA, 10, NA, NA, 20, NA))
#' result$value
#' result$flag
interp_const_ends_flag <- function(y) {
  n <- length(y)
  idx <- which(!is.na(y))
  was_na <- is.na(y)
  
  if (!length(idx)) {
    return(list(value = y, flag = as.integer(was_na)))
  }
  if (length(idx) == 1) {
    return(list(value = rep(y[idx], n), flag = as.integer(was_na)))
  }
  

  v <- stats::approx(x = idx, y = y[idx], xout = seq_len(n), method = "linear", rule = 2)$y
  list(value = v, flag = as.integer(was_na))
}

#' Filter Data to EU27 Countries (Plus Optional Extras)
#'
#' Filters a dataframe with a 'geo' column to include only EU27 countries
#' and optionally additional specified countries.
#'
#' @param df Dataframe with a 'geo' column containing NUTS codes
#' @param extra Character vector of additional 2-letter country codes to include
#' @return Filtered dataframe
#' @export
#' @examples
#' \dontrun{
#' df_filtered <- keep_eu27(my_data, extra = c("NO", "IS", "CH"))
#' }
keep_eu27 <- function(df, extra = c("NO", "IS")) {
  eu27 <- c("AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "EL",
            "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
            "SI", "ES", "SE")
  keep <- union(eu27, extra)
  
  df %>%
    dplyr::mutate(
      ctry = substr(.data$geo, 1, 2),
      ctry = ifelse(.data$ctry == "GR", "EL", .data$ctry)
    ) %>%
    dplyr::filter(.data$ctry %in% keep) %>%
    dplyr::select(-"ctry")
}

#' Standardize Time Column
#'
#' Standardizes time column naming and parses year as integer
#'
#' @param df Dataframe with 'time' or 'TIME_PERIOD' column
#' @return Dataframe with standardized 'time' and 'year' columns
#' @export
standardize_time <- function(df) {
  if (!"time" %in% names(df)) {
    if ("TIME_PERIOD" %in% names(df)) {
      df <- dplyr::rename(df, time = .data$TIME_PERIOD)
    } else {
      stop("No 'time' or 'TIME_PERIOD' column found.")
    }
  }
  
  df %>%
    dplyr::mutate(year = {
      t <- .data$time
      if (inherits(t, "Date")) {
        as.integer(format(t, "%Y"))
      } else {
        as.integer(substr(as.character(t), 1, 4))
      }
    })
}

#' NUTS Country Names Lookup
#'
#' Named vector mapping 2-letter NUTS/EU codes to country names
#'
#' @return Named character vector
#' @export
nuts_country_names <- function() {
  c(
    AT = "Austria", BE = "Belgium", BG = "Bulgaria", HR = "Croatia",
    CY = "Cyprus", CZ = "Czechia", DK = "Denmark", EE = "Estonia",
    FI = "Finland", FR = "France", DE = "Germany", EL = "Greece", GR = "Greece",
    HU = "Hungary", IE = "Ireland", IT = "Italy", LV = "Latvia",
    LT = "Lithuania", LU = "Luxembourg", MT = "Malta", NL = "Netherlands",
    PL = "Poland", PT = "Portugal", RO = "Romania", SK = "Slovakia",
    SI = "Slovenia", ES = "Spain", SE = "Sweden",
    NO = "Norway", IS = "Iceland", CH = "Switzerland",
    UK = "United Kingdom", GB = "United Kingdom",
    RS = "Serbia", TR = "Turkiye", ME = "Montenegro",
    MK = "North Macedonia", AL = "Albania"
  )
}

#' Add Country Name Column
#'
#' Adds a country name column based on the geo code
#'
#' @param df Dataframe with geo column
#' @param geo_col Name of the geo column (default: "geo")
#' @param out_col Name of the output country column (default: "Country")
#' @return Dataframe with added country name column
#' @export
add_country_name <- function(df, geo_col = "geo", out_col = "Country") {
  stopifnot(geo_col %in% names(df))
  
  country_lookup <- nuts_country_names()
  codes <- substr(df[[geo_col]], 1, 2)
  codes[codes == "GR"] <- "EL"
  names_vec <- unname(country_lookup[codes])
  df[[out_col]] <- ifelse(is.na(names_vec), codes, names_vec)
  df
}
