# Documentation, correction ledger, diagnostics, and release validation.

source(here::here("pipeline", "opgaaf", "00_config.R"))
source(here::here("pipeline", "opgaaf", "01_registry_helpers.R"))

registry <- read_csv(file.path(release_dir, "census_schema_registry_v2.csv"), show_col_types = FALSE, guess_max = Inf)
sheets <- read_csv(file.path(release_dir, "census_sheet_registry_v2.csv"), show_col_types = FALSE, guess_max = Inf)
entries <- readRDS(file.path(release_dir, "opgaaf_entries_clean_v2.rds"))
tax_units <- readRDS(file.path(release_dir, "opgaaf_tax_units_clean_v2.rds"))
flags <- read_csv(file.path(release_dir, "data_quality_flags_v2.csv"), show_col_types = FALSE, guess_max = Inf)
flags <- flags %>% mutate(source_sheet = as.character(source_sheet)) %>%
  bind_rows(tibble(record_id = NA_character_, source_key = "george", source_sheet = "1826",
    source_row = NA_integer_, flag_level = "sheet", canonical_field = NA_character_,
    source_column = "V74:V81", raw_value = NA_character_, flag_type = "source_alignment_review",
    severity = "review", detail = paste(
      "Tax amounts also occur on blank/folio rows, indicating possible vertical misalignment.",
      "Released values retain transcribed coordinates; verify the tax block against archival images before analysis.",
      "See addition_nonrecord_cells.csv and addition_review_issues.csv."))) %>% distinct()
write_csv(flags, file.path(release_dir, "data_quality_flags_v2.csv"), na = "")
structural <- read_csv(file.path(release_dir, "structural_missingness_v2.csv"), show_col_types = FALSE, guess_max = Inf)

# ---------------------------------------------------------------------------
# Correction ledger
# ---------------------------------------------------------------------------
known_schema_corrections <- tribble(
  ~source_key, ~sheet, ~reason, ~old_interpretation, ~corrected_interpretation,
  "cape_early", "1675", "Left-shifted demographic block", "V5 generic children; V6 servants; V7-V8 enslaved adults", "V5 sons; V6 daughters; V7 servants; V8-V10 enslaved men/women/children",
  "cape_early", "1692", "Names and demographic block shifted", "Names at V3-V4 and early generic counts", "Names V4-V5; free V6-V9; servants V10; enslaved V11-V14",
  "cape_late", "1805", "Late-Cape generic mapping shifted", "Counts beginning V5", "Names V2-V3; free V4-V7; servants V8; Khoe V9-V12; enslaved V13-V16",
  "cape_late", "1818", "Prize Negro block read as enslaved block", "V14-V17 enslaved people", "V14-V17 Prize Negroes; V18-V21 enslaved people",
  "cape_late", "1819-1824", "Field-cornet/name position and demographic groups vary", "Single fixed late-Cape layout", "Three-tier header-derived, sheet-specific layouts",
  "cape_late", "1825", "Distinct adult/minor age-band form", "Generic late-Cape layout", "Adult and minor sex blocks mapped separately by population status",
  "stellenbosch_early", "1689", "Column-count heuristic selected production columns as people", "Crops/assets included in demographic positions", "Header-derived early demographic and asset mappings",
  "stellenbosch_1780", "1839", "Named-adult/servant form treated as old family/slave form", "Generic Stellenbosch demographic layout", "Named adults and four explicit servant categories",
  "stellenbosch_1780", "1841-1844", "Aggregate houseful/production form treated as old demographics", "Production fields read as old person categories", "White/coloured houseful counts and sector-worker variables preserved separately",
  "graaff_reinet", "1790", "Early fixed mapping shifted", "Names and people one column left", "Names V1-V2; free V3-V6; servants V7; enslaved V8-V11",
  "graaff_reinet", "1815", "Later fixed mapping omitted sex-specific servants and shifted groups", "V9 generic servants and fixed Khoe/slave offsets", "V9-V10 servants; V11-V14 Khoe; V15-V18 enslaved, with age/sex metadata",
  "tulbagh", "1821", "Prize Negro block mistaken for servants/Khoe", "V8 servants and later groups shifted", "V8-V11 Prize Negroes; V12-V15 Khoe; V16-V19 enslaved",
  "george", "1815", "Unique form forced into district-wide mapping", "Fixed George layout", "Header-derived unique 1815 layout",
  "george", "1818-1822", "Newly supplied George returns absent from prior release", "Sheets not present in source workbook", "Five new opgaaf years with demographic, production, mortality, land, and available tax-contribution fields",
  "george", "1818, 1819, 1821", "Nameless continuation rows classified as unconnected data", "Three genuine demographic/livestock rows excluded", "Rows 786, 797, and 1051 retained as subordinate entries of the immediately preceding declarations",
  "graaff_reinet", "1809", "Cumulative totals treated as declarations", "Rows 1236 onward eligible as records", "Rows 1236 onward excluded as summary section",
  "tulbagh", "1807", "Field-cornetcy totals treated as declarations", "Rows 502 onward eligible as records", "Rows 502 onward excluded as summary section"
)

schema_log <- known_schema_corrections %>%
  mutate(
    correction_level = "schema",
    source_row = NA_integer_, source_column = NA_character_, canonical_field = NA_character_,
    raw_value = old_interpretation, corrected_value = corrected_interpretation,
    correction_status = "applied", evidence = "Transcribed multi-tier headers and cross-sheet structural audit",
    confidence = "B", reviewer = "Codex initial audit; researcher review pending", correction_date = as.character(release_date)
  ) %>%
  select(correction_level, source_key, sheet, source_row, source_column,
         canonical_field, raw_value, corrected_value, correction_status,
         reason, evidence, confidence, reviewer, correction_date)

manual_log <- registry %>%
  filter(mapping_method == "manual_header_override") %>%
  transmute(
    correction_level = "schema_column", source_key, sheet,
    source_row = NA_integer_, source_column, canonical_field,
    raw_value = header_combined, corrected_value = canonical_field,
    correction_status = "applied", reason = notes,
    evidence = "Transcribed sheet header", confidence,
    reviewer = "Codex initial audit; researcher review pending",
    correction_date = as.character(release_date)
  )

unresolved_log <- unresolved_cells_v2 %>%
  transmute(
    correction_level = "cell", source_key, sheet, source_row, source_column,
    canonical_field, raw_value, corrected_value = NA_character_,
    correction_status = "row_excluded_pending_archival_image", reason,
    evidence = "Magnitude/context anomaly; no defensible value reconstruction from transcription alone",
    confidence = "D", reviewer = "Unresolved", correction_date = as.character(release_date)
  )

new_row_decisions <- independent_unnumbered_rows_v2 %>%
  transmute(correction_level = "row_classification", source_key, sheet, source_row,
    source_column = "V1", canonical_field = "record_unit_type", raw_value = NA_character_,
    corrected_value = "declaration", correction_status = "applied", reason,
    evidence = "Distinct named declarant with own counts; no explicit subordinate relationship",
    confidence = "B", reviewer = "Codex transcription audit; archival-image review pending",
    correction_date = as.character(release_date))
folio_decision <- tibble(correction_level = "folio_marker", source_key = "george", sheet = "1826",
  source_row = 461L, source_column = "V1", canonical_field = "source_folio", raw_value = "FOLI0 21",
  corrected_value = "21", correction_status = "applied", reason = "Zero in place of letter O in folio marker",
  evidence = "Explicit numbered folio marker between folios 20 and 22", confidence = "B",
  reviewer = "Codex transcription audit", correction_date = as.character(release_date))

normalization_log <- flags %>%
  filter(flag_type == "normalized_fraction_or_explicit_zero") %>%
  transmute(
    correction_level = "cell_normalization", source_key,
    sheet = as.character(source_sheet), source_row = as.integer(source_row),
    source_column, canonical_field, raw_value,
    corrected_value = str_remove(detail, "^Normalized to "),
    correction_status = "applied",
    reason = "Unambiguous fraction, decimal-comma, or explicit-zero notation normalized",
    evidence = "Transcribed cell notation and deterministic parsing rule",
    confidence = "B", reviewer = "Rule-based normalization",
    correction_date = as.character(release_date)
  )

corrections <- bind_rows(schema_log, manual_log, new_row_decisions, folio_decision, normalization_log, unresolved_log) %>%
  mutate(correction_id = sprintf("V2C%04d", row_number()),
         decision_origin_release = if_else(source_key == "clanwilliam" |
           (source_key == "george" & sheet %in% c("1824", "1826")), "v2", "v1"), .before = 1)
write_csv(corrections, file.path(release_dir, "corrections_log_v2.csv"), na = "")

# ---------------------------------------------------------------------------
# Machine-readable codebook
# ---------------------------------------------------------------------------
column_types <- vapply(entries, function(x) class(x)[1], character(1))
registry_codebook <- registry %>%
  filter(!is.na(canonical_field)) %>%
  group_by(canonical_field) %>%
  summarise(
    field_type_registry = paste(sort(unique(na.omit(field_type))), collapse = ";"),
    measure_type = paste(sort(unique(na.omit(measure_type))), collapse = ";"),
    population_group = paste(sort(unique(na.omit(population_group))), collapse = ";"),
    sex = paste(sort(unique(na.omit(sex))), collapse = ";"),
    age_lower_values = paste(sort(unique(na.omit(age_lower))), collapse = ";"),
    age_upper_values = paste(sort(unique(na.omit(age_upper))), collapse = ";"),
    n_sheets_recorded = n_distinct(sheet_id[include_in_clean]),
    definitions_vary_by_sheet = n_distinct(paste(population_group, sex, age_lower, age_upper, measure_type)) > 1L,
    .groups = "drop"
  )

metadata_descriptions <- c(
  release_version = "Version identifier for this clean-data release",
  record_id = "Stable row ID: source key, sheet, and original XLSX row",
  tax_unit_id = "Administrative/tax-unit ID; subordinate entries inherit the preceding declaration ID where explicit",
  parent_record_id = "Parent declaration record ID for subordinate entries",
  record_unit_type = "declaration or subordinate entry",
  form_type = "Historically distinct return format; use to define comparable samples",
  district = "Cape Colony district represented by source workbook",
  year = "Year parsed from source sheet",
  source_key = "Stable source-workbook key",
  source_workbook = "Project-relative path to immutable raw transcription",
  source_sheet = "Original XLSX sheet name",
  source_row = "Original one-based XLSX row number",
  source_folio = "Folio number inferred from explicit folio markers",
  schema_confidence = "Lowest mapping confidence admitted to clean entries (B in v2)"
)

codebook <- tibble(
  variable = names(entries),
  r_type = unname(column_types),
  description = unname(metadata_descriptions[names(entries)])
) %>%
  left_join(registry_codebook, by = c("variable" = "canonical_field")) %>%
  mutate(
    description = case_when(
      !is.na(description) ~ description,
      measure_type == "named_person" ~ "Transcribed name field; not automatically converted to a person count",
      measure_type == "person_stock" ~ "Numeric person stock as defined by the source-sheet header; consult registry for age/status semantics",
      measure_type == "person_flow" ~ "Birth/death/marriage flow during the form's reporting period",
      measure_type == "taxable_person_stock" ~ "Persons liable to the specified tax; not directly comparable to household membership",
      measure_type == "worker_stock" ~ "Persons reported as used in the specified economic sector",
      measure_type == "employment_stock" ~ "People in the separate In Dienst Hebbende block; excluded from recorded_person_count_sum because overlap is unknown",
      measure_type == "asset_stock" ~ "Asset or production quantity as defined by the source sheet",
      measure_type == "tax_amount" ~ "Tax or contribution amount in the source currency unit named by the variable",
      measure_type == "land_context" ~ "Land tenure, distance, or agricultural-use content preserved verbatim from the source",
      measure_type == "identifier" ~ "Transcribed identifier or location field",
      TRUE ~ "See schema registry and release codebook"
    ),
    missing_value_policy = "Blank/unrecorded/ambiguous values are NA; structural availability is in structural_missingness_v2.csv"
  )
write_csv(codebook, file.path(release_dir, "codebook_v2.csv"), na = "")

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
person_fields <- registry %>%
  filter(include_in_clean, measure_type == "person_stock") %>%
  pull(canonical_field) %>% unique() %>% intersect(names(entries))

annual_inventory <- tax_units %>%
  group_by(district, year, form_type) %>%
  summarise(
    n_tax_units = n(),
    n_compound_units = sum(n_sub_entries > 0L),
    median_recorded_person_count = if (all(is.na(recorded_person_count_sum))) NA_real_ else median(recorded_person_count_sum, na.rm = TRUE),
    mean_recorded_person_count = if (all(is.na(recorded_person_count_sum))) NA_real_ else mean(recorded_person_count_sum, na.rm = TRUE),
    max_recorded_person_count = if (all(is.na(recorded_person_count_sum))) NA_real_ else max(recorded_person_count_sum, na.rm = TRUE),
    pct_without_numeric_person_stock = mean(is.na(recorded_person_count_sum)) * 100,
    .groups = "drop"
  )
write_csv(annual_inventory, file.path(release_dir, "annual_inventory_v2.csv"), na = "")

balance_pairs <- tribble(
  ~group, ~male_field, ~female_field,
  "settler_adult", "settler_men", "settler_women",
  "settler_child", "settler_sons", "settler_daughters",
  "slave_adult", "slave_men", "slave_women",
  "slave_child", "slave_sons", "slave_daughters",
  "khoe_adult", "khoe_men", "khoe_women",
  "khoe_child", "khoe_sons", "khoe_daughters",
  "freeblack_adult", "freeblack_men", "freeblack_women",
  "prizenegro_adult", "prizenegro_men", "prizenegro_women"
) %>% filter(male_field %in% names(entries), female_field %in% names(entries))

balance_parts <- map_dfr(seq_len(nrow(balance_pairs)), function(i) {
  p <- balance_pairs[i, ]
  entries %>%
    group_by(district, year, source_key, source_sheet) %>%
    summarise(male_total = sum(.data[[p$male_field]], na.rm = TRUE),
              female_total = sum(.data[[p$female_field]], na.rm = TRUE), .groups = "drop") %>%
    mutate(group = p$group,
           ratio_male_female = ifelse(female_total > 0, male_total / female_total, NA_real_),
           extreme_balance_flag = ratio_male_female > 10 | ratio_male_female < 0.1)
})
write_csv(balance_parts, file.path(release_dir, "demographic_balance_diagnostics_v2.csv"), na = "")

schema_sequence <- registry %>%
  filter(include_in_clean, measure_type == "person_stock") %>%
  arrange(sheet_id, population_group, source_column_index) %>%
  group_by(sheet_id, source_key, district, year, sheet, population_group) %>%
  summarise(
    mapped_sequence = paste(canonical_field, collapse = " -> "),
    source_columns = paste(source_column, collapse = " -> "),
    n_fields = n(),
    duplicate_target = anyDuplicated(canonical_field) > 0L,
    confidence_b_or_better = all(confidence %in% c("A", "B")),
    .groups = "drop"
  )
write_csv(schema_sequence, file.path(release_dir, "schema_sequence_diagnostics_v2.csv"), na = "")

old_path <- here("Output", "Data", "opgaaf_all_entries.csv")
if (file.exists(old_path)) {
  old_counts <- read_csv(old_path, col_select = c(district, year), show_col_types = FALSE, guess_max = Inf, progress = FALSE) %>%
    count(district, year, name = "n_old_extractor")
  impact <- entries %>% count(district, year, form_type, name = "n_v2") %>%
    group_by(district, year) %>%
    summarise(n_v2 = sum(n_v2), forms_v2 = paste(sort(unique(form_type)), collapse = ";"), .groups = "drop") %>%
    full_join(old_counts, by = c("district", "year")) %>%
    mutate(n_v2 = coalesce(n_v2, 0L),
           n_old_extractor = coalesce(n_old_extractor, 0L),
           change_n = n_v2 - n_old_extractor,
           change_pct = ifelse(n_old_extractor > 0, 100 * change_n / n_old_extractor, NA_real_))
  write_csv(impact, file.path(release_dir, "v2_impact_report.csv"), na = "")
}

# ---------------------------------------------------------------------------
# Assertions and validation summary
# ---------------------------------------------------------------------------
numeric_person_matrix <- entries[, person_fields, drop = FALSE]
discrete_fields_present <- intersect(discrete_stock_fields, names(entries))
numeric_discrete_matrix <- entries[, discrete_fields_present, drop = FALSE]
expected_year_sheets <- sum(map2_int(sources_v2$source_key, sources_v2$path,
                                     ~length(year_sheets_v2(.x, .y))))
forced_continuation_ids <- paste(
  forced_continuation_rows_v2$source_key,
  forced_continuation_rows_v2$sheet,
  forced_continuation_rows_v2$source_row,
  sep = "::"
)
configured_unresolved_row_ids <- unique(paste(
  unresolved_cells_v2$source_key,
  unresolved_cells_v2$sheet,
  unresolved_cells_v2$source_row,
  sep = "::"
))
forced_continuations_released <- entries %>%
  filter(record_id %in% forced_continuation_ids) %>%
  summarise(
    all_present = n() == length(forced_continuation_ids),
    all_subentries = all(record_unit_type == "sub_entry"),
    all_parents_released = all(parent_record_id %in% entries$record_id)
  ) %>%
  transmute(pass = all_present & all_subentries & all_parents_released) %>%
  pull(pass)
test_results <- tribble(
  ~test_id, ~description, ~passed, ~observed,
  "V001", "All discoverable year sheets are audited", nrow(sheets) == expected_year_sheets, paste(nrow(sheets), expected_year_sheets, sep = "/"),
  "V002", "One registry row per sheet/source column", !anyDuplicated(registry[c("sheet_id", "source_column")]), as.character(nrow(registry)),
  "V003", "No included duplicate canonical targets within a sheet", nrow(registry %>% filter(include_in_clean) %>% count(sheet_id, canonical_field) %>% filter(!is.na(canonical_field), n > 1L)) == 0L, "0 expected",
  "V004", "All included mappings confidence A or B", all(registry$confidence[registry$include_in_clean] %in% c("A", "B")), paste(sort(unique(registry$confidence[registry$include_in_clean])), collapse = ","),
  "V005", "Entry record IDs unique", !anyDuplicated(entries$record_id), as.character(nrow(entries)),
  "V006", "Tax-unit IDs unique in tax-unit file", !anyDuplicated(tax_units$tax_unit_id), as.character(nrow(tax_units)),
  "V007", "Every entry resolves to a released tax unit", all(entries$tax_unit_id %in% tax_units$tax_unit_id), as.character(sum(!entries$tax_unit_id %in% tax_units$tax_unit_id)),
  "V008", "Tax-unit row counts reconcile to entries", sum(tax_units$n_entry_rows) == nrow(entries), paste(sum(tax_units$n_entry_rows), nrow(entries), sep = "/"),
  "V009", "No summary/header rows in clean entries", all(entries$record_unit_type %in% c("declaration", "sub_entry")), paste(unique(entries$record_unit_type), collapse = ","),
  "V010", "Person stocks are nonnegative", all(as.matrix(numeric_person_matrix) >= 0, na.rm = TRUE), as.character(sum(as.matrix(numeric_person_matrix) < 0, na.rm = TRUE)),
  "V011", "Person stocks are integer-valued", all(abs(as.matrix(numeric_person_matrix) - round(as.matrix(numeric_person_matrix))) < 1e-8, na.rm = TRUE), as.character(sum(abs(as.matrix(numeric_person_matrix) - round(as.matrix(numeric_person_matrix))) >= 1e-8, na.rm = TRUE)),
  "V012", "All configured unresolved transcription cells remain documented", sum(flags$flag_type == "unresolved_transcription") == nrow(unresolved_cells_v2), paste(sum(flags$flag_type == "unresolved_transcription"), nrow(unresolved_cells_v2), sep = "/"),
  "V013", "No clean field treats blank as automatic zero", all(registry$blank_interpretation == "unknown_not_coerced_to_zero"), paste(unique(registry$blank_interpretation), collapse = ","),
  "V014", "All clean records have round-trip workbook/sheet/row provenance", all(!is.na(entries$source_workbook) & !is.na(entries$source_sheet) & !is.na(entries$source_row)), as.character(sum(is.na(entries$source_row))),
  "V015", "All source rows with configured unresolved cells are excluded", all(!configured_unresolved_row_ids %in% entries$record_id), paste(sum(configured_unresolved_row_ids %in% entries$record_id), "released of", length(configured_unresolved_row_ids)),
  "V016", "Discrete person, animal, and vehicle stocks are integer-valued", all(abs(as.matrix(numeric_discrete_matrix) - round(as.matrix(numeric_discrete_matrix))) < 1e-8, na.rm = TRUE), as.character(sum(abs(as.matrix(numeric_discrete_matrix) - round(as.matrix(numeric_discrete_matrix))) >= 1e-8, na.rm = TRUE)),
  "V017", "Documented George continuation rows are released under valid parents", forced_continuations_released, paste(length(forced_continuation_ids), "expected")
)
write_csv(test_results, file.path(release_dir, "validation_tests_v2.csv"), na = "")

validation_summary <- tibble(
  release_version = release_version,
  release_date = as.character(release_date),
  n_source_workbooks = n_distinct(registry$source_key),
  n_year_sheets = nrow(sheets),
  n_registry_columns = nrow(registry),
  n_included_mappings = sum(registry$include_in_clean),
  n_clean_entries = nrow(entries),
  n_declarations = sum(entries$record_unit_type == "declaration"),
  n_sub_entries = sum(entries$record_unit_type == "sub_entry"),
  n_tax_units = nrow(tax_units),
  n_flags = nrow(flags),
  n_unresolved_cells = sum(flags$flag_type == "unresolved_transcription"),
  tests_passed = sum(test_results$passed),
  tests_total = nrow(test_results),
  release_tests_all_pass = all(test_results$passed)
)
write_csv(validation_summary, file.path(release_dir, "validation_summary_v2.csv"), na = "")
print(test_results)
print(validation_summary)
stopifnot(all(test_results$passed))
