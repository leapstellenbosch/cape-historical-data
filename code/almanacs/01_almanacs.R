# Cape almanacs and directories, 1813-1891: one row per directory entry, from
# the 36 edition tables of Almanacs.mdb (exported to CSV by 00_export_mdb.ps1).
# The editions were transcribed by volunteers, table by table, so their column
# names differ; they are mapped to one set of columns. Spellings are kept as
# transcribed; placeholders ("Not given", "Unknown") become missing.
# Run from the project root, after 00_export_mdb.ps1:
#   & 'C:/Program Files/R/R-4.5.2/bin/Rscript.exe' pipeline/almanacs/01_almanacs.R

here::i_am("PLAN.md")
library(tidyverse)
library(here)

export_dir <- here("build", "almanacs", "mdb_export")
out_dir <- here("release", "data", "almanacs")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(export_dir, pattern = "^Sub_.*[.]csv$", full.names = TRUE)
stopifnot(length(files) == 36)

# Column names used across the editions, and what each becomes
map_cols <- c(
  "Surname" = "surname", "Surname Or Business" = "surname", "Surname Or Company Name" = "surname",
  "First Name" = "first_names", "Title" = "title",
  "Profession" = "occupation", "Occupation" = "occupation",
  "Address" = "address", "Street Address" = "address", "StreetAddress" = "address",
  # headings under which the book lists the entry (town, suburb, section)
  "Area" = "section", "Place of Residence" = "section", "Residence" = "section",
  "Section" = "section", "Section Title in Book" = "section",
  "Erf Number" = "erf_number", "Notes" = "notes",
  "Image" = "image", "Image Name" = "image",
  "Transcriber" = "transcriber", "Transcriber Name" = "transcriber")
# Not carried over: the record type (always "Sub"), the database's own record
# numbers, the edition name typed on each row (the table name gives it; in 1813
# Excel's fill-down had numbered it 1814, 1815, ... 1889) and the library where
# the book was consulted (listed per edition in the README)
dropped <- c("source_row", "CType", "Ctype", "ID", "RecID", "Source", "Source Location")

publication_code <- c("African Court Calendar" = "ACC", "Cape Advertiser" = "CAD",
                      "Cape Almanac" = "CAL", "Transvaal Almanac" = "TVL")
read_edition <- function(f) {
  d <- read_csv(f, col_types = cols(.default = "c"), locale = locale(encoding = "UTF-8"), na = "")
  unknown <- setdiff(names(d), c(names(map_cols), dropped))
  if (length(unknown)) stop(basename(f), ": unmapped columns ", paste(unknown, collapse = ", "))
  # no column is mapped twice within an edition
  stopifnot(!anyDuplicated(map_cols[intersect(names(d), names(map_cols))]))
  tbl <- str_match(basename(f), "^Sub_([0-9]{4}) (.+)[.]csv$")
  d %>%
    select(source_row, any_of(names(map_cols))) %>%
    rename_with(~map_cols[.x], -source_row) %>%
    mutate(year = as.integer(tbl[, 2]), publication = tbl[, 3], .before = 1)
}
raw <- map_dfr(files, read_edition)
stopifnot(nrow(raw) == 97848, all(raw$publication %in% names(publication_code)))

# ---------------------------------------------------------------------------
# Cleaning
# ---------------------------------------------------------------------------
fields <- c("surname", "first_names", "title", "occupation", "address", "section", "erf_number", "notes", "image", "transcriber")
# "NA" (once, as first names in the 1881 Transvaal Almanac) is taken as "not available"
placeholder <- regex("^(not given|unknown|name not given|surname not given|first name not given|none given)$", ignore_case = TRUE)
n_placeholders <- raw %>% select(all_of(fields)) %>%
  summarise(across(everything(), ~sum(str_detect(str_squish(.x), placeholder), na.rm = TRUE)))
message("Placeholders set to missing: ", paste(names(n_placeholders), n_placeholders, sep = " ", collapse = ", "))

almanacs <- raw %>%
  mutate(across(all_of(fields), ~na_if(str_squish(.x), "")),
         across(c(surname, first_names, title, occupation, address), ~if_else(str_detect(.x, placeholder) | .x %in% "NA", NA_character_, .x)),
         chdr_id = sprintf("ALM-%s-%d-%05d", publication_code[publication], year, as.integer(source_row))) %>%
  # rows with nothing but the edition (one in the database)
  filter(!if_all(c(surname, first_names, title, occupation, address, notes), is.na)) %>%
  select(chdr_id, publication, year, surname, first_names, title, occupation, address, section,
         erf_number, notes, image, transcriber)

stopifnot(!anyDuplicated(almanacs$chdr_id), all(between(almanacs$year, 1813, 1891)))

# chdr_id comes from the entry's position in its exported table, and some tables
# have no record number to anchor it. The identifiers published in version 1.1
# are frozen in almanacs_id_key.csv (identifier and a hash of the entry's
# content); a later export must give every identifier the same content, or the
# build stops rather than renumber.
content_hash <- almanacs %>% select(-chdr_id) %>% apply(1, function(r) rlang::hash(unname(r)))
key_file <- here("pipeline", "almanacs", "almanacs_id_key.csv")
current_key <- tibble(chdr_id = almanacs$chdr_id, content = content_hash)
if (file.exists(key_file)) {
  frozen <- read_csv(key_file, col_types = "cc")
  stopifnot("an almanac identifier would change content: rebuild from the frozen key, do not renumber" =
              identical(frozen$chdr_id, current_key$chdr_id) && identical(frozen$content, current_key$content))
} else write_csv(current_key, key_file)

# Entries typed twice: identical in every column, page image and transcriber
# included, within one edition. Most sit next to each other; some are a run of
# entries typed again further on (e.g. 1813, rows 131-152 and 903-924). The first
# is kept and each removed entry is listed with the entry it repeats.
key <- almanacs %>% select(-chdr_id) %>% apply(1, paste, collapse = "\r")
first_of <- match(key, key)
removed <- tibble(chdr_id = almanacs$chdr_id, repeats = almanacs$chdr_id[first_of]) %>%
  filter(chdr_id != repeats)
almanacs <- almanacs %>% filter(!chdr_id %in% removed$chdr_id)
write_csv(removed, file.path(out_dir, "almanacs_removed_repeats.csv"))
message("Entries: ", nrow(almanacs), " in ", n_distinct(almanacs$publication, almanacs$year), " editions (",
        sum(almanacs$year < 1850), " before 1850); repeated entries removed: ", nrow(removed))

redundant <- function(d) {
  cols <- names(d)
  pairs <- combn(cols, 2, simplify = FALSE)
  c(cols[map_lgl(d, ~all(is.na(.x)) || n_distinct(.x) == 1)],
    map_chr(keep(pairs, ~identical(d[[.x[1]]], d[[.x[2]]])), paste, collapse = "="))
}
stopifnot(length(redundant(almanacs)) == 0)

write_csv(almanacs, file.path(out_dir, "almanacs_entries.csv"), na = "")
nanoparquet::write_parquet(almanacs, file.path(out_dir, "almanacs_entries.parquet"), compression = "zstd")

v <- function(variable, type, source_column, description)
  tibble(variable = variable, type = type, source_column = source_column, description = description)
variables <- bind_rows(
  v("chdr_id", "character", "", "Repository identifier, never changed: ALM-, the publication (ACC African Court Calendar, CAD Cape Advertiser, CAL Cape Almanac, TVL Transvaal Almanac), the edition year and the entry's position in that edition's table (ALM-CAL-1838-00001)"),
  v("publication", "character", "table name", "African Court Calendar (1813-1827), Cape Advertiser (1821), Cape Almanac (1828-1891) or Transvaal Almanac (1881)"),
  v("year", "integer", "table name", "Year of the edition"),
  v("surname", "character", "Surname; Surname Or Business; Surname Or Company Name", "Surname, or the name of a firm or institution"),
  v("first_names", "character", "First Name", "First names or initials"),
  v("title", "character", "Title", "Title or status as printed: Mrs, Widow, Rev., Captain, Junior, ..."),
  v("occupation", "character", "Profession; Occupation", "Occupation, office or business as printed"),
  v("address", "character", "Address; Street Address; StreetAddress", "Street address as printed"),
  v("section", "character", "Area; Place of Residence; Residence; Section; Section Title in Book", "Heading under which the entry is printed (town, suburb or section), where the transcriber recorded it (1838, 1847, 1863, 1868, 1875, 1881 Transvaal)"),
  v("erf_number", "character", "Erf Number", "Erf (plot) number, 1881 Transvaal Almanac only"),
  v("notes", "character", "Notes", "Transcriber's notes, often the heading of the list the entry comes from"),
  v("image", "character", "Image; Image Name", "File name of the page image the entry was transcribed from"),
  v("transcriber", "character", "Transcriber; Transcriber Name", "Volunteer who transcribed the entry"))
stopifnot(identical(variables$variable, names(almanacs)))
write_csv(variables, file.path(out_dir, "almanacs_variables.csv"), na = "")
