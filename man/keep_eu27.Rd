\name{keep_eu27}
\alias{keep_eu27}
\alias{eu27_codes}
\alias{nuts_country_names}
\alias{add_country_name}
\title{EU27 Country Filtering and Naming Functions}
\usage{
keep_eu27(df, extra = c("NO", "IS"))
eu27_codes()
nuts_country_names()
add_country_name(df, geo_col = "geo", out_col = "Country")
}
\arguments{
\item{df}{Dataframe with a 'geo' column containing NUTS codes}
\item{extra}{Character vector of additional 2-letter country codes to include}
\item{geo_col}{Name of the geo column (default: "geo")}
\item{out_col}{Name of the output country column (default: "Country")}
}
\value{
\code{keep_eu27}: Filtered dataframe
\code{eu27_codes}: Character vector of EU27 country codes
\code{nuts_country_names}: Named character vector mapping codes to country names
\code{add_country_name}: Dataframe with added country name column
}
\description{
Functions for filtering data to EU27 countries and adding country names.
}
\examples{
eu27_codes()
nuts_country_names()
}
