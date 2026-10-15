# Extract genuine declaration/sub-entry rows using the v2 schema registry.

source(here::here("pipeline", "opgaaf", "00_config.R"))
source(here::here("pipeline", "opgaaf", "01_registry_helpers.R"))

registry_path <- file.path(release_dir, "census_schema_registry_v2.csv")
sheet_registry_path <- file.path(release_dir, "census_sheet_registry_v2.csv")
if (!file.exists(registry_path) || !file.exists(sheet_registry_path)) {
  stop("Run Data/v2_pipeline/01_build_schema_registry.R first")
}

registry <- read_csv(registry_path, show_col_types = FALSE, guess_max = Inf)
sheet_registry <- read_csv(sheet_registry_path, show_col_types = FALSE, guess_max = Inf)

included_duplicates <- registry %>%
  filter(include_in_clean, !is.na(canonical_field)) %>%
  count(sheet_id, canonical_field) %>%
  filter(n > 1L)
if (nrow(included_duplicates) > 0L) {
  print(included_duplicates, n = Inf)
  stop("Registry has duplicate included targets; adjudicate before extraction")
}

clean_character <- function(x) {
  x <- as.character(x)
  x <- str_squish(x)
  x[x == "" | is.na(x)] <- NA_character_
  x
}

parse_numeric_strict <- function(x, allow_fraction = TRUE) {
  x <- clean_character(x)
  x <- str_replace_all(x, "\\s", "")
  if (allow_fraction) {
    x <- str_replace(x, "^(\\d+),(\\d+)$", "\\1.\\2")
    x <- str_replace(x, "^,(\\d+)$", "0.\\1")
  }
  out <- suppressWarnings(as.numeric(x))
  # Construct Unicode names at runtime: quoted argument names in c() can be
  # translated to native encoding by R's parser under a Windows C locale.
  fractions <- setNames(c(1/3, 2/3, 1/4, 1/2, 3/4, 1/8, 3/8, 5/8, 7/8),
                        c("\u2153", "\u2154", "\u00bc", "\u00bd", "\u00be",
                          "\u215b", "\u215c", "\u215d", "\u215e"))
  if (allow_fraction) for (symbol in names(fractions)) {
    hit <- !is.na(x) & str_detect(x, fixed(symbol))
    if (any(hit)) {
      whole <- str_remove(x[hit], fixed(symbol))
      whole[whole == ""] <- "0"
      whole_num <- suppressWarnings(as.numeric(whole))
      out[hit] <- whole_num + fractions[[symbol]]
    }
  }
  ascii_fraction <- allow_fraction & !is.na(x) & str_detect(x, "^\\d{1,2}/\\d{1,2}$")
  if (any(ascii_fraction)) {
    numerator <- as.numeric(str_extract(x[ascii_fraction], "^\\d{1,2}"))
    denominator <- as.numeric(str_extract(x[ascii_fraction], "(?<=/)\\d{1,2}$"))
    valid <- denominator > 0 & numerator < denominator
    out[which(ascii_fraction)[valid]] <- numerator[valid] / denominator[valid]
  }
  one_sixteenth <- allow_fraction & !is.na(x) & x == "\u215f16"
  out[one_sixteenth] <- 1/16
  lower <- str_to_lower(x)
  explicit_zero <- !is.na(lower) & lower %in% c("nil", "nix", "nildroogte")
  out[explicit_zero] <- 0
  word_fractions <- c(
    "eenagtste" = 1/8, "one/eigth" = 1/8,
    "drieagstes" = 3/8, "vyfagtste" = 5/8,
    "driesenstiendes" = 3/16,
    "1-16th" = 1/16, "1sixteenth" = 1/16,
    "3-16th" = 3/16, "3sixteenths" = 3/16,
    "3/16th" = 3/16, "1/16th" = 1/16
  )
  if (allow_fraction) for (label in names(word_fractions)) out[!is.na(lower) & lower == label] <- word_fractions[[label]]
  mixed_fraction <- allow_fraction & !is.na(lower) & str_detect(lower, "^\\d+'\\d+/\\d+$")
  if (any(mixed_fraction)) {
    z <- str_match(lower[mixed_fraction], "^(\\d+)'(\\d+)/(\\d+)$")
    out[mixed_fraction] <- as.numeric(z[, 2]) + as.numeric(z[, 3]) / as.numeric(z[, 4])
  }
  implied_one_fraction <- allow_fraction & !is.na(lower) & str_detect(lower, "^\\d+'/(\\d+)$")
  if (any(implied_one_fraction)) {
    z <- str_match(lower[implied_one_fraction], "^(\\d+)'/(\\d+)$")
    out[implied_one_fraction] <- as.numeric(z[, 2]) + 1 / as.numeric(z[, 3])
  }
  out
}

is_special_numeric_normalization <- function(x) {
  z <- str_to_lower(str_replace_all(coalesce(clean_character(x), ""), "\\s", ""))
  str_detect(z, "\u2153|\u2154|\u00bc|\u00bd|\u00be|\u215b|\u215c|\u215d|\u215e|\u215f|^,\\d+$|^\\d{1,2}/\\d{1,2}$|^\\d+'\\d+/\\d+$|^\\d+'/(\\d+)$") |
    z %in% c("nil", "nix", "nildroogte", "eenagtste", "one/eigth", "drieagstes",
             "vyfagtste", "driesenstiendes", "1-16th", "1sixteenth",
             "3-16th", "3sixteenths", "3/16th", "1/16th")
}

is_numeric_entry <- function(x) {
  !is.na(x) & str_detect(str_trim(x), "^\\d+(?:\\.0+)?$")
}

scan_row_structure <- function(raw, first_data_row, entry_col_index = 1L,
                               summary_start_row = NA_integer_) {
  n <- nrow(raw)
  source_row <- seq_len(n)
  first_col <- clean_character(raw[[entry_col_index]])
  row_text <- apply(raw, 1, function(z) paste(na.omit(clean_character(z)), collapse = " | "))
  folio_marker <- str_detect(coalesce(first_col, ""), regex("^folio\\s*\\d+", ignore_case = TRUE))
  folio_value <- suppressWarnings(as.integer(str_extract(first_col, "\\d+")))
  folio_id <- rep(NA_integer_, n)
  current_folio <- NA_integer_
  for (i in seq_len(n)) {
    if (folio_marker[i] && !is.na(folio_value[i])) current_folio <- folio_value[i]
    folio_id[i] <- current_folio
  }
  explicit_summary <- str_detect(
    row_text,
    regex("(^|\\|\\s*)(totaal|total|summa|recapitulation|summary)(\\s|:|$)", ignore_case = TRUE)
  )
  boundary_summary <- !is.na(summary_start_row) & source_row >= summary_start_row
  tibble(
    source_row = source_row,
    row_text = row_text,
    before_data = source_row < first_data_row,
    folio_marker = folio_marker,
    folio_id = folio_id,
    explicit_summary = explicit_summary,
    boundary_summary = boundary_summary,
    blank_row = row_text == ""
  )
}

entries_parts <- list()
flags_parts <- list()
entry_i <- 0L
flag_i <- 0L

for (source_i in seq_len(nrow(sources_v2))) {
  src <- sources_v2[source_i, ]
  message("Entries: ", src$source_key)
  wb <- loadWorkbook(src$path)
  source_sheets <- sheet_registry %>% filter(source_key == src$source_key)

  for (sheet_i in seq_len(nrow(source_sheets))) {
    sm <- source_sheets[sheet_i, ]
    raw <- read.xlsx(wb, sheet = sm$sheet, colNames = FALSE,
                     skipEmptyRows = FALSE, skipEmptyCols = FALSE,
                     fillMergedCells = FALSE, check.names = FALSE)
    if (ncol(raw) < sm$n_columns) {
      for (j in seq.int(ncol(raw) + 1L, sm$n_columns)) raw[[j]] <- NA_character_
    }
    raw <- raw[, seq_len(sm$n_columns), drop = FALSE]
    names(raw) <- paste0("V", seq_len(ncol(raw)))

    sr <- registry %>% filter(sheet_id == sm$sheet_id, include_in_clean)
    entry_col <- sr %>% filter(canonical_field == "entry_number_raw") %>% pull(source_column_index)
    entry_col <- if (length(entry_col)) entry_col[[1]] else 1L
    structure_raw <- raw
    if (src$source_key == "george" && sm$sheet == "1826") {
      stopifnot(identical(as.character(raw[[1]][461]), "FOLI0 21"))
      structure_raw[[1]][461] <- "FOLIO 21"
    }
    structure <- scan_row_structure(structure_raw, sm$first_data_row, entry_col,
                                    sm$summary_start_row)

    mapped <- tibble(source_row = seq_len(nrow(raw)))
    raw_by_field <- list()
    for (j in seq_len(nrow(sr))) {
      source_col <- sr$source_column[j]
      field <- sr$canonical_field[j]
      values_raw <- as.character(raw[[source_col]])
      raw_by_field[[field]] <- values_raw
      mapped[[field]] <- if (sr$field_type[j] == "numeric") {
        parse_numeric_strict(values_raw, allow_fraction = field %in% continuous_quantity_fields)
      } else {
        clean_character(values_raw)
      }
    }

    # Candidate transcription errors remain in the XLSX but are withheld from
    # parsed values until an archival image resolves them.
    unresolved_here <- unresolved_cells_v2 %>%
      filter(source_key == src$source_key, sheet == sm$sheet)
    implausible_row <- mapped$source_row %in% unresolved_here$source_row
    if (nrow(unresolved_here)) {
      for (u in seq_len(nrow(unresolved_here))) {
        target <- unresolved_here$canonical_field[u]
        if (is.na(target)) {
          target <- sr %>%
            filter(source_column == unresolved_here$source_column[u]) %>%
            pull(canonical_field)
          target <- if (length(target)) target[[1]] else NA_character_
        }
        if (!is.na(target) && target %in% names(mapped)) {
          mapped[[target]][mapped$source_row == unresolved_here$source_row[u]] <- NA_real_
        }
      }
    }

    name_fields <- intersect(c("names_men", "names_women", "names_combined", "surname", "given_names"), names(mapped))
    identity_fields_here <- intersect(c(name_fields, "entry_number_raw"), names(mapped))
    has_name <- if (length(name_fields)) {
      rowSums(!is.na(mapped[, name_fields, drop = FALSE])) > 0L
    } else rep(FALSE, nrow(mapped))
    has_identity <- if (length(identity_fields_here)) {
      rowSums(!is.na(mapped[, identity_fields_here, drop = FALSE])) > 0L
    } else rep(FALSE, nrow(mapped))
    mapped_value_fields <- setdiff(names(mapped), "source_row")
    has_mapped_value <- if (length(mapped_value_fields)) {
      rowSums(!is.na(mapped[, mapped_value_fields, drop = FALSE])) > 0L
    } else rep(FALSE, nrow(mapped))

    header_term_rx <- regex(
      "^(nr|number|folio|mannen|mans|men|vrouwen|vroue|women|zoons|soonen|seuns|sons|dogters|dochters|daughters|knegts|knegte|servants|slaven|slaaven|slawe|slavinnen|slaavinnen|hottentotten|horses|paarden|cattle|beesten|ossen|sheep|schapen|schaapen|pigs|varkens|wagons|wagens|carts|karren|tarwe|wheat|garst|barley|rogge|rye|haver|oats|wine|wijn|brandy|brandewijn)$",
      ignore_case = TRUE
    )
    header_like_count <- apply(raw, 1, function(z) {
      sum(str_detect(normalize_header(as.character(z)), header_term_rx), na.rm = TRUE)
    })
    repeated_header <- header_like_count >= 3L

    person_fields_here <- sr %>%
      filter(measure_type == "person_stock") %>%
      pull(canonical_field) %>% unique() %>% intersect(names(mapped))
    simultaneous_large_person <- if (length(person_fields_here)) {
      person_mat <- as.data.frame(mapped[, person_fields_here, drop = FALSE])
      rowSums(person_mat > 100, na.rm = TRUE) >= 3L |
        rowSums(person_mat > 500, na.rm = TRUE) >= 2L
    } else rep(FALSE, nrow(mapped))

    entry_number <- if ("entry_number_raw" %in% names(mapped)) mapped$entry_number_raw else rep(NA_character_, nrow(mapped))
    independent_unnumbered <- mapped$source_row %in% independent_unnumbered_rows_v2$source_row[
      independent_unnumbered_rows_v2$source_key == src$source_key & independent_unnumbered_rows_v2$sheet == sm$sheet]
    is_head <- is_numeric_entry(entry_number) | independent_unnumbered
    current_head_row <- rep(NA_integer_, nrow(mapped))
    last_head <- NA_integer_
    for (i in seq_len(nrow(mapped))) {
      if (is_head[i]) last_head <- i
      current_head_row[i] <- last_head
    }

    forced_continuation <- paste(src$source_key, sm$sheet, mapped$source_row, sep = "::") %in%
      paste(forced_continuation_rows_v2$source_key,
            forced_continuation_rows_v2$sheet,
            forced_continuation_rows_v2$source_row, sep = "::")

    record_unit_type <- case_when(
      structure$before_data ~ "header",
      structure$blank_row ~ "blank",
      structure$folio_marker ~ "folio_marker",
      implausible_row ~ "implausible_transcription_row",
      repeated_header ~ "repeated_header",
      structure$boundary_summary | structure$explicit_summary | simultaneous_large_person ~ "summary",
      forced_continuation ~ "sub_entry",
      is_head ~ "declaration",
      has_name & !is.na(current_head_row) ~ "sub_entry",
      has_name ~ "declaration",
      has_identity | has_mapped_value ~ "unclassified_data_row",
      TRUE ~ "blank"
    )

    record_id <- paste(src$source_key, sm$sheet, mapped$source_row, sep = "::")
    parent_record_id <- ifelse(
      forced_continuation,
      paste(src$source_key, sm$sheet, mapped$source_row - 1L, sep = "::"),
      ifelse(
        record_unit_type == "sub_entry" & !is.na(current_head_row),
        paste(src$source_key, sm$sheet, current_head_row, sep = "::"),
        NA_character_
      )
    )
    tax_unit_id <- ifelse(record_unit_type == "sub_entry", parent_record_id, record_id)

    out <- bind_cols(
      tibble(
        release_version = release_version,
        record_id = record_id,
        tax_unit_id = tax_unit_id,
        parent_record_id = parent_record_id,
        record_unit_type = record_unit_type,
        form_type = sm$form_type,
        district = src$district,
        year = sm$year,
        source_key = src$source_key,
        source_workbook = src$relative_path,
        source_sheet = sm$sheet,
        source_row = mapped$source_row,
        source_folio = structure$folio_id,
        schema_confidence = "B"
      ),
      mapped %>% select(-source_row)
    ) %>%
      filter(record_unit_type %in% c("declaration", "sub_entry"))

    entry_i <- entry_i + 1L
    entries_parts[[entry_i]] <- out

    # Row-level exclusions and cell-level parsing problems.
    excluded <- tibble(
      record_id = record_id,
      source_key = src$source_key, source_sheet = sm$sheet,
      source_row = mapped$source_row,
      flag_level = "row",
      canonical_field = NA_character_, source_column = NA_character_, raw_value = NA_character_,
      flag_type = case_when(
        repeated_header ~ "repeated_header_excluded",
        implausible_row ~ "implausible_transcription_row_excluded",
        structure$boundary_summary | structure$explicit_summary | simultaneous_large_person ~ "summary_row_excluded",
        record_unit_type == "unclassified_data_row" ~ "unclassified_data_row_excluded",
        TRUE ~ NA_character_
      ),
      severity = if_else(flag_type == "summary_row_excluded", "error_prevented", "review"),
      detail = case_when(structure$boundary_summary ~ "Known sheet boundary",
                         implausible_row ~ "User decision: retain raw provenance and exclude entire row pending archival verification",
                         simultaneous_large_person ~ "Multiple simultaneous implausibly large person totals",
                         repeated_header ~ "Repeated page header vocabulary",
                         TRUE ~ "Classifier rule")
    ) %>% filter(!is.na(flag_type))

    numeric_sr <- sr %>% filter(field_type == "numeric")
    cell_flags <- list()
    cf_i <- 0L
    for (j in seq_len(nrow(numeric_sr))) {
      field <- numeric_sr$canonical_field[j]
      source_col <- numeric_sr$source_column[j]
      raw_values <- clean_character(raw[[source_col]])
      parsed_values <- mapped[[field]]
      bad_parse <- !is.na(raw_values) & is.na(parsed_values)
      negative <- !is.na(parsed_values) & parsed_values < 0
      noninteger <- !is.na(parsed_values) & numeric_sr$measure_type[j] %in% c("person_stock", "person_flow", "worker_stock") &
        abs(parsed_values - round(parsed_values)) > 1e-8
      noninteger_discrete <- !is.na(parsed_values) & field %in% discrete_stock_fields &
        abs(parsed_values - round(parsed_values)) > 1e-8
      large_person <- !is.na(parsed_values) & numeric_sr$measure_type[j] == "person_stock" & parsed_values > 100
      stripped_raw <- str_replace_all(coalesce(raw_values, ""), "\\s", "")
      special_candidate <- !is.na(raw_values) & is.na(suppressWarnings(as.numeric(stripped_raw)))
      special_notation <- rep(FALSE, length(raw_values))
      if (any(special_candidate)) {
        special_notation[special_candidate] <-
          is_special_numeric_normalization(raw_values[special_candidate])
      }
      normalized_special <- !is.na(parsed_values) & special_notation
      fraction_in_discrete <- is.na(parsed_values) &
        field %in% discrete_stock_fields & special_notation
      eligible_row <- record_unit_type %in% c("declaration", "sub_entry")
      idx <- which(eligible_row & (bad_parse | negative | noninteger | noninteger_discrete | large_person | normalized_special | fraction_in_discrete))
      if (length(idx)) {
        cf_i <- cf_i + 1L
        cell_flags[[cf_i]] <- tibble(
          record_id = record_id[idx], source_key = src$source_key, source_sheet = sm$sheet,
          source_row = idx, flag_level = "cell", canonical_field = field,
          source_column = source_col, raw_value = raw_values[idx],
          flag_type = case_when(fraction_in_discrete[idx] ~ "noninteger_discrete_stock",
                                bad_parse[idx] ~ "nonnumeric_in_numeric_field",
                                negative[idx] ~ "negative_value",
                                noninteger[idx] ~ "noninteger_person_value",
                                noninteger_discrete[idx] ~ "noninteger_discrete_stock",
                                large_person[idx] ~ "person_value_gt100",
                                normalized_special[idx] ~ "normalized_fraction_or_explicit_zero"),
          severity = case_when(
            fraction_in_discrete[idx] ~ "blocks_cell_use",
            normalized_special[idx] & !bad_parse[idx] & !negative[idx] & !noninteger[idx] & !noninteger_discrete[idx] & !large_person[idx] ~ "resolved",
            TRUE ~ "review"
          ),
          detail = case_when(
            fraction_in_discrete[idx] ~ "Fractional notation is invalid for a discrete person, animal, or vehicle stock; standardized value is NA",
            normalized_special[idx] ~ paste0("Normalized to ", parsed_values[idx]),
            TRUE ~ numeric_sr$header_combined[j]
          )
        )
      }
    }
    flag_i <- flag_i + 1L
    flags_parts[[flag_i]] <- bind_rows(excluded, bind_rows(cell_flags))
  }
}

entries <- bind_rows(entries_parts)
all_fields <- setdiff(unique(registry$canonical_field[registry$include_in_clean]), NA_character_)
for (field in setdiff(all_fields, names(entries))) entries[[field]] <- NA

entries <- entries %>%
  relocate(any_of(c(
    "release_version", "record_id", "tax_unit_id", "parent_record_id", "record_unit_type",
    "form_type", "district", "year", "source_key", "source_workbook", "source_sheet",
    "source_row", "source_folio", "schema_confidence", identity_fields
  ))) %>%
  arrange(district, year, source_key, source_sheet, source_row)

flags <- bind_rows(flags_parts)

# Add the explicitly unresolved transcription cells even if their row otherwise
# passed all row-level checks.
unresolved_flags <- unresolved_cells_v2 %>%
  transmute(
    record_id = paste(source_key, sheet, source_row, sep = "::"),
    source_key, source_sheet = sheet, source_row,
    flag_level = "cell", canonical_field, source_column, raw_value,
    flag_type = "unresolved_transcription", severity = "blocks_cell_use", detail = reason
  )
flags <- bind_rows(flags, unresolved_flags) %>% distinct()

# Invalid parsed stock/flow values are retained in the raw XLSX and flags, but
# withheld from the standardized clean columns. Large integer person values are
# flagged for review and retained because large slave/labour establishments can
# be historically genuine.
blocking_types <- c("negative_value", "noninteger_person_value", "noninteger_discrete_stock", "unresolved_transcription")
blocking_cells <- flags %>%
  filter(flag_type %in% blocking_types, !is.na(canonical_field))
for (field in intersect(unique(blocking_cells$canonical_field), names(entries))) {
  ids <- blocking_cells$record_id[blocking_cells$canonical_field == field]
  entries[[field]][entries$record_id %in% ids] <- NA_real_
}

write_csv(entries, file.path(release_dir, "opgaaf_entries_clean_v2.csv"), na = "")
saveRDS(entries, file.path(release_dir, "opgaaf_entries_clean_v2.rds"), compress = "gzip")
write_csv(flags, file.path(release_dir, "data_quality_flags_v2.csv"), na = "")

structural_missingness <- registry %>%
  group_by(sheet_id, source_key, district, year, sheet, canonical_field) %>%
  summarise(recorded_on_form = any(include_in_clean),
            best_confidence = min(confidence), .groups = "drop") %>%
  filter(!is.na(canonical_field)) %>%
  complete(nesting(sheet_id, source_key, district, year, sheet),
           canonical_field = sort(unique(all_fields)),
           fill = list(recorded_on_form = FALSE, best_confidence = "not_recorded"))
write_csv(structural_missingness, file.path(release_dir, "structural_missingness_v2.csv"), na = "")

message("Wrote ", format(nrow(entries), big.mark = ","), " clean entry rows")
message("Declarations: ", sum(entries$record_unit_type == "declaration"),
        "; sub-entries: ", sum(entries$record_unit_type == "sub_entry"))
message("Flags: ", format(nrow(flags), big.mark = ","))
