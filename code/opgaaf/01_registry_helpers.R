# Helpers for constructing and validating the sheet-column schema registry.

normalize_header <- function(x) {
  x <- ifelse(is.na(x), "", as.character(x))
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
  x %>%
    str_to_lower() %>%
    str_replace_all("[^a-z0-9]+", " ") %>%
    str_squish()
}

excel_column <- function(n) {
  vapply(n, function(x) {
    out <- character()
    while (x > 0) {
      x <- x - 1L
      out <- c(LETTERS[(x %% 26L) + 1L], out)
      x <- x %/% 26L
    }
    paste0(out, collapse = "")
  }, character(1))
}

sheet_year <- function(sheet) suppressWarnings(as.integer(str_extract(sheet, "\\d{4}")))

year_sheets_v2 <- function(source_key, path) {
  sheets <- excel_sheets(path)
  sheets[!str_detect(sheets, regex("index|hottentot", ignore_case = TRUE)) &
           !is.na(sheet_year(sheets))]
}

header_row_count <- function(source_key, year, n_columns) {
  case_when(
    source_key == "george" & year %in% c(1824L, 1826L) ~ 3L,
    source_key == "george" & year %in% c(1819L, 1822L) ~ 3L,
    source_key == "graaff_reinet" & n_columns <= 25L ~ 2L,
    source_key == "graaff_reinet" ~ 3L,
    source_key == "cape_late" & (year == 1807L | year >= 1809L) ~ 3L,
    TRUE ~ 2L
  )
}

first_data_row_v2 <- function(source_key, year, n_header_rows) {
  if (source_key == "george" && year %in% c(1819L, 1822L)) 3L else n_header_rows + 1L
}

rx_v2 <- list(
  names = "naam|namen|naamen|name|names|vrijluijden|vrijluiden|hoofden der|inhabitant|opgezetenen boven",
  male = "(^| )(man|mans|mannen|male|males|men)( |$)",
  female = "vrouw|vroue|vrouwen|female|females|women|woman|slavinnen|slaavinnen|hottentotinnen",
  son = "zoon|zoons|soons|soonen|zonen|sonen|seun|seuns|sons|boys|jonge|jonges|jongen|jongens|jongetjes",
  daughter = "dogter|dogters|dochter|dochters|daughter|daughters|girl|girls|meisje|meijsje|meijd",
  child = "kinder|children",
  servant = "kneg|knecht|servant|bediend|dienaar|dienaer",
  slave = "slaaf|slave|slaven|slavin|slaaven|slawe",
  khoe = "khoe|khoi|hottentot",
  freeblack = "free black|vrije zwart|vrye zwart|vrijzwart",
  prize = "prize|prijs neger|prys neger|recaptured"
)

detect_group <- function(h) {
  case_when(
    str_detect(h, rx_v2$freeblack) ~ "freeblack",
    str_detect(h, rx_v2$prize) ~ "prizenegro",
    str_detect(h, rx_v2$khoe) ~ "khoe",
    str_detect(h, rx_v2$slave) ~ "slave",
    str_detect(h, rx_v2$servant) ~ "servant",
    TRUE ~ "settler"
  )
}

detect_sex_age <- function(direct_header) {
  d <- normalize_header(direct_header)
  below <- str_detect(d, "below|under|beneden|beneede|benede|onder")
  above <- str_detect(d, "above|over|boven|(^| )bo( |$)")
  case_when(
    (below & str_detect(d, rx_v2$male)) | (str_detect(d, rx_v2$son) & !above) ~ "sons",
    (below & str_detect(d, rx_v2$female)) | (str_detect(d, rx_v2$daughter) & !above) ~ "daughters",
    str_detect(d, rx_v2$child) ~ "children",
    (above & (str_detect(d, rx_v2$male) | str_detect(d, rx_v2$son))) |
      str_detect(d, rx_v2$male) | str_detect(d, "^slaven$|^slaaven$|^hottentotten$|^prijs negers$|^prys negers$") ~ "men",
    (above & (str_detect(d, rx_v2$female) | str_detect(d, rx_v2$daughter))) |
      str_detect(d, rx_v2$female) ~ "women",
    TRUE ~ NA_character_
  )
}

age_metadata <- function(direct_header, sex_age) {
  h <- normalize_header(direct_header)
  threshold <- suppressWarnings(as.integer(str_extract(h, "\\d{1,2}")))
  lower <- case_when(
    sex_age %in% c("men", "women") & str_detect(h, "above|over|boven|(^| )bo( |$)") & !is.na(threshold) ~ threshold,
    sex_age %in% c("sons", "daughters") ~ 0L,
    TRUE ~ NA_integer_
  )
  upper <- case_when(
    sex_age %in% c("sons", "daughters") & !is.na(threshold) ~ threshold - 1L,
    TRUE ~ NA_integer_
  )
  list(lower = lower, upper = upper)
}

classify_nonperson_header <- function(h) {
  case_when(
    str_detect(h, "field cornet|fieldcornet|fieldcornetry|veldkornet|veld cornet") ~ "field_cornet",
    str_detect(h, "district|wyk|ward") ~ "sub_district",
    str_detect(h, "additional information|add info|aanmerking|remarks|opmerking") ~ "add_info",
    str_detect(h, "surname|family name") ~ "surname",
    str_detect(h, "christian names?|given names?") ~ "given_names",
    str_detect(h, "folio") ~ "folio_raw",
    str_detect(h, "^(entry )?(number|no|nr)$|^folio number$") ~ "entry_number_raw",
    str_detect(h, "farm name|names? of (the )?(places|farms)|naam van (de )?plaats|plaats naam|naa?men? der (plaatsen|plaatzen|erven)|naa?mens? der (plaatsen|plaatzen|erven)|woonplaats") ~ "farm_name",
    str_detect(h, "work horse|trekpaard|trek paard") ~ "horse_work",
    str_detect(h, "breeding horse|fokpaard|fok paard") ~ "horse_breeding",
    str_detect(h, "foal") ~ "horse_foals",
    str_detect(h, "pleasure horse") ~ "horse_pleasure",
    str_detect(h, "horse|paard") ~ "horses",
    str_detect(h, "breeding cattle|aanteel beest|aanteelbeest") ~ "cattle_breeding",
    str_detect(h, "work cattle|trek os|trekos|ossen") ~ "cattle_work",
    str_detect(h, "bull|stier") ~ "cattle_bull",
    str_detect(h, "cow|koei") ~ "cattle_cows",
    str_detect(h, "heifer|vers") ~ "cattle_heifers",
    str_detect(h, "calf|kalv") ~ "cattle_calves",
    str_detect(h, "cattle|beest") ~ "cattle",
    str_detect(h, "wether|hamel") ~ "sheep_wether",
    str_detect(h, "breeding sheep|aanteel schaap") ~ "sheep_breeding",
    str_detect(h, "wool sheep|wol schaap") ~ "sheep_wool",
    str_detect(h, "sheep|schaap|schapen") ~ "sheep",
    str_detect(h, "goat|bok|geit") ~ "goats",
    str_detect(h, "pig|varken") ~ "pigs",
    str_detect(h, "donkey|ezel") ~ "donkeys",
    str_detect(h, "wagon|wagen") ~ "wagons",
    str_detect(h, "cart|karre|karren") ~ "carts",
    str_detect(h, "wheat|tarwe") & str_detect(h, "seed|gezaai|gesaai|sown") ~ "wheat_seed",
    str_detect(h, "wheat|tarwe") ~ "wheat_vol",
    str_detect(h, "barley|garst") & str_detect(h, "seed|gezaai|gesaai|sown") ~ "barley_seed",
    str_detect(h, "barley|garst") ~ "barley_vol",
    str_detect(h, "(^| )rye( |$)|rogge|(^| )rog( |$)") & str_detect(h, "seed|gezaai|gesaai|sown") ~ "rye_seed",
    str_detect(h, "(^| )rye( |$)|rogge|(^| )rog( |$)") ~ "rye_vol",
    str_detect(h, "oat|haver") & str_detect(h, "seed|gezaai|gesaai|sown") ~ "oat_seed",
    str_detect(h, "oat|haver") ~ "oat_vol",
    str_detect(h, "maize|mielie") ~ "maize_vol",
    str_detect(h, "vine|wingerd|stok") ~ "vines",
    str_detect(h, "brandy|brandewyn") ~ "brandy",
    str_detect(h, "wine|wijn") ~ "wine",
    TRUE ~ NA_character_
  )
}

classify_header_v2 <- function(group_header, direct_header, combined_header, column_index) {
  g <- normalize_header(group_header)
  d <- normalize_header(direct_header)
  h <- normalize_header(combined_header)

  tax_stem <- case_when(
    str_detect(h, "opgaaf geld") ~ "opgaaf_tax",
    str_detect(h, "contributie van wagen|wagon contribution") ~ "wagon_contribution",
    str_detect(h, "kerke contributie|church contribution") ~ "church_contribution",
    TRUE ~ NA_character_
  )
  tax_unit <- case_when(
    str_detect(d, "(^| )(rds|rixdollar|rijksdaalder)( |$)") ~ "rixdollars",
    str_detect(d, "(^| )(sh|shl|skilling|schelling)( |$)") ~ "skillings",
    str_detect(d, "(^| )(stw|stuiver)( |$)") ~ "stuivers",
    TRUE ~ NA_character_
  )
  if (!is.na(tax_stem) && !is.na(tax_unit)) {
    return(tibble(canonical_field = paste(tax_stem, tax_unit, sep = "_"),
                  field_type = "numeric", population_group = NA_character_, sex = NA_character_,
                  age_lower = NA_integer_, age_upper = NA_integer_, measure_type = "tax_amount",
                  mapping_method = "header_semantics", confidence = "B"))
  }

  if (str_detect(h, "persons liable to pay capitation tax|personen.*capitation|capitation tax") &&
      str_detect(h, rx_v2$male)) {
    return(tibble(canonical_field = "taxable_men", field_type = "numeric",
                  population_group = "taxable_person", sex = "male", age_lower = NA_integer_, age_upper = NA_integer_,
                  measure_type = "taxable_person_stock", mapping_method = "header_semantics", confidence = "B"))
  }
  if (str_detect(h, "persons liable to pay capitation tax|personen.*capitation|capitation tax") &&
      str_detect(h, rx_v2$female)) {
    return(tibble(canonical_field = "taxable_women", field_type = "numeric",
                  population_group = "taxable_person", sex = "female", age_lower = NA_integer_, age_upper = NA_integer_,
                  measure_type = "taxable_person_stock", mapping_method = "header_semantics", confidence = "B"))
  }
  if (str_detect(h, "servants liable to taxation|servants liable to tax")) {
    return(tibble(canonical_field = "taxable_servants", field_type = "numeric",
                  population_group = "servant", sex = NA_character_, age_lower = NA_integer_, age_upper = NA_integer_,
                  measure_type = "taxable_person_stock", mapping_method = "header_semantics", confidence = "B"))
  }

  direct_nonperson <- classify_nonperson_header(d)
  if (!is.na(direct_nonperson) && direct_nonperson %in%
      c("field_cornet", "sub_district", "add_info", "entry_number_raw", "farm_name", "surname", "given_names")) {
    return(tibble(canonical_field = direct_nonperson, field_type = "character",
                  population_group = NA_character_, sex = NA_character_,
                  age_lower = NA_integer_, age_upper = NA_integer_, measure_type = "identifier",
                  mapping_method = "header_dictionary", confidence = "B"))
  }

  full_nonperson <- classify_nonperson_header(h)
  if (!is.na(full_nonperson) && full_nonperson %in%
      c("field_cornet", "sub_district", "add_info", "entry_number_raw", "farm_name", "surname", "given_names")) {
    return(tibble(canonical_field = full_nonperson, field_type = "character",
                  population_group = NA_character_, sex = NA_character_,
                  age_lower = NA_integer_, age_upper = NA_integer_, measure_type = "identifier",
                  mapping_method = "header_dictionary", confidence = "B"))
  }

  # Names are checked before age/sex counts: some forms label named adult
  # taxpayers with language that otherwise looks like a male/female count.
  note_signal <- str_detect(h, "numbered by (the )?transcriber|folios? (seem|were)|^nb ")
  name_note <- note_signal && !str_detect(g, "^(name|names|naam|namen|naamen)$")
  if (str_detect(h, rx_v2$names) && !name_note) {
    sex_age <- detect_sex_age(d)
    field <- case_when(
      str_detect(d, rx_v2$male) & str_detect(d, rx_v2$female) ~ "names_combined",
      sex_age == "women" ~ "names_women",
      sex_age == "men" ~ "names_men",
      TRUE ~ "names_men"
    )
    return(tibble(canonical_field = field, field_type = "character",
                  population_group = "settler", sex = ifelse(field == "names_women", "female", "male"),
                  age_lower = NA_integer_, age_upper = NA_integer_, measure_type = "named_person",
                  mapping_method = "header_semantics", confidence = "B"))
  }

  # Stocks and flows must never be conflated. Sex-specific mortality/birth
  # columns remain explicit rather than being read as living household members.
  if (str_detect(h, "mortaliteit|mortality|gestorven|died|deaths?|geboren|born|births?")) {
    group <- detect_group(h)
    sex_age <- detect_sex_age(d)
    event <- ifelse(str_detect(h, "geboren|born|birth"), "born", "died")
    suffix <- case_when(
      sex_age %in% c("men", "sons") ~ "_male",
      sex_age %in% c("women", "daughters") ~ "_female",
      TRUE ~ ""
    )
    stem <- case_when(group == "settler" ~ "settlers", group == "slave" ~ "slaves",
                      group == "khoe" ~ "khoe", group == "freeblack" ~ "freeblacks",
                      group == "prizenegro" ~ "prizenegro", TRUE ~ "persons")
    return(tibble(canonical_field = paste0(stem, "_", event, suffix), field_type = "numeric",
                  population_group = group, sex = case_when(str_ends(suffix, "male") ~ "male",
                                                            str_ends(suffix, "female") ~ "female",
                                                            TRUE ~ NA_character_),
                  age_lower = NA_integer_, age_upper = NA_integer_, measure_type = "person_flow",
                  mapping_method = "header_semantics", confidence = "B"))
  }

  nonperson <- direct_nonperson
  if (is.na(nonperson)) nonperson <- classify_nonperson_header(h)
  if (!is.na(nonperson)) {
    char_fields <- c("field_cornet", "sub_district", "add_info", "folio_raw", "entry_number_raw", "farm_name", "surname", "given_names")
    return(tibble(canonical_field = nonperson,
                  field_type = ifelse(nonperson %in% char_fields, "character", "numeric"),
                  population_group = NA_character_, sex = NA_character_,
                  age_lower = NA_integer_, age_upper = NA_integer_,
                  measure_type = ifelse(nonperson %in% char_fields, "identifier", "asset_stock"),
                  mapping_method = "header_dictionary", confidence = "B"))
  }

  group <- detect_group(h)
  age_signal <- str_detect(paste(g, d), "above|below|over|under|boven|beneden|benede|onder|(^| )bo( |$)")
  group_sex_signal <- str_detect(g, paste(rx_v2$male, rx_v2$female, rx_v2$son, rx_v2$daughter, sep = "|"))
  direct_sex_signal <- str_detect(d, paste(rx_v2$male, rx_v2$female, rx_v2$son, rx_v2$daughter, sep = "|"))
  group_below <- str_detect(g, "below|under|beneden|benede|onder")
  group_above <- str_detect(g, "above|over|boven|(^| )bo( |$)")
  sex_age <- case_when(
    group_below & str_detect(d, rx_v2$male) ~ "sons",
    group_below & str_detect(d, rx_v2$female) ~ "daughters",
    group_above & str_detect(d, rx_v2$male) ~ "men",
    group_above & str_detect(d, rx_v2$female) ~ "women",
    group == "servant" & str_detect(d, rx_v2$servant) & !direct_sex_signal ~ NA_character_,
    TRUE ~ detect_sex_age(if (d == "" || (age_signal && (group_sex_signal || direct_sex_signal))) h else d)
  )
  person_signal <- str_detect(h, paste(unlist(rx_v2[c("male", "female", "son", "daughter", "child", "servant", "slave", "khoe", "freeblack", "prize")]), collapse = "|"))
  if (person_signal && group == "servant" && is.na(sex_age)) {
    return(tibble(canonical_field = "servants", field_type = "numeric",
                  population_group = "servant", sex = NA_character_, age_lower = NA_integer_, age_upper = NA_integer_,
                  measure_type = "person_stock", mapping_method = "header_semantics", confidence = "B"))
  }
  if (person_signal && !is.na(sex_age)) {
    age <- age_metadata(d, sex_age)
    return(tibble(canonical_field = paste(group, sex_age, sep = "_"), field_type = "numeric",
                  population_group = group,
                  sex = case_when(sex_age %in% c("men", "sons") ~ "male",
                                  sex_age %in% c("women", "daughters") ~ "female",
                                  TRUE ~ NA_character_),
                  age_lower = age$lower, age_upper = age$upper,
                  measure_type = "person_stock", mapping_method = "header_semantics", confidence = "B"))
  }

  tibble(canonical_field = NA_character_, field_type = NA_character_,
         population_group = NA_character_, sex = NA_character_,
         age_lower = NA_integer_, age_upper = NA_integer_, measure_type = NA_character_,
         mapping_method = "unmapped", confidence = "C")
}

read_header_block <- function(wb, sheet, n_header_rows, n_columns) {
  x <- read.xlsx(wb, sheet = sheet, rows = seq_len(n_header_rows), colNames = FALSE,
                 skipEmptyRows = FALSE, skipEmptyCols = FALSE,
                 fillMergedCells = TRUE, check.names = FALSE)
  if (ncol(x) < n_columns) {
    for (j in seq.int(ncol(x) + 1L, n_columns)) x[[j]] <- NA_character_
  }
  if (nrow(x) < n_header_rows) {
    x[(nrow(x) + 1L):n_header_rows, ] <- NA_character_
  }
  x[, seq_len(n_columns), drop = FALSE]
}
