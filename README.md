# Cape Historical Data Repository

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23397436.svg)](https://doi.org/10.5281/zenodo.23397436)

Records on the Cape Colony, 1660–1891, released by LEAP (Laboratory for the
Economics of Africa's Past), Stellenbosch University. Data under CC BY 4.0
(the runaway advertisements under CC BY-NC-SA 4.0); code under MIT.

| Collection | Period | What a row or file is | Format |
|---|---|---|---|
| **Opgaaf** (tax censuses) | 1660–1844, ten districts | A tax declaration (325,628), or a line of a multi-line declaration (15,501) | CSV, Parquet |
| **Slave emancipation** | 1834 | A record of an enslaved person in the emancipation registers (36,417) | CSV, Parquet |
| **SAF genealogies** | People born up to 1870 | A person (213,953), or a marriage with the spouse's details (153,568), in the South African Families database | CSV, Parquet |
| **Runaway advertisements** | 1830–1842 | A person named in a runaway advertisement in *De Zuid Afrikaan* or the *Government Gazette* (881) | CSV, Parquet |
| **1779 petition** | 1779 | A signatory of the Cape Patriots petition (404) | CSV, Parquet |
| **Voortrekkers** | 1835–1845 | A trekker in Visagie's register (2,313), or a marriage (2,978) | CSV, Parquet |
| **Almanac directories** | 1813–1891 | An entry in an edition of the Cape almanacs (97,391; 36 editions) | CSV, Parquet |
| **Auction prices** | 1718–1813 | Yearly prices of 30 goods (2,259 good-years) and the goods sold at each auction (1,513 auctions); derived from the auction rolls | CSV, Parquet |
| **Probate inventories** (MOOC8) | 1673–1844 | Transcription XML, one file per archival volume (75 files, 5,953 documents) | XML |
| **Estate auction rolls** (MOOC10) | 1691–1834 | Transcription XML, one file per volume (42 files, 3,266 auctions) | XML |

Records, not people: rows are not linked across collections or across years. A
tax declaration, an auction buyer and a genealogical entry stay separate even
when they probably describe the same person.

Each collection's folder in `data/` has a `README.md` that explains what the
records are, how they were cleaned and what to watch for, and a variable or
file list describing every column. Read it before using the data.

## Archival sources

Most of these records are transcriptions of documents held by the **Western
Cape Archives and Records Service** (WCARS, formerly the Cape Archives, Cape
Town). We acknowledge the archives and their staff, without whom none of this
material would be available. When you use the data, cite the archival source
alongside the papers listed below.

| Collection | Original records | Archive and reference |
|---|---|---|
| Opgaaf | Annual tax returns (*opgaafrollen*) | WCARS, series J (inventory 1/5), J 1–J 438; early returns in the Nationaal Archief, The Hague, VOC archive 1.04.02, inv. nos 3994–4276. Each district-year: `data/opgaaf/opgaaf_archival_references.csv` |
| Slave emancipation | Valuation lists and slave registers, 1816–1834 | WCARS, Slave Office (inventory 1/21): SO 20 (Slave Compensation Office; e.g. SO 20/10, Graaff-Reinet) and SO 6 (registers of slaves); compensation awards from The National Archives (UK), T 71, via Legacies of British Slavery |
| SAF genealogies | Genealogical registers | Genealogical Institute of South Africa, *Suid-Afrikaanse Geslagsregisters*, compiled from Dutch Reformed Church registers, court marriage records (card index at WCARS) and death notices (WCARS, MOOC 6/9) |
| Runaway advertisements | Newspapers | *De Zuid Afrikaan* and the *Cape of Good Hope Government Gazette*, 1830–1842, from Stellenbosch University Library, the National Library of South Africa (Cape Town) and HathiTrust |
| 1779 petition | The Cape Patriots' petition | WCARS, Council of Policy (inventory 1/1), C 2665, pp. 2–9 |
| Voortrekkers | Visagie's register of the Trek's family heads | Compiled from the Cape officials' emigration lists and other archival sources; the book gives the sources of each entry |
| Almanac directories | Printed almanacs and directories | National Library of South Africa, Cape Town, and WCARS |
| Auction prices | Estate auction rolls | WCARS, Master of the Orphan Chamber, MOOC 10/2–10/24 and 10/26 |
| Probate inventories | Inventories of deceased estates | WCARS, Master of the Orphan Chamber (inventory 1/3), MOOC 8/1–8/75 |
| Estate auction rolls | Vendue rolls | WCARS, Master of the Orphan Chamber (inventory 1/3), MOOC 10/1–10/47 and the index to the vendue rolls |

The references were taken from the papers and the transcribers' records and
checked against the WCARS inventories (published by the TANAP project). Each
collection's README gives the details.

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

Every row of a record table has a permanent `chdr_id` that will not change in
later versions: `OPG-STB-1750-00123` (opgaaf: district, year, spreadsheet row),
`EMA-00001` (emancipation), `SAF-000007` (SAF), `RUN-ZA-001` (runaways:
newspaper and reference number), `PET-001` (petition),
`VTR-0001` (Voortrekkers), `ALM-CAL-1838-00001` (almanacs: publication,
edition, entry). Probate and auction documents are identified by their
archival reference (`MOOC8/10.1`, `MOOC10/25.2`), and the price tables by good,
year and auction reference. The identifiers were derived from source
positions once, when each collection was first released; later versions carry
them over rather than derive them again, so a corrected or reordered source
does not renumber records.

## How to cite

Cite the paper(s) for each collection you use, and this release.

| Collection | Cite |
|---|---|
| Opgaaf | Fourie, J. and Green, E. (2018). Building the Cape of Good Hope Panel. *The History of the Family*, 23(3), 493–502. doi:[10.1080/1081602X.2018.1509367](https://doi.org/10.1080/1081602X.2018.1509367). **And** Fourie, J., Green, E., Burger, C., de Wit, C., Ekama, K., Greyling, J., Heese, H., Pretorius, J.-H., Ross, R. and von Fintel, D. (2024). ‘Waar is beter dorp in Zuid Africa dan Stellenbos?’: What the Stellenbosch-Drakenstein Tax Censuses Reveal. *South African Historical Journal*, 76(4), 420–446. doi:[10.1080/02582473.2025.2500410](https://doi.org/10.1080/02582473.2025.2500410). **And** Rijpma, A., Cilliers, J. and Fourie, J. (2020). Record linkage in the Cape of Good Hope Panel. *Historical Methods*, 53(2), 112–129. doi:[10.1080/01615440.2018.1517030](https://doi.org/10.1080/01615440.2018.1517030). |
| Slave emancipation | Ekama, K., Fourie, J., Heese, H. and Martin, L.-C. (2021). When Cape slavery ended: Introducing a new slave emancipation dataset. *Explorations in Economic History*, 81, 101390. doi:[10.1016/j.eeh.2021.101390](https://doi.org/10.1016/j.eeh.2021.101390). **And** Martins, I., Cilliers, J. and Fourie, J. (2023). Legacies of loss: The health outcomes of slaveholder compensation in the British Cape Colony. *Explorations in Economic History*, 89, 101506. doi:[10.1016/j.eeh.2022.101506](https://doi.org/10.1016/j.eeh.2022.101506). |
| SAF genealogies | Cilliers, J. (2021). The South African Families database. *Historical Life Course Studies*, 11, 97–111. doi:[10.51964/hlcs11095](https://doi.org/10.51964/hlcs11095). **And** Cilliers, J., Green, E., McCants, A. E. and Rijpma, A. (2025). Wealth and marriage at the Cape: consanguineous unions as a strategy. *The History of the Family*, 30(2), 258–284. doi:[10.1080/1081602X.2025.2478381](https://doi.org/10.1080/1081602X.2025.2478381). |
| Runaway advertisements | Bergemann, K. (2025). Creating the Cape Colony Runaway Advertisements Datasets, 1830–1842. *Journal of Slavery and Data Preservation*, 6(1), 1–14. doi:[10.14321/jsdp.6.1.0001](https://doi.org/10.14321/jsdp.6.1.0001). **And** Bergemann, K., Brown, G. and Fourie, J. (2026). Running towards: Labour market incentives for runaway slaves in the British Cape Colony, 1830–1838. *Asia-Pacific Economic History Review*. doi:[10.1111/aehr.70034](https://doi.org/10.1111/aehr.70034). Original deposit: Bergemann, K., Ekama, K. and Fourie, J. (2025), Harvard Dataverse, doi:[10.7910/DVN/R1IAFM](https://doi.org/10.7910/DVN/R1IAFM). |
| 1779 petition | Schoots, J. and Fourie, J. (2026). Protest from above: Elite decoupling and public petitioning in the VOC Cape Colony. Working paper, Stellenbosch University. Source: WCARS C 2665, transcribed in Baartman, T. (2011), PhD thesis, University of Cape Town. |
| Voortrekkers | Fourie, J. and Links, C. (forthcoming). Selection into the Great Trek. *European Review of Economic History*. **And** the register: Visagie, J. C. (2011). *Voortrekkerstamouers 1835–1845*, 2nd ed. Pretoria: Protea Boekhuis. |
| Almanac directories | Ross, R. and Martin, L.-C. (2021). Accommodation and resistance: The housing of Cape Town's enslaved and freed population before and after emancipation. *Journal of Southern African Studies*, 47(3), 417–435. doi:[10.1080/03057070.2021.1904751](https://doi.org/10.1080/03057070.2021.1904751). |
| Auction prices | Walters, L., Schoots, J. and Fourie, J. (2026). Prices and living standards: evidence from Cape Colony auction rolls. *Cliometrica*. doi:[10.1007/s11698-026-00339-9](https://doi.org/10.1007/s11698-026-00339-9). |
| Probate inventories | Fourie, J. (2013). The remarkable wealth of the Dutch Cape Colony: measurements from eighteenth-century probate inventories. *The Economic History Review*, 66(2), 419–448. doi:[10.1111/j.1468-0289.2012.00662.x](https://doi.org/10.1111/j.1468-0289.2012.00662.x). |
| Auction rolls | Fourie, J., Liebenberg, H., Schoots, J. and van der Linde, P. (2025). Auction records, consumer culture and social networks in the Cape Colony, 1701–1825. *South African Journal of Cultural History*, 39(1), 27–49. doi:[10.54272/sach.2025.v39n1a2](https://doi.org/10.54272/sach.2025.v39n1a2). |

Release: Fourie, J., Green, E., et al. (2026). *Cape Historical Data
Repository*. Zenodo.
doi:[10.5281/zenodo.23397436](https://doi.org/10.5281/zenodo.23397436)
(all versions; it resolves to the latest). Version 1.1:
doi:[10.5281/zenodo.23419842](https://doi.org/10.5281/zenodo.23419842);
version 1.0: doi:[10.5281/zenodo.23397437](https://doi.org/10.5281/zenodo.23397437).
Each version has its own DOI on Zenodo; cite the one you used.

BibTeX entries for the papers and sources are in `references.bib`; GitHub's
"Cite this repository" button uses `CITATION.cff`.

## Funding

The transcription of these records was funded by **Riksbankens
Jubileumsfond** (the Bank of Sweden Tercentenary Foundation) through the Cape
of Good Hope Panel project, *The establishment, growth and legacy of a settler
colony: Quantitative panel studies of the political economy of Cape Colony*
(grant M20-0041). The project set out to transcribe the full series of the
Cape's annual tax censuses (*opgaafrolle*), which record the settler
population and the enslaved and Khoesan people who worked in the colonial
economy, to combine them with probate inventories, auction rolls and
genealogies, and so to study living standards and economic development,
inequality and social mobility, networks and elite formation, and slavery and
labour coercion in a pre-industrial colonial society. This repository makes
the records it assembled available to all.

## Licence

The data are licensed under CC BY 4.0 (`LICENSE`), except
`data/runaways/`, which keeps the CC BY-NC-SA 4.0 licence of its original
deposit (`data/runaways/LICENSE.md`): non-commercial use only, and
adaptations under the same licence. The code and examples are under MIT
(`LICENSE-code`).

## Contents

```
data/<collection>/   tables (CSV and Parquet) or XML, with README.md and a variable or file list
datapackage.json     machine-readable description of every file and column (Frictionless Data),
                     with each file's size and MD5 checksum
examples/            load_r.R, load_python.py
code/                the code that made the published files
validation/          validation_report.md: the checks run on the published files
ERRATA.md            corrections found after release
CITATION.cff, references.bib, .zenodo.json   citation metadata
LICENSE              CC BY 4.0 (data); LICENSE-code: MIT (code and examples)
```

## Versions

- **1.1** (16 October 2026; doi:10.5281/zenodo.23419842): adds the runaway advertisements, the 1779 petition,
  the Voortrekker register, the almanac directories and the auction prices, and a further paper to cite for the
  opgaaf, emancipation and SAF collections. The 1.0 data files are unchanged.
- **1.0** (15 October 2026): opgaaf, slave emancipation, SAF, probate
  inventories and auction rolls.

## Errors and questions

Errors found after release are listed in `ERRATA.md`; identifiers never
change. Report an error by opening a GitHub issue or writing to leap@sun.ac.za.
