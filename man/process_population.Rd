\name{process_population}
\alias{process_population}
\title{Process Population Data}
\usage{
process_population(df, sex = "T", age = "TOTAL")
}
\arguments{
\item{df}{Raw dataframe from Eurostat demo_r_d2jan}

\item{sex}{Sex filter (default: "T" for total)}

\item{age}{Age group filter (default: "TOTAL")}
}
\value{
Processed dataframe with geo, year, and population columns
}
\description{
Filters regional population data from Eurostat (demo_r_d2jan)
}
\examples{
\dontrun{
population_data <- process_population(raw_population)
}
}
