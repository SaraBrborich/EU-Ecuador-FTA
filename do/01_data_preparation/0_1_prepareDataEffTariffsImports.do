/*==============================================================================
  PREPARE EFFECTIVE TARIFFS FOR IMPORTS
  Project: EU-Ecuador-FTA
  Software: Stata 17
==============================================================================*/

version 17.0
set more off

/* From the pdf 'EUAndesFTAAgreement' we extract the import goods tariffs, we
have the NANDINA 2007 code, the product description, the tariff code and the
category (in the file 'categories_import_goods_meaning.xlsx' are the meanings of
the different categories). Also, the export goods tariffs, with the CN 2007
code, the product description, the base rate, and the category.

The data from this textscraping is then exported to the following files:
- 'export_goods_tariffs.xlsx'
- 'import_goods_tariffs.xlsx'

The raw data is then imported into Stata:
- 'import_tariffs.dta'
- 'export_tariffs.dta'

This do-file generates the monthly statutory tariff matched to import transactions. */

/*------------------------------------------------------------------------------
--- IMPORT TARIFFS DATASET 
------------------------------------------------------------------------------*/

use "$tariffs_data/dta/raw_data/import_tariffs.dta", clear

* --- Setup variables ----------------------------------------------------------

/* --- Products ID: the tariff reduction schedule is performed at different 
levels of aggregation. For merging purposes, we need to separate each 
aggregation level in different variables. */
rename NANDINA_2007 nandina_all
replace nandina_all = "0" + nandina_all if strlen(nandina_all) == 7

gen temp = strlen(nandina_all)
local digits = "4 7 8 9 10"
foreach i of local digits {
	gen nandina_code_`i'd = nandina_all if temp == `i'
}

order nandina_code_*, after(nandina_all)
drop temp

/* --- Base rate: this is the initial tariff from which the reduction begins. 
Most of the observations in the dataset are numeric. At this stage, I separate
these values to have a first version. */

replace base_rate = "20" if base_rate == "20(*)"
replace base_rate = "31.5" if base_rate == "31,5"

gen temp = strlen(base_rate)
gen temp_rate = base_rate if temp <= 4
replace temp_rate = "" if temp_rate == "MEP"
destring temp_rate, replace

gen base_rate_num = temp_rate / 100
replace base_rate_num = . if base_rate == ""

order base_rate_num, after(base_rate)
drop temp*

/* From 7282 observations in the dataset, 7162 were suitable to direct transformation
to numeric values. These represent 97.6% of the entire registry. We need to 
check this, however, because it seems that the text-scrapping algorithm is 
mixing up the rate and the description columns of the document. */

* --- Category
gen temp = strlen(category)
replace category = "10" if temp == 5

gen category_num = .
local cats = "0 3 5 7 10 15"
foreach x of local cats {
	replace category_num = `x' if category == "`x'"
}

replace category_num = . if category == ""
order category_num, after(category)
drop temp

/* From 7282 observations, 7093 categories were suitable to direct transformation 
to numeric values. 

Without further work, we have coverage for 7016 subheadings, which represent 96%
of the universe of subheadings in the document. */

* --- PANEL WITH TARIFFS -------------------------------------------------------

* --- Keep observations without missing values 
keep if (base_rate_num != . & category_num != .)

local total_observations : di _N

tempfile data
save `data'

* --- Take each observation, expand 16 years and create the tariff for each year
forval i = 1/`total_observations' {
    use `data', clear
    
    keep in `i'
    expand 16
    gen year = 2016 + floor(_n - 1)
    
	* --- For products with different periods of tariff discounting
    if category_num > 0 {
        gen tariff = 0
		
		* --- Discount rate and tracking var to check consistency
        gen temp = base_rate_num/category_num
        gen i = _n
        
		/*--- Tariff construction, starting with the base rate and diminishing 
            over time ------------------------------------------------------*/
        local s = category_num
        forval j = 1/`s' {        
            replace  tariff = base_rate_num - ((`j'-1) * temp) if _n == `j'
        }         
    }
	
	* --- For products with immediate tariff discount
    else {
        gen i = _n
		
		* --- Tariff in period 1 
		gen tariff = 0
		replace tariff = base_rate_num if i == 1
    }
    
	* --- Save the current file 
    tempfile obs`i'    
    save `obs`i'', replace
}

* --- Append each database
use `obs1', clear
forval i = 2/`total_observations' {
    append using `obs`i''
}

* --- Drop unnecessary vars
drop base_rate category i temp category_num

* --- Drop duplicates from panel
duplicates tag year nandina_all, gen(zero)
drop if zero == 1 & tariff == 0

duplicates drop nandina_all year, force
drop zero

tempfile data_p16
save `data_p16'

* --- Expand tariffs panel from 2016 to 2012
forval i = 1/`total_observations' {
    use `data', clear
    
    keep in `i'
    expand 4
    gen year = 2012 + floor(_n - 1)

    gen tariff = base_rate_num

    * --- Save the current file 
    tempfile 1obs`i'    
    save `1obs`i'', replace
    
}

use `data_p16', clear
* --- Append each database
forval i = 1/`total_observations' {
    append using `1obs`i''
}

sort year

* --- Make database into monthly frequency -------------------------------------
* -- Monthly range
gen m1 = ym(year, 1)
gen nmonths = 12
expand nmonths

* -- Number of months inside each year 
bysort nandina_all year (m1): gen month_index = _n

gen month = ym(year, month_index)
format month %tm

drop m1 month_index nmonths

* -- Reference month
gen year_month = year(dofm(month))

gen date = month 
format date %tm

drop base_rate_num category_num year_month month
order year date nandina_all tariff 

tempfile tariffs_panel
save `tariffs_panel'

* --- Make all nandina codes 10-digit
replace nandina_all = nandina_all + "0" if strlen(nandina_all) == 9
replace nandina_all = nandina_all + "00" if strlen(nandina_all) == 8

* --- Drop unnecessary vars
drop nandina_code_*

sort nandina_all date
order nandina_all date tariff 

replace tariff = tariff * 100

* --- Label variables
label var nandina_all "NANDINA 2007 code"
label var date "Date"

tempfile imports_tariffs_10d
save `imports_tariffs_10d'

* --- Merge with IDBCompetition data to have effective tariffs
preserve
    use "$competition_data/0_allImportsData_bycountry.dta", clear

    * --- Eliminate unnecessary information
    keep año nummes nandina valorfobdólar paísorigen códigoidentificación 

    rename año year
    rename nummes month

    * --- Date var
    gen date = ym(year, month)
    format date %tm 
    order date

    * --- Fix HTS code
    format nandina %21.0g
    tostring nandina, gen(HTScode)
    gen temp = strlen(HTScode)
    gen zeros = "0"
    egen temp2 = concat(zeros HTScode) if temp == 9
    replace HTScode = temp2 if temp == 9
    drop temp* zeros
    drop nandina
    drop if HTScode == "-998" | HTScode == "-999"

    * --- Indentify firms
    rename códigoidentificación temp_ID
    replace temp_ID = trim(temp_ID)
    gen temp = strlen(temp_ID)
    gen zeros = "0"
    egen temp2 = concat(zeros temp_ID)
    gen FirmsID = temp_ID if temp == 13
    replace FirmsID = temp2 if temp == 12
    drop if FirmsID == ""
    drop temp* zeros

    * --- Identify countries from the EU
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

    /* This dataset is missing the last trimester of 2022, so we will append it
    manually  */

    tempfile imports_competition
    save `imports_competition'

    import excel "$tariffs_data/imports_new/03. Export. o Import. por Subpartida y País_BK.xlsx", sheet("Columnas") cellrange(B7) firstrow allstring clear case(lower)

    drop j subpartida

    rename códigosubpartida HTScode

    * -- Date var
    gen year = real(substr(período, 1, 4))
    gen month = real(substr(período, 8, 2))

    gen date = ym(year, month)
    format date %tm
    drop período month year

    destring fob, gen(valorfobdólar)
    replace valorfobdólar = valorfobdólar * 1000 // Thousands of USD
    drop fob

    sort date HTScode

    * -- HTS code
    gen FirmsID = ""
    label var FirmsID "RUC"

    * -- Countries codes, only keep EU (27)
    replace códigopaísorigen = trim(códigopaísorigen)
    replace paísorigen = trim(paísorigen)

    gen eu = 0
    replace eu = 1 if inlist(códigopaísorigen, /* 
    */ "AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN") /* 
    */ | inlist(códigopaísorigen, /* 
    */ "FRA", "DEU", "GRC", "HUN", "IRL", "ITA", "LVA", "LTU", "LUX") /* 
    */ | inlist(códigopaísorigen, /* 
    */"MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE") /* 
    */ | inlist(códigopaísorigen, "GBR")
    label var eu "European Union Country"

    drop códigopaísorigen

    append using `imports_competition'

    keep if date >= tm(2012m1)

    * --- Rename and label vars
    rename valorfobdólar importsTotal
    rename HTScode nandina_all
    
    label var importsTotal "Total Imports"
    label var nandina_all "NANDINA 2007 code"
    label var date "Date"
    label var FirmsID "RUC"

    * --- Drop observations that contain no relevant info
    drop if paísorigen == "SIN ESTADISTICAS" | paísorigen == "NO DEFINIDO"
    rename paísorigen country
    label var country "Country of origin" 

    tempfile imp_comp
    save `imp_comp'
restore

merge 1:m date nandina_all using `imp_comp' 

drop if _merge == 1 
drop _merge tmpesoneto cif
drop if date >= tm(2024m1)

* --- Rename and label variables
rename importsTotal imports

label var imports "Total imports"
label var base_rate "Base rate"
label var category "Category of tariff reduction"

* -- Real values
preserve
    use "$enemdus/real_exchange_rate_index.dta", clear

    keep year Base2018
    rename Base2018 rexrai

    tempfile real_exchange_rate
    save `real_exchange_rate'
restore

replace year = year(dofm(date))
label var year "Year"

merge m:1 year using `real_exchange_rate', keep(3) nogen

* -- Variables in 2018 USD
gen r_imports = imports / rexrai * 100
gen tariff_paid = .
replace tariff_paid = r_imports * tariff / 100 if eu == 1

drop month
gen month = month(dofm(date))

label var tariff "Ad-valorem tariff"
label var tariff_paid "Effective tariff paid by imports from EU"
label var r_imports "Imports in 2018 USD"
label var month "Month"
label var rexrai "Real exchange rate index (Base 2018)"

order date year month nandina_all FirmsID country eu imports r_imports tariff_paid base_rate category rexrai

save "$tariffs_data/dta/working_data/Imports_etariff.dta", replace 
