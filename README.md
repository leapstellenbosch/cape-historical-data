# Cape Historical Data Repository

Five collections of records on the Cape Colony, 1650–1850, released by LEAP
(Laboratory for the Economics of Africa's Past), Stellenbosch University.
Data under CC BY 4.0; code under MIT.

| Collection | Period | What a row or file is | Format |
|---|---|---|---|
| **Opgaaf** (tax censuses) | 1660–1844, ten districts | A tax declaration (325,628), or a line of a multi-line declaration (15,501) | CSV, Parquet |
| **Slave emancipation** | 1834 | A record of an enslaved person in the emancipation registers (36,417) | CSV, Parquet |
| **SAF genealogies** | People born up to 1870 | A person (213,953), or a marriage with the spouse's details (153,568), in the South African Families database | CSV, Parquet |
| **Probate inventories** (MOOC8) | 1673–1844 | Transcription XML, one file per archival volume (75 files, 5,953 documents) | XML |
| **Estate auction rolls** (MOOC10) | 1691–1834 | Transcription XML, one file per volume (42 files, 3,266 auctions) | XML |

Records, not people: rows are not linked across collections or across years. A
tax declaration, an auction buyer and a genealogical entry stay separate even
when they probably describe the same person.

Each collection's folder in `data/` has a `README.md` that explains what the
records are, how they were cleaned and what to watch for, and a variable list
(`*_variables.csv`) describing every column. Read it before using the data.

## Load the data

**R** (with `readr`, or `nanoparquet` or `arrow` for Parquet):

```r
units <- readr::read_csv("data/opgaaf/opgaaf_tax_units.csv", guess_max = Inf)
units <- nanoparquet::read_parquet("data/opgaaf/opgaaf_tax_units.parquet")  # faster, keeps types
```

**Python** (with `pandas`, and `pyarrow` for Parquet):

```python
import pandas as pd
units = pd.read_parquet("data/opgaaf/opgaaf_tax_units.parquet")
ema = pd.read_csv("data/emancipation/emancipation_persons.csv",
                  keep_default_na=False, na_values=[""], dtype={"lbs_claim_number": str})
```

**Stata:** `import delimited "data/opgaaf/opgaaf_tax_units.csv", varnames(1) encoding(utf-8) stringcols(_all)`,
then `destring` the numeric columns you need.

**Excel:** use *Data › From Text/CSV* and choose *65001: Unicode (UTF-8)*.
Opening a CSV by double-clicking it garbles accented letters.

Things to know when reading the CSV files:

- **Blank cells are missing values, never zero.** Explicit zeros are zeros.
- **Read with full type guessing, or use the Parquet files.** Many columns
  are empty in their first thousand rows (variables that appear only on later
  forms), and some identifiers mix digits and letters (claim number `508a`).
  Default type guessing on the first rows reads these as missing: use
  `guess_max = Inf` in `readr`, `low_memory=False` and text types for
  identifiers in pandas, or the Parquet files, which store each column's type.
- Files are UTF-8, comma-separated, with a header row.
- `examples/load_r.R` and `examples/load_python.py` load every collection,
  join the tables and read the XML.

## Identifiers

Every row has a permanent `chdr_id` that will not change in later versions:
`OPG-STB-1750-00123` (opgaaf: district, year, spreadsheet row),
`EMA-00001` (emancipation), `SAF-000007` (SAF). Probate and auction documents
are identified by their archival reference (`MOOC8/10.1`, `MOOC10/25.2`).
The identifiers were derived from source positions once, for this release;
later versions will carry them over from the 1.0 files rather than derive
them again, so a corrected or reordered source does not renumber records.

## How to cite

Cite the paper(s) for each collection you use, and this release.

| Collection | Cite |
|---|---|
| Opgaaf | Fourie, J. and Green, E. (2018). Building the Cape of Good Hope Panel. *The History of the Family*, 23(3), 493–502. doi:[10.1080/1081602X.2018.1509367](https://doi.org/10.1080/1081602X.2018.1509367). **And** Fourie, J., Green, E., Burger, C., de Wit, C., Ekama, K., Greyling, J., Heese, H., Pretorius, J.-H., Ross, R. and von Fintel, D. (2024). ‘Waar is beter dorp in Zuid Africa dan Stellenbos?’: What the Stellenbosch-Drakenstein Tax Censuses Reveal. *South African Historical Journal*, 76(4), 420–446. doi:[10.1080/02582473.2025.2500410](https://doi.org/10.1080/02582473.2025.2500410). |
| Probate inventories | Fourie, J. (2013). The remarkable wealth of the Dutch Cape Colony: measurements from eighteenth-century probate inventories. *The Economic History Review*, 66(2), 419–448. doi:[10.1111/j.1468-0289.2012.00662.x](https://doi.org/10.1111/j.1468-0289.2012.00662.x). |
| Auction rolls | Fourie, J., Liebenberg, H., Schoots, J. and van der Linde, P. (2025). Auction records, consumer culture and social networks in the Cape Colony, 1701–1825. *South African Journal of Cultural History*, 39(1), 27–49. doi:[10.54272/sach.2025.v39n1a2](https://doi.org/10.54272/sach.2025.v39n1a2). |
| SAF genealogies | Cilliers, J. (2021). The South African Families database. *Historical Life Course Studies*, 11, 97–111. doi:[10.51964/hlcs11095](https://doi.org/10.51964/hlcs11095). |
| Slave emancipation | Ekama, K., Fourie, J., Heese, H. and Martin, L.-C. (2021). When Cape slavery ended: Introducing a new slave emancipation dataset. *Explorations in Economic History*, 81, 101390. doi:[10.1016/j.eeh.2021.101390](https://doi.org/10.1016/j.eeh.2021.101390). |

Release: Fourie, J., Green, E., et al. (2026). *Cape Historical Data
Repository*, version 1.0. Zenodo. DOI: to follow.

BibTeX entries for the six papers are in `references.bib`; GitHub's "Cite
this repository" button uses `CITATION.cff`.

## Contents

```
data/<collection>/   tables (CSV and Parquet) or XML, with README.md and a variable or file list
datapackage.json     machine-readable description of every file and column (Frictionless Data),
                     with each file's size and MD5 checksum
examples/            load_r.R, load_python.py
code/                the R code that made the published files
validation/          validation_report.md: the checks run on the published files
ERRATA.md            corrections found after release
CITATION.cff, references.bib, .zenodo.json   citation metadata
LICENSE              CC BY 4.0 (data); LICENSE-code: MIT (code and examples)
```

## Errors and questions

Errors found after release are listed in `ERRATA.md`; identifiers never
change. Report an error by opening a GitHub issue or writing to leap@sun.ac.za.
