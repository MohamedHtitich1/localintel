\name{export_to_geojson}
\alias{export_to_geojson}
\alias{export_to_excel}
\alias{export_to_rds}
\alias{save_maps_to_pdf}
\alias{enrich_for_tableau}
\alias{health_var_labels}
\alias{health_pillar_mapping}
\alias{cod_labels}
\title{Export Functions}
\usage{
export_to_geojson(sf_data, filepath, crs = 4326)
export_to_excel(df, filepath)
export_to_rds(obj, filepath)
save_maps_to_pdf(plot_fn, filepath, width = 12, height = 8, ...)
enrich_for_tableau(sf_data, pop_data = NULL, nuts2_names = NULL, 
  var_col = "var", value_col = "value")
health_var_labels()
health_pillar_mapping()
cod_labels()
}
\arguments{
\item{sf_data}{sf object to export}
\item{df}{Dataframe to export}
\item{obj}{Object to export}
\item{filepath}{Character path for output file}
\item{crs}{Integer EPSG code (default: 4326)}
\item{plot_fn}{Function that generates plots}
\item{width}{PDF width in inches}
\item{height}{PDF height in inches}
\item{...}{Additional arguments passed to plot_fn}
\item{pop_data}{Population dataframe}
\item{nuts2_names}{Name lookup dataframe}
\item{var_col}{Name of the variable column}
\item{value_col}{Name of the value column}
}
\value{
Invisibly returns the filepath, or named character vector for label functions
}
\description{
Functions for exporting data to various formats including GeoJSON for Tableau,
Excel, and RDS. Also includes helper functions for variable labels and mappings.
}
\examples{
\dontrun{
export_to_geojson(sf_data, "output/data.geojson")
export_to_excel(df, "output/data.xlsx")
}
health_var_labels()
health_pillar_mapping()
}
