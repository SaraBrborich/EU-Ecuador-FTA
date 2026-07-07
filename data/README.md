# Restricted data layout

This repository intentionally contains no data files. The code expects the following roots to be defined in `config/config.do`.

## `$tariffs_data`

Expected subdirectories and files include:

- `dta/raw_data/import_tariffs.dta`
- `dta/raw_data/export_tariffs.dta`
- `dta/working_data/` for derived customs-tariff files
- `excel/MFN Tariffs/ECU_<year>.CSV`
- `excel/exchange_rate_dollar_eur.csv`
- `imports_new/03. Export. o Import. por Subpartida y País_BK.xlsx`

## `$competition_data`

Expected inputs include:

- `tradeDatasets/Exportaciones/export_<period>.csv`
- `0_allImportsData_bycountry.dta`
- `aux_importsPanel.dta`
- `aux_exportsPanel.dta`

## `$superCias`

- `FirmsPanel_2012_2024.dta`

## `$enemdus`

- `real_exchange_rate_index.dta`

## `$Eff_of_Tariffs`

Expected auxiliary files include:

- `aux_DraftFirmMonthly.dta`
- `aux_HTScode_ciiu.dta`
- `universalTariff.dta`
- `aux_bigCorps.dta`
- `aux_econGroup.dta`
- `ProductionNetworks/id_ecuador_complete.csv`
- `ProductionNetworks/totaltax_ND(2014)_firms.csv`

## `$eulas_workData`

This is a local restricted directory for all derived firm-level `.dta` files. It must remain outside the Git repository.
