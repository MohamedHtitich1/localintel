\name{get_dhs_surveys}
\alias{get_dhs_surveys}
\title{Get Available DHS Surveys for Countries}
\description{
Queries the DHS surveys endpoint to discover which surveys exist
for given countries. Useful for understanding temporal coverage.
}
\usage{
get_dhs_surveys(country_ids = NULL)
}
\arguments{
\item{country_ids}{Character vector of DHS country codes.
If NULL, returns surveys for all countries.}
}
\value{
A tibble with survey metadata including SurveyId, CountryName,
SurveyYear, SurveyType, and SurveyStatus.
}
\examples{
\dontrun{
ke_surveys <- get_dhs_surveys(country_ids = "KE")
}
}
\keyword{API}
