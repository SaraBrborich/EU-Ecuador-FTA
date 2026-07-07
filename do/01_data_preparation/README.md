# Data preparation

| File | Purpose | Main restricted output |
|---|---|---|
| `0_1_prepareDataEffTariffsImports.do` | Builds the monthly import tariff panel and merges it with customs transactions. | `Imports_etariff.dta` |
| `0_2_prepareDataEffTariffsExports.do` | Harmonizes exports and the EU tariff schedule and applies `etariff`. | `Exports_etariff.dta` |
| `0_3_prepareFirmData.do` | Cleans annual firm financial statements. | `aux_firmsPanel_2012_2024.dta` |
| `0_4_prepareDataImports.do` | Builds firm import panels and safeguard-based exposure controls. | Several `aux_*.dta` files |
| `0_5_prepareValueChain.do` | Propagates input exposure through the 2014 production network. | `aux_exposureValueChain.dta` |
| `0_6_prepareDataExports.do` | Aggregates exports to firm-product-year level. | `aux_exportsPanel.dta` |
| `0_7_prepareMainData.do` | Merges all components and estimates TFP. | `1_FINAL_firmsData_2012_2024.dta` |

Every output remains in `$eulas_workData`, outside the repository.
