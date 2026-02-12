\name{process_life_expectancy}
\alias{process_life_expectancy}
\title{Process Life Expectancy Data}
\usage{
process_life_expectancy(df, sex = "T", age = "Y_LT1")
}
\arguments{
\item{df}{Raw dataframe from Eurostat demo_r_mlifexp}

\item{sex}{Sex filter (default: "T" for total)}

\item{age}{Age at which expectancy is computed (default: "Y_LT1" for at birth)}
}
\value{
Processed dataframe with geo, year, and life_expectancy columns
}
\description{
Filters regional life expectancy data from Eurostat (demo_r_mlifexp)
}
\examples{
\dontrun{
life_expectancy_data <- process_life_expectancy(raw_life_expectancy)
}
}
