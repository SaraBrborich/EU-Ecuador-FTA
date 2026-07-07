# Stata code

The code is organized in execution order:

1. `A_MAIN.do` — master workflow.
2. `00_install_packages.do` — optional dependency installer.
3. `01_data_preparation/` — customs, tariff, firm, and exposure construction.
4. `02_descriptive/` — five chapter figures and their source spreadsheets.
5. `03_instruments/` — import-side shift-share instrument.
6. `04_estimation/` — estimates and publication tables.
7. `ado/` — custom export-tariff routine.

All scripts use forward slashes and paths defined in `config/config.do`. No personal directory is embedded in the code.
