# Cascade Data to NUTS2 (Generic / Domain-Agnostic)

Cascades data from NUTS0/NUTS1 to NUTS2 level for any set of variables
from any thematic domain. Unlike
[`cascade_to_nuts2_and_compute()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_nuts2_and_compute.md),
this function performs pure cascading without computing domain-specific
derived indicators, making it suitable for economy, education, labour,
environment, or any other Eurostat domain.

## Usage

``` r
cascade_to_nuts2(data, vars, years = NULL, nuts2_ref = NULL, nuts_year = 2024)
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
  If NULL, fetched automatically.

- nuts_year:

  Integer year for NUTS classification (default: 2024)

## Value

Dataframe with cascaded values at NUTS2 level. For each variable `v`, a
corresponding `src_v_level` column tracks the source NUTS level (2 =
original NUTS2, 1 = cascaded from NUTS1, 0 = cascaded from NUTS0).

## Examples

``` r
if (FALSE) { # \dontrun{
# Cascade GDP and unemployment data to NUTS2
result <- cascade_to_nuts2(
  all_data,
  vars = c("gdp", "unemployment_rate", "life_expectancy"),
  years = 2010:2024
)

# Check source levels
table(result$src_gdp_level)
} # }
```
