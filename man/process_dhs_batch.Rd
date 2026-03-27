\name{process_dhs_batch}
\alias{process_dhs_batch}
\title{Process a Batch of DHS Indicators}
\description{
Takes the output of \code{\link{fetch_dhs_batch}()} (a named list of raw
tibbles) and applies \code{process_dhs()} to each, using the list names
as the \code{out_col}. Returns a named list of processed tibbles.
}
\usage{
process_dhs_batch(batch_list,
  ref_period = "Five years preceding the survey",
  keep_ci = FALSE, keep_denominator = FALSE)
}
\arguments{
\item{batch_list}{Named list of raw tibbles from \code{\link{fetch_dhs_batch}()}.}
\item{ref_period}{Reference period filter (passed to \code{\link{process_dhs}()}).}
\item{keep_ci}{Passed to \code{\link{process_dhs}()}.}
\item{keep_denominator}{Passed to \code{\link{process_dhs}()}.}
}
\value{
Named list of processed tibbles, each with \code{geo}, \code{year},
and a value column named after the list element.
}
\examples{
\dontrun{
codes <- c(u5_mortality = "CM_ECMR_C_U5M", stunting = "CN_NUTS_C_HA2")
raw_batch <- fetch_dhs_batch(codes, country_ids = c("KE", "NG"))
processed <- process_dhs_batch(raw_batch)
}
}
\keyword{processing}
