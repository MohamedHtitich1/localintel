\name{process_employment}
\alias{process_employment}
\title{Process Employment Data}
\usage{
process_employment(df, unit = "THS", sex = "T", age = "Y15-64")
}
\arguments{
\item{df}{Raw dataframe from Eurostat lfst_r_lfe2emp or similar}

\item{unit}{Unit filter (default: "THS" for thousands)}

\item{sex}{Sex filter (default: "T" for total)}

\item{age}{Age group filter (default: "Y15-64")}
}
\value{
Processed dataframe with geo, year, and employment columns
}
\description{
Filters regional employment data from Eurostat LFS datasets
}
\examples{
\dontrun{
employment_data <- process_employment(raw_employment)
}
}
