\name{balance_dhs_panel}
\alias{balance_dhs_panel}
\title{Balance DHS Admin 1 Panel}
\description{
Drops indicators or regions with insufficient coverage from the panel.
Balancing is performed in two passes: drop thin indicators, then drop thin regions.
}
\usage{
balance_dhs_panel(panel, indicators = NULL, min_countries = 5L,
  min_indicators = 10L, verbose = TRUE)
}
\arguments{
\item{panel}{Tibble from \code{\link{cascade_to_admin1}()}.}
\item{indicators}{Character vector of indicator column names.
If NULL, auto-detected from \code{imp_*_flag} columns.}
\item{min_countries}{Integer: minimum countries per indicator (default: 5).}
\item{min_indicators}{Integer: minimum indicators per region (default: 10).}
\item{verbose}{Logical: print diagnostics (default: TRUE).}
}
\value{
A list with \code{panel} (balanced tibble), \code{dropped_indicators},
and \code{dropped_regions}.
}
\examples{
\dontrun{
gf <- gapfill_all_dhs()
raw_panel <- cascade_to_admin1(gf)
balanced <- balance_dhs_panel(raw_panel)
}
}
\keyword{panel}
