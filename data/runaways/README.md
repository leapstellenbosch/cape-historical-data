# Runaway advertisements, 1830–1842

Slaveholders and employers at the Cape advertised for people who had fled
them. This collection holds **881 people named in runaway advertisements**:
551 from *De Zuid Afrikaan* (April 1830 to 1842) and 330 from the *Cape of
Good Hope Government Gazette* (1830 to 1842). For each person it gives the
name, sex, age, origin, physical description, clothing, skills, when they fled,
the advertiser, the reward and, for most advertisements, the full text.

Each row is a person in an advertisement. One advertisement can name several
people, and the same person can appear in both newspapers or be advertised
again; rows are not linked. Most are enslaved people; the later years also
include apprentices, "Prize Negroes" (88 rows) and deserting European servants
(100 rows), as the advertisements describe them.

**Licence: CC BY-NC-SA 4.0** (Attribution, NonCommercial, ShareAlike), the
licence of the original deposit, not the CC BY 4.0 of the rest of the
repository. See `LICENSE.md` in this folder.

**Cite:** Bergemann, K. (2025), "Creating the Cape Colony Runaway
Advertisements Datasets, 1830–1842", *Journal of Slavery and Data
Preservation* 6(1), 1–14,
doi:[10.14321/jsdp.6.1.0001](https://doi.org/10.14321/jsdp.6.1.0001); and
Bergemann, K., Brown, G. and Fourie, J. (2026), "Running towards: Labour market
incentives for runaway slaves in the British Cape Colony, 1830–1838",
*Asia-Pacific Economic History Review*,
doi:[10.1111/aehr.70034](https://doi.org/10.1111/aehr.70034).

**Original deposit:** Bergemann, K., Ekama, K. and Fourie, J. (2025), *Cape
Colony Runaway Advertisements, 1830–1842*, Harvard Dataverse, version 1,
doi:[10.7910/DVN/R1IAFM](https://doi.org/10.7910/DVN/R1IAFM).

**Original sources:** *De Zuid Afrikaan*, issues 1–740, from the digital
collections of Stellenbosch University, supplemented by the National Library
of South Africa, Cape Town; and the *Cape of Good Hope Government Gazette*,
issues 1251–1932, photographed from the collection of Stellenbosch University
Library and supplemented for 1834, 1836 and 1837 from HathiTrust (record
100931470), as described in Bergemann (2025).

## Files

| File | Contents |
|---|---|
| `runaways_persons.csv` | One row per person in an advertisement (also as `.parquet`) |
| `runaways_variables.csv` | Every variable, its source column and meaning |
| `LICENSE.md` | The licence of this folder |

`chdr_id` keeps Bergemann's reference number: `RUN-ZA-001` is ZA1 and
`RUN-GG-114a` is GG114a. The Gazette numbers have gaps, because cases were
removed when the deposit was prepared.

## Reading the data

- **Descriptions are the advertisers' words**, including racial and ethnic
  labels and descriptions of scars and bodies. They are kept as transcribed
  because they are the evidence.
- **The full text is given once** per advertisement, on its first person
  (711 rows have it); the other people in the same advertisement follow it, with
  the same publication date. Their advertiser can differ: one advertisement
  may be placed for several owners (`RUN-ZA-001` and `RUN-ZA-002`).
- `time_absconded` is as transcribed (`1m 2w` is one month and two weeks);
  `reward` is as printed (Rd/Rds are rixdollars; some rewards are in pounds),
  with the transcriber's notes in brackets.
- `flight_year` and `flight_month` are given where the advertisement states or
  implies them.

## How the file was made

From the two CSV files of the Dataverse deposit (17 April 2025), the pipeline
in `code/runaways/` stacks the two newspapers, drops the 154 empty rows at the
end of the Gazette file, turns the deposit's placeholder `0` ("not stated")
into a missing value, writes the publication date in ISO form and month names
as numbers, and keeps the recorded fields. Left out: the derived days absconded
and the "assigned" columns (modern ethnicity and resemblance categories and
Enslaved.org skill codes), which are research coding.
