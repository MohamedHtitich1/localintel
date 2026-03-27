\name{get_dhs_countries}
\alias{get_dhs_countries}
\title{Get DHS Countries for a Region}
\description{
Queries the DHS countries endpoint and returns country metadata,
optionally filtered to a specific DHS region.
}
\usage{
get_dhs_countries(region = "Sub-Saharan Africa")
}
\arguments{
\item{region}{Character string for DHS region name filter.
If NULL, returns all countries.}
}
\value{
A tibble with columns: DHS_CountryCode, ISO2_CountryCode, CountryName,
RegionName.
}
\examples{
\dontrun{
ssa <- get_dhs_countries("Sub-Saharan Africa")
}
}
\keyword{API}
