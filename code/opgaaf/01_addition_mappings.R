# Reviewed column layouts for the six September 2026 additions.
# Use complete layouts, not forward-filled guesses across population blocks.
addition_sheet_ids <- c(paste0("george::", c(1824, 1826)),
                        paste0("clanwilliam::", c(1809, 1811, 1812, 1824)))

wide_layout <- c(
  "entry_number_raw", "source_page_info", "add_info", "names_men", "names_women",
  "settler_men", "settler_women", "settler_sons", "settler_daughters", "servants",
  unlist(lapply(c("khoe", "freeblack", "slave", "prizenegro"),
                function(g) paste(g, c("men", "sons", "women", "daughters"), sep = "_"))),
  unlist(lapply(c("khoe_in_service", "slave_in_service"),
                function(g) paste(g, c("men", "sons", "women", "daughters"), sep = "_"))),
  "horse_work", "horse_breeding", "cattle_work", "cattle_breeding", "sheep_wether",
  "sheep_breeding", "sheep_wool", "donkeys", "goats", "pigs",
  "wheat_seed", "barley_seed", "rye_seed", "oat_seed",
  "wheat_vol", "barley_vol", "rye_vol", "oat_vol", "vines", "wine", "brandy", "wagons", "carts",
  "land_owned_raw", "land_quitrent_raw", "land_loan_raw", "farm_name",
  "distance_owned_raw", "distance_quitrent_raw", "distance_loan_raw",
  "agricultural_use_owned_raw", "agricultural_use_quitrent_raw", "agricultural_use_loan_raw",
  "settlers_died_male", "settlers_died_female", "khoe_died_male", "khoe_died_female",
  "slaves_died_male", "slaves_died_female"
)
stopifnot(length(wide_layout) == 73L)
george_layout <- c(wide_layout, tax_amount_fields[1:8])
clan_early_layout <- c(wide_layout, "church_contribution_raw", "opgaaf_tax_raw")
clan_1824_layout <- c(
  "entry_number_raw", "add_info", "names_men", "names_women", "field_cornet",
  "settler_men", "settler_women", "settler_sons", "settler_daughters",
  "prizenegro_men", "prizenegro_women", prize_origin_fields,
  "khoe_men", "khoe_sons", "khoe_women", "khoe_daughters",
  "slave_men", "slave_sons", "slave_women", "slave_daughters",
  "horse_work", "horse_breeding", "cattle_work", "cattle_breeding",
  "sheep_wether", "sheep_breeding", "sheep_wool", "goats", "pigs",
  "wheat_seed", "barley_seed", "rye_seed", "oat_seed",
  "wheat_vol", "barley_vol", "rye_vol", "oat_vol", "vines", "wine", "brandy", "wagons", "carts",
  "land_loan_places_raw", "land_owned_places_raw", "land_owned_erven_raw",
  "land_owned_morgen_raw", "land_owned_square_roods_raw",
  "land_quitrent_places_raw", "land_quitrent_erven_raw", "land_quitrent_morgen_raw",
  "land_quitrent_square_roods_raw", "land_loan_raw", "farm_name", "distance_raw", "agricultural_use_raw",
  "settlers_died_male", "settlers_died_female", "prizenegro_died_male", "prizenegro_died_female",
  "khoe_died_male", "khoe_died_female", "slaves_died_male", "slaves_died_female"
)
stopifnot(length(george_layout) == 81L, length(clan_early_layout) == 75L,
          length(clan_1824_layout) == 66L)

apply_addition_mappings <- function(registry) {
  for (id in addition_sheet_ids) {
    idx <- which(registry$sheet_id == id)
    fields <- if (startsWith(id, "george")) george_layout else if (id == "clanwilliam::1824") clan_1824_layout else clan_early_layout
    stopifnot(length(idx) >= length(fields))
    for (i in idx) {
      col <- registry$source_column_index[i]
      # Blank trailing columns do not inherit the last header's meaning.
      field <- if (col <= length(fields)) fields[col] else NA_character_
      char <- !is.na(field) && (field %in% identity_fields || endsWith(field, "_raw"))
      person <- !is.na(field) && field %in% c(person_stock_fields, prize_origin_fields)
      service <- !is.na(field) && field %in% service_stock_fields
      flow <- !is.na(field) && grepl("_died_", field)
      named <- !is.na(field) && field %in% c("names_men", "names_women")
      group <- if (person || service || flow) sub("_.*", "", field) else if (named) "settler" else NA_character_
      group <- recode(group, settlers = "settler", slaves = "slave", servants = "servant")
      sex <- case_when(
        is.na(field) ~ NA_character_,
        grepl("women|daughters|_female$", field) ~ "female",
        grepl("men|sons|_male$", field) ~ "male",
        TRUE ~ NA_character_
      )
      age <- if (person || service) age_metadata(registry$header_direct[i],
                 if (grepl("sons", field)) "sons" else if (grepl("daughters", field)) "daughters" else if (!is.na(sex) && sex == "male") "men" else "women") else list(lower = NA_integer_, upper = NA_integer_)
      measure <- case_when(
        is.na(field) ~ NA_character_, service ~ "employment_stock", person ~ "person_stock",
        flow ~ "person_flow", named ~ "named_person", char ~ "identifier",
        field %in% tax_amount_fields ~ "tax_amount", TRUE ~ "asset_stock"
      )
      registry$canonical_field[i] <- field
      registry$field_type[i] <- if (is.na(field)) NA_character_ else if (char) "character" else "numeric"
      registry$population_group[i] <- group
      registry$sex[i] <- sex
      registry$age_lower[i] <- age$lower
      registry$age_upper[i] <- age$upper
      registry$measure_type[i] <- measure
      registry$include_in_clean[i] <- !is.na(field)
      registry$duplicate_target[i] <- FALSE
      registry$confidence[i] <- if (is.na(field)) "C" else "B"
      registry$mapping_method[i] <- if (is.na(field)) "unmapped" else "manual_header_override"
      registry$notes[i] <- case_when(
        is.na(field) ~ "Trailing column without a transcribed header; not harmonized",
        service ~ "In Dienst Hebbende block; employment counts kept separate and excluded from the person-count sum because overlap is unknown",
        field %in% prize_origin_fields ~ "Child stock by place of birth/arrival; not an annual birth flow",
        field %in% c("opgaaf_tax_raw", "church_contribution_raw") ~ "Currency unit not stated; preserve original text without conversion",
        TRUE ~ "September 2026 addition: manually reviewed transcribed column header; archival-image verification pending"
      )
    }
  }
  registry
}
