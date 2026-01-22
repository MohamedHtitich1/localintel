\name{safe_log10}
\alias{safe_log10}
\alias{safe_log2}
\alias{scale_0_100}
\alias{rescale_minmax}
\title{Safe Logarithm and Scaling Functions}
\usage{
safe_log10(x)
safe_log2(x)
scale_0_100(x)
rescale_minmax(x)
}
\arguments{
\item{x}{Numeric vector}
}
\value{
Numeric vector with transformed values
}
\description{
Utility functions for safe logarithm transformations and min-max scaling.
\code{safe_log10} and \code{safe_log2} return NA for non-positive values.
\code{scale_0_100} (alias \code{rescale_minmax}) scales values to 0-100 range.
}
\examples{
safe_log10(c(1, 10, 100, 0, -5, NA))
safe_log2(c(1, 2, 4, 0, -5, NA))
scale_0_100(c(10, 20, 30, 40, 50))
}
