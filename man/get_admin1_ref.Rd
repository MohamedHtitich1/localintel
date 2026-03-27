\name{get_admin1_ref}
\alias{get_admin1_ref}
\title{Get Admin 1 Reference Table}
\description{
Builds a reference table mapping DHS Admin 1 regions to their parent
countries. This is the DHS equivalent of \code{\link{get_nuts2_ref}()},
mapping subnational regions to country-level codes.
}
\usage{
get_admin1_ref(country_ids = NULL)
}
\arguments{
\item{country_ids}{Character vector of DHS country codes.
If NULL (default), uses \code{tier1_codes()}.}
}
\value{
A tibble with columns:
\describe{
\item{geo}{Composite key: \code{DHS_CountryCode + "_" + CharacteristicLabel}}
\item{admin0}{2-letter DHS country code}
\item{country_name}{Full country name}
\item{region_label}{Admin 1 region name}
}
}
\examples{
\dontrun{
ref <- get_admin1_ref()
ref_ke <- get_admin1_ref(country_ids = "KE")
}
}
\keyword{reference}
