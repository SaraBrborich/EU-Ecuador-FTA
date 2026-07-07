/*==============================================================================
  BUILD CHAPTER AND ONLINE-APPENDIX TABLES
  Input:  output/tables/results_firm_performance_long.dta
  Output: publication-oriented Excel workbooks and CSV files
==============================================================================*/

version 17.0
clear
set more off

use "$eulas_tables/results_firm_performance_long.dta", clear

/* Human-readable labels and significance stars ----------------------------- */
gen str30 outcome_label = ""
replace outcome_label = "TFP"             if outcome == "tfp"
replace outcome_label = "Value added"     if outcome == "va"
replace outcome_label = "Sales"           if outcome == "sales"
replace outcome_label = "Material costs"  if outcome == "material_costs"
replace outcome_label = "Wages"           if outcome == "wages"
replace outcome_label = "Employment"      if outcome == "workers"
replace outcome_label = "Capital"         if outcome == "capital"

gen str3 stars = ""
replace stars = "*"   if pval < 0.10 & !missing(pval)
replace stars = "**"  if pval < 0.05 & !missing(pval)
replace stars = "***" if pval < 0.01 & !missing(pval)

gen str20 estimate = string(b, "%9.3f") + stars
gen str20 standard_error = "(" + string(se, "%9.3f") + ")"
gen str20 first_stage = string(fs_b, "%9.3f")
gen str20 first_stage_se = "(" + string(fs_se, "%9.3f") + ")"

/* Appendix Table 1: first stage and diagnostics ----------------------------- */
preserve
    keep if estimator == "2sls" & inlist(outcome, "tfp", "workers")
    gen str20 panel = cond(outcome == "workers", "Employment", "Common sample")
    keep panel year fs_b fs_se fs_t fs_p kp_f kp_lm N
    sort panel year
    export excel using "$eulas_tables/appendix_table1_first_stage.xlsx", ///
        firstrow(variables) replace
    export delimited using "$eulas_tables/appendix_table1_first_stage.csv", replace
restore

/* Appendix Table 2: TFP and value added ------------------------------------ */
preserve
    keep if inlist(outcome, "tfp", "va") & ///
        inlist(estimator, "2sls", "liml", "fuller1")
    keep outcome outcome_label estimator year b se pval stars estimate ///
        standard_error N
    sort outcome estimator year
    export excel using "$eulas_tables/appendix_table2_main_outcomes.xlsx", ///
        firstrow(variables) replace
    export delimited using "$eulas_tables/appendix_table2_main_outcomes.csv", replace
restore

/* Appendix Table 3: adjustment mechanisms ---------------------------------- */
preserve
    keep if inlist(outcome, "sales", "material_costs", "wages", ///
        "workers", "capital") & ///
        inlist(estimator, "2sls", "liml", "fuller1")
    keep outcome outcome_label estimator year b se pval stars estimate ///
        standard_error N
    sort outcome estimator year
    export excel using "$eulas_tables/appendix_table3_mechanisms.xlsx", ///
        firstrow(variables) replace
    export delimited using "$eulas_tables/appendix_table3_mechanisms.csv", replace
restore

/* Chapter Table 1: first stage + preferred Fuller(1) estimates ------------- */
preserve
    keep if inlist(year, 2017, 2023)

    tempfile full_results first_stage

    preserve
        keep if estimator == "fuller1"
        keep outcome outcome_label year b se pval stars estimate standard_error
        save `full_results'
    restore

    keep if estimator == "2sls" & outcome == "tfp"
    keep year fs_b fs_se fs_p
    rename fs_b b
    rename fs_se se
    rename fs_p pval
    gen str30 outcome = "import_response"
    gen str30 outcome_label = "Import response"
    gen str3 stars = ""
    replace stars = "*"   if pval < 0.10 & !missing(pval)
    replace stars = "**"  if pval < 0.05 & !missing(pval)
    replace stars = "***" if pval < 0.01 & !missing(pval)
    gen str20 estimate = string(b, "%9.3f") + stars
    gen str20 standard_error = "(" + string(se, "%9.3f") + ")"
    append using `full_results'

    gen byte row_order = .
    replace row_order = 1 if outcome == "import_response"
    replace row_order = 2 if outcome == "material_costs"
    replace row_order = 3 if outcome == "sales"
    replace row_order = 4 if outcome == "workers"
    replace row_order = 5 if outcome == "wages"
    replace row_order = 6 if outcome == "capital"
    replace row_order = 7 if outcome == "tfp"
    replace row_order = 8 if outcome == "va"

    keep if !missing(row_order)
    sort row_order year
    keep row_order outcome outcome_label year b se pval stars estimate standard_error
    export excel using "$eulas_tables/chapter_table1_summary.xlsx", ///
        firstrow(variables) replace
    export delimited using "$eulas_tables/chapter_table1_summary.csv", replace
restore

noi di as result "Chapter and appendix tables written to $eulas_tables"
