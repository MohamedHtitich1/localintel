\name{process_education_attainment}
\alias{process_education_attainment}
\title{Process Education Attainment Data}
\usage{
process_education_attainment(df, sex = "T", age = "Y25-64", isced11 = "ED5-8")
}
\arguments{
\item{df}{Raw dataframe from Eurostat edat_lfse_11 or similar}

\item{sex}{Sex filter (default: "T" for total)}

\item{age}{Age group filter (default: "Y25-64")}

\item{isced11}{Education level filter (default: "ED5-8" for tertiary)}
}
\value{
Processed dataframe with geo, year, and education_attainment columns
}
\description{
Filters regional education attainment data from Eurostat (edat_lfse_*)
}
\examples{
\dontrun{
education_data <- process_education_attainment(raw_education)
}
}
