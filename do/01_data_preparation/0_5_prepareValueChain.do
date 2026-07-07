/*==============================================================================
  PREPARE VALUE-CHAIN EXPOSURE CONTROLS
  Project: EU-Ecuador-FTA
  Software: Stata 17
==============================================================================*/

version 17.0
set more off

/* -----------------------------------------------------------------------------
--- PREPARE VALUE CHAIN EXPOSURE -----------------------------------------------
------------------------------------------------------------------------------*/

frames reset 

* --- Prepare network ----------------------------------------------------------

* --- Setup identifiers 
import delim using "$Eff_of_Tariffs/ProductionNetworks/id_ecuador_complete.csv", varn(1) clear
keep id ciiu4n4

rename id id_inf
tempfile isic_data_inf
save `isic_data_inf'

rename id_inf id_prov
tempfile isic_data_prov
save `isic_data_prov'

* --- Merge isic identifiers
import delim using "$Eff_of_Tariffs/ProductionNetworks/totaltax_ND(2014)_firms.csv", varn(1) clear

* Buyers
merge m:1 id_inf using `isic_data_inf'
drop if _merge == 2
drop _merge
rename ciiu4n4 isic4_buyer

* Sellers
merge m:1 id_prov using `isic_data_prov'
drop if _merge == 2
drop _merge
rename ciiu4n4 isic4_seller

* --- Aggregate at the isic 4 digit code level
collapse (sum) total_tax, by(isic4_buyer isic4_seller)

save "$eulas_workData/prodNetworkIndLevel_2014.dta", replace

* --- Compute link strength 
bysort isic4_buyer (isic4_seller): egen temp = total(total_tax)
gen alpha_js = total_tax / temp
drop temp

tempfile prodNetwork
save `prodNetwork'

* --- Merge exposure data
forvalues t = 2012 / 2024 {
	preserve
		use "$eulas_workData/aux_exposureInputIndustry.dta", clear
		
		keep if year == `t'
		rename isic4 isic4_seller 
		
		merge 1:m isic4_seller using `prodNetwork'
		
		drop if _merge == 1
		drop _merge total_tax
		
		replace year = `t' if year == .
		
		forvalues i = 0 / 1 {
			replace e_input_ind_`i' = 0 if e_input_ind_`i' == .
			gen e_chain_ind_`i' = alpha_js * e_input_ind_`i'
		}
		
		collapse (sum) e_chain_ind_0 e_chain_ind_1, by(year isic4_buyer)
		
		tempfile input_exposure_`t'
		save `input_exposure_`t''
	restore
}

use `input_exposure_2012'

forvalues t = 2013 / 2024 {
	append using `input_exposure_`t''
}

order year isic4_buyer
rename isic4_buyer isic4 

compress
save "$eulas_workData/aux_exposureValueChain.dta", replace