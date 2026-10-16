# Code

The R code that made the published files, for transparency. It reads the
source files (the transcribers' opgaaf workbooks, the SAF, emancipation,
price, petition and Voortrekker workbooks, the almanac database,
the runaway files of the Dataverse deposit and the original MOOC XML files),
which are not part of this release, so it cannot be rerun from the repository
alone. Each script states
what it does and asserts its checks as it runs.

| Folder | Makes |
|---|---|
| `opgaaf/` | `data/opgaaf/`. `run_opgaaf.R` runs stages `00`–`07` (about 35 minutes). Stages `00`–`06` are LEAP's internal release pipeline of 25 September 2026 (labelled "v2" in the code), changed only in file paths; stage `07_public_release.R` assigns the `chdr_id` identifiers, leaves out redundant columns and writes the public files; `08_archival_references.R` writes `opgaaf_archival_references.csv` from the transcribers' indexes. |
| `emancipation/` | `data/emancipation/` |
| `saf/` | `data/saf/` |
| `runaways/` | `data/runaways/`, from the two CSV files of the Harvard Dataverse deposit |
| `prices/` | `data/prices/`, from the authors' price workbook; checks every auction against the MOOC10 XML |
| `petition1779/` | `data/petition1779/` |
| `voortrekkers/` | `data/voortrekkers/`: splits the marriages and realigns blocks typed in the wrong columns (`voortrekkers_realignments.csv`) |
| `almanacs/` | `data/almanacs/`: `00_export_mdb.ps1` exports the Access database's tables (Windows, ACE OLEDB); `01_almanacs.R` maps their columns onto one table |
| `xml/` | `data/probate/` and `data/auctions/`: `01_rename_and_check.R` copies the XML under tidy names and checks that it parses; `02_probate_corrections.R` applies the probate corrections listed in `data/probate/corrections.txt`; `03_auction_corrections.R` removes the DTD declaration from auction volumes 15–18 (`data/auctions/corrections.txt`). |
| `package/` | `citations.R` lists the creators and the works to cite; `00_citation_files.R` writes `CITATION.cff` and `.zenodo.json` from it; `01_copy_code.R` makes this folder's copy of the code; `02_validate.R` writes `validation/validation_report.md`; `03_datapackage.R` writes `datapackage.json` |

The scripts expect to run from a project folder that holds them in
`pipeline/`, the source files in `sources/raw/` and the published files in
`release/` (paths are set with `here::here()`). They use R 4.5 with the
tidyverse, `readxl`, `openxlsx`, `xml2`, `nanoparquet` and `jsonlite`.
