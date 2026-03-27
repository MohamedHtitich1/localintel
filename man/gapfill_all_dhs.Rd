\name{gapfill_all_dhs}
\alias{gapfill_all_dhs}
\title{Gap-Fill All DHS Indicators Across SSA}
\description{
Runs \code{\link{gapfill_indicator}()} for every indicator in the
package's registries. Automatically selects the correct transform
(log for mortality/education, logit for proportions).
}
\usage{
gapfill_all_dhs(country_ids = ssa_codes(), sigma_floor = 0.25,
  forecast_to = NULL, verbose = TRUE)
}
\arguments{
\item{country_ids}{Character vector of DHS country codes.
Defaults to \code{\link{ssa_codes}()}.}
\item{sigma_floor}{Numeric: minimum prediction SE (default: 0.25).}
\item{forecast_to}{Integer: if set, forecasts to this year.}
\item{verbose}{Logical: print progress to console (default: TRUE).}
}
\value{
A named list with \code{data} (named list of tibbles) and \code{summary} (diagnostics).
}
\examples{
\dontrun{
result <- gapfill_all_dhs(country_ids = tier1_codes())
}
}
\keyword{interpolation}
