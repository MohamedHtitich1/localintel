\name{process_tourism_nights}
\alias{process_tourism_nights}
\title{Process Tourism Nights Spent Data}
\usage{
process_tourism_nights(df, unit = "NR", nace_r2 = "I551-I553", c_resid = "TOTAL")
}
\arguments{
\item{df}{Raw dataframe from Eurostat tour_occ_nin2}

\item{unit}{Unit filter (default: "NR" for number)}

\item{nace_r2}{NACE sector filter (default: "I551-I553" for accommodation)}

\item{c_resid}{Residence filter (default: "TOTAL")}
}
\value{
Processed dataframe with geo, year, and nights_spent columns
}
\description{
Filters regional tourism data from Eurostat (tour_occ_nin2)
}
\examples{
\dontrun{
tourism_data <- process_tourism_nights(raw_tourism)
}
}
