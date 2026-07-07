/*==============================================================================
  DESCRIPTIVE FIGURES USED IN THE BOOK CHAPTER
  Outputs: five PDF figures and aggregated Excel source files
  Software: Stata 17
==============================================================================*/

version 17.0
set more off
frames reset 
set scheme s1color
* --- Define frames ------------------------------------------------------------

use "$tariffs_data/dta/working_data/Exports_etariff.dta", clear 

drop if year == 2012 | year == 2022
replace year = 2022 if year == 2023
replace date = ym(2022, month(dofm(date))) if year == 2022

frame rename default exports

frame create imports
frame change imports
use "$tariffs_data/dta/working_data/Imports_etariff.dta", clear

drop if year == 2012 | year == 2022
replace year = 2022 if year == 2023
replace date = ym(2022, month(dofm(date))) if year == 2022

* --- Trade balance ------------------------------------------------------------
* --- Total exports to EU
frame change exports 
preserve
    keep if eu == 1
    keep date FirmsID r_exports

    collapse (sum) r_exports , by(date)
    replace r_exports = r_exports / 1000000

    gen month = month(dofm(date))

    * --- Filter Seasonality (HP)
    tsset date

    // Trend
    tsfilter hp hp_r_exports = r_exports, smooth(14400) trend(trend_r_exports)

    // Cycle
    gen cycle_r_exports = r_exports - trend_r_exports

    // Adjustment
    reg cycle_r_exports i.month 
    predict cycle_r_exports_sa, resid 

    gen sa_r_exports = trend_r_exports + cycle_r_exports  

    tempfile tot_exp 
    save `tot_exp'
restore

frame change imports
* --- Total imports from EU
preserve
    keep if eu == 1
    keep date FirmsID r_imports

    drop if FirmsID == ""

    collapse (sum) r_imports , by(date)
    replace r_imports = r_imports / 1000000

    gen month = month(dofm(date))

    sort date
    gen fake_month = _n

    * --- Filter Seasonality (HP)
    tsset fake_month

    // Trend
    tsfilter hp hp_r_imports = r_imports, smooth(14400) trend(trend_r_imports)

    // Cycle
    gen cycle_r_imports = r_imports - trend_r_imports

    // Adjustment
    reg cycle_r_imports i.month 
    predict cycle_r_imports_sa, resid 

    gen sa_r_imports = trend_r_imports + cycle_r_imports  

    tempfile tot_imp 
    save `tot_imp'
restore

* -- Trade balance, freq: monthly
preserve 
    use `tot_exp', clear 

    merge 1:1 date using `tot_imp'

    collapse (sum) r_exports = sa_r_exports r_imports = sa_r_imports, by(date)

    gen trade_bal = r_exports - r_imports

    label var r_exports "Exports"
    label var r_imports "Imports"
    label var trade_bal "Trade Balance"

    format r_exports %12.0g
    format r_imports %12.0g

    tsset date 

    replace date = ym(2023, month(dofm(date))) if year(dofm(date)) == 2022
    tsfill

    preserve
        gen date_excel = dofm(date)
        format date_excel %td
        keep date date_excel r_exports r_imports trade_bal
        export excel using "$eulas_figuredata/Figure1_trade_balance_data.xlsx", ///
            firstrow(variables) replace
    restore

    twoway (line r_exports date if date < tm(2022m1) , yaxis(1) lcolor(blue) lwidth(0.15)) /*
        */ (line r_exports date if date > tm(2022m1) , yaxis(1) lcolor(blue) lwidth(0.15)) /*
        */	(line r_imports date if date < tm(2022m1), yaxis(1) lcolor(red) lwidth(0.15)) /*
        */	(line r_imports date if date > tm(2022m1), yaxis(1) lcolor(red) lwidth(0.15)) /*
        */  (bar trade_bal date if date < tm(2022m1), yaxis(2) barwidth(0.8) fcolor(gray%30) lcolor(gray%1))  /*
        */  (bar trade_bal date if date > tm(2022m1), yaxis(2) barwidth(0.8) fcolor(gray%30) lcolor(gray%1)) , /*
        */	yline(0, axis(2) lcolor(black) lp(solid) lw(0.11)) /*
        */	title("") xtitle("") /*
        */	ytitle("Millions of 2018 USD", axis(1) size(vsmall)) /*
        */	ytitle("Trade balance (USD)", axis(2) size(vsmall)) /*
        */	tlabel(2013m1(6)2023m12, angle(45)) /*
        */	legend(order(1 "Exports" 3 "Imports" 5 "Trade Balance") cols(3)) /*
        */	graphregion(color(white)) /*
        */	ylabel(#9, nogrid labsize(vsmall)) /*
        */  ylabel(-200(100)200, axis(2) labsize(vsmall)) /*
        */	name(trade_bal, replace)
    graph export "$eulas_plots/Figure1_trade_balance.pdf", as(pdf) replace
restore

* --- Avrg trade partners, wrt total partners ----------------------------------
frame change exports 
preserve
    keep date FirmsID country eu r_exports

    collapse (sum) r_exports if eu == 1, by(date FirmsID country)

    gen counter = 1

    collapse (sum) counter, by(date FirmsID)
    collapse (mean) counter, by(date)

    gen month = month(dofm(date))

    * --- Filter Seasonality (HP)
    tsset date

    // Trend
    tsfilter hp hp_firms = counter, smooth(14400) trend(trend_firms)

    // Cycle
    gen cycle_firms = counter - trend_firms

    // Adjustment
    reg cycle_firms i.month 
    predict cycle_firms_sa, resid 

    gen sa_firms = trend_firms + cycle_firms_sa
    rename sa_firms sa_firms_eu
    gen eu = 1

    keep date eu sa_firms_eu

    tempfile n_tradepartners_exp
    save `n_tradepartners_exp'
restore
preserve
    keep date FirmsID country eu r_exports

    collapse (sum) r_exports, by(date FirmsID country eu)

    gen counter = 1

    collapse (sum) counter, by(date FirmsID eu)
    collapse (mean) counter, by(date eu)

    gen month = month(dofm(date))

    * --- Filter Seasonality (HP)
    xtset eu date

    // Trend
    tsfilter hp hp_firms = counter, smooth(14400) trend(trend_firms)

    // Cycle
    gen cycle_firms = counter - trend_firms

    // Adjustment
    reg cycle_firms i.month 
    predict cycle_firms_sa, resid 

    gen sa_firms = trend_firms + cycle_firms_sa

    bysort date: egen total_f = total(sa_firms)
	bysort date eu: egen eu_f = total(sa_firms) 

	bysort date eu: gen share = eu_f/total_f * 100

    merge 1:1 date eu using `n_tradepartners_exp'

    keep if eu == 1
    keep sa_firms_eu share date 
    gen exp = 1

    tempfile exp_1 
    save `exp_1'
restore

frame change imports 
preserve
    keep date FirmsID country eu r_imports

    collapse (sum) r_imports if eu == 1, by(date FirmsID country)

    gen counter = 1

    collapse (sum) counter, by(date FirmsID)
    collapse (mean) counter, by(date)

    gen month = month(dofm(date))

    * --- Filter Seasonality (HP)
    tsset date

    // Trend
    tsfilter hp hp_firms = counter, smooth(14400) trend(trend_firms)

    // Cycle
    gen cycle_firms = counter - trend_firms

    // Adjustment
    reg cycle_firms i.month 
    predict cycle_firms_sa, resid 

    gen sa_firms = trend_firms + cycle_firms_sa
    rename sa_firms sa_firms_eu
    gen eu = 1

    keep date eu sa_firms_eu

    tempfile n_tradepartners_imp
    save `n_tradepartners_imp'
restore
preserve
    keep date FirmsID country eu r_imports

    collapse (sum) r_imports, by(date FirmsID country eu)

    gen counter = 1

    collapse (sum) counter, by(date FirmsID eu)
    collapse (mean) counter, by(date eu)

    gen month = month(dofm(date))

    * --- Filter Seasonality (HP)
    xtset eu date

    // Trend
    tsfilter hp hp_firms = counter, smooth(14400) trend(trend_firms)

    // Cycle
    gen cycle_firms = counter - trend_firms

    // Adjustment
    reg cycle_firms i.month 
    predict cycle_firms_sa, resid 

    gen sa_firms = trend_firms + cycle_firms_sa

    bysort date: egen total_f = total(sa_firms)
	bysort date eu: egen eu_f = total(sa_firms) 

	bysort date eu: gen share = eu_f/total_f * 100

    merge 1:1 date eu using `n_tradepartners_imp'

    keep if eu == 1
    keep sa_firms_eu share date 
    gen exp = 0

    tempfile imp_1 
    save `imp_1'
restore

frame create temp 
frame change temp
    use `exp_1', clear 
    append using `imp_1'

    label define exp 1 "Exports" 0 "Imports"
    label values exp exp

    xtset exp date

    replace date = ym(2023, month(dofm(date))) if year(dofm(date)) == 2022
    tsfill

    preserve
        gen date_excel = dofm(date)
        format date_excel %td
        keep exp date date_excel sa_firms_eu share
        export excel using "$eulas_figuredata/Figure4b_partner_countries_data.xlsx", ///
            firstrow(variables) replace
    restore

    twoway (line sa_firms_eu date if date < tm(2022m1), yaxis(1) lcolor(blue) /*
    */ lpattern(solid) lwidth(0.15)) (line sa_firms_eu date if date > tm(2022m1), /*
    */ yaxis(1) lcolor(blue) lpattern(solid) lwidth(0.15) legend(off)) (line share date if date < tm(2022m1), /*
    */ yaxis(2) lcolor(red%90) lpattern(--) lwidth(0.08)) (line share date if date > tm(2022m1), /*
    */ yaxis(2) lcolor(red%90) lpattern(--) lwidth(0.08) legend(off)), /*
    */ by(exp, cols(2) note("") r1title("Share (%)")) /*
    */ title("") /*
    */ ytitle("Number of trade partners") /*
    */ xtitle("") /*
    */ legend(order(1 "Trade partners (left)" 3 "Share wrt total number of trade partners") /*
    */ size(2.2) region(lcolor(black) lw(0.20) fcolor(none)) cols(2) symxsize(4.5)) /*
    */ graphregion(color(white)) /*
    */ name(n_share_EUtradepartners, replace) /*
    */ tline(2017m1, lcolor(red) lwidth(0.15) lstyle(solid)) /*
    */ tline(2014m7, lcolor(black) lwidth(0.15) lstyle(solid)) /*
    */ tlabel(2013m1(9)2023m12, angle(45)) /*
    */ ylabel(#9, nogrid labsize(small))
    graph export "$eulas_plots/Figure4b_partner_countries.pdf", as(pdf) replace


* --- Total varieties ----------------------------------------------------------
frame change exports
* --- Total and share of products exported to EU
preserve
    keep date nandina_all eu
    
    gen product = 1

    encode nandina_all, gen(prod_code)

    collapse (sum) product, by(date prod_code eu)
    collapse (count) product, by(date eu)

    gen month = month(dofm(date))

    * --- Filter Seasonality (HP)
    xtset eu date

    // Trend
    tsfilter hp hp_product = product, smooth(14400) trend(trend_product)

    // Cycle
    gen cycle_product = product - trend_product

    // Adjustment
    reg cycle_product i.month 
    predict cycle_product_sa, resid 

    gen sa_product = trend_product + cycle_product_sa   

	bysort date: egen total_p = total(sa_product)
	bysort date eu: egen eu_p = total(sa_product) 

	bysort date eu: gen share = eu_p/total_p * 100

    keep if eu == 1
    keep sa_product share date 
    gen exp = 1

    tempfile products_exp1
    save `products_exp1'
restore

frame change imports
* --- Total and share of products imported from EU
preserve
    keep date nandina_all eu
    
    gen product = 1

    encode nandina_all, gen(prod_code)

    collapse (sum) product, by(date prod_code eu)
    collapse (count) product, by(date eu)

    gen month = month(dofm(date))

    * --- Filter Seasonality (HP)
    xtset eu date

    // Trend
    tsfilter hp hp_product = product, smooth(14400) trend(trend_product)

    // Cycle
    gen cycle_product = product - trend_product

    // Adjustment
    reg cycle_product i.month 
    predict cycle_product_sa, resid 

    gen sa_product = trend_product + cycle_product_sa   

	bysort date: egen total_p = total(sa_product)
	bysort date eu: egen eu_p = total(sa_product) 

	bysort date eu: gen share = eu_p/total_p * 100

    keep if eu == 1
    keep sa_product share date 
    gen exp = 0

    tempfile products_imp
    save `products_imp'
restore

frame drop temp
frame create temp 
frame change temp
    use `products_exp1', clear
    append using `products_imp'

    label define exp 1 "Exports" 0 "Imports"
    label values exp exp

    xtset exp date

    replace date = ym(2023, month(dofm(date))) if year(dofm(date)) == 2022
    tsfill

    preserve
        gen date_excel = dofm(date)
        format date_excel %td
        keep exp date date_excel sa_product share
        export excel using "$eulas_figuredata/Figure4a_product_varieties_data.xlsx", ///
            firstrow(variables) replace
    restore

    twoway (line sa_product date if date < tm(2022m1), /*
    */ yaxis(1) lcolor(blue) lpattern(solid) lwidth(0.15)) (line sa_product date if date > tm(2022m1), /*
    */ yaxis(1) lcolor(blue) lpattern(solid) lwidth(0.15) legend(off)) (line share date if date < tm(2022m1), /*
    */ yaxis(2) lcolor(red%90) lpattern(--) lwidth(0.08)) (line share date if date > tm(2022m1), /*
    */ yaxis(2) lcolor(red%90) lpattern(--) lwidth(0.08) legend(off)), /*
    */ by(exp, cols(2) note("") r1title("Share (%)")) /*
    */ title("") /*
    */ ytitle("Number of varieties") /*
    */ xtitle("") /*
    */ legend(order(1 "Number of varieties (left)" 3 "Share wrt total number of varieties") /*
    */ size(2.2) region(lcolor(black) lw(0.20) fcolor(none)) cols(2) symxsize(4.5)) /*
    */ graphregion(color(white)) /*
    */ name(n_share_products, replace) /*
    */ tline(2017m1, lcolor(red) lwidth(0.15) lstyle(solid)) /*
    */ tline(2014m7, lcolor(black) lwidth(0.15) lstyle(solid)) /*
    */ tlabel(2013m1(9)2023m12, angle(45)) /*
    */ ylabel(#9, nogrid labsize(small))
    graph export "$eulas_plots/Figure4a_product_varieties.pdf", as(pdf) replace

    graph combine n_share_products n_share_EUtradepartners, rows(2) ///
        graphregion(color(white)) name(figure4_combined, replace)
    graph export "$eulas_plots/Figure4_product_partner_diversification.pdf", as(pdf) replace

* --- Avrg varieties by firm ---------------------------------------------------
frame change exports
preserve 
    keep if eu == 1
    keep date FirmsID nandina_all 

    gen product = 1

    encode nandina_all, gen(prod_code)
    encode FirmsID, gen(firm_code)

    collapse (sum) product, by(date firm_code)
    collapse (mean) product, by(date)

    gen month = month(dofm(date))

    * --- Filter Seasonality (HP)
    tsset date

    // Trend
    tsfilter hp hp_product = product, smooth(14400) trend(trend_product)

    // Cycle
    gen cycle_product = product - trend_product

    // Adjustment
    reg cycle_product i.month 
    predict cycle_product_sa, resid 

    gen sa_product = trend_product + cycle_product_sa

    keep sa_product date 
    gen exp = 1
    
    tempfile prod_per_firm_exp
    save `prod_per_firm_exp'
restore

frame change imports 
preserve 
    keep if eu == 1
    keep date FirmsID nandina_all 

    drop if FirmsID == ""

    gen product = 1

    encode nandina_all, gen(prod_code)
    encode FirmsID, gen(firm_code)

    collapse (sum) product, by(date firm_code)
    collapse (mean) product, by(date)

    gen month = month(dofm(date))

    sort date
    gen fake_month = _n

    * --- Filter Seasonality (HP)
    tsset fake_month

    // Trend
    tsfilter hp hp_product = product, smooth(14400) trend(trend_product)

    // Cycle
    gen cycle_product = product - trend_product

    // Adjustment
    reg cycle_product i.month 
    predict cycle_product_sa, resid 

    gen sa_product = trend_product + cycle_product_sa   

    keep sa_product date 
    gen exp = 0

    tempfile prod_per_firm_imp
    save `prod_per_firm_imp'
restore

frame drop temp
frame create temp 
frame change temp
    use `prod_per_firm_exp', clear
    append using `prod_per_firm_imp'

    label define exp 1 "Exports" 0 "Imports"
    label values exp exp

    xtset exp date

    replace date = ym(2023, month(dofm(date))) if year(dofm(date)) == 2022
    tsfill

    preserve
        gen date_excel = dofm(date)
        format date_excel %td
        keep exp date date_excel sa_product
        export excel using "$eulas_figuredata/Figure5_products_per_firm_data.xlsx", ///
            firstrow(variables) replace
    restore

    twoway (line sa_product date if date < tm(2022m1), yaxis(1) lcolor(blue) /*
    */ lpattern(solid) lwidth(0.15) legend(off)) (line sa_product date if date > tm(2022m12), /*
    */ yaxis(1) lcolor(blue) lpattern(solid) lwidth(0.15) legend(off)), /*
    */ by(exp, cols(2) note("")) /*
    */ title("") /*
    */ ytitle("Number of varieties") /*
    */ xtitle("") /*
    */ legend(off) /*
    */ graphregion(color(white)) /*
    */ name(n_products_Firm, replace) /*
    */ tline(2017m1, lcolor(red) lwidth(0.15) lstyle(solid)) /*
    */ tline(2014m7, lcolor(black) lwidth(0.15) lstyle(solid)) /*
    */ tlabel(2013m1(9)2023m12, angle(45)) /*
    */ ylabel(#9, nogrid labsize(small))
    graph export "$eulas_plots/Figure5_products_per_firm.pdf", as(pdf) replace

* --- Total firms and share ----------------------------------------------------
frame change exports 
preserve
    keep date FirmsID eu

    gen firms = 1

    encode FirmsID, gen(firm_code)

    collapse (sum) firms, by(date firm_code eu)
    collapse (count) firms, by(date eu)

    gen month = month(dofm(date))

    * --- Filter Seasonality (HP)
    xtset eu date

    // Trend
    tsfilter hp hp_firms = firms, smooth(14400) trend(trend_firms)

    // Cycle
    gen cycle_firms = firms - trend_firms

    // Adjustment
    reg cycle_firms i.month 
    predict cycle_firms_sa, resid 

    gen sa_firms = trend_firms + cycle_firms_sa

	bysort date: egen total_f = total(sa_firms)
	bysort date eu: egen eu_f = total(sa_firms) 

	bysort date eu: gen share = eu_f/total_f * 100

    keep if eu == 1
    keep sa_firms share date 
    gen exp = 1

    tempfile firms_exp
    save `firms_exp'
restore

frame change imports 
preserve
    keep date FirmsID eu

    drop if FirmsID == ""

    gen firms = 1

    egen firm_code = group(FirmsID)

    collapse (sum) firms, by(date firm_code eu)
    collapse (count) firms, by(date eu)

    gen month = month(dofm(date))

    * --- Filter Seasonality (HP)
    xtset eu date

    // Trend
    tsfilter hp hp_firms = firms, smooth(14400) trend(trend_firms)

    // Cycle
    gen cycle_firms = firms - trend_firms

    // Adjustment
    reg cycle_firms i.month 
    predict cycle_firms_sa, resid 

    gen sa_firms = trend_firms + cycle_firms_sa

	bysort date: egen total_f = total(sa_firms)
	bysort date eu: egen eu_f = total(sa_firms) 

	bysort date eu: gen share = eu_f/total_f * 100

    xtset eu date	

    keep if eu == 1
    keep sa_firms share date 
    gen exp = 0
    
    tempfile firms_imp
    save `firms_imp'
restore

frame drop temp
frame create temp 
frame change temp
    use `firms_exp', clear
    append using `firms_imp'

    label define exp 1 "Exports" 0 "Imports"
    label values exp exp

    xtset exp date

    replace date = ym(2023, month(dofm(date))) if year(dofm(date)) == 2022
    tsfill

    preserve
        gen date_excel = dofm(date)
        format date_excel %td
        keep exp date date_excel sa_firms share
        export excel using "$eulas_figuredata/Figure3_firms_trading_with_EU_data.xlsx", ///
            firstrow(variables) replace
    restore

    twoway (line sa_firms date if date < tm(2022m1), /*
    */ yaxis(1) lcolor(blue) lpattern(solid) lwidth(0.15)) (line sa_firms date if date > tm(2022m1), /*
    */ yaxis(1) lcolor(blue) lpattern(solid) lwidth(0.15) legend(off)) (line share date if date < tm(2022m1), /*
    */ yaxis(2) lcolor(red%90) lpattern(--) lwidth(0.08)) (line share date if date > tm(2022m1), /*
    */ yaxis(2) lcolor(red%90) lpattern(--) lwidth(0.08) legend(off)), /*
    */ by(exp, cols(2) note("") r1title("Share (%)")) /*
    */ title("") /*
    */ ytitle("Number of firms") /*
    */ xtitle("") /*
    */ legend(order(1 "Number of firms (left)" 3 "Share wrt total number of firms") /*
    */ size(2.2) region(lcolor(black) lw(0.20) fcolor(none)) cols(2) symxsize(4.5)) /*
    */ graphregion(color(white)) /*
    */ name(n_share_firms, replace) /*
    */ tline(2017m1, lcolor(red) lwidth(0.15) lstyle(solid)) /*
    */ tline(2014m7, lcolor(black) lwidth(0.15) lstyle(solid)) /*
    */ tlabel(2013m1(9)2023m12, angle(45)) /*
    */ ylabel(#9, nogrid labsize(small))
    graph export "$eulas_plots/Figure3_firms_trading_with_EU.pdf", as(pdf) replace

* -- Average effective tariff paid, as ratio of total value --------------------
* --- Policy changes -----------------------------------------------------------
* --- Exports
* --- Sections HS code from nandina
capture frame drop exports_hs
frame copy exports exports_hs
frame change exports_hs 

gen hs_section = substr(nandina_all, 1, 2)
destring hs_section, replace 

gen section = .
    replace section = 1 if inrange(hs_section, 1, 5)
    replace section = 2 if inrange(hs_section, 6, 14)
    replace section = 3 if inrange(hs_section, 15, 15)
    replace section = 4 if inrange(hs_section, 16, 24)
    replace section = 5 if inrange(hs_section, 25, 27)
    replace section = 6 if inrange(hs_section, 28, 38)
    replace section = 7 if inrange(hs_section, 39, 40)
    replace section = 8 if inrange(hs_section, 41, 43)
    replace section = 9 if inrange(hs_section, 44, 46)
    replace section = 10 if inrange(hs_section, 47, 49)
    replace section = 11 if inrange(hs_section, 50, 63)
    replace section = 12 if inrange(hs_section, 64, 67)
    replace section = 13 if inrange(hs_section, 68, 70)
    replace section = 14 if inrange(hs_section, 71, 71)
    replace section = 15 if inrange(hs_section, 72, 83)
    replace section = 16 if inrange(hs_section, 84, 85)
    replace section = 17 if inrange(hs_section, 86, 89)
    replace section = 18 if inrange(hs_section, 90, 92)
    replace section = 19 if inrange(hs_section, 93, 93)
    replace section = 20 if inrange(hs_section, 94, 96)
    replace section = 21 if inrange(hs_section, 97, 99)

label define section 1 "Live animals; animal products" /*
    */  2 "Vegetable products" /*
    */  3 "Fats and oils" /*
    */  4 "Prepared foodstuffs; beverages; tobacco" /*
    */  5 "Mineral products" /*
    */  6 "Chemical products" /*
    */  7 "Plastics and rubber" /*
    */  8 "Leather, furskins and articles thereof" /*
    */  9 "Wood, cork, manufactures thereof" /*
    */  10 "Pulp, paper, printed matter" /*
    */  11 "Textiles and textile articles" /*
    */  12 "Footwear, headgear, etc." /*
    */  13 "Stone, ceramic, glass" /*
    */  14 "Precious stones and metals" /*
    */  15 "Base metals and articles thereof" /*
    */  16 "Machinery and electrical equipment" /*
    */  17 "Transport equipment" /*
    */  18 "Optical, instruments, clocks, musical instruments" /*
    */  19 "Arms and ammunition" /*
    */  20 "Miscellaneous manufactured articles" /*
    */  21 "Works of art; special transactions"

label values section section

preserve
    keep if eu == 1
    drop if date < tm(2014m1)
    replace tariff_paid = . if mfn_rate != .
    replace base_adval = 0 if date >= tm(2017m1)
    collapse (sum) r_exports tariff_paid (mean) tariff = base_adval , by(date section)
    bysort date section: gen ratio = tariff_paid / r_exports * 100

    keep ratio date section tariff
    gen exp = 1

    tempfile ratio_exp 
    save `ratio_exp'
restore

* --- Imports
* --- Sections HS code from nandina
capture frame drop imports_hs
frame copy imports imports_hs 
frame change imports_hs

gen hs_section = substr(nandina_all, 1, 2)
destring hs_section, replace 

gen section = .
    replace section = 1 if inrange(hs_section, 1, 5)
    replace section = 2 if inrange(hs_section, 6, 14)
    replace section = 3 if inrange(hs_section, 15, 15)
    replace section = 4 if inrange(hs_section, 16, 24)
    replace section = 5 if inrange(hs_section, 25, 27)
    replace section = 6 if inrange(hs_section, 28, 38)
    replace section = 7 if inrange(hs_section, 39, 40)
    replace section = 8 if inrange(hs_section, 41, 43)
    replace section = 9 if inrange(hs_section, 44, 46)
    replace section = 10 if inrange(hs_section, 47, 49)
    replace section = 11 if inrange(hs_section, 50, 63)
    replace section = 12 if inrange(hs_section, 64, 67)
    replace section = 13 if inrange(hs_section, 68, 70)
    replace section = 14 if inrange(hs_section, 71, 71)
    replace section = 15 if inrange(hs_section, 72, 83)
    replace section = 16 if inrange(hs_section, 84, 85)
    replace section = 17 if inrange(hs_section, 86, 89)
    replace section = 18 if inrange(hs_section, 90, 92)
    replace section = 19 if inrange(hs_section, 93, 93)
    replace section = 20 if inrange(hs_section, 94, 96)
    replace section = 21 if inrange(hs_section, 97, 99)

label define section 1 "Live animals; animal products" /*
    */  2 "Vegetable products" /*
    */  3 "Fats and oils" /*
    */  4 "Prepared foodstuffs; beverages; tobacco" /*
    */  5 "Mineral products" /*
    */  6 "Chemical products" /*
    */  7 "Plastics and rubber" /*
    */  8 "Leather, furskins and articles thereof" /*
    */  9 "Wood, cork, manufactures thereof" /*
    */  10 "Pulp, paper, printed matter" /*
    */  11 "Textiles and textile articles" /*
    */  12 "Footwear, headgear, etc." /*
    */  13 "Stone, ceramic, glass" /*
    */  14 "Precious stones and metals" /*
    */  15 "Base metals and articles thereof" /*
    */  16 "Machinery and electrical equipment" /*
    */  17 "Transport equipment" /*
    */  18 "Optical, instruments, clocks, musical instruments" /*
    */  19 "Arms and ammunition" /*
    */  20 "Miscellaneous manufactured articles" /*
    */  21 "Works of art; special transactions"

label values section section

preserve
    keep if eu == 1
    drop if date < tm(2014m1)
    collapse (sum) r_imports tariff_paid (mean) tariff, by(date section)
    bysort date section: gen ratio = tariff_paid / r_imports * 100

    keep ratio date section tariff
    gen exp = 0

    tempfile ratio_imp 
    save `ratio_imp'
restore

frame drop temp
frame create temp 
frame change temp
    use `ratio_exp', clear 
    append using `ratio_imp'

    label define exp 1 "Exports" 0 "Imports"
    label values exp exp 

    egen id = group(exp section)
    xtset id date 

    replace date = ym(2023, month(dofm(date))) if year(dofm(date)) == 2022
    tsfill

    preserve
        decode section, gen(section_label)
        gen date_excel = dofm(date)
        format date_excel %td
        keep exp section section_label date date_excel tariff
        export excel using "$eulas_figuredata/Figure2_tariffs_by_section_data.xlsx", ///
            firstrow(variables) replace
    restore

    twoway (scatter tariff date if exp == 1 & !inlist(section, 1, 2, 4, 16) & date < tm(2022m1), /*
        */  mcolor(gs10%40) msymbol(o) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 1 & !inlist(section, 1, 2, 4, 16) & date > tm(2022m1), /*
        */  mcolor(gs10%40) msymbol(o) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 1 & section == 1  & date < tm(2022m1), /*
        */  mcolor(red)   msymbol(O) msize(vsmall)) /*
        */  (scatter tariff date if exp == 1 & section == 1  & date > tm(2022m1), /*
        */  mcolor(red)   msymbol(O) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 1 & section == 2  & date < tm(2022m1), /*
        */  mcolor(green)    msymbol(T) msize(vsmall)) /*
        */  (scatter tariff date if exp == 1 & section == 2  & date > tm(2022m1), /*
        */  mcolor(green)    msymbol(T) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 1 & section == 4  & date < tm(2022m1), /*
        */  mcolor(blue)  msymbol(S) msize(vsmall)) /*
        */  (scatter tariff date if exp == 1 & section == 4  & date > tm(2022m1), /*
        */  mcolor(blue)  msymbol(S) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 1 & section == 16 & date < tm(2022m1), /*
        */  mcolor(black) msymbol(D) msize(vsmall)) /*
        */  (scatter tariff date if exp == 1 & section == 16 & date > tm(2022m1), /*
        */  mcolor(black) msymbol(D) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 0 & !inlist(section, 7, 11, 15, 16, 17) & date < tm(2022m1), /*
        */  mcolor(gs10%40) msymbol(o) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 0 & !inlist(section, 7, 11, 15, 16, 17) & date > tm(2022m1), /*
        */  mcolor(gs10%40) msymbol(o) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 0 & section == 7  & date < tm(2022m1), /*
        */  mcolor(blue)  msymbol(O) msize(vsmall)) /*
        */  (scatter tariff date if exp == 0 & section == 7  & date > tm(2022m1), /*
        */  mcolor(blue)  msymbol(O) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 0 & section == 11 & date < tm(2022m1), /*
        */  mcolor(red) msymbol(T) msize(vsmall)) /*
        */  (scatter tariff date if exp == 0 & section == 11 & date > tm(2022m1), /*
        */  mcolor(red) msymbol(T) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 0 & section == 15 & date < tm(2022m1), /*
        */  mcolor(orange)  msymbol(X) msize(vsmall)) /*
        */  (scatter tariff date if exp == 0 & section == 15 & date > tm(2022m1), /*
        */  mcolor(orange)  msymbol(X) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 0 & section == 16 & date < tm(2022m1), /*
        */  mcolor(black) msymbol(D) msize(vsmall)) /*
        */  (scatter tariff date if exp == 0 & section == 16 & date > tm(2022m1), /*
        */  mcolor(black) msymbol(D) msize(vsmall) legend(off)) /*
        */  (scatter tariff date if exp == 0 & section == 17 & date < tm(2022m1), /*
        */  mcolor(green) msymbol(+) msize(vsmall)) /*
        */  (scatter tariff date if exp == 0 & section == 17 & date > tm(2022m1), /*
        */  mcolor(green) msymbol(+) msize(vsmall) legend(off)), /*
        */  by(exp, cols(2) note("")) /*
        */  title("") /*
        */  ytitle("Average Rate (%)") /*
        */  xtitle("") /*
        */  legend(order(3  "Live animals; animal products" /*
        */                5  "Vegetable products" /*
        */                7  "Prepared foodstuffs; beverages; tobacco" /*
        */                9  "Machinery and electrical equipment" /*
        */                13 "Plastics and rubber" /*
        */                15 "Textiles and textile articles" /*
        */                17 "Base metals and articles thereof" /*
        */                21 "Transport equipment") /*
        */         size(2) region(lcolor(black) lw(0.20) fcolor(none)) cols(3) symxsize(4)) /*
        */  graphregion(color(white)) /*
        */  tline(2017m1, lcolor(red) lwidth(0.15) lstyle(solid)) /*
        */  tline(2014m7, lcolor(black) lwidth(0.15) lstyle(solid)) /*
        */  tlabel(2014m1(9)2023m12, angle(45)) /*
        */  name(FTA_tariff_sec, replace)
    graph export "$eulas_plots/Figure2_tariffs_by_section.pdf", as(pdf) replace

frames reset
