\name{interp_const_ends_flag}
\alias{interp_const_ends_flag}
\alias{standardize_time}
\title{Data Interpolation and Time Utilities}
\usage{
interp_const_ends_flag(y)
standardize_time(df)
}
\arguments{
\item{y}{Numeric vector to interpolate}
\item{df}{Dataframe with 'time' or 'TIME_PERIOD' column}
}
\value{
\code{interp_const_ends_flag}: List with 'value' (interpolated) and 'flag' (1 if was NA)
\code{standardize_time}: Dataframe with standardized 'time' and 'year' columns
}
\description{
\code{interp_const_ends_flag} performs linear interpolation within gaps and
repeats endpoints, also returning a flag indicating original NA values.
\code{standardize_time} standardizes time column naming and parses year as integer.
}
\examples{
result <- interp_const_ends_flag(c(NA, 10, NA, NA, 20, NA))
result$value
result$flag
}
