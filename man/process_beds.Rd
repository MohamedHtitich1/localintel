\name{process_beds}
\alias{process_beds}
\alias{process_physicians}
\alias{process_los}
\alias{process_hos_days}
\alias{process_disch_inp}
\alias{process_disch_day}
\alias{process_cod}
\alias{process_health_perceptions}
\alias{merge_datasets}
\alias{compute_composite}
\alias{transform_and_score}
\title{Data Processing Functions}
\usage{
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
}
\arguments{
\item{df}{Raw dataframe from Eurostat}
\item{unit}{Unit filter}
\item{icd10}{ICD-10 filter}
\item{age}{Age group filter}
\item{sex}{Sex filter}
\item{out_col}{Name of output value column}
\item{years_full}{Integer vector of years to include}
\item{...}{Named dataframes to merge}
\item{by}{Character vector of join columns}
\item{join_type}{Type of join: "full", "left", "inner"}
\item{score_cols}{Character vector of column names to average}
\item{transforms}{Named list of transformation expressions}
}
\value{
Processed dataframe
}
\description{
Functions for processing and transforming Eurostat health data.
}
\examples{
\dontrun{
beds <- process_beds(data_list$beds)
merged <- merge_datasets(beds, physicians, los)
}
}
