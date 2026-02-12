# Data Processing Functions

Functions for processing and transforming Eurostat health data.

## Usage

``` r
process_beds(df, unit = "P_HTHAB")
process_physicians(df, unit = "P_HTHAB")
process_los(df, unit = "NR", icd10 = "A-T_Z_XNB", age = "TOTAL", sex = "T")
process_hos_days(df, unit = "NR", icd10 = "A-T_Z_XNB", age = "TOTAL", sex = "T")
process_disch_inp(df, unit = c("P_HTHAB", "P100TH"), icd10 = "A-T_Z_XNB", 
  age = "TOTAL", sex = "T")
process_disch_day(df, unit = c("P_HTHAB", "P100TH"), icd10 = "A-T_Z_XNB", 
  age = "TOTAL", sex = "T")
process_cod(df, unit = "RT", icd10 = "A-R_V-Y", age = "TOTAL", sex = "T", 
  out_col = "cod_rate")
process_health_perceptions(df, years_full = 2008:2024)
merge_datasets(..., by = c("geo", "year"), join_type = "full")
compute_composite(df, score_cols, out_col = "composite_score")
transform_and_score(df, transforms)
```

## Arguments

- df:

  Raw dataframe from Eurostat

- unit:

  Unit filter

- icd10:

  ICD-10 filter

- age:

  Age group filter

- sex:

  Sex filter

- out_col:

  Name of output value column

- years_full:

  Integer vector of years to include

- ...:

  Named dataframes to merge

- by:

  Character vector of join columns

- join_type:

  Type of join: "full", "left", "inner"

- score_cols:

  Character vector of column names to average

- transforms:

  Named list of transformation expressions

## Value

Processed dataframe

## Examples

``` r
if (FALSE) { # \dontrun{
beds <- process_beds(data_list$beds)
merged <- merge_datasets(beds, physicians, los)
} # }
```
