/*==============================================================================
  MASTER REPLICATION FILE
  Project: From Preferences to Reciprocity: Firm Adjustment after the
           EU-Ecuador Free Trade Agreement
  Repository: SaraBrborich/EU-Ecuador-FTA
  Software: Stata 17
==============================================================================*/

version 17.0
clear all
set more off
set varabbrev off

/* Load local configuration -------------------------------------------------- */
local config_file "config/config.do"
if !fileexists("`config_file'") {
    di as error "Local configuration file not found: `config_file'"
    di as error "Copy config/config_template.do to config/config.do and edit the paths."
    exit 601
}
do "`config_file'"

/* Normalize the working directory ------------------------------------------ */
cd "$project_root"

/* Create output and restricted working directories when possible ----------- */
foreach d in "$eulas_workData" "$eulas_tables" "$eulas_plots" ///
             "$eulas_figuredata" "$eulas_logs" {
    capture mkdir "`d'"
}

/* Make repository ado-files visible ---------------------------------------- */
adopath ++ "$eulas_ado"
quietly run "$eulas_ado/effective_tariff_exports.ado"

/* Log ----------------------------------------------------------------------- */
capture log close _all
local run_date = subinstr("`c(current_date)'", " ", "_", .)
local run_time = subinstr("`c(current_time)'", ":", "", .)
log using "$eulas_logs/replication_`run_date'_`run_time'.log", text replace

noi di as text "EU-Ecuador-FTA replication started: `c(current_date)' `c(current_time)'"
noi di as text "Project root: $project_root"
noi di as text "Stata version: `c(stata_version)'"

/* Optional package installation ------------------------------------------- */
if $install_packages {
    do "$eulas_do/00_install_packages.do"
}

/* Data preparation ---------------------------------------------------------- */
if $run_data_preparation {
    do "$eulas_do/01_data_preparation/0_1_prepareDataEffTariffsImports.do"
    do "$eulas_do/01_data_preparation/0_2_prepareDataEffTariffsExports.do"
    do "$eulas_do/01_data_preparation/0_3_prepareFirmData.do"
    do "$eulas_do/01_data_preparation/0_4_prepareDataImports.do"
    do "$eulas_do/01_data_preparation/0_5_prepareValueChain.do"
    do "$eulas_do/01_data_preparation/0_6_prepareDataExports.do"
    do "$eulas_do/01_data_preparation/0_7_prepareMainData.do"
}

/* Descriptive figures ------------------------------------------------------- */
if $run_descriptive {
    do "$eulas_do/02_descriptive/1_DescriptiveStats.do"
}

/* Import-side shift-share instrument --------------------------------------- */
if $run_instruments {
    do "$eulas_do/03_instruments/2_prepareInstruments.do"
}

/* Estimations and publication tables --------------------------------------- */
if $run_estimations {
    do "$eulas_do/04_estimation/3_Estimations.do"
}

if $run_tables {
    do "$eulas_do/04_estimation/4_buildTables.do"
}

noi di as result "EU-Ecuador-FTA replication completed: `c(current_date)' `c(current_time)'"
log close
