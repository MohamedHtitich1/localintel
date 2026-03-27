\name{get_admin1_geo}
\alias{get_admin1_geo}
\title{Get Admin 1 Geometries for SSA Countries}
\description{
Fetches Admin 1 (state/province/region) boundary geometries for Sub-Saharan
African countries. Uses GADM as the primary source with Natural Earth fallback.
Automatically harmonizes region names and handles special cases.
}
\usage{
get_admin1_geo(country_ids = NULL)
}
\arguments{
\item{country_ids}{Character vector of 2-letter DHS country codes.
If NULL, uses \code{\link{ssa_codes}()}.}
}
\value{
An sf object with columns: admin0, admin1_name, geometry (MULTIPOLYGON in EPSG:4326).
}
\examples{
\dontrun{
geo <- get_admin1_geo(country_ids = c("KE", "NG"))
plot(geo["admin1_name"])
}
}
\keyword{geospatial}
