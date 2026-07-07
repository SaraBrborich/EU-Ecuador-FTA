# Workflow

```text
Raw tariff schedules + customs records
        |
        |-- 0_1_prepareDataEffTariffsImports.do
        |       -> Imports_etariff.dta
        |
        |-- 0_2_prepareDataEffTariffsExports.do
        |       -> Exports_etariff.dta
        |
Firm financial statements
        |
        |-- 0_3_prepareFirmData.do
        |       -> aux_firmsPanel_2012_2024.dta
        |
Imports + auxiliary classifications
        |
        |-- 0_4_prepareDataImports.do
        |       -> import panels and exposure controls
        |
Production-network inputs
        |
        |-- 0_5_prepareValueChain.do
        |       -> value-chain exposure controls
        |
Exports
        |
        |-- 0_6_prepareDataExports.do
        |       -> aux_exportsPanel.dta
        |
All prepared files
        |
        |-- 0_7_prepareMainData.do
        |       -> 1_FINAL_firmsData_2012_2024.dta
        |
        |-- 1_DescriptiveStats.do
        |       -> chapter figures + source spreadsheets
        |
        |-- 2_prepareInstruments.do
        |       -> shift_share.dta
        |
        |-- 3_Estimations.do
        |       -> long-format estimation results
        |
        `-- 4_buildTables.do
                -> chapter summary and appendix tables
```

All `.dta` files shown above remain in the restricted working-data directory.
