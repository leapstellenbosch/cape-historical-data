# Estate auction rolls of the Orphan Chamber (MOOC10), 1691–1834

When the Orphan Chamber (*Weeskamer*) sold a deceased person's estate at
public auction, a clerk drew up a *vendurol* (auction roll): the name of the
deceased, the date and place of the sale, and then, lot by lot, the item, the
buyer and the price. This collection is the complete transcription of the 47
volumes of the archival series MOOC10 (Master of the Orphan Chamber, series
10) in the Western Cape Archives: **3,266 auction documents**, dated 1691 to
1834, and the volumes' own indexes.

The files are the transcriptions as made by the TEPC project (Transcription
of Estate Papers at the Cape of Good Hope) and the Tracing History Trust,
published unchanged apart from one line in four files (below). They are in
Dutch, as written.

**Cite:** Fourie, J., Liebenberg, H., Schoots, J. and van der Linde, P. (2025),
"Auction records, consumer culture and social networks in the Cape Colony,
1701–1825", *South African Journal of Cultural History* 39(1): 27–49,
doi:[10.54272/sach.2025.v39n1a2](https://doi.org/10.54272/sach.2025.v39n1a2).

**Archival source:** the Western Cape Archives and Records Service (WCARS), Cape Town, records of the Master of the Orphan
Chamber (MOOC, WCARS inventory 1/3): **MOOC 10/1–10/47**, vendue rolls
(*vendurollen*), 1691–1834, and an index to the vendue rolls. The loose rolls
in MOOC 10/48 are not included. The file for each volume is named after it
(`MOOC10_vol25.xml` is MOOC 10/25). The rolls were transcribed on site from
the original documents and converted to XML by the Tracing History Trust.

## Files

| File | Contents |
|---|---|
| `xml/MOOC10_vol01-05.xml`, `MOOC10_vol06-08.xml` | Volumes 1–5 and 6–8, each transcribed as one file |
| `xml/MOOC10_vol09.xml` … `MOOC10_vol47.xml` | One file per volume |
| `xml/MOOC10_index.xml` | The series index (*Hoofindeks*) of the deceased, 1691–1833 |
| `file_names.txt` | New file name, original file name, number of documents, size and MD5 checksum (tab-separated) |
| `corrections.txt` | The change made to the transcribers' files, with the MD5 checksum of each original (tab-separated) |

The files were renamed for clarity. For volumes 15–18 two versions were
supplied; the later corrected versions (`-R`) are published. Thirty-eight
files are byte-identical to the transcribers' files. In the other four
(volumes 15–18) the first line declared a document type definition (DTD) by
a path on a transcriber's computer; the DTD was not supplied, and the
declaration was removed. Every other byte is as transcribed.

## Markup

The XML uses a small subset of TEI (Text Encoding Initiative). A sale:

```xml
<div n="MOOC10/25.2">                                  <!-- archival reference -->
  <head>
    <name type="person" reg="Plessies, Gabriel du">Gabriel du Plessies</name>
    <date value="18090809">9 Augustus 1809</date>
  </head>
  <p>Vendu rolle van zodanige schaapen als ... publiek verkogt ...</p>
  <table>
    <row><cell/><cell/><cell>Rd:s</cell></row>
    <row>
      <cell>78 lammer schaapen</cell>                  <!-- item -->
      <cell>Pet:s Coenr:d v:d: Westhuizen</cell>       <!-- buyer -->
      <cell>63:–</cell>                                <!-- price -->
    </row>
  </table>
  <div type="signed"><p>L: van Wijk, Gert Kruger</p></div>
</div>
```

| Element / attribute | Meaning |
|---|---|
| `div n` | Archival reference, `MOOC10/{volume}.{item}`; `5 1/2` is an item filed between 5 and 6 |
| `head/name @reg` | The deceased, with the name regularised as *Surname, Given names* |
| `head/date @value` | Date of the sale as `YYYYMMDD`; `YYYYMMDD/YYYYMMDD` for sales over several days |
| `table/row/cell` | One lot: usually three cells, item, buyer and price |
| `row @role`, `name @role` | `slave` (an enslaved person sold), `real_estate` (land or buildings) |
| `name @type` | `person`, `geographical` (place), `ship` |
| `div type="signed"` | Signatures and attestations |

**Items, buyers and prices are not tagged:** they are the cells of each row,
as written. Prices are in rixdollars, written as the clerk wrote them,
usually `rixdollars:sub-unit` (`63:–` is 63 rixdollars exactly). In the VOC
rolls the sub-unit is stuivers; some rolls add a third figure or fractions
(`12:4 1/2`). A column header in the roll, such as `Rd:s`, shows the unit. Buyers' names are abbreviated as the clerk wrote
them (`Pet:s` for Petrus); the letter *H* or *E* after a name marks an heir
(*erfgenaam*).

## Indexes and odd references

- Each volume (except 28) opens with the clerks' alphabetical index of the
  deceased, as a document with a reference such as `Alphabeth_MOOC10/13.1-66`,
  `Register_MOOC10/35` or `1811 INHOUD_MOOC10/25.1-21` (43 such documents).
  They are not sales. Select sales with references that begin `MOOC10/`.
- The index in `MOOC10_vol45.xml` is labelled `Alphabeth_MOOC10/44.1-117`
  (should be 45).
- Volume 28 covers items 17–27 only.
- Three sales in volume 10 have the reference `MOOC10/10.[not numbered]`;
  `MOOC10/1_no number 01` and `MOOC10/2 no number 01` are unnumbered items.
  Identify these by file, reference and date together.

## Dates to check

Dates are as transcribed. Four sales have a date that will not parse as a
calendar date or falls outside the series' range:

| Reference | `@value` | Note |
|---|---|---|
| `MOOC10/6.16` | `16501116` | "16 November 1650" in the text too; the volume's other sales date from 1748 onwards |
| `MOOC10/14.60` | `178[...]` | Year partly illegible |
| `MOOC10/15.59` | `178YYYYY` | Year partly illegible |
| `MOOC10/25.53` | `18120128/18120230` | 30 February 1812 |

Two sales have no date value, and some carry only a year (`YYYY`) or a year
and month.
