# South African Families (SAF) genealogies, people born up to 1870

The South African Families database is a genealogical register of settler
families at the Cape and their descendants. It was compiled from baptism,
marriage and death records and published genealogies. This collection holds
everyone born up to and including 1870: **213,953 persons** and their
**153,568 marriages**, each with the spouse's details.

The family structure (who descends from whom) is the compilers'
reconstruction, not an observed record. People are not linked to the other
collections.

**Cite:** Cilliers, J. (2021), "The South African Families Database",
*Historical Life Course Studies* 11: 97–111,
doi:[10.51964/hlcs11095](https://doi.org/10.51964/hlcs11095).

## Files

Each table is a CSV and a Parquet file.

| File | One row per |
|---|---|
| `saf_persons` | Person in the genealogy (a "principal") |
| `saf_marriages` | Marriage of a principal (up to four), with the spouse's details |

`saf_variables.csv` describes every column of both tables and the source
column it comes from (`{n}` is the marriage slot, 1–4).

## Identifiers and the genealogical code

`individual_id` is SAF's genealogical code. The family name is followed by
letters for generations and numbers for birth order: `ABAGOSTUSa1b1` is the
first child (`b1`) of the progenitor `ABAGOSTUSa1`; a question mark stands
for an unknown birth order. The code without its final number is the
sibling group. Because the codes contain spaces, hyphens, question marks and
brackets, they cannot serve as web identifiers, so `chdr_id`
numbers the person's spreadsheet row instead: `SAF-000007` is row 8 of the
source sheet. A marriage is `SAF-000007-M1`.

`spouse_code` is SAF's code for the spouse in a marriage: `ABAGOSTUSa1_1` is
the first spouse of `ABAGOSTUSa1`. A person's `mother_spouse_code` names the
marriage they were born to, so it matches `spouse_code` in `saf_marriages`
where that marriage is in the release (all but 437 of the 175,638 persons
with a `mother_spouse_code`; the others point to marriages that are not in
the release).
Where two people share a genealogical code (`id_flag`), their marriages share
spouse codes too (33 codes on 66 marriages in this release), so a join on these codes can
match more than one row; use `chdr_id` and `principal_chdr_id` to tell them
apart.

## Who is included

A person is included if born in or before 1870; the birth year decides when
it is usable (between 1600 and 2014), otherwise the baptism year. Someone with
neither a usable birth nor a usable baptism year is included if other dates
place their birth by 1870: married or died by 1890, a parent born by 1840 or
a child born by 1895. So a few people with an implausible birth year (such as
1018, flagged in `date_flag`) are included through another rule.
`inclusion_basis` records which rule applied (`birth`, `baptism`,
`marriage`, `death`, `parent`, `child`).

A marriage is included if either partner is. The spouse is judged on their
own birth or baptism year; an undated spouse goes with the principal
(`spouse_inclusion_basis` = `principal`). Where the spouse was born after
1870, the marriage is kept but the spouse's details are left blank
(`spouse_inclusion_basis` is empty; 4,728 marriages). Where the principal was
born after 1870, the marriage appears without a matching row in
`saf_persons` (2,879 marriages).

## Reading the data

- **Dates are separate year, month and day columns**, because most are
  incomplete.
- **Implausible values are flagged, not corrected.** `date_flag` names each
  field outside 1600–2014, months outside 1–12, days outside 1–31, and death
  before birth (165 persons and 124 marriages).
- `sex` is as recorded: `m`, `f`, `u` (unknown, 428 persons) and a few other
  codes.
- `generation` is as recorded; a handful of negative values remain.
- `spouse_daughter_of` and `spouse_son_of` are verbatim and often hold notes
  rather than a parent's name.
- `id_flag` marks the 1,586 codes that occur twice in the sheet:
  `exact_duplicate_row_removed` (the second, identical row was dropped),
  `repeated_id_same_name` (same name and birth year, other fields differ;
  both rows kept) and `repeated_id_different_person` (two different people
  share the code; both kept, each with its own `chdr_id`).

## How the tables were made

The pipeline in `code/saf/` reads the 126-column sheet (version of 10
February 2014), drops the 1,524 exact duplicate rows, turns each person's
four marriage slots into rows of the marriage table, and applies the
inclusion rule. Nothing that repeats or can be derived from another column
is published: the family code (`individual_id` without its final number),
the marriage markers (all "x"), `startyear` (the birth year, else the
baptism year) and the spouse ID columns (always `{individual_id}_{n}`) are
dropped, as are the divorce columns, which are empty.

**Accented letters were repaired.** In the source sheet every accented
letter and typographic quotation mark was garbled ("Henri**Î´**tte" for
Henriëtte, "St Mary**Ã†**s" for St Mary’s): the text had once been saved in
Windows-1252, read as the DOS code page 437, and saved again. The pipeline
reverses these steps for the 60,997 affected cells. A cell is changed only if
garbling the repaired text again gives back the source cell exactly, which
holds for every one, so the repair is lossless. A few characters that look
odd are as the compilers typed them: `÷` (divorced), `±` (about), and `ÿ` or
`Ÿ` for the Dutch *ij* (`Lodewÿk`, `Ÿda`). No other value was changed.
