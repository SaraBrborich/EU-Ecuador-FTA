# Pre-publication checklist

Before uploading or tagging a public release:

- [ ] Confirm that the editor authorizes public distribution of the Word chapter.
- [ ] Confirm that the online appendix is the final version requested by the editor.
- [ ] Run the full workflow in Stata 17 with authorized data.
- [ ] Compare all coefficients, standard errors, sample sizes, and diagnostics with the appendix.
- [ ] Visually compare every generated figure with the chapter.
- [ ] Verify that `config/config.do` is not staged for commit.
- [ ] Search the repository for personal paths, usernames, and restricted filenames.
- [ ] Confirm that no `.dta`, raw `.csv`, or confidential spreadsheet is staged.
- [ ] Update `CITATION.cff` with the final book citation and DOI, when available.
- [ ] Create a GitHub release and, if desired, archive it through Zenodo for a DOI.
