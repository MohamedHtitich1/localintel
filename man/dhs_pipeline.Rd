\name{dhs_pipeline}
\alias{dhs_pipeline}
\title{Full DHS Pipeline: Fetch, Process, Gap-Fill, and Cascade}
\description{
Convenience wrapper that runs the complete DHS data pipeline from raw
API fetch through to a balanced analysis-ready panel.
}
\usage{
dhs_pipeline(country_ids = ssa_codes(), sigma_floor = 0.25,
  balance = TRUE, min_countries = 5L, min_indicators = 10L,
  include_ci = TRUE, national_fallback = TRUE, verbose = TRUE)
}
\arguments{
\item{country_ids}{Character vector of DHS country codes.
Defaults to \code{\link{ssa_codes}()}.}
\item{sigma_floor}{Numeric: minimum prediction SE (default: 0.25).}
\item{balance}{Logical: apply panel balancing (default: TRUE).}
\item{min_countries}{Integer: minimum countries per indicator (default: 5).}
\item{min_indicators}{Integer: minimum indicators per region (default: 10).}
\item{include_ci}{Logical: include CI columns (default: TRUE).}
\item{national_fallback}{Logical: use national fallback (default: TRUE).}
\item{verbose}{Logical: print progress (default: TRUE).}
}
\value{
A list with \code{panel}, \code{gapfill_summary}, \code{dropped_indicators},
and \code{dropped_regions}.
}
\examples{
\dontrun{
result <- dhs_pipeline(country_ids = tier1_codes())
}
}
\keyword{pipeline}
