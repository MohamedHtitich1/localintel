\name{dhs_var_labels}
\alias{dhs_var_labels}
\title{DHS Indicator Variable Labels}
\description{
Returns a named character vector mapping DHS indicator friendly names
(as used in processed data) to human-readable labels for visualization
and export.
}
\usage{
dhs_var_labels()
}
\value{
Named character vector with variable names as names and labels as values.
}
\examples{
\dontrun{
labs <- dhs_var_labels()
labs["u5_mortality"]
}
}
\keyword{labels}
