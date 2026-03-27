\name{get_dhs_data}
\alias{get_dhs_data}
\title{Fetch Data from DHS Program API}
\description{
Single-query wrapper for the DHS Indicator Data API. Constructs the
appropriate URL, sends the request with the partner API key, parses
the JSON response, and returns a standardized tibble.
}
\usage{
get_dhs_data(country_ids = NULL, indicator_ids, years = NULL,
  breakdown = c("subnational", "national"), preferred_only = TRUE)
}
\arguments{
\item{country_ids}{Character vector of DHS 2-letter country codes.
If NULL, fetches all available.}
\item{indicator_ids}{Character vector of DHS indicator IDs (required).}
\item{years}{Integer vector of survey years. If NULL, returns all available.}
\item{breakdown}{Character: \code{"subnational"} (default) or \code{"national"}.}
\item{preferred_only}{Logical: if TRUE (default), filters to preferred estimates.}
}
\value{
A tibble with columns: CountryName, DHS_CountryCode, SurveyYear, SurveyId,
IndicatorId, Indicator, CharacteristicCategory, CharacteristicLabel, Value,
DenominatorWeighted, CILow, CIHigh, IsPreferred, ByVariableLabel, RegionId.
}
\examples{
\dontrun{
ke_u5m <- get_dhs_data(
  country_ids = "KE",
  indicator_ids = "CM_ECMR_C_U5M",
  breakdown = "subnational"
)
}
}
\keyword{API}
