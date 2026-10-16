# Cape almanac directories, 1813–1891

The Cape's annual almanacs listed the colony's officials, merchants and
inhabitants, with occupations and street addresses. This collection holds
**97,391 directory entries from 36 editions**, 1813–1891: the African Court
Calendar (1813–1827), the Cape Advertiser's directory (1821), the Cape Almanac
(1828–1891) and the 1881 Transvaal Almanac. 39,795 entries come from the 22
editions before 1850.

Each row is an entry in one edition. The same person appears in many editions
and sometimes twice in one (under a town and in an official list); entries are
not linked.

**Cite:** Ross, R. and Martin, L.-C. (2021), "Accommodation and resistance:
The housing of Cape Town's enslaved and freed population before and after
emancipation", *Journal of Southern African Studies* 47(3), 417–435,
doi:[10.1080/03057070.2021.1904751](https://doi.org/10.1080/03057070.2021.1904751).

**Original sources:** the printed almanacs and directories. A full set of the
Cape directories and almanacs, 1800–1902, is held by the National Library of
South Africa, Cape Town. The editions were transcribed by volunteers, named in
the `transcriber` column, from copies at the Western Cape Archives and Records
Service and the National Library (the "Consulted at" column below).

## Files

| File | Contents |
|---|---|
| `almanacs_entries.csv` | One row per directory entry (also as `.parquet`) |
| `almanacs_removed_repeats.csv` | The 456 entries typed twice, which were removed, and the entry each repeats |
| `almanacs_variables.csv` | Every variable, its source columns and meaning |

`chdr_id` gives the publication, the edition and the entry's position in that
edition's table: `ALM-CAL-1838-00001` (ACC African Court Calendar, CAD Cape
Advertiser, CAL Cape Almanac, TVL Transvaal Almanac).

## Editions

| Year | Publication | Entries | Consulted at |
|---|---|--:|---|
| 1813 | African Court Calendar | 1,228 | |
| 1814 | African Court Calendar | 1,069 | |
| 1816 | African Court Calendar | 1,478 | |
| 1817 | African Court Calendar | 1,675 | |
| 1818 | African Court Calendar | 2,681 | |
| 1819 | African Court Calendar | 1,314 | |
| 1820 | African Court Calendar | 1,568 | |
| 1821 | Cape Advertiser | 1,547 | National Archives & National Library |
| 1822 | African Court Calendar | 1,338 | |
| 1824 | African Court Calendar | 975 | |
| 1825 | African Court Calendar | 1,542 | National Archives & Library |
| 1827 | African Court Calendar | 1,262 | |
| 1828 | Cape Almanac | 1,601 | National Archives & Library |
| 1829 | Cape Almanac | 1,366 | National Archives, Cape Town |
| 1831 | Cape Almanac | 2,060 | National Archives & National Library |
| 1833 | Cape Almanac | 2,625 | National Archives |
| 1835 | Cape Almanac | 1,924 | National Archives, Cape Town |
| 1838 | Cape Almanac | 2,465 | National Archives & Library |
| 1841 | Cape Almanac | 1,862 | National Archives & National Library |
| 1845 | Cape Almanac | 2,144 | National Archives, Cape Town |
| 1847 | Cape Almanac | 3,395 | National Archives & Library |
| 1849 | Cape Almanac | 2,676 | National Archives, Cape Town |
| 1851 | Cape Almanac | 3,748 | National Archives & National Library |
| 1854 | Cape Almanac | 4,461 | National Archives |
| 1855 | Cape Almanac | 1,420 | National Archives & Library |
| 1861 | Cape Almanac | 4,400 | National Archives & National Library |
| 1863 | Cape Almanac | 3,646 | |
| 1865 | Cape Almanac | 4,679 | National Archives & Library |
| 1866 | Cape Almanac | 5,117 | National Archives & National Library |
| 1868 | Cape Almanac | 4,451 | |
| 1871 | Cape Almanac | 4,201 | National Archives & National Library |
| 1875 | Cape Almanac | 4,339 | National Archives & Library |
| 1881 | Cape Almanac | 3,534 | National Archives & National Library |
| 1881 | Transvaal Almanac | 1,807 | |
| 1886 | Cape Almanac | 4,166 | |
| 1891 | Cape Almanac | 7,627 | National Archives |

## Reading the data

- **Coverage varies by edition.** Early editions list Cape Town; later ones
  add other towns and districts, often under headings (`Inhabitants of
  Grahamstown`) that the transcriber put in `notes` or, in six editions, in
  `section`. Some editions are partial transcriptions. Counts across editions
  are not population counts.
- `surname` also holds the names of firms and institutions (`Lawton & Whitta`).
- `title` is as printed (Mrs, Widow, Rev., Junior), with its variant
  spellings; `occupation` and `address` are as printed, in English or Dutch.
- `image` names the page image transcribed from (not published here); it is
  missing for editions whose transcriber did not record it.

## How the file was made

From the Access database `Almanacs.mdb` (one table per edition), the
pipeline in `code/almanacs/` exports each table (`00_export_mdb.ps1`) and then
(`01_almanacs.R`):

- maps the editions' differing column names onto one set (for example
  `Surname`, `Surname Or Business` and `Surname Or Company Name` become
  `surname`);
- trims spaces, and turns placeholders into missing values: "Not given",
  "Unknown" and similar in 350 surnames and two first names;
- drops one empty row, and **removes 456 entries typed twice**: entries
  identical in every column, page image and transcriber included, within one
  edition (most next to each other, some a run of entries typed again further
  on). The first is kept; each removed entry is listed in
  `almanacs_removed_repeats.csv`;
- leaves out the record type (always "Sub"), the database's record numbers,
  and the edition name typed on each row, which the table name gives (in the
  1813 table it had been filled down as 1814, 1815, … 1889).

Spellings are not standardised.
