/*==============================================================================
  PREPARE FIRM-LEVEL FINANCIAL DATA
  Project: EU-Ecuador-FTA
  Software: Stata 17
==============================================================================*/

version 17.0
set more off

/* -----------------------------------------------------------------------------
--- PREPARE FIRM-LEVEL FINANCIAL DATA -------------------------------------------
------------------------------------------------------------------------------*/

frames reset 

* --- 1. Preliminaries ---------------------------------------------------------
use "$superCias/FirmsPanel_2012_2024.dta", clear

drop if FirmsID == "             "

* --- Generate additional firms' identifiers 
gen prov = substr(FirmsID, 1, 2)
drop if prov == ""
drop if prov == "00"

gen isic1 = substr(isic, 1, 1)
drop if isic1 == ""

forvalues i = 2 / 4 {
	local j = `i' + 1
	gen isic`i' = substr(isic, 1, `j')
	drop if isic`i' == ""
}

* --- Perform basic cleaning
drop if sales <= 0
drop if va <= 0
drop if material_costs <= 0
drop if capital <= 0
drop if workers == 0
drop if workers > 11000 & workers != .

* --- Clean-up atypical values
local vars = "sales wages material_costs"
foreach x of local vars {
	gen temp = log(`x')
	bysort isic1 year: cumul temp, gen(temp2)
	drop if temp2 <= 0.05 
	drop temp*
}

order bigCorp prov, before(isic)
order isic1-isic4, after(isic)

compress
save "$eulas_workData/aux_firmsPanel_2012_2024.dta", replace
