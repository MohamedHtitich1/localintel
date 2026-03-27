\name{get_admin0_geo}
\alias{get_admin0_geo}
\title{Get Admin 0 (Country) Geometries}
\description{
Fetches country (Admin 0) boundary geometries for African countries
from Natural Earth. Optionally includes all African countries as context.
}
\usage{
get_admin0_geo(country_ids = NULL, buffer_countries = TRUE)
}
\arguments{
\item{country_ids}{Character vector of 2-letter DHS country codes.
If NULL, uses \code{\link{ssa_codes}()}.}
\item{buffer_countries}{Logical: if TRUE, includes all African countries
for basemap context (default: TRUE).}
}
\value{
An sf object with columns: admin0, name, in_ssa, geometry (in EPSG:4326).
}
\examples{
\dontrun{
geo <- get_admin0_geo(country_ids = c("KE", "NG"))
}
}
\keyword{geospatial}
