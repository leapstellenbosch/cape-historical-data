# Opgaaf clean-data release v2

Released 25 September 2026. This release contains **@UNITS@ administrative/tax units**
and **@ENTRIES@ source entries**, covering 375 year sheets, 13 workbooks and ten
districts, 1660–1844. These are repeated observations, not counts of unique people.

## Changes from v1

The completed George workbook replaces the earlier George workbook. Its eleven
previously released year sheets have identical transcribed cell contents; 1824
and 1826 are new. Clanwilliam is added from its standalone district workbook.
The overlapping Clanwilliam return in `1825 series.xlsx` is not imported again.

| District | Year | Numbered source rows | Clean tax units |
|---|---:|---:|---:|
| George | 1824 | 965 | 965 |
| George | 1826 | 752 | 752 |
| Clanwilliam | 1809 | 252 | 253 |
| Clanwilliam | 1811 | 269 | 270 |
| Clanwilliam | 1812 | 272 | 273 |
| Clanwilliam | 1824 | 613 | 613 |
| **Added** | | **3,123** | **3,126** |

Three unnumbered but complete named Clanwilliam declarations are retained as
separate units: 1809 row 276, 1811 row 293 and 1812 row 268. Their own names,
family/asset counts and (where supplied) farm details give no basis for merging
them with the previous declaration. This is a documented interpretation of the
transcription, pending archival-image review; source entry numbers remain blank.

All 322,502 v1 tax-unit IDs and 332,399 entry IDs are retained. Every pre-existing
data value is unchanged; only the release label and George workbook path change.
New variables are NA on old observations. See `v1_value_comparison.csv`,
`v2_impact_report.csv`, and `addition_validation_tests.csv`.

## Files and use

- `opgaaf_tax_units_clean_v2.rds`: preferred analysis file, one row per administrative/tax unit.
- `opgaaf_clean_v2.csv`: portable version, identical to `opgaaf_tax_units_clean_v2.csv`.
- `opgaaf_entries_clean_v2.rds` / `.csv`: declarations and subordinate entries before aggregation.
- `census_schema_registry_v2.csv`: original headers, column coordinates, canonical names, age/status/sex meanings and mapping confidence.
- `census_sheet_registry_v2.csv`, `annual_inventory_v2.csv`: sheet and district-year coverage.
- `codebook_v2.csv`: entry-variable types and semantics; tax-unit metadata described below.
- `structural_missingness_v2.csv`: mapped form availability, not proof that any cell was actually filled.
- `corrections_log_v2.csv`, `data_quality_flags_v2.csv`: decisions, exclusions and cell-level warnings.
- `addition_coverage.csv`, `addition_row_audit.csv`: complete reconciliation of the six new sheets to the released data.
- `addition_nonrecord_cells.csv`, `addition_review_issues.csv`: unassigned quantities and issues requiring source review.
- `validation_tests_v2.csv`, `addition_validation_tests.csv`: @TESTS@ passing release and addition/regression checks.
- `preserved_inputs_md5.csv`: source and v1 file hashes checked unchanged during the build.

```r
x <- readRDS(here::here("Data", "v2", "opgaaf_tax_units_clean_v2.rds"))
```

For CSV, specify column types or use `readr::read_csv(..., guess_max = Inf)`.
Default type guessing can misclassify fields absent from the earliest records.
Existing paper pipelines and `spine_v1` remain pinned to v1; they have not been
rebuilt. New row IDs are ready for subsequent central linkage, not yet linked
ancestors or verified unique individuals.

## Interpretation and missingness

Tax units are administrative declarations, not verified residential households.
`tax_unit_id` identifies a declaration; `declaration_record_id` and `head_source_row`
locate it in the workbook. `n_entry_rows` and `n_sub_entries` show aggregation.
`all_names` collects transcribed names without deduplicating people across years.
`unit_interpretation` and `form_type` distinguish ordinary opgaaf, capitation,
named-adult and aggregate establishment returns. `residential_household_verified`
remains FALSE.

`recorded_person_count_sum` adds explicit numeric person-stock cells only.
`person_count_fields_present` counts their nonmissing fields. Named people are
not additionally counted; this is not household size or a unique population.
For the five new wide-format sheets, `khoe_in_service_*` and `slave_in_service_*`
preserve the separate *In Dienst Hebbende* blocks as `employment_stock` and are
excluded from that sum: overlap with other population blocks is unknown. A
missing population subtotal can therefore coexist with recorded employees.
This new distinction is scoped to the added sheets; v1 forms were not remapped.

Clanwilliam 1824 distinguishes `prizenegro_*_imported` from
`prizenegro_*_colony_born`: these are child stocks by origin, not annual births.
Historical status labels are retained for source fidelity, not treated as
interchangeable populations. Age limits vary, including women under/above 20
in one block and under/above 14 in another. The literal headers are authoritative;
numeric age metadata follows v1's threshold convention and is not evidence of
exact individual ages or consistent boundary treatment by enumerators.

Blanks remain NA. NA may also mean unrecorded, illegible, ambiguous or blocked;
consult availability and quality files. Explicit zeros and unambiguous numeric
fractions are normalized; ambiguous numbers and ditto marks are not guessed.
Mortality blocks labelled “Not shown” do not imply zero deaths.

The new mappings distinguish working/riding and breeding horses, other livestock,
sown and harvested grain, vines, wine, brandy and vehicles. Farm names, tenure,
distance, agricultural use and transcriber image notes remain verbatim.
Clanwilliam 1824's land subcolumns are preserved separately as `*_raw`, including
places, erven, morgen and square roods. Its two loan-place columns are retained
separately, not summed. Early Clanwilliam tax columns lack explicit currency
units and remain `opgaaf_tax_raw` / `church_contribution_raw`.

## Review limits

**George 1826 tax columns require archival-image review before quantitative
analysis.** Tax values occur on blank and folio rows, indicating possible
vertical misalignment. Values on released rows retain their transcribed
coordinates; orphan amounts are listed separately and not assigned to a person.
Row 603 contains a horse count without a name, before numbering jumps from 61
to 63: it remains unassigned rather than being merged into entry 61.
The workbook also reports bleed-through, blocked information, water damage,
soiling and tight binding. No damaged value has been reconstructed.

The `FOLI0 21` typo in George 1826 row 461 is interpreted as folio 21 for following
records and documented in the correction log. All raw files remain unchanged.

The four unresolved v1 cells, in three excluded rows, remain excluded:
Swellendam 1824 row 883 V8; Cape 1722 row 140 V8/V9; Stellenbosch 1835 row 1252 V8.
Mapping confidence B means reviewed transcription headers and structural checks,
not an archival-image check. C mappings remain excluded. None of these checks
establish that the transcription itself is error-free.

## Reproduction

From the project root, run `Data/v2_pipeline/run_v2_pipeline.R` with Rscript, or:

```r
source("Data/v2_pipeline/run_v2_pipeline.R")
```

The pipeline reads the 13 workbooks, rebuilds the registry and datasets, compares
against the preserved v1 release, and stops if a release check fails. Paths use
the current `Data/` layout. Allow several minutes for the large workbooks.
