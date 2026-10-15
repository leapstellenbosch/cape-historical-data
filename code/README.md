# Code

The R code that made the published files, for transparency. It reads the
source files (the transcribers' opgaaf workbooks, the SAF and emancipation
workbooks and the original MOOC XML files), which are not part of this
release, so it cannot be rerun from the repository alone. Each script states
what it does and asserts its checks as it runs.

| Folder | Makes |
|---|---|
| `opgaaf/` | `data/opgaaf/`. `run_opgaaf.R` runs stages `00`–`07` (about 35 minutes). Stages `00`–`06` are LEAP's internal release pipeline of 25 September 2026 (labelled "v2" in the code), changed only in file paths; stage `07_public_release.R` assigns the `chdr_id` identifiers, leaves out redundant columns and writes the public files. |
| `emancipation/` | `data/emancipation/` |
| `saf/` | `data/saf/` |
| `xml/` | `data/probate/` and `data/auctions/`: `01_rename_and_check.R` copies the XML under tidy names and checks that it parses; `02_probate_corrections.R` applies the probate corrections listed in `data/probate/corrections.txt`; `03_auction_corrections.R` removes the DTD declaration from auction volumes 15–18 (`data/auctions/corrections.txt`). |
| `package/` | This folder's copy of the code, `validation/validation_report.md` and `datapackage.json` |

The scripts expect to run from a project folder that holds them in
`pipeline/`, the source files in `sources/raw/` and the published files in
`release/` (paths are set with `here::here()`). They use R 4.5 with the
tidyverse, `readxl`, `openxlsx`, `xml2`, `nanoparquet` and `jsonlite`.
