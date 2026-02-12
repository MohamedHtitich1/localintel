\name{process_unemployment_rate}
\alias{process_unemployment_rate}
\title{Process Unemployment Rate Data}
\usage{
process_unemployment_rate(df, sex = "T", age = "Y15-74")
}
\arguments{
\item{df}{Raw dataframe from Eurostat lfst_r_lfu3rt}

\item{sex}{Sex filter (default: "T" for total)}

\item{age}{Age group filter (default: "Y15-74")}
}
\value{
Processed dataframe with geo, year, and unemployment_rate columns
}
\description{
Filters regional unemployment rate data from Eurostat (lfst_r_lfu3rt)
}
\examples{
\dontrun{
unemployment_data <- process_unemployment_rate(raw_unemployment)
}
}
