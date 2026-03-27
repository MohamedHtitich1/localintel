\name{dhs_health_codes}
\alias{dhs_health_codes}
\title{DHS Health Indicator Codes}
\description{
Returns a named vector of DHS indicator IDs for maternal and child health.
Covers antenatal care, skilled birth attendance, vaccination,
postnatal care, and contraceptive use.
}
\usage{
dhs_health_codes()
}
\value{
Named character vector of DHS indicator IDs.
}
\examples{
\dontrun{
codes <- dhs_health_codes()
names(codes)
}
}
\keyword{indicators}
