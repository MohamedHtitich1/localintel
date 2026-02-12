\name{process_gdp}
\alias{process_gdp}
\title{Process GDP Data}
\usage{
process_gdp(df, unit = "MIO_EUR")
}
\arguments{
\item{df}{Raw dataframe from Eurostat nama_10r_2gdp}

\item{unit}{Unit filter (default: "MIO_EUR" for million EUR)}
}
\value{
Processed dataframe with geo, year, and gdp columns
}
\description{
Filters regional GDP data from Eurostat (nama_10r_2gdp)
}
\examples{
\dontrun{
gdp_data <- process_gdp(raw_gdp)
}
}
