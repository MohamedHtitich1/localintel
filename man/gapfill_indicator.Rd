\name{gapfill_indicator}
\alias{gapfill_indicator}
\title{Gap-Fill All Regions for One Indicator}
\description{
Fetches raw DHS data for a set of countries and a single indicator,
processes it, and applies \code{\link{gapfill_series}()} to every region
that has at least \code{min_obs} observations.
}
\usage{
gapfill_indicator(country_ids, ind_code, ind_name, transform,
  min_obs = 2L, sigma_floor = 0.25, forecast_to = NULL)
}
\arguments{
\item{country_ids}{Character vector of DHS country codes.}
\item{ind_code}{Character: DHS indicator ID.}
\item{ind_name}{Character: output column name for the indicator.}
\item{transform}{Character: \code{"log"} or \code{"logit"}.}
\item{min_obs}{Integer: minimum observations per region (default: 2).}
\item{sigma_floor}{Numeric: minimum prediction SE (default: 0.25).}
\item{forecast_to}{Integer: if set, forecasts to this year.}
}
\value{
A named list with \code{gapfilled} (tibble), \code{raw} (tibble),
\code{n_regions}, \code{n_errors}, \code{n_warnings}, and \code{error_regions}.
}
\examples{
\dontrun{
res <- gapfill_indicator(
  country_ids = c("KE", "NG"),
  ind_code = "CM_ECMR_C_U5M",
  ind_name = "u5_mortality",
  transform = "log"
)
}
}
\keyword{interpolation}
