# Get Available DHS Surveys for Countries

Queries the DHS surveys endpoint to discover which surveys exist for
given countries. Useful for understanding temporal coverage.

## Usage

``` r
get_dhs_surveys(country_ids = NULL)
```

## Arguments

- country_ids:

  Character vector of DHS country codes. If NULL, returns surveys for
  all countries.

## Value

A tibble with survey metadata including SurveyId, CountryName,
SurveyYear, SurveyType, and SurveyStatus.

## Examples

``` r
if (FALSE) { # \dontrun{
ke_surveys <- get_dhs_surveys(country_ids = "KE")
} # }
```
