# Compare every pre-existing observation with v1 (when the reference release is
# available; set CHDR_REFERENCE_DATA to the folder holding v1/ and v2/) and audit
# the six sheets added in v2.
reference_data <- Sys.getenv("CHDR_REFERENCE_DATA")
have_v1 <- nzchar(reference_data) && dir.exists(file.path(reference_data, "v1"))
source(here::here("pipeline", "opgaaf", "00_config.R"))
source(here::here("pipeline", "opgaaf", "01_addition_mappings.R"))
entries <- readRDS(file.path(release_dir, "opgaaf_entries_clean_v2.rds"))
units <- readRDS(file.path(release_dir, "opgaaf_tax_units_clean_v2.rds"))
registry <- read_csv(file.path(release_dir, "census_schema_registry_v2.csv"), show_col_types = FALSE, guess_max = Inf)
flags <- read_csv(file.path(release_dir, "data_quality_flags_v2.csv"), show_col_types = FALSE, guess_max = Inf)
checks <- list()
add_check <- function(id, description, passed, observed) {
  checks[[length(checks) + 1L]] <<- tibble(test_id = id, description = description,
                                       passed = isTRUE(passed), observed = as.character(observed))
}
comparisons <- list()
if (have_v1) {
for (kind in c("entries", "tax_units")) {
  old <- readRDS(file.path(reference_data, "v1", paste0("opgaaf_", kind, "_clean_v1.rds")))
  new <- if (kind == "entries") entries else units
  id <- if (kind == "entries") "record_id" else "tax_unit_id"
  at <- match(old[[id]], new[[id]])
  add_check(paste0("R_", kind, "_ids"), paste("Every v1", kind, "ID is retained"),
            !anyNA(at), sum(!is.na(at)))
  stopifnot(!anyNA(at), all(names(old) %in% names(new)))
  aligned <- new[at, ]
  allowed <- c("release_version", "source_workbook")
  cols <- setdiff(names(old), allowed)
  changed <- vapply(cols, function(col) {
    x <- old[[col]]; y <- aligned[[col]]
    sum(is.na(x) != is.na(y) | (!is.na(x) & !is.na(y) & x != y))
  }, numeric(1))
  comparisons[[kind]] <- tibble(dataset = kind, variable = cols, changed_cells = unname(changed))
  add_check(paste0("R_", kind, "_values"), paste("Every pre-existing", kind, "value is unchanged, excluding version and workbook path"),
            sum(changed) == 0, sum(changed))
  expected_path <- old$source_workbook
  expected_path[old$source_key == "george"] <- sources_v2$relative_path[sources_v2$source_key == "george"]
  add_check(paste0("R_", kind, "_paths"), "Only George's workbook reference changes", identical(expected_path, aligned$source_workbook),
            sum(expected_path != aligned$source_workbook))
  extra_cols <- setdiff(names(new), names(old))
  add_check(paste0("R_", kind, "_new_fields"), "New fields are NA on all v1 observations", all(is.na(aligned[, extra_cols, drop = FALSE])),
            paste(length(extra_cols), "new columns"))
}
write_csv(bind_rows(comparisons), file.path(release_dir, "v1_value_comparison.csv"))

old_units <- readRDS(file.path(reference_data, "v1", "opgaaf_tax_units_clean_v1.rds"))
impact <- full_join(old_units %>% count(district, year, name = "n_v1"),
                    units %>% count(district, year, name = "n_v2"), by = c("district", "year")) %>%
  mutate(across(c(n_v1, n_v2), ~coalesce(.x, 0L)), added_tax_units = n_v2 - n_v1) %>% arrange(district, year)
write_csv(impact, file.path(release_dir, "v2_impact_report.csv"))
} else message("CHDR_REFERENCE_DATA not set: v1 regression checks skipped")

audits <- list()
coverage <- list()
nonrecord_cells <- list()
for (key in c("george", "clanwilliam")) {
  wb <- loadWorkbook(sources_v2$path[sources_v2$source_key == key])
  years <- if (key == "george") c("1824", "1826") else c("1809", "1811", "1812", "1824")
  for (yr in years) {
    raw <- read.xlsx(wb, sheet = yr, colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
    raw_number <- str_trim(as.character(raw[[1]]))
    numbered <- !is.na(raw_number) & str_detect(raw_number, "^[0-9]+$")
    row_id <- paste(key, yr, seq_len(nrow(raw)), sep = "::")
    e <- entries %>% filter(source_key == key, source_sheet == yr)
    u <- units %>% filter(source_key == key, source_sheet == yr)
    f <- flags %>% filter(source_key == key, source_sheet == yr, flag_level == "row") %>%
      group_by(record_id) %>% summarise(exclusion = paste(unique(flag_type), collapse = ";"), .groups = "drop")
    audit <- tibble(record_id = row_id, source_key = key, source_sheet = yr,
                    source_row = seq_len(nrow(raw)), numbered = numbered,
                    raw_text = apply(raw, 1, function(x) paste(na.omit(x), collapse = " | "))) %>%
      left_join(e %>% select(record_id, record_unit_type, tax_unit_id), by = "record_id") %>%
      left_join(f, by = "record_id")
    audits[[paste(key, yr)]] <- audit
    sr <- registry %>% filter(source_key == key, sheet == yr, include_in_clean, field_type == "numeric")
    for (j in seq_len(nrow(sr))) {
      values <- str_trim(as.character(raw[[sr$source_column_index[j]]]))
      at <- which(seq_len(nrow(raw)) > 3 & !row_id %in% e$record_id & !is.na(values) & values != "" & values != "NA")
      if (length(at)) nonrecord_cells[[length(nonrecord_cells) + 1L]] <- tibble(
        record_id = row_id[at], source_key = key, source_sheet = yr, source_row = at,
        source_column = sr$source_column[j], canonical_field = sr$canonical_field[j], raw_value = values[at],
        decision = "Not assigned to a declarant; archival-image verification required")
    }
    coverage[[paste(key, yr)]] <- tibble(source_key = key, year = as.integer(yr),
       numbered_source_rows = sum(numbered), released_numbered_rows = sum(row_id[numbered] %in% e$record_id),
       clean_entries = nrow(e), clean_tax_units = nrow(u), subordinate_entries = sum(e$record_unit_type == "sub_entry"))
  }
}
audit <- bind_rows(audits)
coverage <- bind_rows(coverage)
write_csv(audit, file.path(release_dir, "addition_row_audit.csv"), na = "")
write_csv(coverage, file.path(release_dir, "addition_coverage.csv"))
write_csv(bind_rows(nonrecord_cells), file.path(release_dir, "addition_nonrecord_cells.csv"))
review_issues <- tribble(
  ~source_key, ~source_sheet, ~issue, ~treatment,
  "george", "1826", "Tax amounts occur on non-record and folio-marker rows, suggesting possible vertical alignment problems", "Keep named-row amounts exactly at transcribed coordinates; do not reassign orphan amounts. Verify tax columns against archival images before analysis; see addition_nonrecord_cells.csv",
  "george", "1826", "Unnamed row 603 contains one horse and precedes a numbering gap (61 to 63)", "Exclude from declarant file; retain in row/cell audit. Could be an incomplete missing declaration rather than a continuation; do not attach it to entry 61",
  "george", "1826", "Transcriber reports bleed-through, blocked information, water damage, soiling and tight binding", "Preserve transcriber notes and ambiguous-cell flags; do not reconstruct values",
  "clanwilliam", "1809;1811;1812", "Three complete named rows have blank entry numbers", "Retain as separate administrative units with row-based IDs; record decision in corrections log",
  "clanwilliam", "1809;1811", "Mortality block labelled Not shown in the transcription template", "Headers alone do not establish surviving historical observations; retain blank cells as NA"
)
write_csv(review_issues, file.path(release_dir, "addition_review_issues.csv"))
add_check("R_added_numbered", "All 3,123 new numbered source rows are retained", sum(coverage$released_numbered_rows) == 3123,
          sum(coverage$released_numbered_rows))
add_check("R_added_counts", "Each added sheet reconciles to its numbered returns plus the three independent unnumbered declarations",
          identical(coverage$clean_tax_units, c(965L, 752L, 253L, 270L, 273L, 613L)) &&
            all(coverage$clean_entries == coverage$clean_tax_units), sum(coverage$clean_tax_units))
if (have_v1) add_check("R_added_sheets", "Tax-unit additions are confined to the six requested district-years",
          sum(impact$added_tax_units != 0) == 6 && all(impact$added_tax_units >= 0), sum(impact$added_tax_units))
service <- registry %>% filter(sheet_id %in% addition_sheet_ids, canonical_field %in% service_stock_fields)
add_check("R_employment", "Separate employment blocks are not classified as person stocks",
          nrow(service) == 40 && all(service$measure_type == "employment_stock"), nrow(service))
origin <- registry %>% filter(sheet_id == "clanwilliam::1824", canonical_field %in% prize_origin_fields)
add_check("R_child_origin", "The four child-origin categories are stocks, not birth flows",
          nrow(origin) == 4 && all(origin$measure_type == "person_stock"), nrow(origin))
independent_ids <- with(independent_unnumbered_rows_v2, paste(source_key, sheet, source_row, sep = "::"))
add_check("R_unnumbered", "Three complete unnumbered Clanwilliam returns retain separate tax-unit IDs",
          all(independent_ids %in% units$tax_unit_id), sum(independent_ids %in% units$tax_unit_id))
add_check("R_folio", "George 1826 row 462 correctly inherits folio 21 after the FOLI0 marker",
          identical(entries$source_folio[entries$record_id == "george::1826::462"], 21L), "folio 21 expected")
g <- units %>% filter(tax_unit_id == "george::1824::4")
add_check("R_sample_employment", "George 1824 first return retains its one employed Khoe man separately from three explicit family counts",
          nrow(g) == 1 && g$khoe_in_service_men == 1 && is.na(g$khoe_men) && g$recorded_person_count_sum == 3,
          "Source row 4, columns 6, 7, 9 and 27")
c <- units %>% filter(tax_unit_id == "clanwilliam::1809::276")
add_check("R_sample_unnumbered", "Unnumbered Van Zyl declaration retains its own livestock and fractional barley seed",
          nrow(c) == 1 && c$horse_work == 12 && c$barley_seed == 0.5 && c$settler_sons == 2,
          "Source row 276, columns 8, 35 and 46")
add_check("R_canonical_csv", "Canonical CSV equals the tax-unit export",
          unname(tools::md5sum(file.path(release_dir, "opgaaf_clean_v2.csv"))) ==
            unname(tools::md5sum(file.path(release_dir, "opgaaf_tax_units_clean_v2.csv"))), "MD5 comparison")
result <- bind_rows(checks)
write_csv(result, file.path(release_dir, "addition_validation_tests.csv"))
print(coverage)
print(result, n = Inf)
stopifnot(all(result$passed))
