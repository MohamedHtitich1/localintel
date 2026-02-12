\name{process_poverty_rate}
\alias{process_poverty_rate}
\title{Process Poverty Rate Data}
\usage{
process_poverty_rate(df)
}
\arguments{
\item{df}{Raw dataframe from Eurostat ilc_li41}
}
\value{
Processed dataframe with geo, year, and poverty_rate columns
}
\description{
Filters regional at-risk-of-poverty rate data from Eurostat (ilc_li41)
}
\examples{
\dontrun{
poverty_data <- process_poverty_rate(raw_poverty)
}
}
