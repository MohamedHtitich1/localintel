\name{enrich_dhs_for_tableau}
\alias{enrich_dhs_for_tableau}
\title{Enrich DHS Data for Tableau Export}
\description{
Enriches DHS sf data with country names and domain metadata for
Tableau-ready exports.
}
\usage{
enrich_dhs_for_tableau(sf_data, var_col = "var", value_col = "value")
}
\arguments{
\item{sf_data}{sf object from \code{\link{build_dhs_display_sf}()} or \code{\link{build_dhs_multi_var_sf}()}.}
\item{var_col}{Name of the variable column (default: "var").}
\item{value_col}{Name of the value column (default: "value").}
}
\value{
Enriched sf object with country names and performance tags.
}
\examples{
\dontrun{
sf_enriched <- enrich_dhs_for_tableau(sf_multi)
}
}
\keyword{export}
