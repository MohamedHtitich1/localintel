#' @keywords internal
"_PACKAGE"

#' localintel: Local Intelligence for Subnational Data Analysis
#'
#' @description
#' A comprehensive pipeline for fetching, harmonizing, cascading, and
#' visualizing 150+ subnational indicators from Eurostat across 14
#' thematic domains. The package covers economy, health, education,
#' labour market, demographics, tourism, transport, environment,
#' science & technology, agriculture, poverty, business statistics,
#' information society, and crime.
#'
#' \itemize{
#'   \item Fetching data from the Eurostat API at any NUTS level (0/1/2/3)
#'   \item Generic and domain-specific data processing for any indicator
#'   \item Cascading data from higher to lower NUTS levels with source tracking
#'   \item Adaptive econometric imputation (PCHIP + ETS with AIC model selection)
#'   \item Session-level smart caching for instant repeated access
#'   \item Composite scoring and min-max normalization
#'   \item Creating publication-ready maps with automatic best-level selection
#'   \item Exporting for Tableau, Excel, GeoJSON, and RDS
#' }
#'
#' @section Indicator Registry:
#'
#' The package provides curated registries of Eurostat dataset codes for
#' each domain. Use \code{\link{all_regional_codes}()} to see all 150+
#' indicators, or domain-specific functions like \code{\link{economy_codes}()},
#' \code{\link{labour_codes}()}, \code{\link{education_codes}()}, etc.
#'
#' @section Main Functions:
#'
#' \strong{Data Fetching:}
#' \itemize{
#'   \item \code{\link{get_nuts_level}}: Fetch data at any NUTS level
#'   \item \code{\link{fetch_eurostat_batch}}: Fetch multiple datasets
#'   \item \code{\link{all_regional_codes}}: Full indicator registry
#'   \item \code{\link{indicator_count}}: Count available indicators
#' }
#'
#' \strong{Data Processing:}
#' \itemize{
#'   \item \code{\link{process_eurostat}}: Generic processor for any dataset
#'   \item Domain-specific: \code{\link{process_gdp}}, \code{\link{process_unemployment_rate}},
#'     \code{\link{process_life_expectancy}}, \code{\link{process_beds}}, etc.
#'   \item \code{\link{merge_datasets}}: Combine processed datasets
#' }
#'
#' \strong{Data Cascading:}
#' \itemize{
#'   \item \code{\link{cascade_to_nuts2}}: Generic cascade for any domain
#'   \item \code{\link{cascade_to_nuts2_and_compute}}: Health-specific cascade
#'   \item \code{\link{cascade_to_nuts2_light}}: Light cascade for pre-computed scores
#' }
#'
#' \strong{Visualization:}
#' \itemize{
#'   \item \code{\link{build_display_sf}}: Build SF for visualization
#'   \item \code{\link{plot_best_by_country_level}}: Create maps
#' }
#'
#' \strong{Export:}
#' \itemize{
#'   \item \code{\link{export_to_geojson}}: Export for Tableau
#'   \item \code{\link{enrich_for_tableau}}: Prepare data for Tableau
#'   \item \code{\link{regional_var_labels}}: Labels for all domains
#'   \item \code{\link{regional_domain_mapping}}: Domain groupings
#' }
#'
#' @section Typical Workflow:
#' \preformatted{
#' library(localintel)
#'
#' # 1. Browse the indicator registry
#' n <- indicator_count()
#' cat(n$indicators, "indicators across", n$domains, "domains")
#'
#' # 2. Fetch data from multiple domains
#' econ  <- fetch_eurostat_batch(economy_codes(), level = 2, years = 2015:2024)
#' hlth  <- fetch_eurostat_batch(health_system_codes(), level = 2, years = 2015:2024)
#' educ  <- fetch_eurostat_batch(education_codes(), level = 2, years = 2015:2024)
#'
#' # 3. Process with generic or domain-specific processors
#' gdp   <- process_gdp(econ$gdp_nuts2)
#' beds  <- process_beds(hlth$beds)
#' tert  <- process_education_attainment(educ$attain_tertiary)
#'
#' # 4. Merge and cascade to NUTS2 (with adaptive imputation)
#' all_data <- merge_datasets(gdp, beds, tert)
#' cascaded <- cascade_to_nuts2(all_data,
#'   vars = c("gdp", "beds", "education_attainment"),
#'   years = 2015:2024,
#'   impute = TRUE,
#'   forecast_to = 2025)
#'
#' # Check traceability
#' table(cascaded$imp_gdp_flag)
#' # 0 = observed, 1 = PCHIP interpolated, 2 = ETS forecasted
#'
#' # 5. Visualize and export
#' geopolys <- get_nuts_geopolys()
#' plot_best_by_country_level(cascaded, geopolys, var = "gdp", years = 2022:2024)
#' }
#'
#' @docType package
#' @name localintel-package
#' @aliases localintel
#'
#' @import dplyr
#' @import sf
#' @importFrom rlang .data := sym syms
#' @importFrom tidyr complete fill spread expand_grid
#' @importFrom tibble tibble as_tibble
#' @importFrom purrr map imap possibly
#' @importFrom stringr str_length
#' @importFrom eurostat get_eurostat get_eurostat_geospatial
#' @importFrom stats approx na.omit weighted.mean splinefun sd
#' @importFrom grDevices pdf dev.off
NULL

# Suppress R CMD check notes about NSE
utils::globalVariables(c(
  ".", "TIME_PERIOD", "NUTS_ID", "NAME_LATN", "NUTS_NAME",
  "val0", "val1", "val2", "value", "reason", "values",
  "nuts0", "nuts1", "geo2", "ctry", "src", "disp_level",
  "da_num", "da_den", "los_nat", "elig_da_level", "elig_rlos_level",
  "value_scaled", "var_country_avg", "cntry_performance_tag",
  "performance_tag", "score_change", "pop",
  "gdp", "unemployment_rate", "employment", "life_expectancy",
  "education_attainment", "poverty_rate", "nights_spent",
  "rd_expenditure", "municipal_waste", "population"
))
