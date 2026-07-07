/*==============================================================================
  PREPARE FIRM EXPORT PANEL
  Project: EU-Ecuador-FTA
  Software: Stata 17
==============================================================================*/

version 17.0
set more off

/* -----------------------------------------------------------------------------
--- PREPARE EXPORTS PANEL ------------------------------------------------------
------------------------------------------------------------------------------*/

frames reset 

/* -----------------------------------------------------------------------------
--- PREPARE DATASET 
------------------------------------------------------------------------------*/

use "$tariffs_data/dta/working_data/Exports_etariff.dta", clear 

* --- Separate exports by country of destination for Europe 
gen exports_europe = exports if eu == 1
replace exports_europe = 0 if exports_europe == .

gen exports_others = exports if eu != 1
replace exports_others = 0 if exports_others == .

* --- Collapse and save final dataset ------------------------------------------
collapse (sum) exports exports_europe, by(date year month nandina_all FirmsID)

compress
save "$eulas_workData/aux_exportsPanel.dta", replace
