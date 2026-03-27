# Filter to SSA Countries

Filters a dataframe to rows belonging to Sub-Saharan African countries.
Expects the dataframe to have a `geo` column in the format
`CC_RegionName` (as produced by
[`process_dhs()`](https://mohamedhtitich1.github.io/localintel/reference/process_dhs.md)).

## Usage

``` r
keep_ssa(df, extra = NULL)
```

## Arguments

- df:

  Dataframe with a `geo` column containing DHS composite keys.

- extra:

  Character vector of additional 2-letter country codes to keep
  (default: NULL).

## Value

Filtered dataframe with only SSA country rows.

## Examples

``` r
if (FALSE) { # \dontrun{
processed <- process_dhs(raw_data, out_col = "u5_mortality")
ssa_only <- keep_ssa(processed)
} # }
```
