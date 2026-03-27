\name{build_dhs_multi_var_sf}
\alias{build_dhs_multi_var_sf}
\title{Build Multi-Indicator SF for DHS Data}
\description{
Creates an sf object containing multiple DHS indicators suitable for
export to geospatial formats like GeoJSON.
}
\usage{
build_dhs_multi_var_sf(panel, admin1_geo = NULL, vars = NULL,
  years = NULL, var_labels = NULL, domain_mapping = NULL)
}
\arguments{
\item{panel}{Dataframe from \code{\link{cascade_to_admin1}()}.}
\item{admin1_geo}{sf object from \code{\link{get_admin1_geo}()}.
If NULL, fetched automatically.}
\item{vars}{Character vector of variables to include.
If NULL, auto-detected from imp_*_flag columns.}
\item{years}{Integer vector of years to include. If NULL, uses all.}
\item{var_labels}{Named character vector of variable labels.
If NULL, uses \code{\link{dhs_var_labels}()}.}
\item{domain_mapping}{Named character vector of domain assignments.
If NULL, uses \code{\link{dhs_domain_mapping}()}.}
}
\value{
sf object with columns: geo, admin0, year, value, var, var_label,
domain, geometry.
}
\examples{
\dontrun{
sf_all <- build_dhs_multi_var_sf(panel)
}
}
\keyword{visualization}
