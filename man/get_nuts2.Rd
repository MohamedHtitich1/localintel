\name{get_nuts2}
\alias{get_nuts2}
\alias{get_nuts_level}
\alias{get_nuts_level_robust}
\alias{get_nuts_level_safe}
\alias{fetch_eurostat_batch}
\alias{drop_empty}
\title{Eurostat Data Fetching Functions}
\usage{
get_nuts2(code, years = NULL)
get_nuts_level(code, level = 2, years = NULL)
get_nuts_level_robust(code, level = 2, years = NULL)
get_nuts_level_safe(code, level = 2, years = NULL)
fetch_eurostat_batch(codes, level = 2, years = NULL, robust = TRUE)
drop_empty(x)
}
\arguments{
\item{code}{Character string of the Eurostat dataset code}
\item{codes}{Named character vector of Eurostat dataset codes}
\item{level}{Integer NUTS level (0, 1, 2, or 3)}
\item{years}{Integer vector of years to filter}
\item{robust}{Logical, whether to use robust fetching with retry logic}
\item{x}{List of dataframes}
}
\value{
Dataframe or list of dataframes with Eurostat data
}
\description{
Functions for fetching data from the Eurostat API at various NUTS levels.
\code{get_nuts_level_robust} includes retry logic for failed requests.
\code{fetch_eurostat_batch} fetches multiple datasets at once.
}
\examples{
\dontrun{
beds_data <- get_nuts2("hlth_rs_bdsrg2", years = 2015:2023)
data_list <- fetch_eurostat_batch(health_system_codes(), level = 2)
}
}
