\name{localintel-package}
\alias{localintel-package}
\alias{localintel}
\docType{package}
\title{Local Intelligence for Subnational Data Analysis}
\description{
A comprehensive pipeline for fetching, processing, and visualizing
subnational (NUTS 0/1/2) data from Eurostat. The package provides tools for
data fetching, cascading from higher to lower NUTS levels, computing composite
health indicators, creating publication-ready maps, and exporting data for
Tableau and other visualization tools.
}
\details{
\strong{Main Functions:}

Data Fetching: \code{\link{get_nuts2}}, \code{\link{get_nuts_level}}, 
\code{\link{fetch_eurostat_batch}}

Reference Data: \code{\link{get_nuts2_ref}}, \code{\link{get_nuts_geopolys}}, 
\code{\link{get_population_nuts2}}

Data Cascading: \code{\link{cascade_to_nuts2_and_compute}}, 
\code{\link{cascade_to_nuts2_light}}

Visualization: \code{\link{build_display_sf}}, 
\code{\link{plot_best_by_country_level}}

Export: \code{\link{export_to_geojson}}, \code{\link{enrich_for_tableau}}
}
\author{
Mohamed Htitich \email{m.ahtitich@outlook.com}
}
\keyword{package}
