# EU-Ecuador-FTA

Replication code and supporting documents for **“From Preferences to Reciprocity: Firm Adjustment after the EU-Ecuador Free Trade Agreement.”**

## Authors

- **Carlos Uribe-Terán** — School of Economics, Universidad San Francisco de Quito — cauribe@usfq.edu.ec
- **Diego F. Grijalva** — School of Business, Universidad San Francisco de Quito — dgrijalva@usfq.edu.ec
- **Sara Brborich** — Bonn Graduate School of Economics, University of Bonn — sbrborich@uni-bonn.de

## Repository contents

- `do/`: Stata 17 code for data construction, descriptive figures, the import-side shift-share instrument, and the estimations reported in the online appendix.
- `config/`: a local configuration template. Personal paths are never stored in the public repository.
- `documentation/`: workflow, data availability, file inventory, and output crosswalk.
- `documents/appendix/`: the online appendix requested for public access.
- `documents/chapter/`: the current working chapter supplied by the authors. The DOCX is included in the local package but ignored by Git until editorial permission is obtained.
- `documents/agreement/`: the official Protocol of Accession and tariff schedules used to construct the policy variables.
- `output/`: empty folders for generated figures, figure-source spreadsheets, tables, and logs.

## Data availability

The administrative microdata are **not included** and cannot be redistributed. The code expects authorized users to place the required source files in local restricted-data directories defined in `config/config.do`. See [`documentation/DATA_AVAILABILITY.md`](documentation/DATA_AVAILABILITY.md) and [`data/README.md`](data/README.md).

## Software

The replication code was prepared for **Stata 17**. User-written dependencies can be installed with:

```stata
do "do/00_install_packages.do"
```

## Running the replication

1. Copy `config/config_template.do` to `config/config.do`.
2. Edit the paths in `config/config.do`.
3. Open Stata 17, set the working directory to the repository root, and run:

```stata
do "do/A_MAIN.do"
```

The run switches in `config/config.do` allow users to execute the complete workflow or begin from pre-existing intermediate files. The scope and limitations of the package review are recorded in [`documentation/STATIC_QA_REPORT.md`](documentation/STATIC_QA_REPORT.md).

## Main methodological choices encoded in the repository

- Firm exposure weights are based on each firm's **2014 EU import basket**.
- Product-level tariff changes are measured relative to **2016**, the final pre-agreement year.
- The agreement entered into force for Ecuador in January 2017.
- The analysis covers 2014–2023 and excludes 2022 because the customs records are incomplete.
- The public estimation workflow focuses on the import-side mechanism reported in the chapter and online appendix. Historical exporter extensions, event studies, PSM exercises, and superseded code are not part of the replication flow.

## License and document rights

The source code is released under the MIT License; see [`LICENSE`](LICENSE). The license does **not** grant rights to the book chapter, online appendix, or official EU agreement. See [`NOTICE.md`](NOTICE.md).

## Citation

Citation metadata are available in [`CITATION.cff`](CITATION.cff) and [`CITATION.bib`](CITATION.bib).
