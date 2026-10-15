# Build the explicit sheet-column registry from workbook headers.

source(here::here("pipeline", "opgaaf", "00_config.R"))
source(here::here("pipeline", "opgaaf", "01_registry_helpers.R"))

registry_parts <- list()
sheet_parts <- list()
part_i <- 0L
sheet_i <- 0L

for (source_i in seq_len(nrow(sources_v2))) {
  src <- sources_v2[source_i, ]
  message("Registry: ", src$source_key)
  wb <- loadWorkbook(src$path)
  sheets <- year_sheets_v2(src$source_key, src$path)

  for (sheet in sheets) {
    year <- sheet_year(sheet)
    probe <- read.xlsx(wb, sheet = sheet, rows = 1:4, colNames = FALSE,
                       skipEmptyRows = FALSE, skipEmptyCols = FALSE,
                       fillMergedCells = TRUE, check.names = FALSE)
    n_columns <- ncol(probe)
    n_header_rows <- header_row_count(src$source_key, year, n_columns)
    first_data_row <- first_data_row_v2(src$source_key, year, n_header_rows)
    headers <- read_header_block(wb, sheet, n_header_rows, n_columns)

    group_values_raw <- as.character(headers[1, , drop = TRUE])
    group_values <- group_values_raw
    last_group <- NA_character_
    last_group_col <- NA_integer_
    for (j in seq_len(n_columns)) {
      raw_group_norm <- normalize_header(group_values_raw[j])
      if (!is.na(group_values_raw[j]) && str_trim(group_values_raw[j]) != "" &&
          !raw_group_norm %in% c("na", "n a")) {
        last_group <- group_values_raw[j]
        last_group_col <- j
      } else if (!is.na(last_group)) {
        # A title describing named heads/wives normally spans two columns even
        # when the spreadsheet did not encode a merged cell. Do not allow it
        # to leak into the subsequent numeric family-count block.
        is_name_group <- str_detect(normalize_header(last_group), rx_v2$names) &&
          !str_detect(normalize_header(last_group), "numbered by (the )?transcriber|^nb ")
        if (!is_name_group || j <= last_group_col + 1L) group_values[j] <- last_group
      }
    }

    # Fill each lower header tier only within its higher-level block. This is
    # needed for three-level forms such as Group -> Sex -> Above/Below age.
    header_lower <- if (n_header_rows >= 2L) {
      as.matrix(headers[2:n_header_rows, , drop = FALSE])
    } else {
      matrix(NA_character_, nrow = 0L, ncol = n_columns)
    }
    if (nrow(header_lower)) {
      for (k in seq_len(nrow(header_lower))) {
        last_value <- NA_character_
        last_value_col <- NA_integer_
        for (j in seq_len(n_columns)) {
          top_reset <- j == 1L ||
            (!is.na(group_values_raw[j]) && !normalize_header(group_values_raw[j]) %in% c("", "na", "n a"))
          upper_reset <- FALSE
          if (k > 1L) {
            upper_raw <- header_lower[seq_len(k - 1L), j]
            upper_reset <- any(!is.na(upper_raw) & !normalize_header(upper_raw) %in% c("", "na", "n a"))
          }
          if (top_reset || upper_reset) last_value <- NA_character_
          value <- as.character(header_lower[k, j])
          if (!is.na(value) && !normalize_header(value) %in% c("", "na", "n a")) {
            last_value <- value
            last_value_col <- j
          } else if (!is.na(last_value)) {
            is_name_value <- str_detect(normalize_header(last_value), rx_v2$names) &&
              !str_detect(normalize_header(last_value), "numbered by (the )?transcriber|^nb ")
            if (!is_name_value || j <= last_value_col + 1L) header_lower[k, j] <- last_value
          }
        }
      }
    }
    direct_values <- vapply(seq_len(n_columns), function(j) {
      vals <- if (nrow(header_lower)) as.character(header_lower[, j]) else character()
      paste(unique(vals[!is.na(vals) & str_trim(vals) != ""]), collapse = " | ")
    }, character(1))
    # Forms often write the sex once and put "under 16" in the following
    # column. Carry the sex only within the same population-group block.
    for (j in seq.int(2L, n_columns)) {
      d <- normalize_header(direct_values[j])
      prev <- normalize_header(direct_values[j - 1L])
      same_group <- identical(normalize_header(group_values[j]), normalize_header(group_values[j - 1L]))
      if (same_group && str_detect(d, "under|below|onder|beneden") &&
          !str_detect(d, paste(rx_v2$male, rx_v2$female, sep = "|")) &&
          str_detect(prev, paste(rx_v2$male, rx_v2$female, sep = "|"))) {
        direct_values[j] <- paste(direct_values[j - 1L], direct_values[j], sep = " | ")
      }
    }
    combined_values <- vapply(seq_len(n_columns), function(j) {
      vals <- c(group_values[j], direct_values[j])
      paste(unique(vals[!is.na(vals) & str_trim(vals) != ""]), collapse = " | ")
    }, character(1))

    classified <- map_dfr(seq_len(n_columns), function(j) {
      classify_header_v2(group_values[j], direct_values[j], combined_values[j], j)
    })

    sheet_id <- paste(src$source_key, sheet, sep = "::")
    this <- tibble(
      release_version = release_version,
      source_key = src$source_key,
      district = src$district,
      source_workbook = src$relative_path,
      sheet = sheet,
      year = year,
      sheet_id = sheet_id,
      n_header_rows = n_header_rows,
      first_data_row = first_data_row,
      source_column_index = seq_len(n_columns),
      source_column = paste0("V", seq_len(n_columns)),
      excel_column = excel_column(seq_len(n_columns)),
      header_group = group_values,
      header_direct = direct_values,
      header_combined = combined_values,
      header_normalized = normalize_header(combined_values)
    ) %>% bind_cols(classified)

    # Multiple columns mapped to exactly the same canonical field are unsafe
    # unless explicitly adjudicated later.
    this <- this %>%
      group_by(canonical_field) %>%
      mutate(
        duplicate_target = !is.na(canonical_field) & n() > 1L,
        confidence = if_else(duplicate_target, "C", confidence),
        mapping_method = if_else(duplicate_target, paste0(mapping_method, ":duplicate_target"), mapping_method)
      ) %>%
      ungroup() %>%
      mutate(
        include_in_clean = !is.na(canonical_field) & confidence %in% c("A", "B"),
        blank_interpretation = "unknown_not_coerced_to_zero"
      )

    part_i <- part_i + 1L
    registry_parts[[part_i]] <- this
    sheet_i <- sheet_i + 1L
    sheet_parts[[sheet_i]] <- tibble(
      source_key = src$source_key, district = src$district,
      source_workbook = src$relative_path, sheet = sheet, year = year,
      sheet_id = sheet_id, n_header_rows = n_header_rows,
      first_data_row = first_data_row, n_columns = n_columns,
      n_mapped_b = sum(this$include_in_clean),
      n_unmapped_or_ambiguous = sum(!this$include_in_clean),
      form_type = case_when(
        src$source_key == "stellenbosch_1780" & year == 1839L ~ "named_adult_servant_return",
        src$source_key == "stellenbosch_1780" & year %in% 1841:1844 ~ "aggregate_houseful_production_return",
        src$source_key == "worcester" & year >= 1830L ~ "capitation_tax_return",
        TRUE ~ "opgaaf_declaration_return"
      )
    )
  }
}

registry <- bind_rows(registry_parts) %>%
  left_join(summary_boundaries_v2 %>% select(source_key, sheet, summary_start_row),
            by = c("source_key", "sheet")) %>%
  mutate(notes = case_when(
    !is.na(summary_start_row) ~ "Known summary section begins within this sheet",
    confidence == "C" & duplicate_target ~ "Duplicate canonical target requires manual adjudication",
    is.na(canonical_field) ~ "Source column retained in raw workbook but not harmonized in v2",
    TRUE ~ NA_character_
  ))

# Suppress generic person mappings on the aggregate 1841-1844 form, then apply
# the explicitly documented overrides above.
registry <- registry %>%
  mutate(
    suppress_for_special_form = source_key == "stellenbosch_1780" &
      sheet %in% c("1841", "1842", "1843", "1844") &
      measure_type %in% c("named_person", "person_stock", "person_flow"),
    include_in_clean = if_else(suppress_for_special_form, FALSE, include_in_clean),
    confidence = if_else(suppress_for_special_form, "C", confidence),
    notes = if_else(suppress_for_special_form,
                    "Suppressed generic mapping; special-form override required", notes)
  ) %>%
  left_join(
    registry_overrides_v2 %>%
      rename(override_field = canonical_field, override_type = field_type,
             override_group = population_group, override_sex = sex,
             override_measure = measure_type),
    by = c("source_key", "sheet", "source_column")
  ) %>%
  mutate(
    canonical_field = coalesce(override_field, canonical_field),
    field_type = coalesce(override_type, field_type),
    population_group = coalesce(override_group, population_group),
    sex = coalesce(override_sex, sex),
    measure_type = coalesce(override_measure, measure_type),
    confidence = if_else(!is.na(override_field), "B", confidence),
    include_in_clean = if_else(!is.na(override_field), TRUE, include_in_clean),
    mapping_method = if_else(!is.na(override_field), "manual_header_override", mapping_method),
    notes = coalesce(override_note, notes)
  ) %>%
  select(-starts_with("override_"), -suppress_for_special_form)

source(here::here("pipeline", "opgaaf", "01_addition_mappings.R"))
registry <- apply_addition_mappings(registry)

sheet_registry <- bind_rows(sheet_parts) %>%
  select(-n_mapped_b, -n_unmapped_or_ambiguous) %>%
  left_join(registry %>% group_by(sheet_id) %>% summarise(
    n_mapped_b = sum(include_in_clean),
    n_unmapped_or_ambiguous = sum(!include_in_clean), .groups = "drop"), by = "sheet_id") %>%
  left_join(summary_boundaries_v2, by = c("source_key", "sheet")) %>%
  arrange(district, year, source_key, sheet)

write_csv(registry, file.path(release_dir, "census_schema_registry_v2.csv"), na = "")
write_csv(sheet_registry, file.path(release_dir, "census_sheet_registry_v2.csv"), na = "")

message("Wrote ", nrow(registry), " column mappings across ", nrow(sheet_registry), " sheets")
message("Confidence/include counts:")
print(registry %>% count(confidence, include_in_clean))
