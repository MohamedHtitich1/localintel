\name{build_display_sf}
\alias{build_display_sf}
\alias{lc_build_display_sf}
\alias{plot_best_by_country_level}
\alias{build_multi_var_sf}
\alias{level_col_for}
\alias{level_cols_for}
\title{Visualization Functions}
\usage{
build_display_sf(out_nuts2, geopolys, var, years = NULL, 
  skip_nuts0 = TRUE, scale = c("per_year", "global"))
lc_build_display_sf(out_nuts2, geopolys, var, years = NULL, 
  skip_nuts0 = TRUE, scale = c("per_year", "global"), keep = NULL)
plot_best_by_country_level(out_nuts2, geopolys, var, years = NULL, 
  skip_nuts0 = TRUE, scale = c("per_year", "global"), title = NULL, 
  pdf_file = paste0("Map_", var, "_country_level_scaled.pdf"), 
  bb_x = c(2400000, 7800000), bb_y = c(1320000, 5650000), 
  col_var = NULL, n_breaks = 7, breaks = NULL)
build_multi_var_sf(out_nuts2, geopolys, vars, years = 2010:2024, 
  var_labels = NULL, pillar_mapping = NULL)
level_col_for(var)
level_cols_for(vars)
}
\arguments{
\item{out_nuts2}{Dataframe with cascaded NUTS2 data}
\item{geopolys}{sf object with NUTS geometries}
\item{var}{Character string of variable to display}
\item{vars}{Character vector of variables}
\item{years}{Integer vector of years to include}
\item{skip_nuts0}{Logical, whether to skip NUTS0 level display}
\item{scale}{Character, "per_year" or "global" scaling}
\item{keep}{Character vector of additional columns to preserve}
\item{title}{Optional custom title}
\item{pdf_file}{Optional PDF filename for output}
\item{bb_x}{Numeric vector of x bounding box limits}
\item{bb_y}{Numeric vector of y bounding box limits}
\item{col_var}{Column to use for coloring}
\item{n_breaks}{Number of legend breaks}
\item{breaks}{Optional custom breaks vector}
\item{var_labels}{Named character vector mapping vars to display labels}
\item{pillar_mapping}{Named character vector mapping vars to pillars}
}
\value{
sf object for mapping or printed tmap plots
}
\description{
Functions for creating maps and visualizations of NUTS-level data.
\code{build_display_sf} creates an sf object selecting the best available
NUTS level for each country-year combination.
}
\examples{
\dontrun{
sf_data <- build_display_sf(cascaded, geopolys, var = "beds", years = 2020:2024)
plot_best_by_country_level(cascaded, geopolys, var = "beds", years = 2020:2024)
}
}
