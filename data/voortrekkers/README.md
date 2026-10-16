# Voortrekker register

The Voortrekkers left the Cape Colony between 1835 and 1845. This collection
holds **2,313 trekkers** from J.C. Visagie's genealogical register of the
Trek's family heads, with their birth, baptism and death, the ward and
district they left, when they left, the leader they trekked with and where
they went; and **2,978 marriages**, with the spouses' details.

Each row is an entry in the register; no trekker is linked to other
collections.

**Cite:** Fourie, J. and Links, C. (forthcoming), "Selection into the Great
Trek", *European Review of Economic History*.

**Original source:** Visagie, J.C. (2011), *Voortrekkerstamouers 1835–1845*,
2nd edition, Pretoria: Protea Boekhuis (first edition: Universiteit van
Suid-Afrika, 2000). The register is the compiler's work; cite it whenever you
use these data. Visagie compiled it from the Cape officials' lists of people
who left the colony, other archival sources (many at the Western Cape
Archives and Records Service) and the genealogies of the Genealogical
Institute of South Africa; the book gives the sources of each entry, and they
are not repeated here.

## Files

| File | Contents |
|---|---|
| `voortrekkers_persons.csv` | One row per trekker (also as `.parquet`) |
| `voortrekkers_marriages.csv` | One row per marriage, up to five per trekker (also as `.parquet`) |
| `voortrekkers_realignments.csv` | The 74 rows of the source sheet in which a block of dates and places had been typed in the wrong columns, and how each was read |
| `voortrekkers_variables.csv` | Every variable, its source column and meaning |

`chdr_id` is `VTR-` and the row of the source sheet less one (`VTR-0001` is
row 2); a marriage is the trekker's identifier and `-M1` to `-M5`.

## Reading the data

- **Dates** are written in ISO 8601 where the source can be read without
  doubt: `1817-01-07`, `1835-09`, `1835`, or an interval `1804-11-28/1804-11-29`.
  Otherwise (1,202 of 11,812 dates) they are kept as transcribed: `CA 1813`,
  `BEFORE 1840`, `04 OR 05/1838`, `EARLY 1840'S`, or a typo such as
  `115/07/1821`. Dates that Excel stored as dates (32 cells, all after 1900)
  are written in ISO form; two of them fall after 1950, which cannot be
  right, and are marked `EXCEL DATE` (e.g. `EXCEL DATE 2012-09-13`).
- `genealogical_number` is Visagie's number: a letter per generation and the
  birth order (`b1c2d3`), with the transcriber's query marks; the progenitor's
  `a1` is implied where it is absent. Surname and number together identify a
  trekker.
- `trek_party` and `trek_destination` are as written, and spellings vary
  (`A.H. POTGIETER` and `A.H POTGIETER`, `P. RETIEF` and `PIET RETIEF`;
  `TRANSORANJE` and `OVS`). `FAMILY MOVE` means the family trekked on its own.
- Places, names and notes are in the register's Afrikaans and are as
  transcribed; `notes` records battles and family ties.

## How the file was made

From the workbook compiled for Fourie and Links (`Voortrekkers 2.xlsx`, sheet
`Main`, one row per trekker), the pipeline in `code/voortrekkers/`:

- keeps the 2,313 trekkers (rows 2–2314) and leaves out a stray fragment in
  row 2703, which repeats spouse details from row 2306;
- splits the marriages, kept side by side in the sheet, into their own table;
- **realigns blocks typed in the wrong columns.** In 74 rows a person's dates or
  a marriage was entered one or two columns to the left or right of its
  headings (a birth date under "birth place", a spouse's name under "marriage
  date"), or, for third and fourth marriages, with a birth-place column the
  headings lack. Each block is read in the position where its cells have the
  right types (dates under dates, genealogical numbers under numbers, text
  under places and names) and its dates run in order (birth and baptism before
  marriage and death); a cell is moved off a heading only where it is of the
  wrong type for that heading, and stays with the same event where it can (a
  date under "place of death" becomes the death date). Cells that fit no field
  unambiguously stay where they were typed (such as a date of 1888 under the
  spouse's genealogical number). One block was placed by hand (row 2306,
  confirmed by the fragment in row 2703). Every change is listed in
  `voortrekkers_realignments.csv`;
- reads dates that Excel stored as dates (after 1900) as dates, not as the
  day numbers Excel keeps (387 is 21 January 1901), and writes dates in ISO
  form where they can be read without doubt;
- drops the derived columns (years, the surname without spaces, the name in
  title case, the number with `a1` inserted, and the identifier built from
  them).
