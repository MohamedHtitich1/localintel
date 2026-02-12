\name{indicator_count}
\alias{indicator_count}
\title{Count Available Regional Indicators}
\usage{
indicator_count()
}
\value{
A named list with \code{indicators} (total count),
\code{domains} (number of thematic domains), and
\code{by_domain} (count per domain)
}
\description{
Returns the total number of Eurostat regional indicators in the
localintel registry, along with the number of thematic domains.
}
\examples{
n <- indicator_count()
cat(n$indicators, "indicators across", n$domains, "domains\n")
}
