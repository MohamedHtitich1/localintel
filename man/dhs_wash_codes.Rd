\name{dhs_wash_codes}
\alias{dhs_wash_codes}
\title{DHS Water, Sanitation & Hygiene (WASH) Indicator Codes}
\description{
Returns a named vector of DHS indicator IDs for water and sanitation.
Covers improved water source, improved sanitation, and handwashing
facilities.
}
\usage{
dhs_wash_codes()
}
\value{
Named character vector of DHS indicator IDs.
}
\examples{
\dontrun{
codes <- dhs_wash_codes()
names(codes)
}
}
\keyword{indicators}
