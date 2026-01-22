#' @keywords internal
"_PACKAGE"

#' localintel: Local Intelligence for Subnational Data Analysis
#'
#' @description
#' A comprehensive pipeline for fetching, processing, and visualizing
#' subnational (NUTS 0/1/2) data from Eurostat. The package provides tools for:
#'
#' \itemize{
#'   \item Fetching data from the Eurostat API at various NUTS levels
#'   \item Cascading data from higher to lower NUTS levels
#'   \item Computing composite health indicators
#'   \item Creating publication-ready maps
#'   \item Exporting data for Tableau and other visualization tools
#' }
#'
#' @section Main Functions:
#'
#' \strong{Data Fetching:}
#' \itemize{
#'   \item \code{\link{get_nuts2}}: Fetch NUTS2 level data
#'   \item \code{\link{get_nuts_level}}: Fetch data at any NUTS level
#'   \item \code{\link{fetch_eurostat_batch}}: Fetch multiple datasets
#' }
#'
#' \strong{Reference Data:}
#' \itemize{
#'   \item \code{\link{get_nuts2_ref}}: Get NUTS2 reference table
#'   \item \code{\link{get_nuts_geopolys}}: Get NUTS geometries
#'   \item \code{\link{get_population_nuts2}}: Get population data
#' }
#'
#' \strong{Data Cascading:}
#' \itemize{
#'   \item \code{\link{cascade_to_nuts2_and_compute}}: Cascade with indicator computation
#'   \item \code{\link{cascade_to_nuts2_light}}: Simple cascading
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
#' }
#'
#' @section Typical Workflow:
#' \preformatted{
#' library(localintel)
#'
#' # 1. Fetch data
#' codes <- health_system_codes()
#' data_list <- fetch_eurostat_batch(codes, level = 2, years = 2010:2024)
#'
#' # 2. Process data
#' beds <- process_beds(data_list$beds)
#' physicians <- process_physicians(data_list$physicians)
#'
#' # 3. Merge datasets
#' all_data <- merge_datasets(beds, physicians)
#'
#' # 4. Get reference data
#' nuts2_ref <- get_nuts2_ref()
#' geopolys <- get_nuts_geopolys()
#'
#' # 5. Cascade to NUTS2
#' cascaded <- cascade_to_nuts2_and_compute(all_data, nuts2_ref = nuts2_ref)
#'
#' # 6. Visualize
#' plot_best_by_country_level(cascaded, geopolys, var = "beds", years = 2020:2024)
#'
#' # 7. Export for Tableau
#' sf_data <- build_display_sf(cascaded, geopolys, var = "beds", years = 2010:2024)
#' export_to_geojson(sf_data, "output/beds.geojson")
#' }
#'
#' @docType package
#' @name localintel-package
#' @aliases localintel
#'
#' @import dplyr
#' @import sf
#' @importFrom rlang .data := sym syms
#' @importFrom tidyr complete fill spread
#' @importFrom tibble tibble as_tibble
#' @importFrom purrr map imap possibly
#' @importFrom stringr str_length
#' @importFrom eurostat get_eurostat get_eurostat_geospatial
#' @importFrom stats approx na.omit weighted.mean
#' @importFrom grDevices pdf dev.off
NULL

# Suppress R CMD check notes about NSE
utils::globalVariables(c(
  ".", "TIME_PERIOD", "NUTS_ID", "NAME_LATN", "NUTS_NAME",
  "val0", "val1", "val2", "value", "reason", "values",
  "nuts0", "nuts1", "geo2", "ctry", "src", "disp_level",
  "da_num", "da_den", "los_nat", "elig_da_level", "elig_rlos_level",
  "value_scaled", "var_country_avg", "cntry_performance_tag",
  "performance_tag", "score_change", "pop"
))
