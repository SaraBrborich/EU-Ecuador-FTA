/*==============================================================================
  PREPARE IMPORT-SIDE SHIFT-SHARE INSTRUMENT
  Shares: 2014 firm-product EU import composition
  Shifts: change in log(1 + tariff) relative to 2016
  Software: Stata 17
==============================================================================*/

version 17.0
clear
set more off

/* Read EU import transactions ----------------------------------------------- */
use "$tariffs_data/dta/working_data/Imports_etariff.dta", clear

keep if eu == 1
keep if inrange(year, 2012, 2023)
drop if year == 2022
drop if missing(FirmsID) | FirmsID == ""

keep date year month nandina_all FirmsID country r_imports tariff

/* Number of EU import partners by firm-year --------------------------------- */
preserve
    keep year FirmsID country r_imports
    keep if r_imports > 0 & !missing(r_imports)
    duplicates drop year FirmsID country, force
    collapse (count) import_partners_eu = country, by(year FirmsID)
    tempfile import_partners
    save `import_partners'
restore

/* Firm-product-year imports and product-year statutory tariffs -------------- */
collapse (sum) imports = r_imports (mean) tariff_m = tariff, ///
    by(year FirmsID nandina_all)

/* Product-level shifts relative to 2016 ------------------------------------- */
preserve
    collapse (mean) tariff_m, by(year nandina_all)

    preserve
        keep if year == 2016
        keep nandina_all tariff_m
        rename tariff_m tariff_m_2016
        tempfile tariff_base_2016
        save `tariff_base_2016'
    restore

    merge m:1 nandina_all using `tariff_base_2016', keep(3) nogen

    gen double log_tariff_t    = log(1 + tariff_m / 100)
    gen double log_tariff_2016 = log(1 + tariff_m_2016 / 100)
    gen double g_km = log_tariff_t - log_tariff_2016

    keep year nandina_all g_km tariff_m tariff_m_2016
    tempfile product_shifts
    save `product_shifts'
restore

/* Predetermined 2014 firm-product shares ------------------------------------ */
preserve
    keep if year == 2014
    collapse (sum) imports_ik_2014 = imports, by(FirmsID nandina_all)
    bysort FirmsID: egen double imports_i_2014 = total(imports_ik_2014)
    gen double s_ikm_2014 = imports_ik_2014 / imports_i_2014
    keep if imports_i_2014 > 0 & !missing(imports_i_2014)
    keep FirmsID nandina_all s_ikm_2014 imports_ik_2014 imports_i_2014
    tempfile baseline_shares
    save `baseline_shares'
restore

/* Combine shares and shifts ------------------------------------------------- */
merge m:1 year nandina_all using `product_shifts', keep(3) nogen
merge m:1 FirmsID nandina_all using `baseline_shares', keep(1 3) nogen

/* Imports include all current products with an observed tariff shift. The
   instrument contribution is nonzero only for products in the predetermined
   2014 basket. This matches the published design while allowing firms to add
   new products after 2014. */
gen double z_im_component = s_ikm_2014 * g_km
replace z_im_component = 0 if missing(z_im_component)

collapse (sum) imports z_im = z_im_component ///
    (mean) tariff_m tariff_m_2016, by(year FirmsID)

merge 1:1 year FirmsID using `import_partners', keep(1 3) nogen
replace import_partners_eu = 0 if missing(import_partners_eu)

label var z_im "Import shift-share instrument: 2014 shares x tariff changes from 2016"
label var imports "Real imports from the EU"
label var import_partners_eu "Number of EU import partner countries"
label var tariff_m "Average observed product tariff in firm-year basket (%)"
label var tariff_m_2016 "Average 2016 tariff for matched products (%)"

order FirmsID year z_im imports import_partners_eu tariff_m tariff_m_2016
sort FirmsID year
compress

isid FirmsID year
save "$eulas_workData/shift_share.dta", replace
