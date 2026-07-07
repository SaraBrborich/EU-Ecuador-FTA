# Replication instructions

## 1. Software

- Stata 17
- Internet access during the optional package-installation step

## 2. Configure local paths

Copy:

```text
config/config_template.do
```

to:

```text
config/config.do
```

Edit the absolute paths. `config/config.do` is ignored by Git so local usernames and storage locations are not published.

## 3. Install user-written commands

Run once:

```stata
do "do/00_install_packages.do"
```

The workflow uses `ftools`, `reghdfe`, `ivreg2`, `ivreghdfe`, `prodest`.

## 4. Run the master file

From the repository root:

```stata
do "do/A_MAIN.do"
```

The master file executes the following blocks according to the switches in `config/config.do`:

1. tariff and customs preparation;
2. firm and auxiliary exposure preparation;
3. chapter figures and figure-source spreadsheets;
4. construction of the import shift-share instrument;
5. OLS and IV estimation;
6. appendix and chapter-summary tables.

## 5. Important design choices

- The firm-product shares are fixed in 2014.
- The tariff shift is measured relative to 2016.
- The instrument is constructed only for imports, matching the empirical design in the chapter.
- 2023 remains the calendar-year label in all saved results. A separate compressed time index is used internally where Stata lag operators require a consecutive panel after omitting 2022.
