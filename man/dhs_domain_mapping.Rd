\name{dhs_domain_mapping}
\alias{dhs_domain_mapping}
\title{DHS Indicator Domain Mapping}
\description{
Returns a named character vector mapping DHS indicator friendly names
to their thematic domain (e.g., "Maternal & Child Health", "Mortality").
}
\usage{
dhs_domain_mapping()
}
\value{
Named character vector with variable names as names and domains as values.
}
\examples{
\dontrun{
domains <- dhs_domain_mapping()
table(domains)
}
}
\keyword{labels}
