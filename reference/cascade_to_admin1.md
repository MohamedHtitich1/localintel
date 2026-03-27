# Assemble DHS Gap-Filled Data into Admin 1 Panel

Takes the output of
[`gapfill_all_dhs()`](https://mohamedhtitich1.github.io/localintel/reference/gapfill_all_dhs.md)
and reshapes it into a single wide-format panel aligned to the Admin 1
reference skeleton.

## Usage

``` r
cascade_to_admin1(gapfill_result, admin1_ref = NULL, years = NULL,
  include_ci = TRUE, national_fallback = TRUE)
```

## Arguments

- gapfill_result:

  Output of
  [`gapfill_all_dhs()`](https://mohamedhtitich1.github.io/localintel/reference/gapfill_all_dhs.md).

- admin1_ref:

  Admin 1 reference table from
  [`get_admin1_ref()`](https://mohamedhtitich1.github.io/localintel/reference/get_admin1_ref.md).
  If NULL, built automatically.

- years:

  Integer vector of years to include. If NULL, uses observed range.

- include_ci:

  Logical: include confidence interval columns (default: TRUE).

- national_fallback:

  Logical: fill NAs with national values (default: TRUE).

## Value

A tibble with one row per region x year, with columns `<var>`,
`src_<var>_level`, and `imp_<var>_flag` per indicator.

## Examples

``` r
if (FALSE) { # \dontrun{
gf <- gapfill_all_dhs(country_ids = tier1_codes())
panel <- cascade_to_admin1(gf)
} # }
```
