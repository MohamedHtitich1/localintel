# DHS Indicator Variable Labels

Returns a named character vector mapping DHS indicator friendly names
(as used in processed data) to human-readable labels for visualization
and export.

## Usage

``` r
dhs_var_labels()
```

## Value

Named character vector with variable names as names and labels as
values.

## Examples

``` r
if (FALSE) { # \dontrun{
labs <- dhs_var_labels()
labs["u5_mortality"]
} # }
```
