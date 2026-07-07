/*==============================================================================
  PREPARE EFFECTIVE TARIFFS FOR EXPORTS
  Project: EU-Ecuador-FTA
  Software: Stata 17

  This do-file harmonizes firm-level export transactions, merges the official
  EU tariff-elimination schedule and MFN rates, and applies the custom etariff
  program. Export tariff information supports the descriptive tariff figure;
  the final causal estimations use the import-side instrument.
==============================================================================*/

version 17.0
set more off

local years = "2000_2001 2002_2003 2004_2005 2006_2007 2008_2009 2010_2011 2012_2013 2014_2015 2016_2017 2018_2019 2020_2021 2022_2023_1"

foreach t of local years {
	import delim "$competition_data/tradeDatasets/Exportaciones/export_`t'.csv", clear
	
	capture confirm string variable valorfobdólar

	if _rc == 0 {
		* Variable is a string. 
		if "`t'" == "2022_2023_1" {
			* Special Case
			gen temp = real(subinstr(valorfobdólar, ",", ".", .))
			replace temp = real(subinstr(valorfobdólar, ",", "", .)) if temp == .
			drop valorfobdólar
			gen valorfobdólar = temp
			drop temp
		}
		else {
			destring valorfobdólar, gen(temp) dpcomma
			drop valorfobdólar
			gen valorfobdólar = temp
			drop temp
		}
	}
	
	capture confirm string variable códigoidentificación

	if _rc != 0 {
		* Variable is not a string. 
		tostring códigoidentificación, format(%16.0g) force replace
	}
	
	tempfile exports`t'
	save `exports`t''
}

use `exports2000_2001', clear

local years = "2002_2003 2004_2005 2006_2007 2008_2009 2010_2011 2012_2013 2014_2015 2016_2017 2018_2019 2020_2021 2022_2023_1"

foreach t of local years {
	di "`t'"
	append using `exports`t''
}

/* -----------------------------------------------------------------------------
--- CLEAN UP VARIABLES 
------------------------------------------------------------------------------*/

* --- All transactions are exports, this variable is redundant.
drop tipotransacción

* --- Fix date variable
rename año year 
rename nummes month

gen date = ym(year, month)
format date %tm

order date year month

* --- Eliminate redundant date-related variables
drop periodo trimestre añomes nombremes mes día

* --- HTS code
tostring nandina, format(%14.0g) gen(temp)
gen temp2 = strlen(temp)

drop if temp2 == 4
gen zeros = "0"
egen temp3 = concat(zeros temp) if temp2 == 9

gen HTScode = temp if temp2 == 10
replace HTScode = temp3 if temp2 == 9

drop temp* 
order HTScode, after(month)

drop nandina descripciónnandina

* --- Fix fiscal ID
gen temp = strlen(códigoidentificación)

keep if temp >= 12
egen temp2 = concat(zeros códigoidentificación)	

gen FirmsID = códigoidentificación if temp == 13
replace FirmsID = temp2 if temp == 12

drop temp* zeros 
order FirmsID, after(HTScode)
drop códigoidentificación nombreexportadorimportador


* --- Identify countries from the EU + UK
gen eu = 0
replace eu = 1 if paísorigen == "AUSTRIA"
replace eu = 1 if paísorigen == "BÉLGICA"
replace eu = 1 if paísorigen == "BULGARIA"
replace eu = 1 if paísorigen == "REPÚBLICA CHECA"
replace eu = 1 if paísorigen == "CHIPRE"
replace eu = 1 if paísorigen == "ALEMANIA"
replace eu = 1 if paísorigen == "DINAMARCA"
replace eu = 1 if paísorigen == "ESTONIA"
replace eu = 1 if paísorigen == "ESPAÑA"
replace eu = 1 if paísorigen == "FINLANDIA"
replace eu = 1 if paísorigen == "FRANCIA"
replace eu = 1 if paísorigen == "GRECIA"
replace eu = 1 if paísorigen == "HUNGRÍA"
replace eu = 1 if paísorigen == "IRLANDA"
replace eu = 1 if paísorigen == "ITALIA"
replace eu = 1 if paísorigen == "LITUANIA"
replace eu = 1 if paísorigen == "LUXEMBURGO"
replace eu = 1 if paísorigen == "MALTA"
replace eu = 1 if paísorigen == "PAÍSES BAJOS (HOLANDA)"
replace eu = 1 if paísorigen == "POLONIA"
replace eu = 1 if paísorigen == "PORTUGAL"
replace eu = 1 if paísorigen == "REINO UNIDO"
replace eu = 1 if paísorigen == "RUMANIA"
replace eu = 1 if paísorigen == "ESLOVENIA"
replace eu = 1 if paísorigen == "ESLOVAQUIA"
replace eu = 1 if paísorigen == "SUECIA"
replace eu = 1 if paísorigen == "CROACIA"

* Drop redundant variables
drop promptorigenprocedencia paísorigen

* --- Exports
rename valorfobdólar exports
rename HTScode nandina_all
rename paísprocedenciadestino country

gen weight = . 
order nandina_all date exports 

* --- Format variables
format exports %12.2f
format weight %12.0g

label var nandina_all "NANDINA 2007 code"
label var date "Date"
label var weight "Exports (in metric tons)"
label var exports "Exports (USD)"
label var country "Country of destination"
label var eu "European Union Country"
label var FirmsID "RUC"
label var year "Year"
label var month "Month"

order year month date nandina_all FirmsID country eu exports
sort date nandina_all exports

* -- Real values
preserve
    use "$enemdus/real_exchange_rate_index.dta", clear

    keep year Base2018
    rename Base2018 rexrai

    tempfile real_exchange_rate
    save `real_exchange_rate'
restore

merge m:1 year using `real_exchange_rate', keep(3) nogen
gen r_exports = exports / rexrai * 100 // Real dollars
order r_exports, after(exports)

label var r_exports "Exports in 2018 USD"
label var rexrai "Real exchange rate index (Base 2018)"

* -- Save the exports dataset
save "$tariffs_data/dta/raw_data/aux_Exports_RUC_2000m1_2023m12.dta", replace

* -- USD to EUR 
preserve
    import delimited "$tariffs_data/excel/exchange_rate_dollar_eur.csv", clear

    rename date temp
    
    gen date = date(temp, "YMD")
    format date %td

    rename usdollareuroexrdusdeursp00a exchange_rate

    gen date_month = month(date)
    gen date_year = year(date)

    collapse (mean) exchange_rate, by(date_month date_year)

    label var exchange_rate "Exchange rate (USD to EUR)"

    gen date = ym(date_year, date_month)
    format date %tm
    drop date_month date_year
    order date exchange_rate

    tempfile exchange_rate
    save `exchange_rate'
restore

* -- Merge exchange rate
merge m:1 date using `exchange_rate', keep(3) nogen

rename exchange_rate usd_to_eur
label var usd_to_eur "Exchange rate (USD to EUR)"

* -- For this analysis we use the exports from 2012 onwards
keep if year >= 2012 & year <= 2023

tempfile exports_2012_2023
save `exports_2012_2023'



/* From weight and value of exports we need to compute the effective tariff
   We will use a user-written command to do this. But first we need to clean
   the database with the nandina codes, base rates and categories. 
   The database with RUC var doesn't have the weight of exports, so we will
   only be able to compute ad-valorem tariffs.                            */

use "$tariffs_data/dta/raw_data/export_tariffs.dta", clear

drop description
rename CN_2007 nandina_all

label var nandina_all "NANDINA 2007 code"
label var base_rate "Base rate"
label var category "Category"

* -- Normalize strings
foreach var of varlist base_rate category {
    replace `var' = ustrupper(ustrregexra(ustrnormalize(`var', "nfd"), "\p{Mark}", ""))
    replace `var' = subinstr(`var', char(10), " ", .) // Remove line breaks
    replace `var' = subinstr(`var', ",", ".", .)
}

replace nandina_all = ustrregexra(nandina_all, "\s+", "")
replace nandina_all = nandina_all + "00"

* -- Special cases
replace base_rate = "SECTION A OF APPENDIX 2 OF ANNEX I" if base_rate == "SECTION A OF APPEN­ DIX 2 OF ANNEX I" 
replace base_rate = "0.4 EUR/100 KG/1 % OF SUCROSE BY WEIGHT INCLUDING OTHER SUGARS EXPRESSED AS SUCROSE" if base_rate == "0.4 EUR/100 KG/1 % OF SUCROSE BY WEIGHT INCLUDING OTHER SU­ GARS EXPRESSED AS SU­ CROSE"

* --- Type of base rates
gen tariff_type = .

replace tariff_type = 1 if regexm(base_rate, "^[0-9]+(\.[0-9]+)?$") // pure ad valorem 
replace tariff_type = 2 if regexm(base_rate, "^[0-9]+(\.[0-9]+)? \+ [0-9\.]+ EUR/ ?100 KG/ ?NET") // ad valorem + specific per 100 KG NET
replace tariff_type = 3 if regexm(base_rate, "^[0-9\.]+ EUR/ ?100 KG/ ?NET$") // specific only per 100 KG NET
replace tariff_type = 4 if regexm(base_rate, "^[0-9\.]+ EUR/HL$") // specific only per HL
replace tariff_type = 5 if regexm(base_rate, "^[0-9\.]+ \+ [0-9\.]+ EUR/HL") // ad valorem + specific per HL
replace tariff_type = 6 if regexm(base_rate, "EUR/T") // specific per metric ton
replace tariff_type = 7 if regexm(base_rate, "EA") // contains "EA" (tariff equivalent)
replace tariff_type = 8 if regexm(base_rate, "MIN") & regexm(base_rate, "MAX") & (regexm(base_rate, "100 KG/ ?NET") | regexm(base_rate, "100 KG NET")) // conditional MIN/MAX (per 100kg net)
replace tariff_type = 9 if regexm(base_rate, "AD") // includes anti-dumping or additional duties
replace tariff_type = 10 if regexm(base_rate, "SUCROSE") // sugar content–based
replace tariff_type = 11 if inlist(upper(base_rate), "FREE", "SECTION A OF APPENDIX 2 OF ANNEX I") // exempt or zero tariff
replace tariff_type = 12 if regexm(base_rate, "TOT\.? ALC\.?") // specific per kg of total alcohol
replace tariff_type = 13 if regexm(base_rate, "EUR/KG") & regexm(base_rate, "\+ [0-9\.]+ EUR/ ?100 KG/ ?NET") // Specific per KG + specific per 100kg
replace tariff_type = 14 if regexm(base_rate, "EUR/% VOL/HL") // Specific per % alcohol volume per HL
replace tariff_type = 15 if regexm(base_rate, "EUR/% VOL/HL \+ [0-9\.]+ EUR/HL") // Specific per % alcohol volume + HL
replace tariff_type = 16 if regexm(base_rate, "EUR/1 000 KG") // Specific per 1000 kg
replace tariff_type = 17 if regexm(base_rate, "EUR/100 M") // Specific per 100 meters
replace tariff_type = 18 if regexm(base_rate, "EUR/100 KG/ NET MAS") // Specific per 100kg with MAS (special clause)
replace tariff_type = 19 if regexm(base_rate, "MIN") & regexm(base_rate, "MAX") & ///
    (regexm(base_rate, "P/ST") | regexm(base_rate, "P/ ST"))  // conditional thresholds (MIN/MAX by piece)
replace tariff_type = 20 if regexm(base_rate, "MIN") & !regexm(base_rate, "MAX") & (regexm(base_rate, "100 KG/ ?NET") | regexm(base_rate, "100 KG NET")) // conditional MIN (per 100kg net)
replace tariff_type = 21 if !regexm(base_rate, "MIN") & regexm(base_rate, "MAX") & regexm(base_rate, "\+") & (regexm(base_rate, "100 KG/ ?NET") | regexm(base_rate, "100 KG NET")) // conditional MAX (per 100kg net)
replace tariff_type = 22 if regexm(base_rate, "MIN") & regexm(base_rate, "KG/BR") // conditional MIN (per gross kgs)
replace tariff_type = 23 if regexm(base_rate, "MAX") & regexm(base_rate, "EUR/M2") // conditional MAX (per square meter)

label define tariff_type /*
    */  1 "Ad valorem only" /*
    */  2 "Ad valorem + specific (100kg)" /*
    */  3 "Specific only (100kg)" /*
    */  4 "Specific only (HL)" /*
    */  5 "Ad valorem + specific (HL)" /*
    */  6 "Specific per metric ton" /*
    */  7 "Includes EA clause" /*
    */  8 "Conditional thresholds (per 100kg net)" /*
    */  9 "Includes anti-dumping or additional duties" /*
    */ 10 "Sugar content-based" /*
    */ 11 "Exempt or zero tariff" /*
    */ 12 "Specific per total alcohol (kg)" /*
    */ 13 "Specific per kg + specific per 100kg" /*
    */ 14 "Specific per % alcohol volume per HL" /*
    */ 15 "Specific per % alcohol volume + HL" /*
    */ 16 "Specific per 1000 kg" /*
    */ 17 "Specific per 100 meters" /*
    */ 18 "Specific per 100kg with MAS (special clause)" /*
    */ 19 "Conditional thresholds (MIN/MAX by piece)" /*
    */ 20 "Conditional MIN (per 100kg net)" /*
    */ 21 "Conditional MAX (per 100kg net)" /*
    */ 22 "Conditional MIN (per gross kgs)" /*
    */ 23 "Conditional MAX (per square meter)" 

label values tariff_type tariff_type

* --- Type of category
egen category_id = group(category), label

/* The final categories are:
    1    0
    2    0+EP
    3    0/5+EP
    4    0’
    5    10
    6    3
    7    5
    8    7
    9    AV0
    10   AV0-3
    11   AV0-5
    12   AV0-7
    13   AV0-TQ (MM)
    14   AV0-TQ (SC1)
    15   AV0-TQ (SC2)
    16   AV0-TQ(SP)
    17   SP 1
    18   TQ(MZ)
    19   TQ(GC)
    20   TQ(MC)
    21   TQ(MZ)
    22   TQ(RI)
    23   TQ(RM)
    24   TQ(SP)
    25   TQ(SR)
    26   —     
*/

label var category_id "Tax relief category"
label var tariff_type "Type of tariff rate"

* -- Save this new harmonized dataset
duplicates drop nandina_all, force
save "$tariffs_data/dta/raw_data/export_tariffs_clean.dta", replace

* --- Merge exports value and weight with tariffs
use `exports_2012_2023', clear

merge m:1 nandina_all using "$tariffs_data/dta/raw_data/export_tariffs_clean.dta", gen(merge1) 
drop if merge1 == 2

tempfile exports_full
save `exports_full'

/* 
   After merging the export records from Competition with the tariff relief 
   schedule, any products that did not match correspond to lines not covered 
   by the FTA preferential treatment. These unmatched products must 
   therefore be subject to the standard EU MFN (most-favoured-nation) tariff. 
   
   The next step is to assemble a dataset containing those MFN rates for the 
   non-preferential products.
*/

foreach t of numlist 1993/2012 2014/2023 {
    import delimited "$tariffs_data/excel/MFN Tariffs/ECU_`t'.CSV", stringcols(4) clear 

    /*
        We use `simpleaverage` as the MFN tariff rate because it reflects the 
        unweighted mean of all applicable ad valorem rates for the HS code. 
        This provides a reasonable benchmark in the absence of 
        transaction-level tariff line details. Unlike `min_rate` or `max_rate`,
        it avoids extreme values and offers a balanced representation of the 
        MFN regime.
    */

    keep year productcode simpleaverage

    replace productcode = "0" + productcode if strlen(productcode) < 6 // Ensure 6-digit code

    replace productcode = ustrregexra(productcode, "\s+", "")

    rename productcode nandina_all
    rename simpleaverage mfn_rate

    tempfile mfn_`t'
    save `mfn_`t''
}

* -- Append all MFN rates by year
use `mfn_1993', clear

foreach t of numlist 1994/2012 2014/2023 {
    append using `mfn_`t''
}

sort year nandina_all 

label var nandina_all "NANDINA 2007 code"
label var mfn_rate "MFN tariff rate (ad valorem)"
label var year "Year"

tempfile mfn_rates
save `mfn_rates'

* --- Merge MFN rates with exports
use `exports_full', clear

keep if merge1 == 1 

clonevar nandina_10d = nandina_all

replace nandina_all = substr(nandina_all, 1, 6) 

merge m:1 nandina_all year using `mfn_rates'
drop if _merge == 2
drop _merge

replace nandina_all = nandina_10d
drop nandina_10d

tempfile mfn_codes
save `mfn_codes'

use `exports_full', clear
drop if merge1 == 1 
append using `mfn_codes'

replace mfn_rate = 0 if tariff_type == . & mfn_rate == . & year == 2013

/* Since we don't have the info on the MFN from 2024 onwards, we restrict the
dataset until 2023.  */
keep if year < 2024
drop merge1

order nandina_all year date
sort date nandina_all exports

/* Now, with the full dataset, we can compute the value of the effective tariff
paid by exports to Europe, we will use a user-written command:    */

* -- For products on the FTA
etariff if eu == 1, base_rate(base_rate) category_id(category_id) date(date) tariff_type(tariff_type) value(r_exports) weight(weight) exchange_rate(usd_to_eur)
* -- For products not on the FTA, we compute the effective tariff using the MFN rate
replace tariff_paid = r_exports * mfn_rate / 100 if tariff_type == . & mfn_rate != . & eu == 1
drop if exports == 0 

format tariff_paid %12.2f

* -- For Non-EU countries we don't know the info
replace tariff_paid = . if eu == 0
replace base_rate = "" if eu == 0
replace category = "" if eu == 0
replace category_id = . if eu == 0
replace tariff_type = . if eu == 0

* -- Problems with applied tariffs due to weight been larger than value
replace tariff_paid = . if tariff_paid > r_exports

order date year month nandina_all FirmsID country eu exports r_exports weight tariff_paid tariff_type category_id mfn_rate desgrav_period months_since_start rel_year base_rate category rexrai

sort date eu nandina_all

save "$tariffs_data/dta/working_data/Exports_etariff.dta", replace 
