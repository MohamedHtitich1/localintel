\name{process_rd_expenditure}
\alias{process_rd_expenditure}
\title{Process R&D Expenditure Data}
\usage{
process_rd_expenditure(df, unit = "PC_GDP", sectperf = "TOTAL")
}
\arguments{
\item{df}{Raw dataframe from Eurostat rd_e_gerdreg}

\item{unit}{Unit filter (default: "PC_GDP" for percentage of GDP)}

\item{sectperf}{Sector of performance (default: "TOTAL")}
}
\value{
Processed dataframe with geo, year, and rd_expenditure columns
}
\description{
Filters regional R&D expenditure data from Eurostat (rd_e_gerdreg)
}
\examples{
\dontrun{
rd_data <- process_rd_expenditure(raw_rd)
}
}
