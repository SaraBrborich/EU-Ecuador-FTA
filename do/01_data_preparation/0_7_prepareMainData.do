/*==============================================================================
  PREPARE MAIN FIRM-YEAR DATASET
  Project: EU-Ecuador-FTA
  Software: Stata 17
==============================================================================*/

version 17.0
set more off

/* -----------------------------------------------------------------------------
--- PREPARE MAIN DATASET -------------------------------------------------------
------------------------------------------------------------------------------*/

frames reset 

* --- 1. Prepare trade data ----------------------------------------------------

use "$eulas_workData/aux_importsPanel.dta", clear

preserve 
	collapse (sum) importsTotal imports_europe, by(FirmsID year)
	rename importsTotal imports
	
	tempfile importsFirm
	save `importsFirm'
restore

* --- Import competing at baseline
preserve 
	keep if year == 2014
	
	collapse (sum) importsTotal, by(isic4_m)
	
	keep if importsTotal > 0 & importsTotal != .
	drop importsTotal
	gen import_competing = 1
	rename isic4_m isic4 
	
	tempfile importCompeting
	save `importCompeting'
restore

preserve 
	collapse (sum) importsTotal, by(year isic4_m)
	
	keep if importsTotal > 0 & importsTotal != .
	drop importsTotal
	gen aux_import_competing = 1
	rename isic4_m isic4 
	
	tempfile aux_importCompeting
	save `aux_importCompeting'
restore

use "$eulas_workData/aux_exposureOutputIndustry.dta", clear

rename isic4_m isic4 

tempfile outputExposure
save `outputExposure'

use "$eulas_workData/aux_exportsPanel.dta", clear

collapse (sum) exports exports_europe, by(FirmsID year)

tempfile exportsFirm
save `exportsFirm'

* --- 2. Open firm level dataset and merge trade data --------------------------

use  "$eulas_workData/aux_firmsPanel_2012_2024.dta", clear 

local files = "importsFirm exportsFirm"
foreach x of local files {
	merge 1:1 FirmsID year using ``x''
	drop if _merge == 2
	drop _merge
}

merge m:1 isic4 year using `outputExposure'
drop if _merge == 2
drop _merge

merge m:1 isic4 using `importCompeting'
drop if _merge == 2
drop _merge

merge m:1 isic4 year using `aux_importCompeting'
drop if _merge == 2
drop _merge

local files = "aux_exposureInputIndustry aux_exposureValueChain"
foreach x of local files {
	merge m:1 isic4 year using "$eulas_workData/`x'.dta"
	drop if _merge == 2
	drop _merge
}

merge 1:1 FirmsID year using "$eulas_workData/aux_exposureInputFirm.dta"
drop if _merge == 2
drop _merge

order import_competing, after(isic4)

merge 1:1 FirmsID year using "$eulas_workData/aux_paidTariffs.dta"
drop if _merge == 2
drop _merge

* --- 3. Perform basic cleaning ------------------------------------------------

* --- Increase coverage of exposure measures
local vars = "e_output_ind e_input_ind e_chain_ind e_input_firm"
forvalues i = 0 / 1 {
	foreach x of local vars {
		replace `x'_`i' = 0 if `x'_`i' == .
	}
}

* --- Eliminate irrelevant isic codes 
keep if isic1 == "A" | isic1 == "C" | isic1 == "G"

* --- 4. Create relevant variables ----------------------------------------------

* --- Firm size
gen firmSize = . 
replace firmSize = 1 if sales <= 100000
replace firmSize = 2 if sales > 100000 & sales <= 1000000
replace firmSize = 3 if sales > 1000000 & sales <= 2000000
replace firmSize = 4 if sales > 2000000

label define fsizecan 1 "Micro" 2 "Small" 3 "Medium" 4 "Large"
label values firmSize fsizecan

order firmSize, after(isic4)

* --- Import competing and trade status ----------------------------------------
replace import_competing = aux_import_competing if import_competing == .
replace import_competing = 0 if import_competing == .
drop aux_import_competing

* --- Baseline trade-status categories used only in the TFP routine
* The unavailable legacy trade_status.ado created several thresholds. The
* published workflow uses the zero-threshold classification for 2014 only.
preserve
    keep if year == 2014
    keep FirmsID imports exports
    duplicates drop FirmsID, force

    gen byte trade_status_1 = .
    replace trade_status_1 = 1 if (missing(imports) | imports <= 0) & ///
        (missing(exports) | exports <= 0)
    replace trade_status_1 = 2 if imports > 0 & (missing(exports) | exports <= 0)
    replace trade_status_1 = 3 if exports > 0 & (missing(imports) | imports <= 0)
    replace trade_status_1 = 4 if imports > 0 & exports > 0

    label define trade_status_lbl 1 "Non-trader" 2 "Importer only" ///
        3 "Exporter only" 4 "Two-way trader"
    label values trade_status_1 trade_status_lbl

    tempfile baseline_trade_status
    save `baseline_trade_status'
restore

merge m:1 FirmsID using `baseline_trade_status', keep(1 3) nogen

* --- Identify economic groups
merge m:1 FirmsID using "$Eff_of_Tariffs/aux_bigCorps.dta"
drop if _merge == 2
drop _merge

order bigCorp, after(firmSize)

merge m:1 FirmsID using "$Eff_of_Tariffs/aux_econGroup.dta"
drop if _merge == 2
drop _merge

order econGroup, after(bigCorp)

local vars = "bigCorp econGroup"
foreach x of local vars {
	replace `x' = 0 if `x' == .
}

* --- Herfindahl indexes for sales and imports (computed without add-ons) 
bysort year isic4: egen double __sales_total = total(sales)
gen double __sales_share_sq = (sales / __sales_total)^2 if __sales_total > 0
bysort year isic4: egen double hhi_sales = total(__sales_share_sq)

bysort year isic4: egen double __imports_total = total(imports)
gen double __imports_share_sq = (imports / __imports_total)^2 if __imports_total > 0
bysort year isic4: egen double hhi_imports = total(__imports_share_sq)

drop __sales_total __sales_share_sq __imports_total __imports_share_sq
order hhi_sales hhi_imports, after(exports_europe)

* --- Setup deflator 
preserve
    use "$enemdus/real_exchange_rate_index.dta", clear

    keep year Base2018
    rename Base2018 rexrai

    replace rexrai = rexrai/100

    tempfile real_exchange_rate
    save `real_exchange_rate'
restore

merge m:1 year using `real_exchange_rate', keep(3) nogen
order rexrai, after(hhi_imports)

* --- Estimate TFP -------------------------------------------------------------

preserve 
	xtset ID year
	
	* --- Generate variables 
	gen c_y = log(sales) - log(rexrai)
	gen c_l = log(wages) - log(rexrai)
	gen c_k = log(capital) - log(rexrai)
	gen c_m = log(material_costs) - log(rexrai)
	gen c_va = log(va) - log(rexrai)
	gen l_exports = log(exports + 1)
	gen l_imports = log(imports + 1)
	
	tab firmSize, gen(dfsize)
	tab year, gen(dyear)
	
	* Gen interaction terms
	gen var_1_1 = c_l * c_l 
	gen var_1_2 = c_l * c_k 
	gen var_2_2 = c_k * c_k
	
	* --- Exposure variables 
	local exp = "output chain"
	foreach x of local exp {
		gen e_`x'_x = e_`x'_ind_0
		replace e_`x'_x = 0 if year < 2014
		replace e_`x'_x = 0 if e_`x'_x == .
	}

	* --- Fill firms that do not have information for capital 
	encode isic1, gen(isic1_n)
	
	reg c_k c_y c_l c_m i.year i.isic1_n
	predict k_hat, xb 
	replace c_k = k_hat if c_k == .
	
	gen tfp = .
	gen tfp_cb = .
	local k = 0
	
	forvalues j = 1 / 4 {
		if `j' <= 2 {
			gen isic_est = substr(isic, 1, 3)
			replace isic_est = "A02" if isic_est == "A03" 
			replace isic_est = "C14" if isic_est == "C15"
			replace isic_est = "C12" if isic_est == "C13"
			replace isic_est = "C25" if isic_est == "C26"
			replace isic_est = "C25" if isic_est == "C27"
			replace isic_est = "C3" if isic_est == "C31"
			replace isic_est = "C3" if isic_est == "C32"
			replace isic_est = "C3" if isic_est == "C33"
			
			levelsof isic_est, local(sectors)
		}
		if `j' == 3 {
			gen isic_est = substr(isic, 1, 3)
			replace isic_est = "A01" if isic_est == "A02" 
			replace isic_est = "C12" if isic_est == "C13"
			replace isic_est = "" if isic_est == "C33"
			replace isic_est = "" if isic1 == "G"
			
			levelsof isic_est, local(sectors)
		}
		if `j' == 4 {
			gen isic_est = substr(isic, 1, 3)
			replace isic_est = "A" if isic1 == "A"
			replace isic_est = "C" if isic1 == "C"
			
			levelsof isic_est, local(sectors)
		}
				
		foreach i of local sectors {
			local k = `k' + 1
			local seed = 124 + `k'
			set seed `seed'

			di ("Estimating tradables: Industry `i'")		
			qui {				
				local controls = "e_output_x e_chain_x dyear2 dyear3 dyear4 dyear5 dyear6 dyear7 dyear8 dyear9 dyear10"
				local xvars = "c_l c_k e_output_x e_chain_x dyear2 dyear3 dyear4 dyear5 dyear6 dyear7 dyear8 dyear9 dyear10 var_1_1 var_1_2 var_2_2"
				
				local xvars_cd = "c_l c_k e_output_x e_chain_x dyear2 dyear3 dyear4 dyear5 dyear6 dyear7 dyear8 dyear9 dyear10"
				
				* Trans-log
				prodest c_va if isic_est == "`i'" & trade_status_1 == `j', free(c_l) proxy(c_m) state(c_k) method(lp) control(`controls') acf translog va
				
				gen yhat = 0
				foreach x of local xvars {
					replace yhat = yhat + _b[`x'] * `x' 
				}
				replace tfp = c_va - yhat if isic_est == "`i'" & trade_status_1 == `j'
				
				drop yhat
				
				* Cobb-Douglas (for comparison)
				prodest c_va if isic_est == "`i'" & trade_status_1 == `j', free(c_l) proxy(c_m) state(c_k) method(lp) control(`controls') acf va
				
				gen yhat = 0
				foreach x of local xvars_cd {
					replace yhat = yhat + _b[`x'] * `x' 
				}
				replace tfp_cb = c_va - yhat if isic_est == "`i'" & trade_status_1 == `j'
				
				drop yhat
			}
		}
		
		drop isic_est
	}
	
	keep if tfp != .
	keep year FirmsID tfp tfp_cb
	
	tempfile tfpData
	save `tfpData'
restore

merge 1:1 FirmsID year using `tfpData'
drop _merge



compress
save "$eulas_workData/1_FINAL_firmsData_2012_2024.dta", replace
