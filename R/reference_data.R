#' @title Reference Data Functions
#' @description Functions for fetching NUTS reference geometries and lookup tables.
#'   All geometry and reference functions use session-level smart caching
#'   via \code{\link{clear_localintel_cache}} for instant repeated access.
#' @name reference_data
NULL

#' Get NUTS Geometry from Eurostat
#'
#' Fetches NUTS boundary geometries from Eurostat geospatial API.
#' Results are cached within the R session for instant repeated access.
#' Use \code{\link{clear_localintel_cache}()} to force a fresh fetch.
#'
#' @param level Integer NUTS level (0, 1, 2, or 3)
#' @param year Integer year for NUTS classification (default: 2024)
#' @param resolution Character resolution code ("60", "20", "10", "03", "01")
#' @param crs Integer EPSG code for coordinate reference system (default: 4326)
#' @return sf object with NUTS boundaries
#' @export
#' @examples
#' \dontrun{
#' nuts2_geo <- get_nuts_geo(level = 2, year = 2024)
#' }
get_nuts_geo <- function(level, year = 2024, resolution = "60", crs = 4326) {
  key <- cache_key("get_nuts_geo", level, year, resolution, crs)
  cached <- cache_get(key)
  if (!is.null(cached)) return(cached)

  if (!requireNamespace("giscoR", quietly = TRUE)) {
    stop("'giscoR' package is required for geospatial functionalities.\n",
         "Install it with: install.packages('giscoR')",
         call. = FALSE)
  }

  result <- eurostat::get_eurostat_geospatial(
    nuts_level = level,
    year = year,
    resolution = resolution,
    cache = TRUE,
    update_cache = TRUE,
    output_class = "sf",
    crs = crs
  ) %>%
    sf::st_make_valid() %>%
    dplyr::transmute(
      geo = .data$NUTS_ID,
      level = level,
      geometry = .data$geometry
    )

  cache_set(key, result)
  result
}

#' Get All NUTS Level Geometries
#'
#' Fetches and combines NUTS 0, 1, and 2 level geometries into a single sf object.
#' Results are cached within the R session.
#'
#' @param year Integer year for NUTS classification (default: 2024)
#' @param resolution Character resolution code (default: "60")
#' @param crs Integer EPSG code (default: 4326)
#' @param levels Integer vector of NUTS levels to include (default: c(0, 1, 2))
#' @return sf object with combined NUTS boundaries
#' @export
#' @examples
#' \dontrun{
#' geopolys <- get_nuts_geopolys()
#' }
get_nuts_geopolys <- function(year = 2024, resolution = "60", crs = 4326, levels = c(0, 1, 2)) {
  key <- cache_key("get_nuts_geopolys", year, resolution, crs, paste(levels, collapse = "-"))
  cached <- cache_get(key)
  if (!is.null(cached)) return(cached)

  geo_list <- lapply(levels, function(lvl) {
    get_nuts_geo(level = lvl, year = year, resolution = resolution, crs = crs)
  })

  result <- dplyr::bind_rows(geo_list)
  cache_set(key, result)
  result
}

#' Get NUTS2 Reference Table
#'
#' Creates a reference table mapping NUTS2 codes to their parent NUTS1 and NUTS0 codes.
#' Results are cached within the R session.
#'
#' @param year Integer year for NUTS classification (default: 2024)
#' @param resolution Character resolution code (default: "60")
#' @return Dataframe with geo, nuts1, and nuts0 columns
#' @export
#' @examples
#' \dontrun{
#' nuts2_ref <- get_nuts2_ref()
#' head(nuts2_ref)
#' }
get_nuts2_ref <- function(year = 2024, resolution = "60") {
  key <- cache_key("get_nuts2_ref", year, resolution)
  cached <- cache_get(key)
  if (!is.null(cached)) return(cached)

  if (!requireNamespace("giscoR", quietly = TRUE)) {
    stop("'giscoR' package is required for geospatial functionalities.\n",
         "Install it with: install.packages('giscoR')",
         call. = FALSE)
  }

  geodata <- eurostat::get_eurostat_geospatial(
    nuts_level = 2,
    year = year,
    resolution = resolution,
    cache = TRUE,
    update_cache = TRUE,
    output_class = "sf",
    crs = 4326
  )

  result <- geodata %>%
    sf::st_drop_geometry() %>%
    dplyr::transmute(
      geo = .data$NUTS_ID,
      nuts1 = substr(.data$NUTS_ID, 1, 3),
      nuts0 = substr(.data$NUTS_ID, 1, 2)
    )

  cache_set(key, result)
  result
}

#' Get NUTS2 Name Lookup Table
#'
#' Creates a lookup table mapping NUTS2 codes to region names.
#' Results are cached within the R session.
#'
#' @param year Integer year for NUTS classification (default: 2024)
#' @param resolution Character resolution code (default: "60")
#' @param countries Optional character vector of 2-letter country codes to filter
#' @return Dataframe with geo and nuts2_name columns
#' @export
#' @examples
#' \dontrun{
#' lut <- get_nuts2_names()
#' }
get_nuts2_names <- function(year = 2024, resolution = "60", countries = NULL) {
  key <- cache_key("get_nuts2_names", year, resolution)
  cached <- cache_get(key)

  if (is.null(cached)) {
    if (!requireNamespace("giscoR", quietly = TRUE)) {
      stop("'giscoR' package is required for geospatial functionalities.\n",
           "Install it with: install.packages('giscoR')",
           call. = FALSE)
    }

    geodata <- eurostat::get_eurostat_geospatial(
      nuts_level = 2,
      year = year,
      resolution = resolution,
      output_class = "sf",
      crs = 4326,
      cache = TRUE,
      update_cache = TRUE
    )

    cached <- geodata %>%
      sf::st_drop_geometry() %>%
      dplyr::transmute(
        geo = .data$NUTS_ID,
        nuts2_name = dplyr::coalesce(.data$NAME_LATN, .data$NUTS_NAME)
      ) %>%
      dplyr::distinct()

    cache_set(key, cached)
  }

  result <- cached
  if (!is.null(countries)) {
    result <- result %>%
      dplyr::filter(substr(.data$geo, 1, 2) %in% countries)
  }

  result
}

#' Get Population Data by NUTS2
#'
#' Fetches population data from Eurostat for NUTS2 regions
#'
#' @param years Integer vector of years
#' @param countries Optional character vector of 2-letter country codes to filter
#' @param fill_gaps Logical, whether to fill gaps using forward/backward fill
#' @return Dataframe with geo, year, and pop columns
#' @export
#' @examples
#' \dontrun{
#' pop <- get_population_nuts2(years = 2010:2024)
#' }
get_population_nuts2 <- function(years = 2000:2024, countries = NULL, fill_gaps = TRUE) {
  pop_data <- eurostat::get_eurostat("tgs00096", time_format = "raw", cache = TRUE) %>%
    standardize_time() %>%
    dplyr::filter(
      nchar(.data$geo) == 4,
      .data$year %in% years
    ) %>%
    dplyr::transmute(geo = .data$geo, year = .data$year, pop = .data$values)

  if (fill_gaps) {
    pop_data <- pop_data %>%
      dplyr::group_by(.data$geo) %>%
      tidyr::complete(year = years) %>%
      dplyr::arrange(.data$geo, .data$year) %>%
      tidyr::fill("pop", .direction = "downup") %>%
      dplyr::ungroup()
  }

  if (!is.null(countries)) {
    pop_data <- pop_data %>%
      dplyr::filter(substr(.data$geo, 1, 2) %in% countries)
  }

  pop_data
}

#' EU27 Country Codes
#'
#' Returns a character vector of EU27 country codes
#'
#' @return Character vector of 2-letter country codes
#' @export
#' @examples
#' eu27_codes()
eu27_codes <- function() {
  c("AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "EL",
    "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
    "SI", "ES", "SE")
}
