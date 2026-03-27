\name{add_dhs_country_name}
\alias{add_dhs_country_name}
\title{Add DHS Country Name}
\description{
Joins a full country name column to a processed DHS dataframe.
Extracts the 2-letter country code from the \code{geo} column and
looks up the name from the DHS countries endpoint.
}
\usage{
add_dhs_country_name(df, col_name = "country_name")
}
\arguments{
\item{df}{Dataframe with a \code{geo} column in DHS composite format.}
\item{col_name}{Name of the new column (default: \code{"country_name"}).}
}
\value{
Dataframe with an additional country name column.
}
\examples{
\dontrun{
processed <- process_dhs(raw_data, out_col = "stunting")
with_names <- add_dhs_country_name(processed)
}
}
\keyword{utility}
