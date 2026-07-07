# Static quality-assurance report

Package review date: **2026-07-07**

## Checks completed

- Confirmed that the package contains no `.dta`, `.csv`, `.xlsx`, `.xls`, `.sav`, `.parquet`, `.rds`, Stata log, or graph files.
- Removed hard-coded personal directories and usernames from executable code.
- Confirmed that all do-files called by `do/A_MAIN.do` exist in the package.
- Checked UTF-8 readability, balanced Stata block comments, balanced braces, and absence of dangling line continuations.
- Validated `CITATION.cff` as YAML and checked internal Markdown links.
- Confirmed ZIP integrity of the Word chapter and preserved its paragraph and table text during metadata scrubbing.
- Checked that the appendix and official agreement are readable, unencrypted PDFs. The appendix has 7 pages; the official agreement has 1,454 pages.
- Visually rendered and reviewed the complete chapter and appendix. The first pages and metadata of the official agreement were inspected; the agreement itself was not modified.
- Confirmed that the import instrument uses 2014 firm-product shares and a 2016 tariff baseline, and that no executable 2013 alternative overwrites the instrument.
- Confirmed that the estimation output preserves 2023 as the reported calendar year.

## Code corrections made during review

- Corrected the creation of `imports_europe` after renaming the source import variable.
- Corrected the impossible safeguard-date condition so tariffs are zero outside March 2015–June 2017.
- Corrected construction of the buyer and seller industry lookup files in the production-network code.
- Corrected capitalization and path inconsistencies in intermediate filenames.
- Replaced the unavailable `trade_status.ado` dependency with the 2014 zero-threshold classification used by the TFP routine.
- Replaced the external HHI command with transparent within-code calculations.
- Prevented post-2014 products from being dropped when total EU imports are constructed for the first-stage endogenous variable; only their instrument contribution is zero when they are absent from the 2014 basket.
- Corrected parsing and assignment errors in `effective_tariff_exports.ado`, including the pure specific-duty formula and minimum-tariff rule.

## Limitation

The package cannot be executed end-to-end without the restricted administrative data and a licensed Stata 17 installation. The review is therefore a static and document-level audit, not a numerical reproduction test. Before creating the public `v1.0.0` release, an authorized user should run `do/A_MAIN.do`, compare every generated figure and coefficient with the chapter and online appendix, and complete `PRE_PUBLICATION_CHECKLIST.md`.
