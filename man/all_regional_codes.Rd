\name{all_regional_codes}
\alias{all_regional_codes}
\title{All Regional Indicator Dataset Codes}
\usage{
all_regional_codes()
}
\value{
Named character vector of all regional dataset codes
}
\description{
Returns a comprehensive named vector combining dataset codes from all
14 thematic domains. This is the full registry of Eurostat regional
indicators that localintel can process seamlessly.
}
\examples{
all_codes <- all_regional_codes()
cat("Total indicators:", length(all_codes), "\n")
}
