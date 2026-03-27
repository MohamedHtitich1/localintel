# Balance DHS Admin 1 Panel

Drops indicators or regions with insufficient coverage from the panel.
Balancing is performed in two passes: drop thin indicators, then drop
thin regions.

## Usage

``` r
balance_dhs_panel(panel, indicators = NULL, min_countries = 5L,
  min_indicators = 10L, verbose = TRUE)
```

## Arguments

- panel:

  Tibble from
  [`cascade_to_admin1()`](https://mohamedhtitich1.github.io/localintel/reference/cascade_to_admin1.md).

- indicators:

  Character vector of indicator column names. If NULL, auto-detected
  from `imp_*_flag` columns.

- min_countries:

  Integer: minimum countries per indicator (default: 5).

- min_indicators:

  Integer: minimum indicators per region (default: 10).

- verbose:

  Logical: print diagnostics (default: TRUE).

## Value

A list with `panel` (balanced tibble), `dropped_indicators`, and
`dropped_regions`.

## Examples

``` r
if (FALSE) { # \dontrun{
gf <- gapfill_all_dhs()
raw_panel <- cascade_to_admin1(gf)
balanced <- balance_dhs_panel(raw_panel)
} # }
```
