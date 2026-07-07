/*==============================================================================
  IMPORT-SIDE FIRM-LEVEL ESTIMATIONS
  Outcomes: TFP, value added, sales, material costs, wages, employment, capital
  Estimators: OLS, 2SLS, LIML, Fuller(1)
  Software: Stata 17
==============================================================================*/

version 17.0
clear all
set more off
set varabbrev off

/* Helper: extract a named coefficient from r(table) ------------------------- */
capture program drop _extract_from_rtable
program define _extract_from_rtable, rclass
    syntax , COEFname(string)

    tempname RT
    matrix `RT' = r(table)
    local c = colnumb(`RT', "`coefname'")

    if missing(`c') | `c' <= 0 {
        di as error "Coefficient `coefname' not found in r(table)."
        matrix list `RT'
        exit 498
    }

    return scalar b  = `RT'[1, `c']
    return scalar se = `RT'[2, `c']
    return scalar t  = `RT'[3, `c']
    return scalar p  = `RT'[4, `c']
    return scalar ll = `RT'[5, `c']
    return scalar ul = `RT'[6, `c']
end

/* Helper: extract a named coefficient from e(b) and e(V) -------------------- */
capture program drop _extract_from_ev
program define _extract_from_ev, rclass
    syntax , COEFname(string)

    tempname B V
    matrix `B' = e(b)
    matrix `V' = e(V)
    local c = colnumb(`B', "`coefname'")

    if missing(`c') | `c' <= 0 {
        di as error "Coefficient `coefname' not found in e(b)."
        matrix list `B'
        exit 498
    }

    return scalar b  = `B'[1, `c']
    return scalar se = sqrt(`V'[`c', `c'])
end

/* Prepare estimation data --------------------------------------------------- */
use "$eulas_workData/1_FINAL_firmsData_2012_2024.dta", clear
merge 1:1 year FirmsID using "$eulas_workData/shift_share.dta", ///
    keep(1 3) nogen

/* Deflator */
preserve
    use "$enemdus/real_exchange_rate_index.dta", clear
    keep year Base2018
    rename Base2018 defY
    tempfile real_exchange_rate
    save `real_exchange_rate'
restore
merge m:1 year using `real_exchange_rate', keep(3) nogen

/* Published sector sample: Manufacturing and Wholesale & Retail */
keep if inlist(isic1, "C", "G")
keep if inrange(year, 2014, 2023)
drop if year == 2022

/* Preserve calendar time; use a consecutive index only for lag operators. */
gen int calendar_year = year
gen int analysis_year = year
replace analysis_year = 2022 if calendar_year == 2023

/* Transform identifiers used in fixed effects and clustering. */
local strvars "isic isic1 isic3 isic4"
foreach x of local strvars {
    clonevar __tmp_`x' = `x'
    drop `x'
    encode __tmp_`x', gen(`x')
    drop __tmp_`x'
}

capture drop prov_n
encode prov, gen(prov_n)

/* Constant 2018 dollars. */
local moneyvars "imports exports imports_europe exports_europe va sales wages material_costs capital"
foreach y of local moneyvars {
    replace `y' = `y' / defY
}

replace tfp = exp(tfp)
gen double m_share_eu = imports_europe / imports

/* Match the sample restriction in the published code. */
keep if imports_europe > 0 & !missing(imports_europe)
keep if !missing(tfp)

xtset ID analysis_year
sort ID analysis_year

/* Specification ------------------------------------------------------------- */
global firmOutcomes "tfp va sales material_costs wages workers capital"
global controls "bigCorp econGroup hhi_sales hhi_imports e_input_firm_0 e_chain_ind_0"
global fe "i.isic3 i.prov_n"

/* Long-format result file ---------------------------------------------------- */
tempfile perf_results
tempname PERF
postfile `PERF' ///
    str20 result_block ///
    str30 outcome ///
    str20 sample ///
    byte sample_id ///
    int year ///
    byte horizon ///
    str12 estimator ///
    double b se tstat pval ll ul N ///
    double kp_f kp_lm ///
    double fs_b fs_se fs_t fs_p fs_ll fs_ul ///
    using `perf_results', replace

/* Estimate year-specific changes relative to 2014 -------------------------- */
foreach y of global firmOutcomes {

    local lagnum = 2
    forvalues tt = 2017/2022 {
        local ++lagnum
        local report_year = cond(`tt' == 2022, 2023, `tt')
        local h = `report_year' - 2014

        capture drop dy_iv dx_iv
        quietly gen double dy_iv = log(`y') - log(L`lagnum'.`y') ///
            if analysis_year == `tt'
        quietly gen double dx_iv = log(imports_europe) - ///
            log(L`lagnum'.imports_europe) if analysis_year == `tt'

        /* OLS benchmark ------------------------------------------------------ */
        quietly reghdfe dy_iv dx_iv $controls if analysis_year == `tt', ///
            absorb($fe) vce(cluster isic3)
        quietly _extract_from_rtable, coefname("dx_iv")

        post `PERF' ("firm_performance") ("`y'") ("manufacturing_retail") ///
            (1) (`report_year') (`h') ("ols") ///
            (r(b)) (r(se)) (r(t)) (r(p)) (r(ll)) (r(ul)) (e(N)) ///
            (.) (.) (.) (.) (.) (.) (.) (.)

        /* IV estimators ------------------------------------------------------ */
        foreach estimator in 2sls liml fuller1 {
            local iv_options "first savefirst savefp(_fstage_)"
            if "`estimator'" == "liml"    local iv_options "liml `iv_options'"
            if "`estimator'" == "fuller1" local iv_options "fuller(1) `iv_options'"

            local fs_est "_fstage_dx_iv"
            capture estimates drop `fs_est'

            quietly ivreghdfe dy_iv $controls (dx_iv = z_im) ///
                if analysis_year == `tt', absorb($fe) ///
                vce(cluster isic3) `iv_options'

            quietly _extract_from_rtable, coefname("dx_iv")
            scalar b_iv  = r(b)
            scalar se_iv = r(se)
            scalar t_iv  = r(t)
            scalar p_iv  = r(p)
            scalar ll_iv = r(ll)
            scalar ul_iv = r(ul)
            scalar N_iv  = e(N)

            capture scalar kp_f_iv = e(rkf)
            if _rc scalar kp_f_iv = .
            capture scalar kp_lm_iv = e(idstat)
            if _rc scalar kp_lm_iv = .

            quietly estimates restore `fs_est'
            quietly _extract_from_ev, coefname("z_im")
            scalar fs_b_iv  = r(b)
            scalar fs_se_iv = r(se)
            scalar fs_t_iv  = fs_b_iv / fs_se_iv

            capture scalar fs_dfr_iv = e(df_r)
            if !_rc & !missing(fs_dfr_iv) {
                scalar fs_p_iv  = 2 * ttail(fs_dfr_iv, abs(fs_t_iv))
                scalar fs_cv_iv = invttail(fs_dfr_iv, 0.025)
            }
            else {
                scalar fs_p_iv  = 2 * normal(-abs(fs_t_iv))
                scalar fs_cv_iv = invnormal(0.975)
            }
            scalar fs_ll_iv = fs_b_iv - fs_cv_iv * fs_se_iv
            scalar fs_ul_iv = fs_b_iv + fs_cv_iv * fs_se_iv

            post `PERF' ("firm_performance") ("`y'") ///
                ("manufacturing_retail") (1) (`report_year') (`h') ///
                ("`estimator'") ///
                (b_iv) (se_iv) (t_iv) (p_iv) (ll_iv) (ul_iv) (N_iv) ///
                (kp_f_iv) (kp_lm_iv) ///
                (fs_b_iv) (fs_se_iv) (fs_t_iv) (fs_p_iv) ///
                (fs_ll_iv) (fs_ul_iv)

            capture estimates drop `fs_est'
        }

        drop dy_iv dx_iv
    }
}

postclose `PERF'

use `perf_results', clear
order result_block outcome sample sample_id year horizon estimator ///
      b se tstat pval ll ul N kp_f kp_lm ///
      fs_b fs_se fs_t fs_p fs_ll fs_ul
sort outcome estimator year
compress
save "$eulas_tables/results_firm_performance_long.dta", replace
export delimited using "$eulas_tables/results_firm_performance_long.csv", replace

preserve
    keep if inlist(estimator, "2sls", "liml", "fuller1")
    save "$eulas_tables/results_iv_diagnostics_long.dta", replace
    export delimited using "$eulas_tables/results_iv_diagnostics_long.csv", replace
restore
