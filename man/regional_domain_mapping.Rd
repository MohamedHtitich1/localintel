\name{regional_domain_mapping}
\alias{regional_domain_mapping}
\title{Regional Domain Mapping (All Domains)}
\usage{
regional_domain_mapping()
}
\value{
Named character vector mapping variable names to domain names
}
\description{
Returns a named vector mapping variable names to their thematic domain.
Useful for grouping variables in dashboards and Tableau exports.
}
\examples{
mapping <- regional_domain_mapping()
mapping["gdp"]
mapping["unemployment_rate"]
}
