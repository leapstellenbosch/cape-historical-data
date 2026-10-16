# Validate the release as published: every table and XML file is read back
# from release/ and checked. Writes release/validation/validation_report.md
# and stops if any check fails.
here::i_am("PLAN.md")
suppressMessages({library(tidyverse); library(here); library(xml2)})

rel <- here("release")
data_dir <- file.path(rel, "data")
checks <- tibble(collection = character(), check = character(), result = logical(), detail = character())
check <- function(collection, what, ok, detail = "") {
  checks <<- add_row(checks, collection = collection, check = what, result = isTRUE(ok), detail = as.character(detail))
  if (!isTRUE(ok)) message("FAILED: ", collection, ": ", what, " ", detail)
}
same_values <- function(a, b) length(a) == length(b) && all(is.na(a) == is.na(b) & (is.na(a) | a == b))

# ---------------------------------------------------------------------------
# 1. Main tables: Parquet and CSV hold the same values; identifiers unique;
#    no empty, constant or duplicate column; every column documented
# ---------------------------------------------------------------------------
main <- tribble(
  ~collection,    ~table,                     ~rows,  ~variables,                   ~key,
  "opgaaf",       "opgaaf_tax_units",         325628, "opgaaf_variables.csv",       "chdr_id",
  "opgaaf",       "opgaaf_entries",           15501,  "opgaaf_variables.csv",       "chdr_id",
  "emancipation", "emancipation_persons",     36417,  "emancipation_variables.csv", "chdr_id",
  "saf",          "saf_persons",              213953, "saf_variables.csv",          "chdr_id",
  "saf",          "saf_marriages",            153568, "saf_variables.csv",          "chdr_id",
  "runaways",     "runaways_persons",         881,    "runaways_variables.csv",     "chdr_id",
  "prices",       "prices_goods",             30,     "prices_variables.csv",       "good",
  "prices",       "prices_annual",            2259,   "prices_variables.csv",       "year,good",
  "prices",       "prices_auction_goods",     15453,  "prices_variables.csv",       "mooc_id,year,good",
  "petition1779", "petition1779_signatories", 404,    "petition1779_variables.csv", "chdr_id",
  "voortrekkers", "voortrekkers_persons",     2313,   "voortrekkers_variables.csv", "chdr_id",
  "voortrekkers", "voortrekkers_marriages",   2978,   "voortrekkers_variables.csv", "chdr_id",
  "almanacs",     "almanacs_entries",         97391,  "almanacs_variables.csv",     "chdr_id")

csv_types <- function(d) {
  spec <- map_chr(d, ~ case_when(inherits(.x, "Date") ~ "D", is.integer(.x) ~ "i", is.double(.x) ~ "d",
                                 is.logical(.x) ~ "l", TRUE ~ "c"))
  paste(spec, collapse = "")
}
tables <- list()
for (k in seq_len(nrow(main))) {
  m <- main[k, ]
  stem <- file.path(data_dir, m$collection, m$table)
  pq <- nanoparquet::read_parquet(paste0(stem, ".parquet"))
  csv <- read_csv(paste0(stem, ".csv"), col_types = csv_types(pq), na = "", progress = FALSE)
  tables[[m$table]] <- pq
  check(m$collection, paste(m$table, "row count"), nrow(pq) == m$rows && nrow(csv) == m$rows,
        format(nrow(pq), big.mark = ","))
  check(m$collection, paste(m$table, "CSV and Parquet identical"),
        identical(names(csv), names(pq)) && all(map2_lgl(csv, pq, same_values)),
        paste(ncol(pq), "columns"))
  key <- str_split_1(m$key, ",")
  check(m$collection, paste(m$table, if (m$key == "chdr_id") "chdr_id" else paste0("key (", m$key, ")"), "unique and complete"),
        !anyNA(pq[key]) && !anyDuplicated(pq[key]))
  constant <- names(pq)[map_lgl(pq, ~ all(is.na(.x)) || (!anyNA(.x) && n_distinct(.x) == 1))]
  dup <- keep(combn(names(pq), 2, simplify = FALSE), ~ identical(pq[[.x[1]]], pq[[.x[2]]]))
  check(m$collection, paste(m$table, "no empty, constant or duplicate column"),
        length(constant) == 0 && length(dup) == 0, paste(c(constant, map_chr(dup, paste, collapse = "=")), collapse = ", "))
  vars <- read_csv(file.path(data_dir, m$collection, m$variables), show_col_types = FALSE)
  if ("table" %in% names(vars)) vars <- filter(vars, table == m$table)
  check(m$collection, paste(m$table, "every column described in", m$variables),
        all(names(pq) %in% vars$variable))
  # garbled accents: UTF-8 read as Windows-1252 ("Ã©", "â€™") or via cp437 ("Î´")
  moji <- "Ã[\u0080-¿Œ-ƒˆ-˜–-™]|Î[´˜¦]|â€"
  n_moji <- sum(map_int(keep(pq, is.character), ~ sum(str_detect(.x, moji), na.rm = TRUE)))
  check(m$collection, paste(m$table, "no garbled accents (such as Ã© or Î´)"), n_moji == 0, n_moji)
  na_text <- sum(map_int(keep(pq, is.character), ~ sum(.x == "NA", na.rm = TRUE)))
  check(m$collection, paste(m$table, "no text cell reads \"NA\" (R would read it as missing)"), na_text == 0, na_text)
}

# ---------------------------------------------------------------------------
# 2. Links between tables
# ---------------------------------------------------------------------------
read_c <- function(...) read_csv(file.path(data_dir, ...), col_types = cols(.default = "c"), na = "", progress = FALSE)
units <- tables$opgaaf_tax_units; entries <- tables$opgaaf_entries
sheets <- read_c("opgaaf", "opgaaf_sheet_inventory.csv")
flags <- read_c("opgaaf", "opgaaf_quality_flags.csv")
registry <- read_c("opgaaf", "opgaaf_schema_registry.csv")
corrections <- read_c("opgaaf", "opgaaf_corrections_log.csv")
dy <- function(d) paste(d$district, as.integer(d$year))
check("opgaaf", "each entry belongs to a tax unit", all(entries$tax_unit_chdr_id %in% units$chdr_id))
check("opgaaf", "each tax unit in the entries table has at least two lines",
      all(count(entries, tax_unit_chdr_id)$n >= 2))
check("opgaaf", "each flagged tax unit exists", all(na.omit(flags$tax_unit_chdr_id) %in% units$chdr_id),
      paste(sum(!is.na(flags$tax_unit_chdr_id)), "of", nrow(flags), "flags name a tax unit"))
check("opgaaf", "one sheet-inventory row per district and year", !anyDuplicated(dy(sheets)), nrow(sheets))
check("opgaaf", "every district-year of the tables is in the sheet inventory",
      all(c(dy(units), dy(flags), dy(registry), dy(filter(corrections, !is.na(year)))) %in% dy(sheets)))
check("opgaaf", "corrections without a year cover a range of sheets",
      all(!is.na(corrections$district)) && all(str_starts(corrections$reason[is.na(corrections$year)], "Sheets ")),
      sum(is.na(corrections$year)))
arch <- read_c("opgaaf", "opgaaf_archival_references.csv")
check("opgaaf", "every district-year has an archival reference",
      setequal(dy(arch), dy(sheets)) && !anyNA(arch$reference) && !anyDuplicated(dy(arch)), nrow(arch))
check("opgaaf", "every opgaaf variable is in the tables",
      all(read_csv(file.path(data_dir, "opgaaf", "opgaaf_variables.csv"), show_col_types = FALSE)$variable %in%
            c(names(units), names(entries))))

persons <- tables$saf_persons; marriages <- tables$saf_marriages
check("saf", "nobody in saf_persons born or baptised after 1870",
      !any(persons$birth_year > 1870 & persons$birth_year <= 2014, na.rm = TRUE) &&
        !any(is.na(persons$birth_year) & persons$baptism_year > 1870 & persons$baptism_year <= 2014, na.rm = TRUE))
check("saf", "no published spouse born after 1870",
      !any(marriages$spouse_birth_year > 1870 & marriages$spouse_birth_year <= 2014, na.rm = TRUE))
check("saf", "every person has an inclusion basis", !anyNA(persons$inclusion_basis))
missing_principal <- sum(!marriages$principal_chdr_id %in% persons$chdr_id)
check("saf", "marriages without a published principal (principal born after 1870): 2,879, as the README states",
      missing_principal == 2879, missing_principal)
# Not a pass/fail check: reported under "Notes"
born_to <- na.omit(persons$mother_spouse_code)
notes <- sprintf("SAF: %.1f%% of the %s persons with a `mother_spouse_code` have their parents' marriage in `saf_marriages`; the rest point to marriages that are not in the sheet or not in the release.",
                 100 * mean(born_to %in% marriages$spouse_code), format(length(born_to), big.mark = ","))
check("saf", "variable list covers both tables exactly",
      nrow(read_csv(file.path(data_dir, "saf", "saf_variables.csv"), show_col_types = FALSE)) == ncol(persons) + ncol(marriages))

ema <- tables$emancipation_persons
check("emancipation", "valuations below 300 and not negative",
      all(ema$valuation >= 0 & ema$valuation < 300, na.rm = TRUE))

run <- tables$runaways_persons
check("runaways", "every advertisement published 1830-1842",
      all(between(as.integer(format(run$publication_date, "%Y")), 1830, 1842)))

goods <- tables$prices_goods
check("prices", "every good in prices_annual and prices_auction_goods is in prices_goods",
      all(c(tables$prices_annual$good, tables$prices_auction_goods$good) %in% goods$good))
check("prices", "prices positive, years 1718-1813",
      all(tables$prices_annual$median_price > 0 & tables$prices_annual$mean_price > 0) &&
        all(between(c(tables$prices_annual$year, tables$prices_auction_goods$year), 1718, 1813)))


vp <- tables$voortrekkers_persons; vm <- tables$voortrekkers_marriages
realign <- read_c("voortrekkers", "voortrekkers_realignments.csv")
check("voortrekkers", "every marriage belongs to a published trekker", all(vm$principal_chdr_id %in% vp$chdr_id))
check("voortrekkers", "every realignment names a published trekker", all(realign$chdr_id %in% vp$chdr_id), nrow(realign))
vdates <- na.omit(c(vp$birth_date, vp$baptism_date, vp$death_date, vp$trek_date, vm$marriage_date,
                    vm$spouse_birth_date, vm$spouse_baptism_date, vm$spouse_death_date))
# Dates are ISO 8601 (a date, or an interval a/b) or text as transcribed. Each end
# of an ISO value must be a real year (1600-1999), month or day; a bare number
# outside that range (7561, a typo) is text kept as written.
iso_end <- function(x) {
  ok <- str_detect(x, "^1[6-9][0-9]{2}(-(0[1-9]|1[0-2])(-[0-3][0-9])?)?$")
  full <- ok & str_length(x) == 10
  ok[full] <- !is.na(as.Date(x[full], format = "%Y-%m-%d"))
  ok
}
ends <- str_split_fixed(vdates, "/", 2)
iso <- str_detect(vdates, "^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?(/[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?)?$") &
  str_detect(vdates, "^1[6-9]")
check("voortrekkers", "dates in ISO form are valid dates in 1600-1999",
      all(iso_end(ends[iso, 1]) & (ends[iso, 2] == "" | iso_end(ends[iso, 2]))),
      sprintf("%.0f%% of %s dates in ISO form", 100 * mean(iso), format(length(vdates), big.mark = ",")))

alm <- tables$almanacs_entries
repeats <- read_c("almanacs", "almanacs_removed_repeats.csv")
check("almanacs", "removed repeats are not published and repeat a published entry",
      !any(repeats$chdr_id %in% alm$chdr_id) && all(repeats$repeats %in% alm$chdr_id), nrow(repeats))
pub_years <- list("African Court Calendar" = c(1813, 1827), "Cape Advertiser" = c(1821, 1821),
                  "Cape Almanac" = c(1828, 1891), "Transvaal Almanac" = c(1881, 1881))
check("almanacs", "each edition year within its publication's run",
      all(map2_lgl(alm$publication, alm$year, ~ between(.y, pub_years[[.x]][1], pub_years[[.x]][2]))))

# ---------------------------------------------------------------------------
# 3. XML: every file parses; checksums and counts match file_names.txt;
#    probate references unique
# ---------------------------------------------------------------------------
for (coll in c("probate", "auctions")) {
  map_tbl <- read_tsv(file.path(data_dir, coll, "file_names.txt"), col_types = cols(.default = "c"))
  files <- file.path(data_dir, coll, "xml", map_tbl$new_name)
  on_disk <- list.files(file.path(data_dir, coll, "xml"))
  check(coll, "files on disk match file_names.txt", setequal(on_disk, map_tbl$new_name), length(on_disk))
  check(coll, "MD5 checksums match file_names.txt", all(unname(tools::md5sum(files)) == map_tbl$md5))
  refs <- map(files, function(f) {
    doc <- tryCatch(read_xml(f), error = function(e) NULL)
    if (is.null(doc)) return(NULL)
    xml_attr(xml_find_all(doc, "/text/body/div"), "n")
  })
  check(coll, "every file parses as XML", !any(map_lgl(refs, is.null)))
  check(coll, "no file declares an external DTD or a local path",
        !any(map_lgl(files, ~ any(grepl("<!DOCTYPE|[A-Za-z]:\\\\", readLines(.x, n = 3, warn = FALSE))))))
  check(coll, "document counts match file_names.txt",
        all(map_int(refs, length) == as.integer(map_tbl$n_documents)),
        format(sum(map_int(refs, length)), big.mark = ","))
  if (coll == "auctions") {
    check("prices", "every auction in prices_auction_goods is a document in the MOOC10 XML",
          all(tables$prices_auction_goods$mooc_id %in% unlist(refs)))
  }
  if (coll == "probate") {
    all_refs <- unlist(refs)
    check(coll, "every reference unique", !anyDuplicated(all_refs))
    check(coll, "every document in its own volume's file",
          all(map2_lgl(refs, map_tbl$new_name, function(r, f)
            all(as.integer(str_match(r, "^MOOC8/([0-9]+)")[, 2]) == as.integer(str_match(f, "vol([0-9]+)")[, 2])))))
  }
}

# ---------------------------------------------------------------------------
# 4. Every file: under GitHub's 100 MB limit; text files are valid UTF-8
# ---------------------------------------------------------------------------
all_files <- list.files(rel, recursive = TRUE, all.files = TRUE)
all_files <- all_files[!str_detect(all_files, "^validation/")]
sizes <- file.size(file.path(rel, all_files))
check("all", "every file under 100 MB", all(sizes < 100 * 2^20),
      sprintf("largest %s, %.1f MB", all_files[which.max(sizes)], max(sizes) / 2^20))
text_files <- all_files[str_detect(all_files, "[.](csv|txt|md|json|cff|bib|xml|R|py|ps1)$|LICENSE")]
bad_utf8 <- text_files[!map_lgl(text_files, ~ validUTF8(rawToChar(readBin(file.path(rel, .x), "raw", file.size(file.path(rel, .x))))))]
check("all", "every text file is valid UTF-8", length(bad_utf8) == 0, paste(bad_utf8, collapse = ", "))
csv_files <- all_files[str_detect(all_files, "^data/.*[.]csv$")]
na_text <- map_int(csv_files, ~ sum(read_csv(file.path(rel, .x), col_types = cols(.default = "c"), na = "",
                                             progress = FALSE) == "NA", na.rm = TRUE))
check("all", "no CSV cell reads \"NA\"", all(na_text == 0), paste(csv_files[na_text > 0], collapse = ", "))
bom <- text_files[map_lgl(text_files, ~ identical(readBin(file.path(rel, .x), "raw", 3), as.raw(c(0xef, 0xbb, 0xbf))))]
check("all", "no CSV starts with a byte-order mark", !any(str_detect(bom, "[.]csv$")), paste(bom, collapse = ", "))

# ---------------------------------------------------------------------------
# 5. Report
# ---------------------------------------------------------------------------
inventory <- tibble(file = all_files[str_detect(all_files, "^data/.*[.](csv|parquet)$")]) |>
  mutate(size_mb = round(file.size(file.path(rel, file)) / 2^20, 1))
md <- c(
  "# Validation report",
  "",
  sprintf("Generated by `code/package/02_validate.R` on %s, reading the published files.", Sys.Date()),
  sprintf("**%d of %d checks passed.**", sum(checks$result), nrow(checks)),
  "",
  "| Collection | Check | Result | Detail |",
  "|---|---|---|---|",
  sprintf("| %s | %s | %s | %s |", checks$collection, checks$check,
          if_else(checks$result, "pass", "**FAIL**"), checks$detail),
  "",
  "## Notes",
  "",
  paste("-", notes),
  "",
  "## Tables",
  "",
  "| File | Size (MB) |",
  "|---|---|",
  sprintf("| `%s` | %s |", inventory$file, inventory$size_mb),
  "")
dir.create(file.path(rel, "validation"), showWarnings = FALSE)
writeLines(md, file.path(rel, "validation", "validation_report.md"), useBytes = TRUE)
message(sum(checks$result), " of ", nrow(checks), " checks passed")
stopifnot(all(checks$result))
