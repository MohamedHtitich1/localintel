\name{plot_dhs_map}
\alias{plot_dhs_map}
\title{Plot DHS Indicator as Choropleth Map}
\description{
Creates choropleth maps of DHS indicator data at Admin 1 level across
Sub-Saharan Africa using tmap.
}
\usage{
plot_dhs_map(panel, admin1_geo = NULL, var, years = NULL,
  title = NULL, palette = "viridis", n_breaks = 7, breaks = NULL,
  bb_x = c(-18, 52), bb_y = c(-36, 18), basemap = TRUE,
  pdf_file = NULL)
}
\arguments{
\item{panel}{Dataframe from \code{\link{cascade_to_admin1}()}.}
\item{admin1_geo}{sf object from \code{\link{get_admin1_geo}()}.
If NULL, fetched automatically.}
\item{var}{Character string of variable to plot.}
\item{years}{Integer vector of years to plot. If NULL, uses most recent.}
\item{title}{Optional custom title. If NULL, uses DHS variable label.}
\item{palette}{Character: tmap/viridis palette (default: "viridis").}
\item{n_breaks}{Integer: number of legend breaks (default: 7).}
\item{breaks}{Optional custom breaks vector.}
\item{bb_x}{Numeric vector of longitude limits (default: Africa extent).}
\item{bb_y}{Numeric vector of latitude limits (default: Africa extent).}
\item{basemap}{Logical: draw country borders (default: TRUE).}
\item{pdf_file}{Optional PDF filename for output.}
}
\value{
Prints tmap objects for each year.
}
\examples{
\dontrun{
plot_dhs_map(panel, var = "u5_mortality", years = 2020)
}
}
\keyword{visualization}
