# Process Tourism Nights Spent Data

Filters regional tourism data from Eurostat (tour_occ_nin2)

## Usage

``` r
process_tourism_nights(df, unit = "NR", nace_r2 = "I551-I553", c_resid = "TOTAL")
```

## Arguments

- df:

  Raw dataframe from Eurostat tour_occ_nin2

- unit:

  Unit filter (default: "NR" for number)

- nace_r2:

  NACE sector filter (default: "I551-I553" for accommodation)

- c_resid:

  Residence filter (default: "TOTAL")

## Value

Processed dataframe with geo, year, and nights_spent columns

## Examples

``` r
if (FALSE) { # \dontrun{
tourism_data <- process_tourism_nights(raw_tourism)
} # }
```
