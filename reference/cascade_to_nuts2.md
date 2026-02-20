# Cascade Data to NUTS2 (Generic / Domain-Agnostic)

Cascades data from NUTS0/NUTS1 to NUTS2 level for any set of variables
from any thematic domain. Unlike
[`cascade_to_nuts2_and_compute()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md),
this function performs pure cascading without computing domain-specific
derived indicators, making it suitable for economy, education, labour,
environment, or any other Eurostat domain.

When `impute = TRUE` (the default), adaptive econometric imputation is
applied after cascading to fill temporal gaps within each region's time
series. This uses PCHIP interpolation for internal gaps and optionally
ETS autoregressive forecasting for future periods (when `forecast_to` is
specified). The best model is selected automatically via AIC.

## Usage

``` r
cascade_to_nuts2(
  data,
  vars,
  years = NULL,
  nuts2_ref = NULL,
  nuts_year = 2024,
  impute = TRUE,
  forecast_to = NULL
)
```

## Arguments

- data:

  Dataframe with 'geo', 'year', and variable columns. May contain data
  at mixed NUTS levels (identified by geo code length: 2=NUTS0, 3=NUTS1,
  4=NUTS2).

- vars:

  Character vector of variable names to cascade

- years:

  Integer vector of years to include. If NULL, uses all available years.

- nuts2_ref:

  Reference table from
  [`get_nuts2_ref()`](https://mohamedhtitich1.github.io/localintel/reference/get_nuts2_ref.md).
  If NULL, fetched automatically (session-cached for instant repeated
  access).

- nuts_year:

  Integer year for NUTS classification (default: 2024)

- impute:

  Logical. If TRUE (default), apply adaptive econometric imputation
  (PCHIP + optional ETS) to fill temporal gaps after cascading.

- forecast_to:

  Integer year. If specified and greater than max(years), extend the
  series with ETS autoregressive forecasts up to this year. Only used
  when `impute = TRUE`.

## Value

Dataframe with cascaded values at NUTS2 level. For each variable `v`:

- `src_v_level`: source NUTS level (2 = original NUTS2, 1 = cascaded
  from NUTS1, 0 = cascaded from NUTS0)

- `imp_v_flag`: imputation flag (0 = observed/cascaded, 1 = PCHIP
  interpolated, 2 = ETS forecasted). Only present when `impute = TRUE`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Cascade with adaptive imputation (default)
result <- cascade_to_nuts2(
  all_data,
  vars = c("gdp", "unemployment_rate"),
  years = 2015:2024,
  impute = TRUE
)

# Cascade with imputation + forecasting to 2025
result <- cascade_to_nuts2(
  all_data,
  vars = c("gdp", "unemployment_rate"),
  years = 2015:2024,
  impute = TRUE,
  forecast_to = 2025
)

# Check traceability
table(result$src_gdp_level)   # cascade source
table(result$imp_gdp_flag)    # imputation method

# Cascade without imputation (legacy behaviour)
result <- cascade_to_nuts2(
  all_data,
  vars = c("gdp", "unemployment_rate"),
  years = 2015:2024,
  impute = FALSE
)
} # }
```
