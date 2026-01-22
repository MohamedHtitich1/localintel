\name{cascade_to_nuts2_and_compute}
\alias{cascade_to_nuts2_and_compute}
\alias{cascade_to_nuts2_light}
\alias{balance_panel}
\title{Data Cascading Functions}
\usage{
cascade_to_nuts2_and_compute(data, vars = c("disch_inp", "disch_day", 
  "beds", "physicians", "los"), years = NULL, nuts2_ref = NULL, 
  nuts_year = 2024)
cascade_to_nuts2_light(data, vars, nuts2_ref, years = NULL, agg = dplyr::first)
balance_panel(data, vars, years, fill_direction = "downup")
}
\arguments{
\item{data}{Dataframe with 'geo', 'year', and variable columns}
\item{vars}{Character vector of variable names to cascade}
\item{years}{Integer vector of years to include}
\item{nuts2_ref}{Reference table from get_nuts2_ref()}
\item{nuts_year}{Integer year for NUTS classification}
\item{agg}{Aggregation function for duplicates}
\item{fill_direction}{Direction for filling ("downup", "down", "up")}
}
\value{
Dataframe with cascaded values at NUTS2 level
}
\description{
Functions for cascading data from NUTS0/NUTS1 to NUTS2 level.
\code{cascade_to_nuts2_and_compute} also computes derived indicators (DA, rLOS).
\code{cascade_to_nuts2_light} is a simpler version for pre-computed scores.
\code{balance_panel} ensures all geo-year combinations exist.
}
\examples{
\dontrun{
cascaded <- cascade_to_nuts2_and_compute(all_data, nuts2_ref = nuts2_ref)
}
}
