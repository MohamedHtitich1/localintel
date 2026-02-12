#' @title Export Functions
#' @description Functions for exporting data to various formats including Tableau
#' @name export
NULL

#' Export SF to GeoJSON for Tableau
#'
#' Exports an sf object to GeoJSON format suitable for Tableau
#'
#' @param sf_data sf object to export
#' @param filepath Character path for output file
#' @param crs Integer EPSG code (default: 4326 for WGS84, required by Tableau)
#' @return Invisibly returns the filepath
#' @export
#' @examples
#' \dontrun{
#' export_to_geojson(sf_all, "output/eu_data.geojson")
#' }
export_to_geojson <- function(sf_data, filepath, crs = 4326) {
  sf_data %>%
    sf::st_transform(crs) %>%
    sf::st_cast("MULTIPOLYGON", warn = FALSE) %>%
    sf::st_write(filepath, delete_dsn = TRUE)
  
  message("Exported to: ", filepath)
  invisible(filepath)
}

#' Prepare Data for Tableau with Enrichment
#'
#' Enriches sf data with country names, region names, population, and performance tags
#'
#' @param sf_data sf object from build_display_sf or build_multi_var_sf
#' @param pop_data Population dataframe from get_population_nuts2()
#' @param nuts2_names Name lookup from get_nuts2_names()
#' @param var_col Name of the variable column (default: "var")
#' @param value_col Name of the value column (default: "value")
#' @return Enriched sf object ready for Tableau
#' @export
enrich_for_tableau <- function(sf_data,
                               pop_data = NULL,
                               nuts2_names = NULL,
                               var_col = "var",
                               value_col = "value") {
  
  result <- sf_data %>%
    add_country_name()
  
  # Add NUTS2 region names
  if (!is.null(nuts2_names)) {
    result <- result %>%
      dplyr::left_join(nuts2_names, by = "geo")
  }
  
  # Add population data
  if (!is.null(pop_data)) {
    result <- result %>%
      dplyr::left_join(pop_data, by = c("geo", "year"))
  }
  
  # Compute weighted country averages and performance tags
  if (var_col %in% names(result) && !is.null(pop_data)) {
    result <- result %>%
      dplyr::group_by(.data$Country, .data$year, .data[[var_col]]) %>%
      dplyr::mutate(
        var_country_avg = stats::weighted.mean(.data[[value_col]], .data$pop, na.rm = TRUE)
      ) %>%
      dplyr::group_by(.data$year, .data[[var_col]]) %>%
      dplyr::mutate(
        cntry_performance_tag = dplyr::case_when(
          .data$var_country_avg == max(.data$var_country_avg, na.rm = TRUE) ~ "Best",
          .data$var_country_avg == min(.data$var_country_avg, na.rm = TRUE) ~ "Worst",
          TRUE ~ NA_character_
        )
      ) %>%
      dplyr::group_by(.data$geo, .data[[var_col]]) %>%
      dplyr::mutate(
        score_change = .data[[value_col]][.data$year == min(.data$year)] - 
          .data[[value_col]][.data$year == max(.data$year)]
      ) %>%
      dplyr::group_by(.data$year, .data$Country, .data[[var_col]]) %>%
      dplyr::mutate(
        performance_tag = dplyr::case_when(
          .data[[value_col]] == max(.data[[value_col]], na.rm = TRUE) ~ "Best",
          .data[[value_col]] == min(.data[[value_col]], na.rm = TRUE) ~ "Worst",
          TRUE ~ NA_character_
        )
      ) %>%
      dplyr::ungroup()
  }
  
  result
}

#' Health Pillar Variable Labels
#'
#' Returns a named vector of display labels for health variables
#'
#' @return Named character vector
#' @export
health_var_labels <- function() {
  c(
    score_cod_standardised_rate_res_tr = "Standardized causes of death (rate)",
    score_cod_pyll_3y_res_tr = "Potential Years of Life Lost (3-year average)",
    score_infant_mortality_rt_tr = "Infant mortality (rate)",
    health_outcome = "Health Outcomes (composite)",
    score_E_E = "Enabling Environment (Composite)",
    physicians = "Physicians per 100000 inhabitants",
    beds = "Beds per 100000 inhabitants",
    score_TOOEFW_tr = "Too expensive or too far to travel or waiting list",
    score_HOPING_tr = "Wanted to wait and see if problem got better on its own",
    score_NO_UNMET_tr = "No unmet needs to declare",
    score_health_percep = "Health Perception (Composite)"
  )
}

#' Health Pillar Mapping
#'
#' Returns a named vector mapping variables to pillars
#'
#' @return Named character vector
#' @export
health_pillar_mapping <- function() {
  c(
    score_cod_standardised_rate_res_tr = "Health Outcomes",
    score_cod_pyll_3y_res_tr = "Health Outcomes",
    score_infant_mortality_rt_tr = "Health Outcomes",
    health_outcome = "Health Outcomes",
    score_E_E = "Enabling Environment",
    physicians = "Enabling Environment",
    beds = "Enabling Environment",
    score_TOOEFW_tr = "Health Perception (Reason of unmet needs)",
    score_HOPING_tr = "Health Perception (Reason of unmet needs)",
    score_NO_UNMET_tr = "Health Perception (Reason of unmet needs)",
    score_health_percep = "Health Perception (Reason of unmet needs)"
  )
}

#' Causes of Death Labels
#'
#' Returns a named vector of display labels for causes of death codes
#'
#' @return Named character vector
#' @export
cod_labels <- function() {
  c(
    A_R_V_Y = "All causes of death (raw)",
    R95 = "Sudden infant death syndrome",
    V01_Y89 = "External causes of morbidity and mortality",
    C00_D48 = "Neoplasms",
    G_H = "Diseases of the nervous system and the sense organs",
    J12_J18 = "Pneumonia",
    P = "Certain conditions originating in the perinatal period",
    Q = "Congenital malformations, deformations and chromosomal abnormalities",
    R96_R99 = "Ill-defined and unknown causes of mortality",
    ARVY = "All Causes of Death (% of the EU average 2013)",
    C = "Malignant neoplasm",
    W00_W19 = "Falls",
    V_Y85 = "Transport accidents",
    W65_W74 = "Accidental drowning and submersion",
    X60_X84_Y870 = "Intentional self-harm",
    I = "Diseases of the circulatory system",
    K = "Diseases of the digestive system",
    A_B = "Certain infectious and parasitic diseases",
    E = "Endocrine, nutritional and metabolic diseases",
    F01_F03 = "Dementia",
    G20 = "Parkinson disease",
    G30 = "Alzheimer disease",
    J = "Diseases of the respiratory system",
    N = "Diseases of the genitourinary system",
    R = "Symptoms, signs and abnormal clinical and laboratory findings"
  )
}

#' Export Data to Excel
#'
#' Exports dataframe to Excel format
#'
#' @param df Dataframe to export
#' @param filepath Character path for output file
#' @return Invisibly returns the filepath
#' @export
export_to_excel <- function(df, filepath) {
  # Remove geometry if present
  if (inherits(df, "sf")) {
    df <- sf::st_drop_geometry(df)
  }
  
  writexl::write_xlsx(df, filepath)
  message("Exported to: ", filepath)
  invisible(filepath)
}

#' Export Data to RDS
#'
#' Exports object to RDS format
#'
#' @param obj Object to export
#' @param filepath Character path for output file
#' @return Invisibly returns the filepath
#' @export
export_to_rds <- function(obj, filepath) {
  saveRDS(obj, filepath)
  message("Exported to: ", filepath)
  invisible(filepath)
}

#' Save Map to PDF
#'
#' Wrapper for saving multi-page map plots to PDF
#'
#' @param plot_fn Function that generates plots
#' @param filepath Character path for output PDF
#' @param width PDF width in inches
#' @param height PDF height in inches
#' @param ... Additional arguments passed to plot_fn
#' @return Invisibly returns the filepath
#' @export
save_maps_to_pdf <- function(plot_fn, filepath, width = 12, height = 8, ...) {
  grDevices::pdf(file = filepath, width = width, height = height)
  plot_fn(...)
  grDevices::dev.off()
  message("Saved to: ", filepath)
  invisible(filepath)
}

# ============================================================================
# MULTI-DOMAIN LABELS AND MAPPINGS
# ============================================================================

#' Regional Variable Labels (All Domains)
#'
#' Returns a comprehensive named vector of display labels for variables
#' across all thematic domains. Extends health-specific labels with
#' economy, education, labour, demography, tourism, and other domains.
#'
#' @return Named character vector mapping variable names to display labels
#' @export
#' @examples
#' labels <- regional_var_labels()
#' labels["gdp"]
regional_var_labels <- function() {
  c(
    # Health
    beds                 = "Hospital beds per 100,000 inhabitants",
    physicians           = "Physicians per 100,000 inhabitants",
    disch_inp            = "In-patient discharges per 100,000",
    disch_day            = "Day-case discharges per 100,000",
    los                  = "Average length of stay (days)",
    hos_days             = "Hospital days",
    da                   = "Discharge Activity (DA)",
    rlos                 = "Relative Length of Stay (rLOS)",
    cod_rate             = "Causes of death (standardised rate)",
    # Economy
    gdp                  = "GDP at current market prices (million EUR)",
    gdp_per_capita       = "GDP per capita (EUR)",
    gdp_growth           = "Real GDP growth rate (%)",
    gfcf                 = "Gross fixed capital formation (million EUR)",
    compensation         = "Compensation of employees (million EUR)",
    hh_disp_income       = "Household disposable income",
    # Demography
    population           = "Population on 1 January",
    pop_density          = "Population density (per km2)",
    life_expectancy      = "Life expectancy at birth (years)",
    fertility_rate       = "Total fertility rate",
    infant_mortality     = "Infant mortality rate",
    # Education
    education_attainment = "Tertiary education attainment (% of 25-64)",
    early_leavers        = "Early leavers from education (%)",
    neet_rate            = "NEET rate (% of 15-24)",
    training_rate        = "Participation in education and training (%)",
    # Labour
    employment           = "Employment (thousands)",
    employment_rate      = "Employment rate (%)",
    unemployment_rate    = "Unemployment rate (%)",
    long_term_unemp      = "Long-term unemployment (%)",
    activity_rate        = "Economic activity rate (%)",
    # Tourism
    nights_spent         = "Nights spent in tourist accommodation",
    arrivals             = "Arrivals at tourist accommodation",
    # Transport
    road_accidents       = "Road accident victims",
    vehicles             = "Stock of vehicles",
    # Environment
    municipal_waste      = "Municipal waste (kg per inhabitant)",
    energy_consumption   = "Energy consumption",
    # Science & Technology
    rd_expenditure       = "R&D expenditure (% of GDP)",
    patents_total        = "Patent applications to EPO",
    hightech_employment  = "High-tech employment",
    # Poverty
    poverty_rate         = "At-risk-of-poverty rate (%)",
    material_deprivation = "Severe material deprivation rate (%)",
    # Information Society
    internet_access      = "Households with internet access (%)",
    broadband            = "Households with broadband access (%)",
    ecommerce            = "Individuals using e-commerce (%)"
  )
}

#' Regional Domain Mapping (All Domains)
#'
#' Returns a named vector mapping variable names to their thematic domain.
#' Useful for grouping variables in dashboards and Tableau exports.
#'
#' @return Named character vector mapping variable names to domain names
#' @export
#' @examples
#' mapping <- regional_domain_mapping()
#' mapping["gdp"]            # "Economy"
#' mapping["unemployment_rate"]  # "Labour Market"
regional_domain_mapping <- function() {
  c(
    # Health
    beds = "Health", physicians = "Health", disch_inp = "Health",
    disch_day = "Health", los = "Health", hos_days = "Health",
    da = "Health", rlos = "Health", cod_rate = "Health",
    # Economy
    gdp = "Economy", gdp_per_capita = "Economy", gdp_growth = "Economy",
    gfcf = "Economy", compensation = "Economy", hh_disp_income = "Economy",
    # Demography
    population = "Demography", pop_density = "Demography",
    life_expectancy = "Demography", fertility_rate = "Demography",
    infant_mortality = "Demography",
    # Education
    education_attainment = "Education", early_leavers = "Education",
    neet_rate = "Education", training_rate = "Education",
    # Labour Market
    employment = "Labour Market", employment_rate = "Labour Market",
    unemployment_rate = "Labour Market", long_term_unemp = "Labour Market",
    activity_rate = "Labour Market",
    # Tourism
    nights_spent = "Tourism", arrivals = "Tourism",
    # Transport
    road_accidents = "Transport", vehicles = "Transport",
    # Environment
    municipal_waste = "Environment", energy_consumption = "Environment",
    # Science & Technology
    rd_expenditure = "Science & Technology",
    patents_total = "Science & Technology",
    hightech_employment = "Science & Technology",
    # Poverty & Social Exclusion
    poverty_rate = "Poverty & Exclusion",
    material_deprivation = "Poverty & Exclusion",
    # Information Society
    internet_access = "Information Society",
    broadband = "Information Society",
    ecommerce = "Information Society"
  )
}
