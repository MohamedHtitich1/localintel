\name{cascade_to_nuts2}
\alias{cascade_to_nuts2}
\title{Cascade Data to NUTS2 (Generic / Domain-Agnostic)}
\usage{
cascade_to_nuts2(data, vars, years = NULL, nuts2_ref = NULL, nuts_year = 2024)
}
\arguments{
\item{data}{Dataframe with 'geo', 'year', and variable columns. May contain
data at mixed NUTS levels (identified by geo code length: 2=NUTS0, 3=NUTS1, 4=NUTS2).}

\item{vars}{Character vector of variable names to cascade}

\item{years}{Integer vector of years to include. If NULL, uses all available years.}

\item{nuts2_ref}{Reference table from \code{get_nuts2_ref()}. If NULL, fetched automatically.}

\item{nuts_year}{Integer year for NUTS classification (default: 2024)}
}
\value{
Dataframe with cascaded values at NUTS2 level. For each variable \code{v},
a corresponding \code{src_v_level} column tracks the source NUTS level
(2 = original NUTS2, 1 = cascaded from NUTS1, 0 = cascaded from NUTS0).
}
\description{
Cascades data from NUTS0/NUTS1 to NUTS2 level for any set of variables
from any thematic domain. Unlike \code{cascade_to_nuts2_and_compute()},
this function performs pure cascading without computing domain-specific
derived indicators, making it suitable for economy, education, labour,
environment, or any other Eurostat domain.
}
\examples{
\dontrun{
# Cascade GDP and unemployment data to NUTS2
result <- cascade_to_nuts2(
  all_data,
  vars = c("gdp", "unemployment_rate", "life_expectancy"),
  years = 2010:2024
)

# Check source levels
table(result$src_gdp_level)
}
}
