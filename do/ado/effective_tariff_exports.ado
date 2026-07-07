/*==============================================================================
  EFFECTIVE TARIFF ON ECUADORIAN EXPORTS TO THE EUROPEAN UNION
  Original author: Sara Brborich
  Replication revision: July 2026
  Software: Stata 17

  This program parses the EU tariff schedule and computes tariff payments when
  the transaction data contain the units required by the tariff formula. See
  do/ado/README.md for assumptions and unsupported tariff types.
==============================================================================*/

/* This ado file calculates the effective tariff paid by exports to the EU.
The process requires the clean data on NANDINA codes (10-digits), the base rates
on the FTA (those can be found in the pdf EUAndesFTAAgreement), and
the category of each product. For further detail on the meaning of each
category and reduction schedule, visit the excel file 
categories_export_goods_meaning.                                             */

capture program drop etariff
program define etariff, rclass
    version 17.0

    syntax [if] [in], BASE_RATE(varname) CATEGORY_ID(varname) DATE(varname) ///
        TARIFF_TYPE(varname) VALUE(varname) WEIGHT(varname) EXCHANGE_RATE(varname)

    marksample touse
    
    * Identify variables and locals 
	local base_rate : word 1 of `base_rate'				/* base rate variable */
	local category_id : word 1 of `category_id'		    /* tariff relief category */
	local date : word 1 of `date'				        /* date variable */
	local tariff_type : word 1 of `tariff_type'		    /* tariff type variable */
	local value : word 1 of `value'				        /* value of exports variable */
	local weight : word 1 of `weight'			        /* weight of exports variable */
    local exchange_rate : word 1 of `exchange_rate'		/* exchange rate variable */

    * -- Gen phase variables
    phase_vars, base_rate(`base_rate') category_id(`category_id') date(`date')

    // drop variables if they exist
    capture drop base_adval 
    capture drop factor_degrav 
    capture drop eff_adval

    // temporary variables
    tempvar factor_degrav eff_adval base_spec100 eff_spec100 base_spec_ton eff_spec_ton base_min base_max base_spec_kg eff_spec_kg base_spec_k1000 base_spec_p1000 eff_spec_k1000 adval_paid spec_min_paid spec_max_paid base_spec max_adval max_spec spec_paid max_adval_paid max_spec_paid


    // Final tariff paid
    gen double tariff_paid = .
    replace tariff_paid = 0 if `touse' 
    
    // Base rates
    gen base_adval = .
    gen `factor_degrav' = 1
    gen `eff_adval' = .
    gen `base_spec100' = .
    gen `eff_spec100' = .
    gen `base_spec_ton' = .
    gen `eff_spec_ton' = .
    gen `base_min' = .
    gen `base_max' = .
    gen `base_spec_kg' = .
    gen `eff_spec_kg' = .
    gen `base_spec_k1000' = .
    gen `base_spec_p1000' = .
    gen `eff_spec_k1000' = .
    gen `adval_paid' = .
    gen `spec_min_paid' = .
    gen `spec_max_paid' = .
    gen `base_spec' = .
    gen `max_adval' = .
    gen `max_spec' = .
    gen `spec_paid' = .
    gen `max_adval_paid' = .
    gen `max_spec_paid' = .


    * --- Case 1: Ad valorem only ----------------------------------------------
    
        * -- Base ad valorem rate        
        replace base_adval = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?)$") & `tariff_type' == 1

        * -- Phase-out factor        
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0 & `tariff_type' == 1
        replace `factor_degrav' = 0 if desgrav_period == 0 & `tariff_type' == 1
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period & `tariff_type' == 1

        * -- Effective ad valorem rate
        replace `eff_adval' = base_adval * `factor_degrav'

        * -- Effective tariff paid
        replace tariff_paid = (`eff_adval'/100) * `value' if `tariff_type' == 1


    * --- Case 2: Ad valorem + specific (100 kg) -------------------------------
        * -- Base ad valorem rate        
        replace base_adval = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?) \+") & `tariff_type' == 2

        * -- Base specific rate per 100 kg        
        replace `base_spec100' = real(regexs(1)) if regexm(`base_rate', "\+ *([0-9]+(\.[0-9]+)?) *EUR/ */?100 *KG") & `tariff_type' == 2

        * -- Phase-out factor        
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0 & `tariff_type' == 2
        replace `factor_degrav' = 0 if desgrav_period == 0 & `tariff_type' == 2
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period & `tariff_type' == 2

        * -- Effective component rates
        replace `eff_adval' = base_adval * `factor_degrav' if `tariff_type' == 2
        replace `eff_spec100' = `base_spec100' * `factor_degrav' if `tariff_type' == 2

        * -- Tariff paid = ad valorem component + specific component
        replace tariff_paid = (`eff_adval'/100) * `value' + ((`eff_spec100'/100) * (`weight' * 1000) * `exchange_rate') if `tariff_type' == 2 & desgrav_period > 0 & desgrav_period != .        
    

    * --- Case 3: Specific only per net 100 kg ---------------------------------
        * -- Base specific rate per net 100 kg        
        replace `base_spec100' = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?) *EUR */?100 *KG/?NET$") & `tariff_type' == 3

        * -- Phase-out factor        
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0 & `tariff_type' == 3
        replace `factor_degrav' = 0 if desgrav_period == 0 & `tariff_type' == 3
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period & `tariff_type' == 3

        * -- Effective specific rate
        replace `eff_spec100' = `base_spec100' * `factor_degrav' if `tariff_type' == 3

        * -- Tariff paid = specific component only
        replace tariff_paid = ((`eff_spec100'/100) * (`weight' * 1000) * `exchange_rate') if `tariff_type' == 3 & desgrav_period > 0 & desgrav_period != .        
    

    * --- Case 4: Specific only per HL -----------------------------------------
        /* Given that the base rate is a specific rate per HL, and we dont have the
           weight in HL, we cannot calculate the tariff paid. */
        
        replace tariff_paid = . if `tariff_type' == 4
    

    * --- Case 5: Ad valorem + specific per HL ---------------------------------
        * -- Base ad valorem rate
        
        replace base_adval = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?) \+") & `tariff_type' == 5

        * -- Phase-out factor        
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0 & `tariff_type' == 5
        replace `factor_degrav' = 0 if desgrav_period == 0 & `tariff_type' == 5
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period & `tariff_type' == 5

        * -- Effective ad valorem rate
        replace `eff_adval' = base_adval * `factor_degrav'

        * -- Tariff paid: ad valorem component only (specific per HL omitted)
        replace tariff_paid = (`eff_adval'/100) * `value' if `tariff_type' == 5
    

    * --- Case 6: Specific per metric ton -------------------
        * -- Base specific rate per metric ton        
        replace `base_spec_ton' = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?) *EUR */?T") & `tariff_type' == 6 & `date' >= tm(2017m1)

        * -- Phase-out factor        
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0 & `tariff_type' == 6
        replace `factor_degrav' = 0 if desgrav_period == 0 & `tariff_type' == 6
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period & `tariff_type' == 6

        * -- Effective ad valorem rate
        replace `eff_adval' = `base_spec_ton' * `factor_degrav'

        * -- Tariff paid = specific per ton × weight
        replace tariff_paid = `eff_adval' / 100 * `weight' if `tariff_type' == 6 & `date' >= tm(2017m1)
    

    * --- Case 7: Includes EA clause -------------------------------------------
        * -- Entry‐price adjustment not available
        replace tariff_paid = . if `tariff_type' == 7
    

    * --- Case 8: Conditional thresholds MIN/MAX (per 100kg) -------------------
        * -- Extract base ad valorem rate     
        replace base_adval = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?) *MIN") & `tariff_type' == 8

        * -- Extract base minimum rate per 100 kg
        replace `base_min' = real(regexs(1)) if regexm(`base_rate', "MIN *([0-9]+(\.[0-9]+)?) *EUR/ */?100 *KG") & `tariff_type' == 8

        * -- Extract base maximum rate per 100 kg
        replace `base_max' = real(regexs(1)) if regexm(`base_rate', "MAX *([0-9]+(\.[0-9]+)?) *EUR/ */?100 *KG") & `tariff_type' == 8

        * -- Phase-out factor        
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0 & `tariff_type' == 8
        replace `factor_degrav' = 0 if desgrav_period == 0 & `tariff_type' == 8
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period & `tariff_type' == 8

        * -- Effective ad valorem rate
        replace `eff_adval' = base_adval * `factor_degrav'

        * -- Component tariffs
        replace `adval_paid' = (`eff_adval'/100) * `value' if `tariff_type' == 8
        replace `spec_min_paid' = ((`base_min'/100) * (`weight' * 1000) * `exchange_rate') if `tariff_type' == 8
        replace `spec_max_paid' = ((`base_max'/100) * (`weight' * 1000) * `exchange_rate') if `tariff_type' == 8

        * -- Final tariff paid (bounded ad valorem)
        replace tariff_paid = min(max(`adval_paid', `spec_min_paid'), `spec_max_paid') if `tariff_type' == 8 & desgrav_period > 0 & desgrav_period != . & !missing(`weight')
    

    * --- Case 9: Includes AD clause -------------------------------------------
        * -- Anti-dumping/additional duties info unavailable
        replace tariff_paid = . if `tariff_type' == 9
    

    * --- Case 10: Sugar content–based -----------------------------------------
        * -- Sugar‐content data unavailable
        replace tariff_paid = . if `tariff_type' == 10
    

    * --- Case 11: Exempt or free ----------------------------------------------
        * -- Tariff is zero under this category
        replace tariff_paid = 0 if `tariff_type' == 11
    

    * --- Case 12: Specific per kg of total alcohol ----------------------------
        * -- Alcohol‐content per kg data unavailable
        replace tariff_paid = . if `tariff_type' == 12
    

    * --- Case 13: Specific per KG + per 100kg ---------------------------------
        * -- Base specific rate per kg
        replace `base_spec_kg' = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?) *EUR */?KG") & `tariff_type' == 13

        * -- Base specific rate per 100 kg        
        replace `base_spec100' = real(regexs(1)) if regexm(`base_rate', "\+ *([0-9]+(\.[0-9]+)?) *EUR */?100 *KG") & `tariff_type' == 13

        * -- Phase-out factor        
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0 & `tariff_type' == 13
        replace `factor_degrav' = 0 if desgrav_period == 0 & `tariff_type' == 13
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period & `tariff_type' == 13

        * -- Effective specific rates
        replace `eff_spec_kg' = `base_spec_kg' * `factor_degrav' if `tariff_type' == 13
        replace `eff_spec100' = `base_spec100' * `factor_degrav' if `tariff_type' == 13

        * -- Tariff paid = (per-kg component × kg) + (per-100kg component × 100-kg blocks)
        replace tariff_paid = (`eff_spec_kg' * (`weight' * 1000) * `exchange_rate') + (`eff_spec100'/100 * (`weight' * 1000) * `exchange_rate') if `tariff_type' == 13 & desgrav_period > 0 & desgrav_period != .
    

    * --- Case 14: Specific per % vol/HL ---------------------------------------
        * -- Alcohol‐volume percentage data per HL unavailable
        replace tariff_paid = . if `tariff_type' == 14
    

    * --- Case 15: Specific per % vol/HL + HL ----------------------------------
        * -- Alcohol‐volume + HL data unavailable
        replace tariff_paid = . if `tariff_type' == 15
    

    * --- Case 16: Specific per 1000 kg ----------------------------------------
        * -- Base specific rate per 1000 kg
        replace `base_spec_k1000' = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?) *EUR */?1 *000 *KG") & `tariff_type' == 16        

        * -- Phase-out factor (same logic as in other cases)        
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0 & `tariff_type' == 16
        replace `factor_degrav' = 0 if desgrav_period == 0 & `tariff_type' == 16
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period & `tariff_type' == 16

        * -- Effective specific rate per 1000 kg
        replace `eff_spec_k1000' = `base_spec_k1000' * `factor_degrav' if `tariff_type' == 16

        * -- Tariff paid:
        *    if rate per 1000 kg is defined, compute as (rate/1000-kg-block) × weight
        *    if only pieces rate is defined, cannot compute → missing
        replace tariff_paid = `eff_spec_k1000' * `weight' if !missing(`base_spec_k1000') & `tariff_type' == 16 & desgrav_period > 0 & desgrav_period != .        
        replace tariff_paid = . if !missing(`base_spec_p1000') & missing(`base_spec_k1000') & `tariff_type' == 16 & desgrav_period > 0 & desgrav_period != .
    

    * --- Case 17: Specific per 100 meters -------------------------------------
        * -- Length data (meters) unavailable, cannot compute tariff
        replace tariff_paid = . if `tariff_type' == 17
    

    * --- Case 18: Specific per 100 kg (MAS) -----------------------------------
        * -- Base specific rate per 100 kg         
        replace `base_spec100' = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?) *EUR */?100 *KG */?NET *MAS") & `tariff_type' == 18

        * -- Phase-out factor        
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0 & `tariff_type' == 18
        replace `factor_degrav' = 0 if desgrav_period == 0 & `tariff_type' == 18
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period & `tariff_type' == 18

        * -- Effective specific rate
        replace `eff_spec100' = `base_spec100' * `factor_degrav' if `tariff_type' == 18

        * -- Tariff paid = specific component only 
        replace tariff_paid = ((`eff_spec100'/100) * (`weight' * 1000) * `exchange_rate') if `tariff_type' == 18

    * --- Case 19: Conditional thresholds (MIN/MAX by piece) -------------------
        * -- Units data (pieces) unavailable, cannot compute tariff
        replace tariff_paid = . if `tariff_type' == 19

    * --- Case 20: Conditional MIN (per 100kg net) -----------------------------
        * -- Base ad valorem rate        
        replace base_adval = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?) *MIN") & `tariff_type' == 20

        * -- Base minimum rate per 100 kg
        replace `base_min' = real(regexs(1)) if regexm(`base_rate', "MIN *([0-9]+(\.[0-9]+)?) *EUR/ */?100 *KG/ ?NET")  & `tariff_type' == 20
        replace `base_min' = real(regexs(1)) if regexm(`base_rate', "MIN *([0-9]+(\.[0-9]+)?) *EUR/ */?100 *KG NET")  & `tariff_type' == 20 & `base_min' == .

        * -- Phase-out factor        
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0 & `tariff_type' == 20
        replace `factor_degrav' = 0 if desgrav_period == 0 & `tariff_type' == 20
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period & `tariff_type' == 20

        * -- Effective ad valorem rate
        replace `eff_adval' = base_adval * `factor_degrav'

        * -- Component tariffs
        replace `adval_paid' = (`eff_adval'/100) * `value' if `tariff_type' == 20
        replace `spec_min_paid' = ((`base_min'/100) * (`weight' * 1000) * `exchange_rate') if `tariff_type' == 20

        * -- Final tariff paid (bounded ad valorem)
        replace tariff_paid = max(`adval_paid', `spec_min_paid') if `tariff_type' == 20 & desgrav_period > 0 & desgrav_period != . & !missing(`weight')


    * --- Case 21: Conditional MAX (per 100kg net) -----------------------------
        * -- Base ad valorem
        replace base_adval = real(regexs(1)) if regexm(`base_rate', "^([0-9]+(\.[0-9]+)?) *\+") & `tariff_type' == 21

        * -- Base specific per 100 kg
        replace `base_spec' = real(regexs(1)) if regexm(`base_rate', "\+ *([0-9]+(\.[0-9]+)?) *EUR/ */?100 *KG") & `tariff_type' == 21

        * -- Maximum ad valorem
        replace `max_adval' = real(regexs(1)) if regexm(`base_rate', "MAX *([0-9]+(\.[0-9]+)?) *\+") & `tariff_type' == 21

        * -- Maximum specific
        replace `max_spec' = real(regexs(2)) if regexm(`base_rate', "MAX *[0-9]+(\.[0-9]+)? *\+ *([0-9]+(\.[0-9]+)?) *EUR/ */?100 *KG") & `tariff_type' == 21

        * -- Phase-out factor
        replace `factor_degrav' = max(0, 1 - (rel_year - 1) / desgrav_period) if desgrav_period > 0
        replace `factor_degrav' = 0 if desgrav_period == 0
        replace `factor_degrav' = 0 if desgrav_period > 0 & rel_year > desgrav_period

        * -- Effective ad valorem
        replace `eff_adval' = base_adval * `factor_degrav' if `tariff_type' == 21

        * -- Tariff components
        replace `adval_paid' = (`eff_adval'/100) * `value' if `tariff_type' == 21
        replace `spec_paid' = ((`base_spec'/100) * (`weight' * 1000) * `exchange_rate') if `tariff_type' == 21
        replace `max_adval_paid' = (`max_adval'/100) * `value' if `tariff_type' == 21
        replace `max_spec_paid' = ((`max_spec'/100) * (`weight' * 1000) * `exchange_rate') if `tariff_type' == 21

        * -- Final tariff paid: bounded from above
        replace tariff_paid = min(`adval_paid' + `spec_paid', `max_adval_paid' + `max_spec_paid') if `tariff_type' == 21 & desgrav_period > 0 & desgrav_period != . 
        
        
    * --- Case 22: Conditional MIN (per gross kgs) ------------------------
        * -- Gross kgs data unavailable, cannot compute tariff
        replace tariff_paid = . if `tariff_type' == 22

    * --- Case 23: Conditional MAX (per square meter) ------------------------
        * -- Square meters data unavailable, cannot compute tariff
        replace tariff_paid = . if `tariff_type' == 23

    * --- For Tax relief categories 
    replace tariff_paid = . if `tariff_type' >= 13 & `tariff_type' <= 25 & `date' >= tm(2017m1)
    replace tariff_paid = . if !`touse'
    label var tariff_paid "Effective tariff paid by exports to EU"
    label var base_adval "Ad valorem tariff rate, FTA"
end

capture program drop phase_vars
program define phase_vars, rclass
    version 17.0

    syntax [if] [in], BASE_RATE(varname) CATEGORY_ID(varname) DATE(varname)

    marksample touse

    * Identify variables and locals 
	local base_rate : word 1 of `base_rate'					/* base rate variable */
    local category_id : word 1 of `category_id'				/* tariff relief category */
    local date : word 1 of `date'						    /* date variable */

    capture drop desgrav_period 
    capture drop months_since_start 
    capture drop rel_year 
    capture drop tariff_paid
    gen desgrav_period = 1
    
    // Immediate elimination (ad valorem or full)
    // 1=0, 2=0+EP, 4=0’, 9=AV0
    replace desgrav_period = 0 if inlist(`category_id', 1, 2, 4, 9, 14) & `date' >= tm(2017m1)            

    // Ad valorem immediate + 3-year phase-out of specific
    // 6=3, 10=AV0-3
    replace desgrav_period = 3 if inlist(`category_id', 6, 10) & `date' >= tm(2017m1)

    // Ad valorem immediate + 5-year phase-out of specific
    // 7=5, 11=AV0-5
    replace desgrav_period = 5 if inlist(`category_id', 7, 11) & `date' >= tm(2017m1)

    // Ad valorem immediate + 7-year phase-out of specific
    // 8=7, 12=AV0-7
    replace desgrav_period = 7 if inlist(`category_id', 8, 12) & `date' >= tm(2017m1)

    // 11-stage elimination (duty-free from year 11)
    // 5=10
    replace desgrav_period = 10 if `category_id' == 5 & `date' >= tm(2017m1)

    // “—” means no tariff relief, it stays with the base rate
    // so we use the 99 periods to simulate a permanent tariff
    replace desgrav_period = 99 if `category_id' == 26

    /* All TQ(*) categories (13–25) involve tariff-rate quotas with volume 
    triggers or complex allocation rules.
    Since we lack transaction-level quota allocation data, we cannot 
    determine if the preferential rate applies. Therefore, we leave 
    desgrav_period as missing to prevent incorrect effective tariff 
    calculations. */
    replace desgrav_period = . if `category_id' >= 13 & `category_id' <= 25 & `date' >= tm(2017m1)
    label var desgrav_period "Tax relief period"

    capture drop months_since_start 
    capture drop rel_year

    gen months_since_start = `date' - tm(2017m1) if desgrav_period != .
    replace months_since_start = 0 if months_since_start < 0 & desgrav_period != .
    label var months_since_start "Months since 2017m1"

    gen rel_year = floor(months_since_start/12) + 1 if desgrav_period != .
    replace rel_year = 1 if `category_id' == 26 & desgrav_period != .
    label var rel_year "Relative year in tariff schedule (from Jan 2017)"

    return local desgrav_var "desgrav_period" // tariff relief period
    return local relyear_var "rel_year" // relative year in tariff schedule
end

