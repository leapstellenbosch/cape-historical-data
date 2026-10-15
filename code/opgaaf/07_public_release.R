# Stage 07: check the build against v2, then write the public opgaaf files.
# Public tables carry no empty, constant, duplicate or derivable column (see
# section 3); identifiers are chdr_id. docs/schemas.md, section 2.

source(here::here("pipeline", "opgaaf", "00_config.R"))
entries <- readRDS(file.path(release_dir, "opgaaf_entries_clean_v2.rds"))
units <- readRDS(file.path(release_dir, "opgaaf_tax_units_clean_v2.rds"))

# ---------------------------------------------------------------------------
# 1. The build must equal v2, cell for cell
# ---------------------------------------------------------------------------
reference_data <- Sys.getenv("CHDR_REFERENCE_DATA")
if (nzchar(reference_data) && dir.exists(file.path(reference_data, "v2"))) {
  compare <- function(new, kind, id) {
    old <- readRDS(file.path(reference_data, "v2", paste0("opgaaf_", kind, "_clean_v2.rds")))
    stopifnot(identical(names(old), names(new)), nrow(old) == nrow(new),
              identical(old[[id]], new[[id]]))
    tibble(dataset = kind, variable = names(old),
           changed_cells = map_int(names(old), function(col) {
             x <- old[[col]]; y <- new[[col]]
             sum(is.na(x) != is.na(y) | (!is.na(x) & !is.na(y) & x != y))
           }))
  }
  comparison <- bind_rows(compare(entries, "entries", "record_id"),
                          compare(units, "tax_units", "tax_unit_id"))
  write_csv(comparison, file.path(release_dir, "v2_value_comparison.csv"))
  stopifnot(sum(comparison$changed_cells) == 0)
  message("Build equals v2: ", nrow(units), " tax units, ", nrow(entries), " entries, 0 changed cells")
} else message("CHDR_REFERENCE_DATA not set: v2 comparison skipped")

# ---------------------------------------------------------------------------
# 2. Identifiers
# ---------------------------------------------------------------------------
district_codes <- c(Albany = "ALB", Cape = "CAP", Clanwilliam = "CLW", George = "GEO",
                    `Graaff-Reinet` = "GRF", Stellenbosch = "STB", Swellendam = "SWL",
                    Tulbagh = "TUL", Uitenhage = "UIT", Worcester = "WOR")
stopifnot(all(units$district %in% names(district_codes)),
          all(units$year == round(units$year)),
          # one sheet per district-year, so no sheet letter is needed
          nrow(distinct(units, district, year)) == nrow(distinct(units, district, year, source_key, source_sheet)),
          max(units$head_source_row) < 1e5)

units <- units %>%
  mutate(chdr_id = sprintf("OPG-%s-%d-%05d", district_codes[district], as.integer(year), head_source_row))
stopifnot(!anyDuplicated(units$chdr_id))

entries <- entries %>%
  left_join(select(units, tax_unit_id, tax_unit_chdr_id = chdr_id), by = "tax_unit_id") %>%
  group_by(tax_unit_id) %>%
  arrange(source_row, .by_group = TRUE) %>%
  mutate(chdr_id = paste0(tax_unit_chdr_id, "-E", row_number())) %>%
  ungroup()
stopifnot(!anyNA(entries$tax_unit_chdr_id), !anyDuplicated(entries$chdr_id),
          # the declaration row heads its tax unit
          all(entries$record_unit_type[endsWith(entries$chdr_id, "-E1")] == "declaration"))

# ---------------------------------------------------------------------------
# 3. Public tables. No column repeats another, is constant or empty, or can be
#    derived from its row, its identifier or the sheet inventory (Johan,
#    14 October 2026):
#    - sheet-level fields (workbook, sheet name, form type) are in the sheet
#      inventory, keyed by district and year (one sheet per district-year);
#    - the entries table holds only the tax units that combine several
#      transcribed lines; every other line is identical to its tax unit;
#    - derived counts and name lists, constant notes and v2 identifiers go.
# ---------------------------------------------------------------------------
v2_crosswalk <- bind_rows(
  select(units, chdr_id, v2_id = tax_unit_id),
  select(entries, chdr_id, v2_id = record_id))
write_csv(v2_crosswalk, file.path(release_dir, "chdr_v2_crosswalk.csv"))  # internal, not published

drop_empty <- function(d) select(d, where(~!all(is.na(.x))))
sheet_level <- c("source_workbook", "source_sheet", "form_type")
unit_derived <- c("tax_unit_id", "declaration_record_id", "unit_interpretation",
                  "residential_household_verified", "recorded_person_count_includes_named_people",
                  "comparability_note", "n_entry_rows", "n_sub_entries", "person_count_fields_present",
                  "recorded_person_count_sum", "all_names", "head_source_row")
stopifnot(# unit_interpretation is one-to-one with form_type
          nrow(distinct(units, unit_interpretation, form_type)) == n_distinct(units$form_type),
          all(units$n_entry_rows == units$n_sub_entries + 1),
          all(units$declaration_record_id == units$tax_unit_id),
          # form type is fixed within a sheet
          nrow(distinct(units, district, year, form_type)) == nrow(distinct(units, district, year)))

units_pub <- units %>%
  select(-release_version, -source_key, -all_of(sheet_level), -all_of(unit_derived)) %>%
  relocate(chdr_id, district, year, source_folio) %>%
  arrange(district, year, chdr_id) %>%
  drop_empty()

multi <- units$tax_unit_id[units$n_sub_entries > 0]
entries_pub <- entries %>%
  filter(tax_unit_id %in% multi) %>%
  select(-release_version, -source_key, -all_of(sheet_level), -district, -year,
         -record_id, -tax_unit_id, -parent_record_id,
         -record_unit_type,   # -E1 is the declaration, -E2 onwards the subordinate lines
         -schema_confidence) %>%
  relocate(chdr_id, tax_unit_chdr_id, source_row, source_folio) %>%
  arrange(chdr_id) %>%
  drop_empty()
stopifnot(all(entries$schema_confidence == "B"),
          n_distinct(entries_pub$tax_unit_chdr_id) == length(multi))

# A tax unit with one line equals that line, column for column
single <- units %>% filter(n_sub_entries == 0)
line <- entries[match(single$tax_unit_id, entries$tax_unit_id), ]
shared <- setdiff(intersect(names(units_pub), names(entries)), "chdr_id")
same_values <- function(a, b) all(is.na(a) == is.na(b) & (is.na(a) | a == b))
stopifnot(all(map_lgl(shared, ~same_values(single[[.x]], line[[.x]]))))

# ---------------------------------------------------------------------------
# 4. Write: one CSV and one Parquet file per table
# ---------------------------------------------------------------------------
out_dir <- here("release", "data", "opgaaf")
unlink(c(file.path(out_dir, c("csv", "parquet")),
         list.files(out_dir, pattern = "[.](csv|parquet)$", full.names = TRUE)), recursive = TRUE)

github_limit_mb <- 95
for (stem in c("opgaaf_tax_units", "opgaaf_entries")) {
  d <- if (stem == "opgaaf_tax_units") units_pub else entries_pub
  csv <- file.path(out_dir, paste0(stem, ".csv"))
  pq <- file.path(out_dir, paste0(stem, ".parquet"))
  write_csv(d, csv, na = "")
  nanoparquet::write_parquet(d, pq, compression = "zstd")
  back <- nanoparquet::read_parquet(pq)
  stopifnot(file.size(csv) / 2^20 < github_limit_mb,
            nrow(back) == nrow(d), identical(names(back), names(d)), identical(back$chdr_id, d$chdr_id),
            identical(read_csv(csv, col_select = "chdr_id", show_col_types = FALSE)$chdr_id, d$chdr_id))
  message(stem, ": CSV ", round(file.size(csv) / 2^20, 1), " MB, Parquet ", round(file.size(pq) / 2^20, 1), " MB")
}

# ---------------------------------------------------------------------------
# 5. Supporting tables, keyed by district and year
# ---------------------------------------------------------------------------
read_build <- function(f) read_csv(file.path(release_dir, f), show_col_types = FALSE,
                                   col_types = cols(.default = col_character()))
sheets <- read_build("census_sheet_registry_v2.csv")
stopifnot(!anyDuplicated(sheets[c("district", "year")]))
sheet_key <- select(sheets, source_key, sheet, district, year)
locate <- function(d, sheet_col) {
  d %>%
    select(-any_of(c("district", "year", "source_workbook", "sheet_id"))) %>%
    left_join(rename(sheet_key, !!sheet_col := sheet), by = c("source_key", sheet_col)) %>%
    select(-source_key, -all_of(sheet_col)) %>%
    relocate(district, year)
}

sheet_inventory <- sheets %>%
  transmute(district, year, source_workbook = basename(source_workbook), source_sheet = sheet,
            form_type, n_header_rows, first_data_row, summary_start_row, n_columns,
            n_mapped_b, n_unmapped_or_ambiguous, reason) %>%
  arrange(district, as.integer(year))

# Registry: one row per original column of every sheet. Sheet-level fields
# are in the inventory; the column position is given once (source_column, as
# in the flags and corrections); include_in_clean is confidence != "C"; the
# combined header is group | direct; field_type is fixed per variable and is
# in opgaaf_variables.csv.
registry <- read_build("census_schema_registry_v2.csv")
stopifnot(all((registry$include_in_clean == "TRUE") == (registry$confidence != "C")),
          n_distinct(registry$blank_interpretation) == 1,
          nrow(distinct(registry, canonical_field, field_type)) == n_distinct(registry$canonical_field))
schema_registry <- registry %>%
  locate("sheet") %>%
  select(district, year, source_column, header = header_combined, canonical_field,
         measure_type, population_group, sex, age_lower, age_upper,
         mapping_method, confidence, duplicate_target, notes) %>%
  mutate(notes = str_replace(notes, "not harmonized in v2", "not harmonized in this release")) %>%
  drop_empty()

flags <- read_build("data_quality_flags_v2.csv") %>%
  left_join(select(entries, record_id, tax_unit_chdr_id), by = "record_id", relationship = "many-to-one") %>%
  select(-record_id) %>%
  locate("source_sheet") %>%
  relocate(tax_unit_chdr_id)

corrections <- read_build("corrections_log_v2.csv")
stopifnot(# evidence is fixed by correction level, confidence by status; one date
          nrow(distinct(corrections, correction_level, evidence)) == n_distinct(corrections$correction_level),
          nrow(distinct(corrections, correction_status, confidence)) == n_distinct(corrections$correction_status),
          n_distinct(corrections$correction_date) == 1)
corrections <- corrections %>%
  select(-decision_origin_release, -evidence, -confidence, -correction_date, -reviewer) %>%
  mutate(reason = str_replace(reason, "absent from prior release",
                              "absent from LEAP's earlier internal release"),
         # four schema corrections cover a range of sheets ("1819-1824"):
         # their district comes from the workbook, the range goes in the reason
         sheet_range = !paste(source_key, sheet) %in% paste(sheet_key$source_key, sheet_key$sheet),
         range_district = sources_v2$district[match(source_key, sources_v2$source_key)],
         reason = if_else(sheet_range, paste0("Sheets ", sheet, ": ", reason), reason)) %>%
  locate("sheet") %>%
  mutate(district = coalesce(district, range_district)) %>%
  select(-sheet_range, -range_district)
stopifnot(!anyNA(corrections$district))

write_csv(sheet_inventory, file.path(out_dir, "opgaaf_sheet_inventory.csv"), na = "")
write_csv(schema_registry, file.path(out_dir, "opgaaf_schema_registry.csv"), na = "")
write_csv(flags, file.path(out_dir, "opgaaf_quality_flags.csv"), na = "")
write_csv(corrections, file.path(out_dir, "opgaaf_corrections_log.csv"), na = "")

# ---------------------------------------------------------------------------
# 6. Variable list
# ---------------------------------------------------------------------------
cb <- read_build("codebook_v2.csv")
id_vars <- tribble(
  ~variable, ~r_type, ~description,
  "chdr_id", "character", "Repository identifier, never changed: OPG-{district}-{year}-{row} for a tax unit, where row is the spreadsheet row of its declaration; -E{n} for the n-th line of a tax unit (E1 is the declaration)",
  "tax_unit_chdr_id", "character", "chdr_id of the tax unit the line belongs to")
variables <- bind_rows(id_vars, filter(cb, !variable %in% id_vars$variable)) %>%
  mutate(in_tax_units = variable %in% names(units_pub),
         in_entries = variable %in% names(entries_pub)) %>%
  filter(in_tax_units | in_entries) %>%
  # the missing-value policy is the same for every variable (README) and
  # names an internal build file
  select(-missing_value_policy) %>%
  select(where(~n_distinct(.x) > 1))  # drops columns with one value throughout
stopifnot(all(c(names(units_pub), names(entries_pub)) %in% variables$variable))
write_csv(variables, file.path(out_dir, "opgaaf_variables.csv"), na = "")

# ---------------------------------------------------------------------------
# 7. No published table may hold an empty, constant or duplicate column
# ---------------------------------------------------------------------------
redundant <- function(d) {
  cols <- names(d)
  constant <- map_lgl(d, ~all(is.na(.x)) || (!anyNA(.x) && n_distinct(.x) == 1))
  same <- keep(combn(cols, 2, simplify = FALSE), ~identical(d[[.x[1]]], d[[.x[2]]]))
  c(cols[constant], map_chr(same, paste, collapse = "="))
}
found <- map(list(units = units_pub, entries = entries_pub, sheets = sheet_inventory,
                  registry = schema_registry, flags = flags, corrections = corrections,
                  variables = variables), redundant)
print(compact(found))
stopifnot(length(compact(found)) == 0)

message("Public opgaaf files written: ", nrow(units_pub), " tax units x ", ncol(units_pub),
        " columns; ", nrow(entries_pub), " lines x ", ncol(entries_pub), " columns")
