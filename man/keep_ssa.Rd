\name{keep_ssa}
\alias{keep_ssa}
\title{Filter to SSA Countries}
\description{
Filters a dataframe to rows belonging to Sub-Saharan African countries.
Expects the dataframe to have a \code{geo} column in the format
\code{CC_RegionName} (as produced by \code{\link{process_dhs}()}).
}
\usage{
keep_ssa(df, extra = NULL)
}
\arguments{
\item{df}{Dataframe with a \code{geo} column containing DHS composite keys.}
\item{extra}{Character vector of additional 2-letter country codes to keep
(default: NULL).}
}
\value{
Filtered dataframe with only SSA country rows.
}
\examples{
\dontrun{
processed <- process_dhs(raw_data, out_col = "u5_mortality")
ssa_only <- keep_ssa(processed)
}
}
\keyword{filter}
