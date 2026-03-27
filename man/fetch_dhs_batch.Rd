\name{fetch_dhs_batch}
\alias{fetch_dhs_batch}
\title{Batch Fetch DHS Indicators}
\description{
Iterates over indicator/country combinations with rate-limit-aware
delays. Returns a named list of tibbles, one per indicator ID.
}
\usage{
fetch_dhs_batch(indicator_ids, country_ids = NULL, years = NULL,
  breakdown = "subnational")
}
\arguments{
\item{indicator_ids}{Named character vector where names are friendly
names and values are DHS indicator IDs.}
\item{country_ids}{Character vector of DHS country codes. If NULL,
fetches all SSA countries.}
\item{years}{Integer vector of survey years. If NULL, returns all available.}
\item{breakdown}{Character: \code{"subnational"} (default) or \code{"national"}.}
}
\value{
Named list of tibbles, one per indicator.
}
\examples{
\dontrun{
codes <- c(u5_mortality = "CM_ECMR_C_U5M", stunting = "CN_NUTS_C_HA2")
data_list <- fetch_dhs_batch(codes, country_ids = c("KE", "NG"))
}
}
\keyword{API}
