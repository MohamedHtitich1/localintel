\name{process_dhs}
\alias{process_dhs}
\title{Process Raw DHS Data}
\description{
Transforms a raw DHS API response into the standard localintel
\code{geo / year / value} structure. Handles deduplication,
reference-period filtering, and composite key construction.
}
\usage{
process_dhs(df, out_col = NULL,
  ref_period = "Five years preceding the survey",
  keep_ci = FALSE, keep_denominator = FALSE, keep_metadata = FALSE)
}
\arguments{
\item{df}{Raw tibble from \code{\link{get_dhs_data}()} or \code{\link{fetch_dhs_batch}()}.}
\item{out_col}{Character name for the output value column (default: \code{"value"}).}
\item{ref_period}{Character string for reference-period filtering
(default: \code{"Five years preceding the survey"}).}
\item{keep_ci}{Logical: if TRUE, retains confidence interval columns (default: FALSE).}
\item{keep_denominator}{Logical: if TRUE, retains DenominatorWeighted (default: FALSE).}
\item{keep_metadata}{Logical: if TRUE, retains metadata columns (default: FALSE).}
}
\value{
A tibble with columns: geo, year, and the value column
(plus optional CI, denominator, and metadata columns).
}
\examples{
\dontrun{
raw <- get_dhs_data(
  country_ids = c("KE", "NG"),
  indicator_ids = "CM_ECMR_C_U5M",
  breakdown = "subnational"
)
processed <- process_dhs(raw, out_col = "u5_mortality")
}
}
\keyword{processing}
