\name{dhs_indicator_count}
\alias{dhs_indicator_count}
\title{Count Available DHS Indicators}
\description{
Returns the total number of DHS indicators in the localintel
registry, along with the number of thematic domains.
}
\usage{
dhs_indicator_count()
}
\value{
A named list with \code{indicators} (total count), \code{domains}
(number of domains), and \code{by_domain} (counts per domain).
}
\examples{
\dontrun{
n <- dhs_indicator_count()
cat(n$indicators, "DHS indicators across", n$domains, "domains")
}
}
\keyword{indicators}
