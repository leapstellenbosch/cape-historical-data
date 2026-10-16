# Probate inventories of the Orphan Chamber (MOOC8), 1673–1844

When a settler at the Cape died, the Orphan Chamber (*Weeskamer*) had the
estate listed: the house room by room, furniture, clothing, tools, livestock,
enslaved people, land, debts and credits. This collection is the complete
transcription of the 75 volumes of the archival series MOOC8 (Master of the
Orphan Chamber, series 8) in the Western Cape Archives: **5,953 documents**,
dated 1673 to 1844.

The files are the transcriptions as made by the TEPC project (Transcription
of Estate Papers at the Cape of Good Hope, 2004–2008), with a few corrections
listed below.
They are in Dutch, as written; spelling and abbreviations are those of the
clerks.

**Cite:** Fourie, J. (2013), "The remarkable wealth of the Dutch Cape Colony:
Measurements from eighteenth-century probate inventories", *Economic History
Review* 66(2): 419–448,
doi:[10.1111/j.1468-0289.2012.00662.x](https://doi.org/10.1111/j.1468-0289.2012.00662.x).

**Archival source:** the Western Cape Archives and Records Service (WCARS), Cape Town, records of the Master of the Orphan
Chamber (MOOC, WCARS inventory 1/3): **MOOC 8/1–8/48**, inventories, general
series, 1673–1834; **MOOC 8/49–8/74**, inventories and appraisements,
1780–1834; and **MOOC 8/75**, unbound inventories, 1673–1825. The file for
each volume is named after it (`MOOC8_vol01.xml` is MOOC 8/1). The volumes
were transcribed from the originals at the archives by the TEPC transcription
project (2004–2008).

## Files

| File | Contents |
|---|---|
| `xml/MOOC8_vol01.xml` … `MOOC8_vol75.xml` | One file per archival volume |
| `file_names.txt` | New file name, original file name, number of documents, size and MD5 checksum (tab-separated) |
| `corrections.txt` | Every change made to the transcribers' files (tab-separated) |

The files were renamed for clarity. Sixty-four of them are byte-identical to
the transcribers' files; the other eleven differ only by the corrections below.

## Markup

The XML uses a small subset of TEI (Text Encoding Initiative):

```xml
<text><body>
  <div n="MOOC8/10.1">                      <!-- one document: archival reference -->
    <head>
      <date value="17600705">5 Julij 1760</date>
      <name type="person" reg="Meijer, Pieter Barend">Pieter Barend Meijer</name>
    </head>
    <p>Inventaris van alle soodanige goederen ...</p>
    <table>
      <row role="slave"><cell>een <name type="person" reg="unnamed">mans slaaf</name></cell></row>
      <row><cell>agt ossen</cell></row>
    </table>
    <div type="signed"><p>Helena Zappel</p></div>
  </div>
</body></text>
```

| Element / attribute | Meaning |
|---|---|
| `div n` | Archival reference of the document, `MOOC8/{volume}.{item}`; letters (`10.6a`, `10.6b`) are parts of one estate's papers, `8 1/2` an item filed between 8 and 9 |
| `head/date @value` | Date of the document as `YYYYMMDD` (or shorter where incomplete; `YYYY` where unreadable, 153 documents) |
| `head/name @reg` | The deceased, with the name regularised as *Surname, Given names* |
| `table/row/cell` | One line of the inventory; `cell @rows`/`@cols` span lines or columns |
| `row @role` | `slave` (a line listing enslaved people), `real_estate` (land or buildings) |
| `name @type` | `person`, `geographical` (place), `ship`; `@reg="unnamed"` where a person is described but not named |
| `div type="signed"` | Signatures and attestations |

Items, quantities and values are not tagged separately: they are the text of
each `cell`, as written. Where values are given, they are mostly in
rixdollars (*rd:s*), written as in the source.

## Corrections

Two kinds of correction were made to the transcribers' files. `corrections.txt`
lists each one, with the MD5 checksum of the original file:

- **A duplicated volume was removed.** The transcribers' file for volume 1 also
  contained a complete copy of volume 10 (114 documents) after volume 1's own
  87. The copy was identical to `MOOC8_vol10.xml` apart from spacing.
- **Thirteen archival references were corrected:**

| File | Was | Now | Deceased |
|---|---|---|---|
| `MOOC8_vol03.xml` | `MOOC8/3.54` | `MOOC8/3.54a` | Pieter Pijl (1714) |
| `MOOC8_vol03.xml` | `MOOC8/3.54` | `MOOC8/3.54b` | Jan Smit and Eva Zaijman (1714) |
| `MOOC8_vol06.xml` | `MOOC8/4.24` | `MOOC8/6.24` | Johanna van Zeijl (1738) |
| `MOOC8_vol07.xml` | `MOOC8/8.44` | `MOOC8/7.44` | Maria van der Schelde (1756) |
| `MOOC8_vol19.xml` | `MOOC8/20.20` | `MOOC8/19.20` | Andries van Sitterd (1786) |
| `MOOC8_vol19.xml` | `MOOC8/10.35` | `MOOC8/19.35` | Gerrit van Wijk (1787) |
| `MOOC8_vol44.xml` | `MOOC8/4.14` | `MOOC8/44.14` | Johanna Maria Janzen (1828) |
| `MOOC8_vol56.xml` | `MOOC8/54.4a` | `MOOC8/56.4a` | Dorothea Maria Forster (1805) |
| `MOOC8_vol59.xml` | `MOOC8/69.52a` | `MOOC8/59.52a` | Jacomina Snijman (1813) |
| `MOOC8_vol61.xml` | `MOOC8/61_no number 01` | `MOOC8/61_no number 01a` | Gerrit Cloete (1815) |
| `MOOC8_vol61.xml` | `MOOC8/61_no number 01` | `MOOC8/61_no number 01b` | Gerrit Cloete (1815) |
| `MOOC8_vol71.xml` | `MOOC8/1.12a` | `MOOC8/71.12a` | Johannes Marthinus van der Merwe (1828) |
| `MOOC8_vol73.xml` | `MOOC8/37.11` | `MOOC8/73.11` | Barend Hendrik Burger (1832) |

Nine of these carried the wrong volume number. Each now takes the number of
the volume it is filed in, which the items on either side confirm (for
example, the vol06 document sits between `6.23` and `6.25`). The other four
are two pairs that each shared one reference, so letters were added in file
order. At
`3.54` these are two different estates, and volume 3 has no gap in its
numbering that would suggest another number. At `61_no number 01` they are
two documents of the same estate.

Nothing else was changed: in each corrected file, every byte outside the
corrected references and the removed copy is as transcribed. Every reference
is now unique, and every document sits in its own volume's file.

## Dates to check

Dates are as transcribed. Two are impossible calendar dates:
`MOOC8/14.43` (`17720931`, 31 September 1772) and `MOOC8/22.15`
(`17970229`, 29 February 1797). Parse dates leniently and check these
against the document text.

## Further reading

The TEPC transcribers describe their work and the series in two short
pieces held with the project: Liebenberg et al., "Transcribing the
inventories: a personal experience", and Liebenberg and Malan, "The Orphan
Chamber of 1792: a visit".
