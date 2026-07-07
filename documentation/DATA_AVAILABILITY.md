# Data availability

The replication code uses administrative and proprietary inputs that cannot be redistributed through GitHub. No microdata are included in this repository.

## Main administrative sources

1. **Customs transaction records** from the Central Bank of Ecuador. The records contain firm identifiers, ten-digit NANDINA product codes, partner countries, transaction values, and dates.
2. **Annual firm financial statements** from the Superintendencia de Compañías, Valores y Seguros. The files contain firm identifiers and financial and employment outcomes.
3. **Tariff schedules** associated with Ecuador's accession to the EU-Colombia-Peru Trade Agreement.
4. **Auxiliary concordances and exposure files** produced in related restricted-data projects, including HS-to-ISIC mappings, safeguard tariff files, economic-group indicators, and production-network inputs.

## Years

- Customs and firm analysis: 2014-2023.
- 2022 is omitted from the empirical analysis because the customs records are incomplete.
- Some data-construction scripts use earlier years to create controls and harmonized panels.

## Access

Researchers seeking access must contact the relevant data providers and comply with their confidentiality and use agreements. Possession of the public repository does not imply authorization to access the underlying data.

## Reproducibility scope

Authorized users with the required source files can use the code to reconstruct the derived data, figures, and estimates. Users without access can inspect the full data-construction and estimation logic, the online appendix, and the official agreement, but cannot execute the complete workflow.
