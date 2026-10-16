# Opgaaf tax censuses, 1660–1844

The *opgaafrollen* were the annual tax returns of the Cape Colony. Each
household head, or other taxable unit, declared the people in the
household, the enslaved and Khoe people attached to it, and its livestock,
crops, vines, wine and tax. This collection holds **325,628 tax units** and
**335,525 source entries** from 375 year sheets in ten districts: Albany, Cape,
Clanwilliam, George, Graaff-Reinet, Stellenbosch, Swellendam, Tulbagh,
Uitenhage and Worcester.

The opgaaf were transcribed in the Cape of Good Hope Panel project, funded by
Riksbankens Jubileumsfond (grant M20-0041).

These are repeated annual observations of declarations. They are not counts of
unique people, and no person or household is linked across years.

**Cite:** Fourie, J. and Green, E. (2018), *The History of the Family*,
doi:[10.1080/1081602X.2018.1509367](https://doi.org/10.1080/1081602X.2018.1509367),
and Fourie, J., Green, E., Burger, C., de Wit, C., Ekama, K., Greyling, J.,
Heese, H., Pretorius, J.-H., Ross, R. and von Fintel, D. (2024),
*South African Historical Journal*,
doi:[10.1080/02582473.2025.2500410](https://doi.org/10.1080/02582473.2025.2500410),
and Rijpma, A., Cilliers, J. and Fourie, J. (2020), "Record linkage in the Cape
of Good Hope Panel", *Historical Methods* 53(2): 112–129,
doi:[10.1080/01615440.2018.1517030](https://doi.org/10.1080/01615440.2018.1517030).

**Archival source:** the original returns are held by the Western Cape Archives and Records Service (WCARS), Cape Town, in
the opgaafrollen (returns for taxation purposes), series **J** (WCARS
inventory 1/5), volumes J 1 to J 438. Returns not preserved in Cape Town,
mostly before 1764, were transcribed from the copies sent to the Netherlands,
now in the **Nationaal Archief, The Hague**, archive of the Dutch East India
Company (VOC), 1.04.02, inventory numbers 3994 to 4276. The volume or
inventory number of every district-year is in `opgaaf_archival_references.csv`.

## Files

| File | Contents |
|---|---|
| `opgaaf_tax_units` | One row per tax unit (CSV and Parquet) |
| `opgaaf_entries` | The 15,501 transcribed lines of the 5,604 tax units that combine several lines (CSV and Parquet) |
| `opgaaf_sheet_inventory.csv` | One row per district and year: workbook, sheet, form type, header rows |
| `opgaaf_variables.csv` | Every variable: type, meaning, population group, sex, age limits |
| `opgaaf_schema_registry.csv` | Every original column header in every sheet, the variable it maps to and the confidence of the mapping |
| `opgaaf_quality_flags.csv` | Cell- and row-level warnings and exclusions |
| `opgaaf_archival_references.csv` | The archive and reference (WCARS volume or VOC inventory number) of the original return of each district and year |
| `opgaaf_corrections_log.csv` | Every correction or interpretation applied to the transcription |

The tables are parsimonious: no column is empty, constant, a copy of another,
or derivable from the row, its identifier or the sheet inventory. So:

- **Form type, workbook and sheet** are attributes of a district-year (each
  has one sheet) and are in `opgaaf_sheet_inventory.csv`; join on `district`
  and `year`.
- **The entries table holds only multi-line tax units.** Most declarations
  are one line, and the tax unit then equals that line. Where a declaration
  continues on further lines (sub-entries), the tax unit sums them, and
  `opgaaf_entries.csv` gives each line; `-E1` is the declaration.
- Derived totals (such as the sum of recorded people) and lists of names are
  not included; compute them from the columns.

```r
library(readr); library(dplyr)
units <- read_csv("data/opgaaf/opgaaf_tax_units.csv", guess_max = Inf)
sheets <- read_csv("data/opgaaf/opgaaf_sheet_inventory.csv")
units <- left_join(units, select(sheets, district, year, form_type), by = c("district", "year"))
```

Use `guess_max = Inf` (or specify column types): many variables appear only in
later forms, and default type guessing on the first rows will misread them.

## Identifiers

`chdr_id` is the permanent identifier: `OPG-{district}-{year}-{row}` for a tax
unit, where `row` is the spreadsheet row of the declaration, and
`OPG-…-E{n}` for the *n*-th line of that unit. District codes: ALB Albany,
CAP Cape, CLW Clanwilliam, GEO George, GRF Graaff-Reinet, STB Stellenbosch,
SWL Swellendam, TUL Tulbagh, UIT Uitenhage, WOR Worcester. Lines carry
`tax_unit_chdr_id` for joining; quality flags carry the `tax_unit_chdr_id`
of the record they concern.

## Reading the data

- **Tax units are administrative declarations, not verified households.**
  `form_type` (in the sheet inventory) distinguishes ordinary returns,
  capitation lists, named-adult lists and aggregate returns for establishments.
- **Blank is NA, never zero.** NA can mean unrecorded, illegible, ambiguous or
  not on that year's form; `opgaaf_schema_registry.csv` shows which variables
  each sheet's form contains. Explicit zeros are kept as zeros. Ditto marks and
  ambiguous numbers are not guessed.
- A sum of the person counts is not household size: named heads and spouses
  are not counted separately, and the categories differ between forms.
- **Status labels follow the source** (settler, enslaved, Khoe, free black,
  prize negro). Age limits vary between forms; the original headers in the
  schema registry are authoritative.
- Farm names, tenure, distances, land use and transcribers' notes are verbatim
  (`*_raw` columns). Early Clanwilliam tax columns have no currency and stay as
  recorded.
- In five of the George and Clanwilliam sheets, `khoe_in_service_*` and
  `slave_in_service_*` record the separate *In Dienst Hebbende* blocks. They are
  not part of the family counts, because their overlap with the other blocks
  is unknown.
- Columns that some forms printed but no clerk ever filled in (such as
  Clanwilliam 1824's prize-negro children by origin) are not included.

## Known problems

- **George 1826 tax columns need checking against the archival images before
  any quantitative use.** Tax amounts appear on blank and folio rows, which
  suggests that the column has slipped vertically. Amounts on named rows are
  kept where they were transcribed; orphan amounts are not assigned to anyone.
- Three unnumbered but complete Clanwilliam declarations (1809 row 276, 1811
  row 293, 1812 row 268) are kept as separate tax units.
- Four unresolved cells in three rows remain excluded (Swellendam 1824 row 883;
  Cape 1722 row 140; Stellenbosch 1835 row 1252).
- Mapping confidence B means the transcription headers and structural checks
  were reviewed, not the archival images. C mappings are excluded. None of the
  checks shows that the transcription itself is free of error.

## How the files were made

The transcribers' workbooks were read by the pipeline in `code/opgaaf/`, which
maps every header to a variable, extracts and cleans every entry, aggregates
entries into tax units and runs the release checks. Every value is identical
to LEAP's internal v2 release of 25 September 2026 (checked cell by cell);
the public tables differ only in their identifiers and in leaving out the
redundant columns described above.
