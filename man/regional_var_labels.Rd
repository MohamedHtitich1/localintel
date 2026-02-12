\name{regional_var_labels}
\alias{regional_var_labels}
\title{Regional Variable Labels (All Domains)}
\usage{
regional_var_labels()
}
\value{
Named character vector mapping variable names to display labels
}
\description{
Returns a comprehensive named vector of display labels for variables
across all thematic domains. Extends health-specific labels with
economy, education, labour, demography, tourism, and other domains.
}
\examples{
labels <- regional_var_labels()
labels["gdp"]
}
