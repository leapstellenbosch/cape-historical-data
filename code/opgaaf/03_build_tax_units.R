# Build conservative administrative/tax-unit aggregates from clean entries.

source(here::here("pipeline", "opgaaf", "00_config.R"))

entries_path <- file.path(release_dir, "opgaaf_entries_clean_v2.rds")
registry_path <- file.path(release_dir, "census_schema_registry_v2.csv")
if (!file.exists(entries_path) || !file.exists(registry_path)) {
  stop("Run registry and entry extraction stages first")
}

entries <- readRDS(entries_path)
registry <- read_csv(registry_path, show_col_types = FALSE, guess_max = Inf)

sum_or_na <- function(x) if (all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE)
first_or_na <- function(x) {
  x <- x[!is.na(x) & str_trim(as.character(x)) != ""]
  if (length(x)) x[[1]] else NA
}
collapse_unique <- function(x) {
  x <- unique(x[!is.na(x) & str_trim(as.character(x)) != ""])
  if (length(x)) paste(x, collapse = " | ") else NA_character_
}

numeric_fields <- registry %>%
  filter(include_in_clean, field_type == "numeric") %>%
  pull(canonical_field) %>% unique() %>% intersect(names(entries))

character_fields <- registry %>%
  filter(include_in_clean, field_type == "character") %>%
  pull(canonical_field) %>% unique() %>% intersect(names(entries))

person_stock_fields_release <- registry %>%
  filter(include_in_clean, measure_type == "person_stock") %>%
  pull(canonical_field) %>% unique() %>% intersect(numeric_fields)

name_fields_release <- intersect(
  c("names_men", "names_women", "names_combined", "surname", "given_names"),
  names(entries)
)

entries <- entries %>% arrange(district, year, source_key, source_sheet, source_row)
unit_ids <- unique(entries$tax_unit_id)
group_index <- match(entries$tax_unit_id, unit_ids)
first_index <- match(unit_ids, entries$tax_unit_id)

# Almost all units have one row. Preserve the first declaration without an
# expensive 318k-group summarise, then replace numeric columns with matrix sums.
tax_units <- entries[first_index, , drop = FALSE]
tax_units$declaration_record_id <- ifelse(
  tax_units$record_unit_type == "declaration", tax_units$record_id, NA_character_
)
tax_units$head_source_row <- tax_units$source_row
tax_units$n_entry_rows <- tabulate(group_index, nbins = length(unit_ids))
tax_units$n_sub_entries <- tabulate(
  group_index[entries$record_unit_type == "sub_entry"], nbins = length(unit_ids)
)

if (length(numeric_fields)) {
  numeric_matrix <- as.matrix(entries[, numeric_fields, drop = FALSE])
  numeric_sums <- rowsum(numeric_matrix, group_index, reorder = FALSE, na.rm = TRUE)
  numeric_present <- rowsum(1L * !is.na(numeric_matrix), group_index, reorder = FALSE)
  numeric_sums[numeric_present == 0] <- NA_real_
  for (j in seq_along(numeric_fields)) {
    tax_units[[numeric_fields[j]]] <- numeric_sums[, j]
  }
}

row_names <- if (length(name_fields_release)) {
  apply(entries[, name_fields_release, drop = FALSE], 1, collapse_unique)
} else rep(NA_character_, nrow(entries))
tax_units$all_names <- row_names[first_index]

multi_ids <- unit_ids[tax_units$n_entry_rows > 1L]
if (length(multi_ids)) {
  multi_names <- tibble(
    tax_unit_id = entries$tax_unit_id[entries$tax_unit_id %in% multi_ids],
    row_name = row_names[entries$tax_unit_id %in% multi_ids]
  ) %>%
    group_by(tax_unit_id) %>%
    summarise(all_names_multi = collapse_unique(row_name), .groups = "drop")
  replace_at <- match(multi_names$tax_unit_id, tax_units$tax_unit_id)
  tax_units$all_names[replace_at] <- multi_names$all_names_multi
}

tax_units <- tax_units %>%
  select(-record_id, -parent_record_id, -record_unit_type, -source_row, -schema_confidence)

if (length(person_stock_fields_release)) {
  person_matrix <- tax_units %>%
    select(all_of(person_stock_fields_release)) %>%
    as.data.frame()
  tax_units$person_count_fields_present <- rowSums(!is.na(person_matrix))
  tax_units$recorded_person_count_sum <- ifelse(
    tax_units$person_count_fields_present == 0L,
    NA_real_,
    rowSums(person_matrix, na.rm = TRUE)
  )
} else {
  tax_units$person_count_fields_present <- 0L
  tax_units$recorded_person_count_sum <- NA_real_
}

tax_units <- tax_units %>%
  mutate(
    unit_interpretation = case_when(
      form_type == "capitation_tax_return" ~ "capitation_tax_unit",
      form_type == "aggregate_houseful_production_return" ~ "administrative_houseful_or_establishment",
      form_type == "named_adult_servant_return" ~ "named_adult_administrative_unit",
      TRUE ~ "opgaaf_administrative_or_tax_unit"
    ),
    residential_household_verified = FALSE,
    recorded_person_count_includes_named_people = FALSE,
    comparability_note = "Counts sum only explicitly numeric person-stock cells. Named heads/spouses are not added, and blanks remain NA at entry level."
  ) %>%
  relocate(
    release_version, tax_unit_id, declaration_record_id, unit_interpretation,
    residential_household_verified, form_type, district, year, source_key,
    source_workbook, source_sheet, head_source_row, source_folio,
    n_entry_rows, n_sub_entries, all_names,
    person_count_fields_present, recorded_person_count_sum,
    recorded_person_count_includes_named_people, comparability_note
  ) %>%
  arrange(district, year, source_key, source_sheet, head_source_row)

tax_units_csv <- file.path(release_dir, "opgaaf_tax_units_clean_v2.csv")
canonical_csv <- file.path(release_dir, "opgaaf_clean_v2.csv")
write_csv(tax_units, tax_units_csv, na = "")
saveRDS(tax_units, file.path(release_dir, "opgaaf_tax_units_clean_v2.rds"), compress = "gzip")
if (!file.copy(tax_units_csv, canonical_csv, overwrite = TRUE)) {
  stop("Could not create canonical single-file CSV: ", canonical_csv)
}

message("Wrote ", format(nrow(tax_units), big.mark = ","), " tax/administrative units")
message("Units with subordinate rows: ", sum(tax_units$n_sub_entries > 0L))
message("Canonical CSV: ", canonical_csv)
