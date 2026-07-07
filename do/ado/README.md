# `effective_tariff_exports.ado`

## Purpose

The file defines two Stata programs:

- `etariff`: computes the effective tariff payment associated with an Ecuadorian export transaction to the European Union;
- `phase_vars`: translates the agreement's staging category and transaction month into a phase-out period and relative implementation year.

The routine is used by `0_2_prepareDataEffTariffsExports.do`. The export-side effective-tariff measure is not the endogenous policy variable in the final firm-performance estimations, but it is part of the construction and documentation of the bilateral tariff series and supports Figure 2.

## Required variables

The calling syntax is:

```stata
etariff if <sample>, ///
    base_rate(<string tariff formula>) ///
    category_id(<numeric staging category>) ///
    date(<monthly Stata date>) ///
    tariff_type(<numeric formula type>) ///
    value(<real export value>) ///
    weight(<metric tons>) ///
    exchange_rate(<currency conversion>)
```

The program creates or replaces:

- `tariff_paid`;
- `base_adval`;
- `desgrav_period`;
- `months_since_start`;
- `rel_year`.

## Staging logic

The program interprets the agreement's categories as follows:

- category 0 and equivalent immediate-elimination categories: tariff-free from January 2017;
- categories 3, 5, 7, and 10: staged elimination according to the agreement;
- category “-”: no scheduled elimination;
- tariff-rate quota categories: missing after implementation because transaction-level quota allocation is unavailable.

## Tariff formulas

The code parses 23 tariff-formula types, including pure ad valorem rates, ad valorem plus specific duties, specific rates per weight unit, and bounded minimum/maximum formulas. Calculations requiring unavailable physical units are intentionally set to missing rather than approximated.

Unsupported or partially supported cases include tariffs based on:

- hectoliters;
- alcohol volume;
- pieces;
- meters or square meters;
- gross weight when only net weight is available;
- entry-price or quota-allocation information.

## Important assumptions

1. `weight` is interpreted according to the units documented in the customs preparation file.
2. `exchange_rate` must convert the euro-denominated specific duty into the currency used by `value`.
3. Tariff formulas are parsed from normalized strings; changes in source formatting may require updates to the regular expressions.
4. Products subject to tariff-rate quotas cannot be assigned a transaction-specific preferential rate without quota-use data.
5. The program deliberately prefers missing values to unsupported imputation.

## Corrections in the replication version

The July 2026 version:

- makes every syntax option explicit and required;
- respects the caller's `if`/`in` sample for `tariff_paid`;
- fixes the tariff-string parser and specific-duty assignment for tariff type 3;
- applies the correct lower-bound rule for a minimum tariff;
- keeps non-liberalized lines at their base rate rather than allowing a mechanical 99-year decline;
- corrects the January 2017 implementation label;
- uses the supplied date-variable option consistently.

## Validation recommendation

Before a public tagged release, authorized users should tabulate tariff-formula coverage and compare representative products from every supported formula type with the official schedule in `documents/agreement/EUAndesFTAAgreement.pdf`.
