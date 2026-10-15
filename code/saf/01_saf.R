# South African Families (SAF) genealogies: reshape the wide sheet into
# persons, marriages and spouses, and keep people born up to 1870.
# Design: docs/schemas.md, section 4; inclusion rule: PLAN.md, section 7.
# Run from the project root:
#   & 'C:/Program Files/R/R-4.5.2/bin/Rscript.exe' pipeline/saf/01_saf.R

here::i_am("PLAN.md")
library(tidyverse)
library(here)

src <- here("sources", "raw", "saf", "SAF 10_02_2014.xlsx")
build_dir <- here("build", "saf")
out_dir <- here("release", "data", "saf")
walk(c(build_dir, out_dir), dir.create, recursive = TRUE, showWarnings = FALSE)

cutoff_birth <- 1870L     # people born up to and including 1870
cutoff_event <- 1890L     # undated: married or died by 1890
cutoff_parent <- 1840L    # undated: a parent born by 1840
cutoff_child <- 1895L     # undated: a child born by 1895
year_range <- c(1600L, 2014L)  # outside this a year is flagged (sheet dated 2014)

# Read every cell as text (the workbook is slow to read, so cache by checksum)
cache <- file.path(build_dir, paste0("saf_raw_", tools::md5sum(src), ".rds"))
if (file.exists(cache)) raw <- readRDS(cache) else {
  raw <- readxl::read_excel(src, sheet = 1, col_types = "text")
  saveRDS(raw, cache)
}
stopifnot(nrow(raw) == 582124, ncol(raw) == 126,
          # the divorce columns are empty throughout, so they are not published
          all(is.na(unlist(raw[paste0("spouse", 1:4, "_divorced")]))))
# Repair the sheet's garbled accents ("Î´" for "ë"; 00_repair_encoding.R).
# Every non-ASCII cell in the sheet is garbled, and every one is repaired
# exactly (each repair, garbled again, gives back the original cell).
source(here("pipeline", "saf", "00_repair_encoding.R"))
repaired <- raw %>% mutate(across(everything(), repair_encoding))
n_repaired <- sum(map2_int(raw, repaired, ~sum(.x != .y, na.rm = TRUE)))
stopifnot(sum(map_int(raw, ~sum(!is.na(.x) & !stringi::stri_enc_isascii(.x)))) == n_repaired,
          !any(map_lgl(repaired, ~any(str_detect(.x, "Î´|Ã†|Ã¶|Ã´"), na.rm = TRUE))))
message("Cells with garbled accents repaired: ", n_repaired)
raw <- repaired %>% mutate(source_row = row_number() + 1L, .before = 1)

# Dates and generation are whole numbers in the sheet; stop if any value is
# not, so the conversion never drops or truncates a value silently
to_int <- function(v) {
  out <- suppressWarnings(as.integer(v))
  stopifnot(all(is.na(v) | (!is.na(out) & suppressWarnings(as.numeric(v)) == out)))
  out
}
ok_year <- function(y) !is.na(y) & y >= year_range[1] & y <= year_range[2]
ok_month <- function(m) is.na(m) | (m >= 1 & m <= 12)
ok_day <- function(d) is.na(d) | (d >= 1 & d <= 31)
first_ok <- function(a, b) if_else(ok_year(a), a, if_else(ok_year(b), b, NA_integer_))
# Names of fields whose values are implausible, separated by semicolons
flag_dates <- function(d, prefix) {
  parts <- list(
    if_else(!is.na(d[[paste0(prefix, "_year")]]) & !ok_year(d[[paste0(prefix, "_year")]]), paste0(prefix, "_year"), NA),
    if_else(!ok_month(d[[paste0(prefix, "_month")]]), paste0(prefix, "_month"), NA),
    if_else(!ok_day(d[[paste0(prefix, "_day")]]), paste0(prefix, "_day"), NA))
  clean_flags(do.call(paste, c(parts, sep = ";")))
}
# Drop the "NA" pieces left by pasting missing values together
clean_flags <- function(x) {
  x %>% str_replace_all("(^|;)NA(?=;|$)", "") %>% str_replace_all(";+", ";") %>%
    str_remove_all("^;|;$") %>% na_if("")
}
join_flags <- function(...) clean_flags(do.call(paste, c(list(...), sep = ";")))

# ---------------------------------------------------------------------------
# 1. Repeated individual_id: 1,586 codes occur twice
# ---------------------------------------------------------------------------
content <- do.call(paste, c(select(raw, -source_row), sep = "\r"))
raw <- raw %>%
  mutate(content = content) %>%
  group_by(individual_id) %>%
  mutate(n_id = n(),
         copy = row_number(),
         exact_copy = n_id > 1 & duplicated(content),
         same_name = n_distinct(paste(surname, first_names, birth_year)) == 1) %>%
  ungroup()
dupes <- raw %>% filter(n_id > 1)
stopifnot(all(dupes$n_id == 2))
write_csv(dupes %>% select(source_row, individual_id, copy, exact_copy, same_name, surname, first_names, birth_year),
          file.path(build_dir, "saf_repeated_ids.csv"), na = "")

persons_wide <- raw %>%
  filter(!exact_copy) %>%  # an exact copy of an earlier row is dropped
  group_by(individual_id) %>%
  mutate(n_kept = n(), k = row_number()) %>%
  ungroup() %>%
  mutate(
    # the genealogical code holds spaces, ?, hyphens and brackets, so the
    # repository ID numbers the workbook row instead (row 2 = SAF-000001)
    chdr_id = sprintf("SAF-%06d", source_row - 1L),
    id_flag = case_when(
      n_id > 1 & n_kept == 1 ~ "exact_duplicate_row_removed",
      n_kept > 1 & same_name ~ "repeated_id_same_name",
      n_kept > 1 ~ "repeated_id_different_person"))
stopifnot(!anyDuplicated(persons_wide$chdr_id))
message("Rows: ", nrow(raw), "; exact copies removed: ", sum(raw$exact_copy),
        "; codes shared by two different records: ", sum(persons_wide$k > 1))

# ---------------------------------------------------------------------------
# 2. Principals
# ---------------------------------------------------------------------------
date_fields <- function(d, prefix) {
  tibble("{prefix}_year" := to_int(d[[paste0(prefix, "_year")]]),
         "{prefix}_month" := to_int(d[[paste0(prefix, "_month")]]),
         "{prefix}_day" := to_int(d[[paste0(prefix, "_day")]]))
}
p <- persons_wide %>%
  transmute(chdr_id, individual_id, generation = to_int(generation),
            mother_spouse_code = mothers_id, surname, first_names) %>%
  bind_cols(date_fields(persons_wide, "birth"), birth_place = persons_wide$birth_place,
            date_fields(persons_wide, "baptism"), baptism_place = persons_wide$baptism_place,
            occupation = persons_wide$occupation,
            date_fields(persons_wide, "death"), death_place = persons_wide$death_place,
            burial_place = persons_wide$burial_place)

# ---------------------------------------------------------------------------
# 3. Marriages and spouses: one row per filled marriage slot
# ---------------------------------------------------------------------------
slot <- function(n) {
  w <- persons_wide
  f <- function(x) w[[sprintf(x, n)]]
  slot_cols <- grep(sprintf("^(married%d|wife%d_id|spouse%d_)", n, n, n), names(w), value = TRUE)
  filled <- rowSums(!is.na(w[slot_cols])) > 0
  tibble(principal_chdr_id = w$chdr_id, individual_id = w$individual_id, marriage_order = n,
         married_marker = f("married%d"),
         marriage_year = to_int(f("married%d_year")), marriage_month = to_int(f("married%d_month")),
         marriage_day = to_int(f("married%d_day")), marriage_place = f("married%d_place"),
         spouse_code = paste0(w$individual_id, "_", n),
         surname = f("spouse%d_surname"), first_names = f("spouse%d_first_names"),
         daughter_of = f("spouse%d_daughter_of"), son_of = f("spouse%d_son_of"),
         birth_year = to_int(f("spouse%d_birth_year")), birth_month = to_int(f("spouse%d_birth_month")),
         birth_day = to_int(f("spouse%d_birth_day")), birth_place = f("spouse%d_birth_place"),
         baptism_year = to_int(f("spouse%d_baptism_year")), baptism_month = to_int(f("spouse%d_baptism_month")),
         baptism_day = to_int(f("spouse%d_baptism_day")), baptism_place = f("spouse%d_baptism_place"),
         occupation = f("spouse%d_occupation"),
         death_year = to_int(f("spouse%d_death_year")), death_month = to_int(f("spouse%d_death_month")),
         death_day = to_int(f("spouse%d_death_day")), death_place = f("spouse%d_death_place"),
         burial_place = f("spouse%d_burial_place"))[filled, ]
}
slots <- map(1:4, slot) %>% list_rbind()
message("Filled marriage slots: ", paste(table(slots$marriage_order), collapse = " / "))

# ---------------------------------------------------------------------------
# 4. Inclusion: born up to 1870, with the rule for the undated (option b)
# ---------------------------------------------------------------------------
p <- p %>% mutate(base_year = first_ok(birth_year, baptism_year))

# parents: the principal of the mother's spouse code and that spouse
parent_years <- bind_rows(
  p %>% filter(!duplicated(individual_id)) %>% transmute(code = individual_id, y = base_year),
  slots %>% filter(!duplicated(spouse_code)) %>% transmute(code = spouse_code, y = first_ok(birth_year, baptism_year)))
p <- p %>%
  mutate(father_code = str_remove(mother_spouse_code, "_[0-9]+$")) %>%
  left_join(rename(parent_years, father_code = code, y_principal_parent = y), by = "father_code") %>%
  left_join(rename(parent_years, mother_spouse_code = code, y_mother = y), by = "mother_spouse_code") %>%
  mutate(parent_year = pmin(y_principal_parent, y_mother, na.rm = TRUE))
# children: people whose mother's spouse code belongs to this principal
child_years <- p %>% filter(!is.na(father_code), !is.na(base_year)) %>%
  group_by(individual_id = father_code) %>% summarise(child_year = min(base_year), .groups = "drop")
event_years <- slots %>% filter(ok_year(marriage_year)) %>%
  group_by(principal_chdr_id) %>% summarise(marriage_min = min(marriage_year), .groups = "drop")
p <- p %>%
  left_join(child_years, by = "individual_id") %>%
  left_join(event_years, by = c("chdr_id" = "principal_chdr_id")) %>%
  mutate(death_ok = if_else(ok_year(death_year), death_year, NA_integer_),
         inclusion_basis = case_when(
           ok_year(birth_year) & birth_year <= cutoff_birth ~ "birth",
           ok_year(birth_year) ~ NA_character_,
           ok_year(baptism_year) & baptism_year <= cutoff_birth ~ "baptism",
           ok_year(baptism_year) ~ NA_character_,
           marriage_min <= cutoff_event ~ "marriage",
           death_ok <= cutoff_event ~ "death",
           parent_year <= cutoff_parent ~ "parent",
           child_year <= cutoff_child ~ "child"))
message("Principals kept: ", sum(!is.na(p$inclusion_basis)), " of ", nrow(p))
print(count(p, inclusion_basis))

# Spouses: their own birth or baptism year decides; undated spouses follow the principal
slots <- slots %>%
  left_join(select(p, principal_chdr_id = chdr_id, principal_basis = inclusion_basis), by = "principal_chdr_id") %>%
  mutate(inclusion_basis = case_when(
    ok_year(birth_year) & birth_year <= cutoff_birth ~ "birth",
    ok_year(birth_year) ~ NA_character_,
    ok_year(baptism_year) & baptism_year <= cutoff_birth ~ "baptism",
    ok_year(baptism_year) ~ NA_character_,
    !is.na(principal_basis) ~ "principal"),
    principal_in_release = !is.na(principal_basis),
    spouse_in_release = !is.na(inclusion_basis))

# ---------------------------------------------------------------------------
# 5. Published tables: no column that repeats another or can be derived from
#    the same row (Johan, 14 October 2026). Dates stay as year, month, day.
# ---------------------------------------------------------------------------
add_flags <- function(d) {
  d %>% mutate(date_flag = join_flags(
    flag_dates(d, "birth"), flag_dates(d, "baptism"), flag_dates(d, "death"),
    if_else(ok_year(birth_year) & ok_year(death_year) & death_year < birth_year, "death_before_birth", NA)))
}

# family_id is the code without its final birth-order number (digits or ?),
# so it is not published
stopifnot(all(persons_wide$family_id == str_remove(persons_wide$individual_id, "[0-9?]+$")))

saf_persons <- p %>%
  filter(!is.na(inclusion_basis)) %>%
  add_flags() %>%
  left_join(select(persons_wide, chdr_id, sex = gender, id_flag), by = "chdr_id") %>%
  select(chdr_id, individual_id, generation, mother_spouse_code,
         surname, first_names, sex,
         birth_year, birth_month, birth_day, birth_place,
         baptism_year, baptism_month, baptism_day, baptism_place,
         occupation, death_year, death_month, death_day, death_place, burial_place,
         inclusion_basis, date_flag, id_flag)

# One row per marriage, with the spouse's details; withheld when the spouse
# was born after 1870
spouse_cols <- c("surname", "first_names", "daughter_of", "son_of",
                 "birth_year", "birth_month", "birth_day", "birth_place",
                 "baptism_year", "baptism_month", "baptism_day", "baptism_place",
                 "occupation", "death_year", "death_month", "death_day", "death_place", "burial_place")
saf_marriages <- slots %>%
  filter(principal_in_release | spouse_in_release) %>%
  add_flags() %>%
  rename(spouse_date_flag = date_flag) %>%
  mutate(chdr_id = paste0(principal_chdr_id, "-M", marriage_order),
         marriage_flag = flag_dates(rename_with(., ~str_replace(.x, "^marriage_", "m_")), "m") %>%
           str_replace_all("m_", "marriage_"),
         date_flag = join_flags(marriage_flag, str_replace_all(spouse_date_flag, "(^|;)", "\\1spouse_")),
         across(all_of(spouse_cols), ~if_else(spouse_in_release, .x, NA)),
         date_flag = if_else(spouse_in_release, date_flag, marriage_flag)) %>%
  rename_with(~paste0("spouse_", .x), all_of(spouse_cols)) %>%
  select(chdr_id, principal_chdr_id, marriage_order, spouse_code,
         marriage_year, marriage_month, marriage_day, marriage_place,
         spouse_inclusion_basis = inclusion_basis, starts_with("spouse_") & !any_of(c("spouse_code", "spouse_in_release", "spouse_chdr_id", "spouse_date_flag")),
         date_flag)

# ---------------------------------------------------------------------------
# 6. Checks
# ---------------------------------------------------------------------------
redundant <- function(d) {
  cols <- names(d)
  pairs <- combn(cols, 2, simplify = FALSE)
  c(cols[map_lgl(d, ~all(is.na(.x)) || n_distinct(.x) == 1)],
    map_chr(keep(pairs, ~identical(d[[.x[1]]], d[[.x[2]]])), paste, collapse = "="))
}
stopifnot(
  !anyDuplicated(saf_persons$chdr_id), !anyDuplicated(saf_marriages$chdr_id),
  # nobody with a plausible birth or baptism year after the cutoff
  !any(ok_year(saf_persons$birth_year) & saf_persons$birth_year > cutoff_birth),
  !any(ok_year(saf_marriages$spouse_birth_year) & saf_marriages$spouse_birth_year > cutoff_birth),
  !any(!ok_year(saf_persons$birth_year) & ok_year(saf_persons$baptism_year) & saf_persons$baptism_year > cutoff_birth),
  # every published principal's marriages are published
  nrow(filter(slots, principal_in_release)) == sum(saf_marriages$principal_chdr_id %in% saf_persons$chdr_id),
  length(redundant(saf_persons)) == 0, length(redundant(saf_marriages)) == 0)

write_tables <- function(d, name) {
  write_csv(d, file.path(out_dir, paste0(name, ".csv")), na = "")
  nanoparquet::write_parquet(d, file.path(out_dir, paste0(name, ".parquet")), compression = "zstd")
  message(name, ": ", nrow(d), " rows x ", ncol(d), " columns, ",
          round(file.size(file.path(out_dir, paste0(name, ".csv"))) / 2^20, 1), " MB")
}
unlink(list.files(out_dir, pattern = "^saf_.*[.](csv|parquet)$", full.names = TRUE))
write_tables(saf_persons, "saf_persons")
write_tables(saf_marriages, "saf_marriages")

# ---------------------------------------------------------------------------
# 7. Variable list
# ---------------------------------------------------------------------------
date_vars <- function(table, prefix, source, what) {
  tibble(table = table, variable = paste0(prefix, c("_year", "_month", "_day")), type = "integer",
         source_column = paste0(source, c("_year", "_month", "_day")),
         description = paste(c("Year", "Month", "Day"), "of", what, "as recorded; NA where not recorded"))
}
place_var <- function(table, variable, source, what)
  tibble(table = table, variable = variable, type = "character", source_column = source,
         description = paste("Place of", what, "as recorded"))
v <- function(table, variable, type, source_column, description)
  tibble(table = table, variable = variable, type = type, source_column = source_column, description = description)
spouse_dates <- function(prefix, what)
  date_vars("saf_marriages", paste0("spouse_", prefix), paste0("spouse{n}_", prefix), paste("the spouse's", what))

variables <- bind_rows(
  v("saf_persons", "chdr_id", "character", "", "Repository identifier, never changed: SAF- and the person's row in the source sheet less one (SAF-000001 is row 2)"),
  v("saf_persons", "individual_id", "character", "individual_id", "SAF genealogical code: family name, then a letter per generation and a birth-order number (? = unknown); the code without its final number is the sibling group"),
  v("saf_persons", "generation", "integer", "generation", "Generation number as recorded (the progenitor is 1); a few negative values remain"),
  v("saf_persons", "mother_spouse_code", "character", "mothers_id", "spouse_code of the marriage the person was born to; matches spouse_code in saf_marriages where that marriage is in the release (all but 437 persons)"),
  v("saf_persons", "surname", "character", "surname", "Surname as recorded"),
  v("saf_persons", "first_names", "character", "first_names", "Given names as recorded"),
  v("saf_persons", "sex", "character", "gender", "Sex as recorded: m, f, u (unknown) and a few other codes"),
  date_vars("saf_persons", "birth", "birth", "birth"), place_var("saf_persons", "birth_place", "birth_place", "birth"),
  date_vars("saf_persons", "baptism", "baptism", "baptism"), place_var("saf_persons", "baptism_place", "baptism_place", "baptism"),
  v("saf_persons", "occupation", "character", "occupation", "Occupation as recorded"),
  date_vars("saf_persons", "death", "death", "death"), place_var("saf_persons", "death_place", "death_place", "death"),
  place_var("saf_persons", "burial_place", "burial_place", "burial"),
  v("saf_persons", "inclusion_basis", "character", "", "Why the person is in the release (born up to 1870): birth, baptism, or for the undated marriage or death by 1890, a parent born by 1840 or a child born by 1895"),
  v("saf_persons", "date_flag", "character", "", "Fields with implausible values, separated by semicolons: years outside 1600-2014, months outside 1-12, days outside 1-31, death_before_birth"),
  v("saf_persons", "id_flag", "character", "", "Set where individual_id occurs twice in the sheet: exact_duplicate_row_removed, repeated_id_same_name or repeated_id_different_person"),
  v("saf_marriages", "chdr_id", "character", "", "Repository identifier, never changed: the principal's chdr_id and -M{marriage_order}"),
  v("saf_marriages", "principal_chdr_id", "character", "", "chdr_id of the principal; absent from saf_persons where the principal was born after 1870"),
  v("saf_marriages", "marriage_order", "integer", "", "Which of the principal's marriages (1-4), from the sheet's marriage slot"),
  v("saf_marriages", "spouse_code", "character", "wife{n}_id", "SAF code of the spouse: the principal's individual_id and _{marriage_order}"),
  date_vars("saf_marriages", "marriage", "married{n}", "the marriage"),
  place_var("saf_marriages", "marriage_place", "married{n}_place", "marriage"),
  v("saf_marriages", "spouse_inclusion_basis", "character", "", "Why the spouse's details are published: birth or baptism up to 1870, or principal (an undated spouse of a published principal); empty where the spouse was born after 1870 and the details are withheld"),
  v("saf_marriages", "spouse_surname", "character", "spouse{n}_surname", "Spouse's surname as recorded"),
  v("saf_marriages", "spouse_first_names", "character", "spouse{n}_first_names", "Spouse's given names as recorded"),
  v("saf_marriages", "spouse_daughter_of", "character", "spouse{n}_daughter_of", "Spouse's parents, as recorded for a wife; often a note rather than a name"),
  v("saf_marriages", "spouse_son_of", "character", "spouse{n}_son_of", "Spouse's parents, as recorded for a husband; often a note rather than a name"),
  spouse_dates("birth", "birth"), place_var("saf_marriages", "spouse_birth_place", "spouse{n}_birth_place", "the spouse's birth"),
  spouse_dates("baptism", "baptism"), place_var("saf_marriages", "spouse_baptism_place", "spouse{n}_baptism_place", "the spouse's baptism"),
  v("saf_marriages", "spouse_occupation", "character", "spouse{n}_occupation", "Spouse's occupation as recorded"),
  spouse_dates("death", "death"), place_var("saf_marriages", "spouse_death_place", "spouse{n}_death_place", "the spouse's death"),
  place_var("saf_marriages", "spouse_burial_place", "spouse{n}_burial_place", "the spouse's burial"),
  v("saf_marriages", "date_flag", "character", "", "Fields with implausible values, as in saf_persons; spouse fields carry the prefix spouse_"))
stopifnot(identical(variables$variable[variables$table == "saf_persons"], names(saf_persons)),
          identical(variables$variable[variables$table == "saf_marriages"], names(saf_marriages)))
write_csv(variables, file.path(out_dir, "saf_variables.csv"), na = "")
