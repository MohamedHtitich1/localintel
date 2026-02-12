#' @title Visualization Functions
#' @description Functions for creating maps and visualizations of NUTS-level data
#' @name visualization
NULL

#' Get Level Column Name for Variable
#'
#' Returns the source level column name for a given variable
#'
#' @param var Character string of variable name
#' @return Character string of the corresponding level column name
#' @export
#' @examples
#' level_col_for("beds")  # returns "src_beds_level"
level_col_for <- function(var, special_cases = NULL) {
  # Build the standard pattern
  std_col <- paste0("src_", var, "_level")

  # Default special cases for backward compatibility with health indicators
  if (is.null(special_cases)) {
    special_cases <- c(
      da = "elig_da_level",
      rlos = "elig_rlos_level",
      physicians_log2 = "src_physicians_level"
    )
  }

  if (var %in% names(special_cases)) {
    return(special_cases[[var]])
  }

  std_col
}

#' Get Level Columns for Multiple Variables
#'
#' Vectorized version of level_col_for
#'
#' @param vars Character vector of variable names
#' @return Character vector of level column names
#' @export
level_cols_for <- function(vars) {
  vapply(vars, level_col_for, character(1))
}

#' Build Display SF Object
#'
#' Creates an sf object for visualization, selecting the best available NUTS level
#' for each country-year combination.
#'
#' @param out_nuts2 Dataframe with cascaded NUTS2 data
#' @param geopolys sf object with NUTS geometries from get_nuts_geopolys()
#' @param var Character string of variable to display
#' @param years Integer vector of years to include. If NULL, uses all available.
#' @param skip_nuts0 Logical, whether to skip NUTS0 level display (default: TRUE)
#' @param scale Character, "per_year" or "global" scaling
#' @return sf object ready for mapping
#' @export
#' @examples
#' \dontrun{
#' sf_data <- build_display_sf(cascaded_data, geopolys, var = "beds", years = 2020:2024)
#' }
build_display_sf <- function(out_nuts2,
                             geopolys,
                             var,
                             years = NULL,
                             skip_nuts0 = TRUE,
                             scale = c("per_year", "global")) {
  scale <- match.arg(scale)
  stopifnot(
    all(c("geo", "year", var) %in% names(out_nuts2)),
    all(c("geo", "level", "geometry") %in% names(geopolys))
  )
  
  lvl_col <- level_col_for(var)
  
  D <- out_nuts2
  if (!is.null(years)) {
    D <- D %>% dplyr::filter(.data$year %in% years)
  }
  
  # Decide display level per country-year
  disp <- D %>%
    dplyr::mutate(ctry = substr(.data$geo, 1, 2), src = .data[[lvl_col]]) %>%
    dplyr::group_by(.data$ctry, .data$year) %>%
    dplyr::summarise(
      disp_level = dplyr::case_when(
        any(.data$src == 2, na.rm = TRUE) ~ 2L,
        any(.data$src == 1, na.rm = TRUE) ~ 1L,
        any(.data$src == 0, na.rm = TRUE) ~ 0L,
        TRUE ~ NA_integer_
      ),
      .groups = "drop"
    ) %>%
    dplyr::filter(!is.na(.data$disp_level))
  
  if (skip_nuts0) {
    disp <- disp %>% dplyr::filter(.data$disp_level != 0L)
  }
  
  # Assemble values at display level
  vals2 <- D %>%
    dplyr::mutate(ctry = substr(.data$geo, 1, 2)) %>%
    dplyr::inner_join(disp %>% dplyr::filter(.data$disp_level == 2L), by = c("ctry", "year")) %>%
    dplyr::transmute(geo = .data$geo, year = .data$year, level = 2L, value = .data[[var]])
  
  vals1 <- D %>%
    dplyr::mutate(ctry = substr(.data$geo, 1, 2), nuts1 = substr(.data$geo, 1, 3)) %>%
    dplyr::inner_join(disp %>% dplyr::filter(.data$disp_level == 1L), by = c("ctry", "year")) %>%
    dplyr::group_by(.data$nuts1, .data$year) %>%
    dplyr::summarise(value = dplyr::first(stats::na.omit(.data[[var]])), .groups = "drop") %>%
    dplyr::transmute(geo = .data$nuts1, year = .data$year, level = 1L, value = .data$value)
  
  vals0 <- if (skip_nuts0) {
    tibble::tibble(geo = character(), year = integer(), level = integer(), value = numeric())
  } else {
    D %>%
      dplyr::mutate(ctry = substr(.data$geo, 1, 2)) %>%
      dplyr::inner_join(disp %>% dplyr::filter(.data$disp_level == 0L), by = c("ctry", "year")) %>%
      dplyr::group_by(.data$ctry, .data$year) %>%
      dplyr::summarise(value = dplyr::first(stats::na.omit(.data[[var]])), .groups = "drop") %>%
      dplyr::transmute(geo = .data$ctry, year = .data$year, level = 0L, value = .data$value)
  }
  
  vals <- dplyr::bind_rows(vals2, vals1, vals0) %>%
    dplyr::distinct(.data$geo, .data$year, .data$level, .keep_all = TRUE)
  
  # Apply scaling
  vals <- if (scale == "per_year") {
    vals %>% dplyr::group_by(.data$year) %>% dplyr::mutate(value_scaled = .data$value) %>% dplyr::ungroup()
  } else {
    vals %>% dplyr::mutate(value_scaled = .data$value)
  }
  
  vals %>%
    dplyr::left_join(geopolys, by = c("geo", "level")) %>%
    sf::st_as_sf()
}

#' Build Display SF for Life Course Data
#'
#' Version of build_display_sf that preserves additional grouping columns like Age
#'
#' @inheritParams build_display_sf
#' @param keep Character vector of additional columns to preserve
#' @return sf object ready for mapping
#' @export
lc_build_display_sf <- function(out_nuts2,
                                geopolys,
                                var,
                                years = NULL,
                                skip_nuts0 = TRUE,
                                scale = c("per_year", "global"),
                                keep = NULL) {
  scale <- match.arg(scale)
  stopifnot(
    all(c("geo", "year", var) %in% names(out_nuts2)),
    all(c("geo", "level", "geometry") %in% names(geopolys))
  )
  
  # Auto-keep age_group if present
  if (is.null(keep)) keep <- intersect("Age", names(out_nuts2))
  stopifnot(all(keep %in% names(out_nuts2)))
  
  lvl_col <- level_col_for(var)
  D <- out_nuts2
  if (!is.null(years)) D <- D %>% dplyr::filter(.data$year %in% years)
  
  # Decide display level per country-year
  disp <- D %>%
    dplyr::mutate(ctry = substr(.data$geo, 1, 2), src = .data[[lvl_col]]) %>%
    dplyr::group_by(.data$ctry, .data$year) %>%
    dplyr::summarise(
      disp_level = dplyr::case_when(
        any(.data$src == 2, na.rm = TRUE) ~ 2L,
        any(.data$src == 1, na.rm = TRUE) ~ 1L,
        any(.data$src == 0, na.rm = TRUE) ~ 0L,
        TRUE ~ NA_integer_
      ),
      .groups = "drop"
    ) %>%
    dplyr::filter(!is.na(.data$disp_level))
  
  if (skip_nuts0) disp <- disp %>% dplyr::filter(.data$disp_level != 0L)
  
  # Level 2 (NUTS2)
  vals2 <- D %>%
    dplyr::mutate(ctry = substr(.data$geo, 1, 2)) %>%
    dplyr::inner_join(disp %>% dplyr::filter(.data$disp_level == 2L), by = c("ctry", "year")) %>%
    dplyr::mutate(level = 2L, value = .data[[var]]) %>%
    dplyr::select("geo", "year", "level", "value", dplyr::all_of(keep))
  
  # Level 1 (NUTS1)
  vals1 <- D %>%
    dplyr::mutate(ctry = substr(.data$geo, 1, 2), nuts1 = substr(.data$geo, 1, 3)) %>%
    dplyr::inner_join(disp %>% dplyr::filter(.data$disp_level == 1L), by = c("ctry", "year")) %>%
    dplyr::group_by(.data$nuts1, .data$year, dplyr::across(dplyr::all_of(keep))) %>%
    dplyr::summarise(value = dplyr::first(stats::na.omit(.data[[var]])), .groups = "drop") %>%
    dplyr::transmute(geo = .data$nuts1, year = .data$year, level = 1L, value = .data$value, !!!rlang::syms(keep))
  
  pieces <- list(vals2, vals1)
  
  # Level 0 (NUTS0) if requested
  if (!skip_nuts0) {
    vals0 <- D %>%
      dplyr::mutate(ctry = substr(.data$geo, 1, 2)) %>%
      dplyr::inner_join(disp %>% dplyr::filter(.data$disp_level == 0L), by = c("ctry", "year")) %>%
      dplyr::group_by(.data$ctry, .data$year, dplyr::across(dplyr::all_of(keep))) %>%
      dplyr::summarise(value = dplyr::first(stats::na.omit(.data[[var]])), .groups = "drop") %>%
      dplyr::transmute(geo = .data$ctry, year = .data$year, level = 0L, value = .data$value, !!!rlang::syms(keep))
    pieces <- append(pieces, list(vals0))
  }
  
  vals <- dplyr::bind_rows(pieces) %>%
    dplyr::distinct(.data$geo, .data$year, .data$level, !!!rlang::syms(keep), .keep_all = TRUE)
  
  # Scaling
  vals <- if (scale == "per_year") {
    vals %>% dplyr::group_by(.data$year) %>% dplyr::mutate(value_scaled = .data$value) %>% dplyr::ungroup()
  } else {
    vals %>% dplyr::mutate(value_scaled = .data$value)
  }
  
  vals %>%
    dplyr::left_join(geopolys, by = c("geo", "level")) %>%
    sf::st_as_sf()
}

#' Plot Map by Best Country Level
#'
#' Creates faceted maps showing the best available data for each country,
#' with consistent color scales across years.
#'
#' @param out_nuts2 Dataframe with cascaded NUTS2 data
#' @param geopolys sf object with NUTS geometries
#' @param var Character string of variable to plot
#' @param years Integer vector of years to plot
#' @param skip_nuts0 Logical, whether to skip NUTS0 level (default: TRUE)
#' @param scale Character, "per_year" or "global" scaling
#' @param title Optional custom title
#' @param pdf_file Optional PDF filename for output
#' @param bb_x Numeric vector of x bounding box limits (in EPSG:3035)
#' @param bb_y Numeric vector of y bounding box limits (in EPSG:3035)
#' @param col_var Column to use for coloring ("value" or "value_scaled")
#' @param n_breaks Number of legend breaks
#' @param breaks Optional custom breaks vector
#' @return Prints tmap objects for each year
#' @export
#' @examples
#' \dontrun{
#' plot_best_by_country_level(cascaded_data, geopolys, var = "beds", years = 2020:2024)
#' }
plot_best_by_country_level <- function(out_nuts2,
                                       geopolys,
                                       var,
                                       years = NULL,
                                       skip_nuts0 = TRUE,
                                       scale = c("per_year", "global"),
                                       title = NULL,
                                       pdf_file = paste0("Map_", var, "_country_level_scaled.pdf"),
                                       bb_x = c(2400000, 7800000),
                                       bb_y = c(1320000, 5650000),
                                       col_var = NULL,
                                       n_breaks = 7,
                                       breaks = NULL) {
  scale <- match.arg(scale)
  
  sf_vals <- build_display_sf(out_nuts2, geopolys, var, years,
                              skip_nuts0 = skip_nuts0, scale = scale)
  yrs <- sort(unique(sf_vals$year))
  if (!length(yrs)) stop("No data to plot for variable: ", var)
  
  # Which column to color by
  if (is.null(col_var)) {
    col_var <- if ("value_scaled" %in% names(sf_vals)) "value_scaled" else "value"
  }
  
  # Fixed breaks across all years
  if (is.null(breaks)) {
    rng <- range(sf_vals[[col_var]], na.rm = TRUE)
    if (!is.finite(rng[1]) || !is.finite(rng[2])) stop("No finite values for ", col_var)
    if (rng[1] == rng[2]) rng <- c(rng[1] - 1e-9, rng[2] + 1e-9)
    breaks <- pretty(rng, n = n_breaks)
  }
  
  title_base <- if (is.null(title)) var else title
  tmap::tmap_mode("plot")
  
  for (yy in yrs) {
    legend_title <- paste0(title_base, " - ", yy)
    
    p <- tmap::tm_shape(sf::st_transform(geopolys, 3035), xlim = bb_x, ylim = bb_y) +
      tmap::tm_polygons(col = "grey95", lwd = 0.7, border.col = "white") +
      tmap::tm_shape(sf_vals %>% dplyr::filter(.data$year == yy) %>% sf::st_transform(3035)) +
      tmap::tm_polygons(
        col_var,
        style = "fixed",
        breaks = breaks,
        palette = "Viridis",
        title = legend_title,
        border.col = "white",
        lwd = 0.4,
        legend.show = TRUE
      ) +
      tmap::tm_layout(frame = FALSE)
    
    print(p)
  }
  
  message("Plotted: ", pdf_file)
}

#' Build Multi-Variable Display SF for Tableau
#'
#' Creates a combined sf object with multiple variables for export to Tableau
#'
#' @param out_nuts2 Dataframe with cascaded NUTS2 data
#' @param geopolys sf object with NUTS geometries
#' @param vars Character vector of variables to include
#' @param years Integer vector of years
#' @param var_labels Optional named character vector mapping vars to display labels
#' @param pillar_mapping Optional named character vector mapping vars to pillars
#' @return sf object with all variables, ready for Tableau export
#' @export
build_multi_var_sf <- function(out_nuts2,
                               geopolys,
                               vars,
                               years = 2010:2024,
                               var_labels = NULL,
                               pillar_mapping = NULL) {
  
  sf_all <- dplyr::bind_rows(
    lapply(vars, function(v) {
      sf_data <- build_display_sf(out_nuts2, geopolys, var = v, years = years)
      
      sf_data <- sf_data %>%
        dplyr::mutate(var = v)
      
      # Add variable labels if provided
      if (!is.null(var_labels) && v %in% names(var_labels)) {
        sf_data$var_fullname <- var_labels[[v]]
      } else {
        sf_data$var_fullname <- v
      }
      
      # Add pillar mapping if provided
      if (!is.null(pillar_mapping) && v %in% names(pillar_mapping)) {
        sf_data$pillar <- pillar_mapping[[v]]
      }
      
      sf_data
    })
  )
  
  sf_all %>%
    sf::st_transform(4326) %>%
    sf::st_cast("MULTIPOLYGON", warn = FALSE)
}
