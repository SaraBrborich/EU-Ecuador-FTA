# Changelog

## v1.0.0 - 2026-07-07

- Replaced personal Dropbox paths with a local configuration file.
- Added a single master workflow for Stata 17.
- Removed the unavailable `trade_status.ado` dependency and implemented the only status classification used by the TFP routine: non-trader, importer only, exporter only, and two-way trader at the 2014 baseline.
- Retained 2016 as the tariff baseline for the import instrument.
- Removed the second instrument block that used 2013 and overwrote `shift_share.dta`.
- Restricted the public estimation workflow to the import-side analysis reported in the chapter and online appendix.
- Removed superseded exporter, event-study, PSM, and historical estimation blocks.
- Consolidated the former Excel-export do-file into the main descriptive-statistics workflow.
- Removed `3_EffectsPerformance_imports.do`, which depended on an unproduced `imports_yearly.dta` and was superseded by `3_Estimations.do`.
- Added explicit figure exports for all five chapter figures.
- Added table-building code for the chapter summary and appendix tables.
- Corrected creation of `imports_europe` after the source variable is renamed to `importsTotal`.
- Corrected an impossible date condition in the safeguard-exposure construction (`&` to `|`).
- Corrected construction of the buyer and seller industry lookup files used by the production-network code.
- Kept current EU imports from products added after 2014 in the endogenous import measure while assigning those products a zero instrument contribution when they are absent from the predetermined basket.
- Corrected filename capitalization for the value-chain exposure file.
- Corrected clear logical and syntax errors in `effective_tariff_exports.ado` and documented tariff types that cannot be calculated with the available transaction fields.
- Preserved 2023 as the reported calendar year while using a separate consecutive panel index internally.
- Added MIT licensing for code, citation metadata, data-availability documentation, and a publication checklist.
