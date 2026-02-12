# Data Interpolation and Time Utilities

`interp_const_ends_flag` performs linear interpolation within gaps and
repeats endpoints, also returning a flag indicating original NA values.
`standardize_time` standardizes time column naming and parses year as
integer.

## Usage

``` r
interp_const_ends_flag(y)
standardize_time(df)
```

## Arguments

- y:

  Numeric vector to interpolate

- df:

  Dataframe with 'time' or 'TIME_PERIOD' column

## Value

`interp_const_ends_flag`: List with 'value' (interpolated) and 'flag' (1
if was NA) `standardize_time`: Dataframe with standardized 'time' and
'year' columns

## Examples

``` r
result <- interp_const_ends_flag(c(NA, 10, NA, NA, 20, NA))
result$value
#> [1] 10.00000 10.00000 13.33333 16.66667 20.00000 20.00000
result$flag
#> [1] 1 0 1 1 0 1
```
