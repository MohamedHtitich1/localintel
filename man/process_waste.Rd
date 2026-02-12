\name{process_waste}
\alias{process_waste}
\title{Process Municipal Waste Data}
\usage{
process_waste(df, unit = "KG_HAB")
}
\arguments{
\item{df}{Raw dataframe from Eurostat env_rwas_gen}

\item{unit}{Unit filter (default: "KG_HAB" for kg per inhabitant)}
}
\value{
Processed dataframe with geo, year, and municipal_waste columns
}
\description{
Filters regional municipal waste data from Eurostat (env_rwas_gen)
}
\examples{
\dontrun{
waste_data <- process_waste(raw_waste)
}
}
