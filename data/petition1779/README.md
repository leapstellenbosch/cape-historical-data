# The 1779 Cape Patriots petition

In 1779 the Cape Patriots (*Kaapse Patriotte*) petitioned the governing board
of the Dutch East India Company for trade rights, limits on officials'
commerce and settler seats in the colony's councils. This collection lists
the **404 signatories** in the order they signed, with the rank or office each
wrote after his name: 355 burghers, and heemraden, burgher councillors, church
officers and militia officers, serving and former.

Each row is a signature; no signatory is linked to other collections.

**Cite:** Schoots, J. and Fourie, J. (2026), "Protest from above: Elite
decoupling and public petitioning in the VOC Cape Colony", Working paper,
Stellenbosch University.

**Archival source:** the Western Cape Archives and Records Service (WCARS), Cape Town, records of the
Council of Policy (C, WCARS inventory 1/1), **C 2665** (burgher complaints,
1716–1782), pp. 2–9, as transcribed in Baartman, T. (2011), *Fighting for the spoils: Cape
burgerschap and faction disputes in Cape Town in the 1770s*, PhD thesis,
University of Cape Town.

## Files

| File | Contents |
|---|---|
| `petition1779_signatories.csv` | One row per signatory (also as `.parquet`) |
| `petition1779_variables.csv` | Every variable, its source column and meaning |

`chdr_id` is the position on the petition: `PET-001` signed first.

## Reading the data

- `name_suffix` holds the patronymic or distinguishing word written after the
  name (*Jansz*, *de Jonge*, *de Oude*), which often tells apart men of the
  same name: 14 names occur more than once.
- `rank` is as written; *oud* means former (*oud Heemraad*, former heemraad).
- `note` is the transcriber's: four men signed with a cross ("signed with x"), and one note reads "Senior".
- Two names read "Jacobus R" and "Johannes Nieuw" with rank *oud Burger*; the
  full signature lines read "Jacobus Roud Burger" and "Johannes Nieuwoud
  Burger", so these may instead be the surname Nieuwoud(t) with rank Burger.
  They are kept as in the transcription.

## How the file was made

From the transcription used by Schoots and Fourie (`404_signatories.xlsx`,
sheet 2), the pipeline in `code/petition1779/` keeps the name, suffix, rank
and note. The sheet also gives each signature as one line; for two signatories
whose name was lost when that line was split into columns, the name is taken
from the line. Not published: the flag and index that matched signatories to
the tax censuses, which are record linkage.
