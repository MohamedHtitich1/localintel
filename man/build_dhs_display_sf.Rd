\name{build_dhs_display_sf}
\alias{build_dhs_display_sf}
\title{Build Display SF for DHS Admin 1 Data}
\description{
Creates an sf object for visualization by joining the DHS panel data
to Admin 1 geometries.
}
\usage{
build_dhs_display_sf(panel, admin1_geo = NULL, var, years = NULL)
}
\arguments{
\item{panel}{Dataframe from \code{\link{cascade_to_admin1}()}, with columns
\code{geo}, \code{admin0}, \code{year}, and indicator columns.}
\item{admin1_geo}{sf object from \code{\link{get_admin1_geo}()}.
If NULL, fetched automatically.}
\item{var}{Character string of variable to display.}
\item{years}{Integer vector of years to include. If NULL, uses all available.}
}
\value{
sf object with columns: geo, admin0, year, value, geometry.
}
\examples{
\dontrun{
sf_data <- build_dhs_display_sf(panel, var = "u5_mortality", years = 2020)
}
}
\keyword{visualization}
