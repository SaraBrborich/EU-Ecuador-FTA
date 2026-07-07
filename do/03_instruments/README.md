# Import shift-share instrument

`2_prepareInstruments.do` implements the instrument described in the chapter and appendix:

- shares: firm-product EU import shares in 2014;
- shifts: product-level changes in `log(1 + tariff)` relative to 2016;
- aggregation: sum of the share-shift products within firm-year.

The file produces `shift_share.dta` in the restricted working-data directory. No 2013-based alternative is included, preventing the final instrument from being overwritten by an inconsistent specification.
