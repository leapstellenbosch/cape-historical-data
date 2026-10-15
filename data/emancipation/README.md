# Slave emancipation records, 1834

When slavery was abolished in the British Empire in 1834, slaveholders at the
Cape registered the people they held and claimed compensation. This collection
holds **36,417 records** of enslaved people in eleven districts: name, age,
sex, occupation, origin, slaveholder, place, appraised value and the
compensation claim.

Each row is a record in the registers, not a verified unique person, and no
record is linked to other collections.

**Cite:** Ekama, K., Fourie, J., Heese, H. and Martin, L.-C. (2021), "When Cape
slavery ended: Introducing a new slave emancipation dataset", *Explorations in
Economic History* 81, 101390,
doi:[10.1016/j.eeh.2021.101390](https://doi.org/10.1016/j.eeh.2021.101390).

## Files

| File | Contents |
|---|---|
| `emancipation_persons.csv` | One row per record (also as `.parquet`) |
| `emancipation_variables.csv` | Every variable, its source column and meaning |

`chdr_id` numbers the records in workbook order: `EMA-00001` is the first
record (spreadsheet row 2).

## Reading the data

- **`claim_compensation` is an award for a claim**, not for the person on that
  row, and must not be summed across people. It is usually entered on one row
  of the claim (4,088 claims). In 198 claims it appears on several rows, usually
  once per owner and sometimes repeating the same amount. In 26 of these the
  amounts differ: some claims list several owners, each with an award, and a
  few rows of one owner differ slightly (claim 5086: £2,241.50 and £2,240.50),
  as recorded. Compensation is on 4 rows that have no claim number, and 227
  claims have none. For a total per claim, take the distinct amounts within
  `lbs_claim_number` and look at claims with more than one before adding them.
- **Currency.** Valuations and compensation are as recorded, in pounds
  sterling with shillings and pence as decimal fractions. Some valuations may
  be in rixdollars; none has been converted. All valuations are below £300.
- `valuation` is missing for 14,434 records, including all of Clanwilliam and
  Swellendam. Zero valuations (170) are kept as recorded.
- `lbs_claim_number` is the claim number used by the
  [Legacies of British Slavery](https://www.ucl.ac.uk/lbs/) database at UCL,
  so records can be matched to it. A few claim numbers carry a letter
  (`508a`); `ND` is kept as recorded.
- `occupation` reads "Not Specified" where the source gives none (19,022
  records); it is missing for the 76 records where the workbook reads "NA".
  `origin` is NA where not recorded; "Cape" means born in the colony.
- Names, owners, places and notes are as recorded, in the source's Dutch and
  English. `owner_note` holds qualifiers written with the owner's name
  (*sr*, *jr*, *oorlede* "deceased", *Weduwee* "widow", *sv* "son of").

## How the file was made

From the project workbook, the pipeline in `code/emancipation/` keeps the
recorded fields and drops the research coding (name categories, HISCO codes,
origin regions, owner-origin indicators, logs and squares), which belong to
the paper. Whitespace was trimmed (457 cells), the spacing of claim numbers
made uniform, one impossible age (−1) and the 76 occupations written "NA"
set to missing, and valuations and compensation given to the 15 significant
digits the workbook displays (some cells held binary rounding noise from
formulas, such as 42.449999999999996 for 42.45). No other value was changed.
