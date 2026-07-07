/*==============================================================================
  PREPARE FIRM IMPORT PANEL AND EXPOSURE CONTROLS
  Project: EU-Ecuador-FTA
  Software: Stata 17
==============================================================================*/

version 17.0
set more off

/* -----------------------------------------------------------------------------
--- PREPARE IMPORTS PANEL ------------------------------------------------------
------------------------------------------------------------------------------*/

use "$tariffs_data/dta/working_data/Imports_etariff.dta", clear 

* --- Aggregate dataset 
rename imports importsTotal
gen imports_europe = importsTotal if eu == 1

collapse (sum) importsTotal imports_europe, by(date year month FirmsID nandina_all)
sort FirmsID nandina_all

gen temp = substr(FirmsID, 4, 1)
drop if temp == "." | temp == "U"
drop temp

* --- Merge with use classification from previous dataset
preserve 
	use  "$Eff_of_Tariffs/aux_DraftFirmMonthly.dta", clear
	
	collapse (sum) importsConsumption importsCapital importsRaw /*
		*/ importsFuel, by(HTScode)

    rename HTScode nandina_all

	gen importClassByUse = .
	replace importClassByUse = 1 if importsConsumption > 0 & importsConsumption != .
	replace importClassByUse = 2 if importsCapital > 0 & importsCapital != .
	replace importClassByUse = 2 if importsRaw > 0 & importsRaw != .
	replace importClassByUse = 3 if importsFuel > 0 & importsFuel != .
	replace importClassByUse = 4 if importClassByUse == .

	tempfile importClass
	save `importClass'
restore

* Keep only consumption, capital and raw material imports
merge m:1 nandina_all using `importClass'
drop if _merge == 2
drop _merge
drop importsConsumption importsCapital importsRaw importsFuel

label define importClassLab 1 "Consumption" 2 "Inputs" 3 "Fuel" 4 "Others" 
label values importClassByUse importClassLab

* --- Merge with ISIC classification codes 
rename nandina_all HTScode
merge m:1 HTScode using "$Eff_of_Tariffs/aux_HTScode_ciiu.dta"
drop if _merge == 1
drop _merge
rename HTScode nandina_all

rename ciiuProd isicImports
gen isic4_m = substr(isicImports, 1, 5)
gen isic1_m = substr(isic4_m, 1, 1)

* --- Merge with ISIC codes of the importer
preserve 
	use "$eulas_workData/aux_firmsPanel_2012_2024.dta", clear	
	
	collapse (sum) sales, by(FirmsID isic4 isic1)
	drop sales
	
	* Do not consider firms that change isic codes
	bysort FirmsID: gen temp = 1
	bysort FirmsID: egen temp2 = total(temp)
	drop if temp2 > 1
	drop temp*
	
	tempfile isicImporter
	save `isicImporter'	
restore

merge m:1 FirmsID using `isicImporter'
keep if _merge == 3
drop _merge

* --- Compute exposure measures

* Binary exposure measure 
preserve 
	use "$Eff_of_Tariffs/universalTariff.dta", clear
	
	keep if year == 2015 & month == 3
	keep HTScode
    rename HTScode nandina_all
	
	gen exposed_product = 1
	
	tempfile affected
	save `affected'
restore

merge m:1 nandina_all using `affected'
drop if _merge == 2
drop _merge

replace exposed_product = 0 if exposed_product == .

* Accumulated exposure 

* - Create dummy dataset (perfectly balanced panel)
forvalues t = 2012 / 2024 {
	* --- Dataset for benchmark
	preserve 
		keep if year == 2014
		drop year date
		
		gen year = `t'
		
		gen date = ym(year, month)
		format date %tm 
		order date year month
		
		keep date year month FirmsID nandina_all importsTotal isic4 isic4_m 
		
		tempfile firms`t'
		save `firms`t''
	restore
	
	* --- Dataset for robustness (baseline is the average of the last three years)
	preserve 
		keep if year <= 2014
		
		collapse (mean) importsTotal, by(month FirmsID nandina_all isic4 isic4_m)
		
		gen year = `t'
		
		gen date = ym(year, month)
		format date %tm 
		order date year month
		
		tempfile rbst_firms`t'
		save `rbst_firms`t''
	restore
}

local files = "firms rbst_firms"
local varnames = "importsSafeguards importsSafeguards_rbst"
local i = 0
foreach f of local files {
	local i = `i' + 1
	local varn : word `i' of `varnames'
	
	preserve 
		use ``f'2012', clear
		
		forvalues t = 2013 / 2024 {
			append using ``f'`t''
		}
		
		rename importsTotal `varn'
		
		tempfile `f'All
		save ``f'All'
	restore
}

* - Create dataset with information on safeguards tariff 

* 2012 - 2013
forvalues t = 2012 / 2014 {
	preserve
		use "$Eff_of_Tariffs/universalTariff.dta", clear
		
		keep if year == 2015 
		keep year month HTScode tariff 
        rename HTScode nandina_all
		
		drop year
		gen year = `t'
		
		gen date = ym(year, month)
		format date %tm
		
		tempfile safeguards`t'
		save `safeguards`t''
	restore
}

preserve 
	use `safeguards2012', clear 
	
	forvalues t = 2013 / 2014 {
		append using `safeguards`t''
	}
	
	replace tariff = 0 if year == 2014
	
	order date year month nandina_all tariff
	
	tempfile safeguards2012_2014
	save `safeguards2012_2014'
restore

* 2015 - 2017
preserve
	use "$Eff_of_Tariffs/universalTariff.dta", clear
	
	keep year month HTScode tariff 
	gen date = ym(year, month)
	format date %tm
	
	order date year month HTScode tariff
    rename HTScode nandina_all
	
	append using `safeguards2012_2014'
	
	keep date nandina_all tariff
	
	drop if date == .
	
	tempfile safeguardsAll
	save `safeguardsAll'
restore

* - Compute exposure
frame create exposure
frame change exposure 

use `firmsAll', clear

merge m:1 date nandina_all using `safeguardsAll'
drop if _merge == 2
drop _merge

merge 1:1 date FirmsID nandina_all using `rbst_firmsAll'
drop if _merge == 2
drop _merge
drop month

rename importsSafeguards imports_0
rename importsSafeguards_rbst imports_1

forvalues i = 0 / 1 {
	gen paid_tariff_`i' = tariff * imports_`i'
	replace paid_tariff_`i' = 0 if date < tm(2015m3) | date > tm(2017m6)
}

collapse (sum) imports_0 imports_1 paid_tariff_0 paid_tariff_1, by(year nandina_all FirmsID isic4_m isic4)

* Firm level exposure
preserve 
	* Aggregate at the firm-year level
	collapse (sum) paid_tariff_0 paid_tariff_1 imports_0 imports_1, by(FirmsID year)
	
	* Accumulate exposure
	forvalues i = 0 / 1 {
		bysort FirmsID (year): gen acc_tariff = sum(paid_tariff_`i') if year >= 2015
		bysort FirmsID (year): gen acc_imports = sum(imports_`i') if year >= 2015

		replace acc_tariff = paid_tariff_`i' if year <= 2014
		replace acc_imports = imports_`i' if year <= 2014
		
		gen e_input_firm_`i' = acc_tariff / acc_imports
		
		drop acc_tariff acc_imports
	}
	
	save "$eulas_workData/aux_exposureInputFirm.dta", replace
restore

* Input exposure, industry level
preserve
	* Aggregate at the industry-year level
	collapse (sum) paid_tariff_0 paid_tariff_1 imports_0 imports_1, by(isic4 year)
	
	* Accumulate exposure
	forvalues i = 0 / 1 {
		bysort isic4 (year): gen acc_tariff = sum(paid_tariff_`i') if year >= 2015
		bysort isic4 (year): gen acc_imports = sum(imports_`i') if year >= 2015

		replace acc_tariff = paid_tariff_`i' if year <= 2014
		replace acc_imports = imports_`i' if year <= 2014

		gen e_input_ind_`i' = acc_tariff / acc_imports
		
		drop acc_tariff acc_imports
	}
	
	save "$eulas_workData/aux_exposureInputIndustry.dta", replace
restore

* Output exposure, industry level
preserve 
	* Aggregate at the industry-year level
	collapse (sum) paid_tariff_0 paid_tariff_1 imports_0 imports_1, by(isic4_m year)
	
	* Accumulate exposure
	forvalues i = 0 / 1 {
		bysort isic4_m (year): gen acc_tariff = sum(paid_tariff_`i') if year >= 2015
		bysort isic4_m (year): gen acc_imports = sum(imports_`i') if year >= 2015

		replace acc_tariff = paid_tariff_`i' if year <= 2014
		replace acc_imports = imports_`i' if year <= 2014

		gen e_output_ind_`i' = acc_tariff / acc_imports
		
		drop acc_tariff acc_imports
	}
	
	save "$eulas_workData/aux_exposureOutputIndustry.dta", replace
restore

frame change default
frame drop exposure 

* Paid tariffs for elasticities
preserve 
	merge m:1 nandina_all date using `safeguardsAll'
	
	bysort year FirmsID (nandina_all): egen tempImp = total(importsTotal)
	gen weight = importsTotal / tempImp	
	
	gen paid_tariff = tariff
	replace paid_tariff = . if date < tm(2015m3) | date > tm(2017m6)
	
	collapse (mean) paid_tariff [pw = weight], by(year FirmsID)
	
	save "$eulas_workData/aux_paidTariffs.dta", replace
restore

compress
save "$eulas_workData/aux_importsPanel.dta", replace