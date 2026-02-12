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

# ============================================================================
# MULTI-DOMAIN INDICATOR REGISTRIES
# ============================================================================

#' Economy and Regional Accounts Dataset Codes
#'
#' Returns a named vector of Eurostat regional economic account dataset codes
#' covering GDP, GVA, employment, household income, and capital formation at
#' NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- economy_codes()
#' names(codes)
economy_codes <- function() {
  c(
    gdp_nuts2            = "nama_10r_2gdp",
    gdp_nuts3            = "nama_10r_3gdp",
    gdp_growth           = "nama_10r_2grgdp",
    gva_a10              = "nama_10r_3gva",
    gfcf                 = "nama_10r_2gfcf",
    compensation         = "nama_10r_2rem",
    employment_hours     = "nama_10r_2emhrw",
    hh_primary_income    = "nama_10r_2hhinc",
    hh_disp_income       = "nama_10r_2hhdi",
    gdp_per_capita       = "nama_10r_2gdp"
  )
}

#' Demography Dataset Codes
#'
#' Returns a named vector of Eurostat regional demography dataset codes
#' covering population, fertility, mortality, and life expectancy at
#' NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- demography_codes()
#' names(codes)
demography_codes <- function() {
  c(
    pop_jan              = "demo_r_d2jan",
    pop_5yr_groups       = "demo_r_pjangroup",
    pop_density          = "demo_r_d3dens",
    births               = "demo_r_births",
    fertility_rate       = "demo_r_frate2",
    births_mother_age    = "demo_r_fagec",
    deaths               = "demo_r_deaths",
    deaths_age_sex       = "demo_r_magec",
    infant_mortality     = "demo_r_minf",
    infant_mortality_rate = "demo_r_minfind",
    life_table           = "demo_r_mlife",
    life_expectancy      = "demo_r_mlifexp",
    pop_change           = "demo_r_gind3"
  )
}

#' Education Dataset Codes
#'
#' Returns a named vector of Eurostat regional education dataset codes
#' covering students, educational attainment, training, early leavers,
#' and NEET rates at NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- education_codes()
#' names(codes)
education_codes <- function() {
  c(
    students_level       = "educ_renrlrg1",
    students_age         = "educ_renrlrg3",
    educ_indicators      = "educ_regind",
    training_rate        = "trng_lfse_04",
    attain_lower_sec     = "edat_lfse_09",
    attain_upper_sec     = "edat_lfse_10",
    attain_tertiary      = "edat_lfse_11",
    attain_tert_30_34    = "edat_lfse_12",
    attain_upper_or_tert = "edat_lfse_13",
    early_leavers        = "edat_lfse_16",
    neet_rate            = "edat_lfse_22"
  )
}

#' Labour Market Dataset Codes
#'
#' Returns a named vector of Eurostat regional labour market dataset codes
#' covering employment, unemployment, economic activity, and labour force
#' participation at NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- labour_codes()
#' names(codes)
labour_codes <- function() {
  c(
    pop_15plus           = "lfst_r_lfsd2pop",
    active_pop           = "lfst_r_lfp2act",
    activity_rate        = "lfst_r_lfp2actrt",
    employment           = "lfst_r_lfe2emp",
    employment_rate      = "lfst_r_lfe2emprt",
    empl_by_sector       = "lfst_r_lfe2en2",
    empl_by_status       = "lfst_r_lfe2estat",
    empl_full_part       = "lfst_r_lfe2eftpt",
    empl_by_education    = "lfst_r_lfe2eedu",
    empl_hours           = "lfst_r_lfe2ehour",
    unemployment         = "lfst_r_lfu3pers",
    unemployment_rate    = "lfst_r_lfu3rt",
    long_term_unemp      = "lfst_r_lfu2ltu"
  )
}

#' Tourism Dataset Codes
#'
#' Returns a named vector of Eurostat regional tourism dataset codes
#' covering arrivals, nights spent, and accommodation capacity at
#' NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- tourism_codes()
#' names(codes)
tourism_codes <- function() {
  c(
    arrivals             = "tour_occ_arn2",
    nights_spent         = "tour_occ_nin2",
    nights_urbanisation  = "tour_occ_nin2d",
    nights_coastal       = "tour_occ_nin2c",
    occupancy_rate       = "tour_occ_anor2",
    capacity_nuts2       = "tour_cap_nuts2",
    capacity_urbanisation = "tour_cap_nuts2d",
    capacity_coastal     = "tour_cap_nuts2c"
  )
}

#' Transport Dataset Codes
#'
#' Returns a named vector of Eurostat regional transport dataset codes
#' covering road, rail, air, and maritime transport infrastructure
#' and traffic at NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- transport_codes()
#' names(codes)
transport_codes <- function() {
  c(
    road_rail_waterway   = "tran_r_net",
    vehicles             = "tran_r_vehst",
    road_accidents       = "tran_r_acci",
    maritime_passengers  = "tran_r_mapa_nm",
    maritime_freight     = "tran_r_mago_nm",
    air_passengers       = "tran_r_avpa_nm",
    air_freight          = "tran_r_avgo_nm",
    rail_goods_load      = "tran_r_rago",
    rail_passengers      = "tran_r_rapa",
    road_goods_journeys  = "tran_r_veh_jour"
  )
}

#' Environment and Energy Dataset Codes
#'
#' Returns a named vector of Eurostat regional environment and energy
#' dataset codes covering waste, water, land use, energy consumption,
#' and contaminated sites at NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- environment_codes()
#' names(codes)
environment_codes <- function() {
  c(
    municipal_waste      = "env_rwas_gen",
    waste_coverage       = "env_rwas_cov",
    contaminated_sites   = "env_rlu",
    energy_consumption   = "env_rpep",
    transport_params     = "env_rtr",
    heating_degree_month = "nrg_esdgr_m",
    heating_degree_annual = "nrg_esdgr_a"
  )
}

#' Science and Technology Dataset Codes
#'
#' Returns a named vector of Eurostat regional science and technology
#' dataset codes covering R&D expenditure, personnel, patents, HRST,
#' and high-tech employment at NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- science_codes()
#' names(codes)
science_codes <- function() {
  c(
    rd_expenditure       = "rd_e_gerdreg",
    rd_personnel         = "rd_p_persreg",
    hrst_subgroups       = "hrst_st_rcat",
    hrst_sex             = "hrst_st_rsex",
    hrst_age             = "hrst_st_rage",
    hightech_employment  = "htec_emp_reg2",
    patents_total        = "pat_ep_rtot",
    patents_ipc          = "pat_ep_ripc",
    patents_hightech     = "pat_ep_rtec",
    patents_ict          = "pat_ep_rict",
    patents_biotech      = "pat_ep_rbio"
  )
}

#' Poverty and Social Exclusion Dataset Codes
#'
#' Returns a named vector of Eurostat regional poverty and social
#' exclusion dataset codes at NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- poverty_codes()
#' names(codes)
poverty_codes <- function() {
  c(
    at_risk_poverty_exclusion = "ilc_peps11",
    low_work_intensity   = "ilc_lvhl21",
    material_deprivation = "ilc_mddd21",
    at_risk_poverty_rate = "ilc_li41"
  )
}

#' Agriculture Dataset Codes
#'
#' Returns a named vector of Eurostat regional agriculture dataset codes
#' covering crop production, livestock, land use, and milk production
#' at NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- agriculture_codes()
#' names(codes)
agriculture_codes <- function() {
  c(
    animal_pop           = "agr_r_animal",
    crop_production      = "agr_r_crops",
    land_use             = "agr_r_landuse",
    milk_production      = "agr_r_milkpr",
    agri_accounts        = "agr_r_accts"
  )
}

#' Business Statistics Dataset Codes
#'
#' Returns a named vector of Eurostat regional structural business
#' statistics and business demography dataset codes at NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- business_codes()
#' names(codes)
business_codes <- function() {
  c(
    sbs_nace2            = "sbs_r_nuts06_r2",
    sbs_distributive     = "sbs_r_3k_my_r2",
    local_units          = "sbs_cre_rreg",
    bd_high_growth       = "bd_hgnace2_r3",
    bd_size_class        = "bd_size_r3",
    bd_nace2             = "bd_enace2_r3"
  )
}

#' Information Society Dataset Codes
#'
#' Returns a named vector of Eurostat regional information society
#' dataset codes covering internet access, broadband, e-commerce,
#' and e-government at NUTS 2 level.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- information_society_codes()
#' names(codes)
information_society_codes <- function() {
  c(
    internet_access      = "isoc_r_iacc_h",
    broadband            = "isoc_r_broad_h",
    never_used_computer  = "isoc_r_cux_i",
    internet_use         = "isoc_r_iuse_i",
    egov_use             = "isoc_r_gov_i",
    ecommerce            = "isoc_r_blt12_i"
  )
}

#' Crime Dataset Codes
#'
#' Returns a named vector of Eurostat regional crime dataset codes.
#'
#' @return Named character vector of dataset codes
#' @export
#' @examples
#' codes <- crime_codes()
#' names(codes)
crime_codes <- function() {
  c(
    crimes_recorded      = "crim_gen_reg"
  )
}

#' All Regional Indicator Dataset Codes
#'
#' Returns a comprehensive named vector combining dataset codes from all
#' 14 thematic domains. This is the full registry of Eurostat regional
#' indicators that localintel can process seamlessly.
#'
#' @return Named character vector of all regional dataset codes
#' @export
#' @examples
#' all_codes <- all_regional_codes()
#' cat("Total indicators:", length(all_codes), "\n")
all_regional_codes <- function() {
  c(
    economy_codes(),
    demography_codes(),
    education_codes(),
    labour_codes(),
    health_system_codes(),
    causes_of_death_codes(),
    tourism_codes(),
    transport_codes(),
    environment_codes(),
    science_codes(),
    poverty_codes(),
    agriculture_codes(),
    business_codes(),
    information_society_codes(),
    crime_codes()
  )
}

#' Count Available Regional Indicators
#'
#' Returns the total number of Eurostat regional indicators in the
#' localintel registry, along with the number of thematic domains.
#'
#' @return A named list with \code{indicators} (total count) and
#'   \code{domains} (number of thematic domains)
#' @export
#' @examples
#' n <- indicator_count()
#' cat(n$indicators, "indicators across", n$domains, "domains\n")
indicator_count <- function() {
  domain_fns <- list(
    Economy             = economy_codes,
    Demography          = demography_codes,
    Education           = education_codes,
    `Labour Market`     = labour_codes,
    `Health System`     = health_system_codes,
    `Causes of Death`   = causes_of_death_codes,
    Tourism             = tourism_codes,
    Transport           = transport_codes,
    Environment         = environment_codes,
    `Science & Technology` = science_codes,
    `Poverty & Exclusion`  = poverty_codes,
    Agriculture         = agriculture_codes,
    Business            = business_codes,
    `Information Society`  = information_society_codes,
    Crime               = crime_codes
  )
  counts <- vapply(domain_fns, function(fn) length(fn()), integer(1))
  list(
    indicators = sum(counts),
    domains    = length(counts),
    by_domain  = counts
  )
}
