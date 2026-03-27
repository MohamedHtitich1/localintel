\name{cascade_to_admin1}
\alias{cascade_to_admin1}
\title{Assemble DHS Gap-Filled Data into Admin 1 Panel}
\description{
Takes the output of \code{\link{gapfill_all_dhs}()} and reshapes it into a
single wide-format panel aligned to the Admin 1 reference skeleton.
}
\usage{
cascade_to_admin1(gapfill_result, admin1_ref = NULL, years = NULL,
  include_ci = TRUE, national_fallback = TRUE)
}
\arguments{
\item{gapfill_result}{Output of \code{\link{gapfill_all_dhs}()}.}
\item{admin1_ref}{Admin 1 reference table from \code{\link{get_admin1_ref}()}.
If NULL, built automatically.}
\item{years}{Integer vector of years to include. If NULL, uses observed range.}
\item{include_ci}{Logical: include confidence interval columns (default: TRUE).}
\item{national_fallback}{Logical: fill NAs with national values (default: TRUE).}
}
\value{
A tibble with one row per region x year, with columns
\code{<var>}, \code{src_<var>_level}, and \code{imp_<var>_flag} per indicator.
}
\examples{
\dontrun{
gf <- gapfill_all_dhs(country_ids = tier1_codes())
panel <- cascade_to_admin1(gf)
}
}
\keyword{panel}
