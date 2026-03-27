\name{dhs_nutrition_codes}
\alias{dhs_nutrition_codes}
\title{DHS Nutrition Indicator Codes}
\description{
Returns a named vector of DHS indicator IDs for child and maternal
nutrition. Covers stunting, wasting, underweight, anemia, obesity,
and breastfeeding indicators.
}
\usage{
dhs_nutrition_codes()
}
\value{
Named character vector of DHS indicator IDs.
}
\examples{
\dontrun{
codes <- dhs_nutrition_codes()
names(codes)
}
}
\keyword{indicators}
