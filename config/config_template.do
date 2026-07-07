/*==============================================================================
  LOCAL CONFIGURATION TEMPLATE
  Repository: EU-Ecuador-FTA
  Stata:      17

  Instructions:
  1. Copy this file to config/config.do.
  2. Replace every placeholder path below with a local absolute path.
  3. Do not commit config/config.do to GitHub.
==============================================================================*/

version 17.0

/* Repository root ----------------------------------------------------------- */
global project_root "C:/CHANGE/ME/EU-Ecuador-FTA"

/* Restricted-data roots -----------------------------------------------------
   These directories are outside the Git repository. They may contain
   confidential administrative microdata and derived firm-level files. */
global tariffs_data    "C:/CHANGE/ME/restricted/tariffs_data"
global competition_data "C:/CHANGE/ME/restricted/competition_data"
global enemdus          "C:/CHANGE/ME/restricted/enemdus"
global Eff_of_Tariffs   "C:/CHANGE/ME/restricted/effects_of_tariffs"
global superCias        "C:/CHANGE/ME/restricted/supercias"

/* Restricted working-data directory ---------------------------------------- */
global eulas_workData "C:/CHANGE/ME/restricted/eulas_working_data"

/* Repository directories --------------------------------------------------- */
global eulas_do          "$project_root/do"
global eulas_ado         "$project_root/do/ado"
global eulas_tables      "$project_root/output/tables"
global eulas_plots       "$project_root/output/figures"
global eulas_figuredata  "$project_root/output/figure_data"
global eulas_logs        "$project_root/output/logs"

/* Run switches --------------------------------------------------------------
   Set to 1 to run a block and 0 to skip it. Building the raw and intermediate
   data requires authorized access to every source listed in data/README.md. */
global install_packages       0
global run_data_preparation   1
global run_descriptive        1
global run_instruments        1
global run_estimations        1
global run_tables             1
