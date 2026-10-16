# Write release/datapackage.json (Frictionless Data Package v1): every
# published data file with its size, MD5 checksum and, for tables, every
# column with its type and meaning, read from the files themselves and from
# the collections' variable lists.
here::i_am("PLAN.md")
suppressMessages({library(tidyverse); library(here); library(jsonlite)})

rel <- here("release")
d <- function(...) file.path(rel, "data", ...)
md5 <- function(path) unname(tools::md5sum(file.path(rel, path)))
bytes <- function(path) file.size(file.path(rel, path))

# ---- Citations, by collection (from citations.R) ----
source(here("pipeline", "package", "citations.R"))
cite <- map(set_names(unique(map_chr(works, "coll"))), function(coll) {
  c(map(keep(works, ~.x$coll == coll), function(w) {
      s <- list(title = paste0(if (w$role == "source") "Source: ", short_ref(w)))
      if (!is.null(w$doi)) s$path <- paste0("https://doi.org/", w$doi)
      s
    }),
    # where the original records are held
    map(archives[[coll]], ~list(title = paste("Archival source:", .x))))
})
cite_note <- function(coll) paste0(" Cite: ", paste(map_chr(keep(cite[[coll]], ~!str_starts(.x$title, "Source: |Archival source: ")), "title"),
                                                   collapse = "; and "), ".")
# The runaway advertisements keep the licence of their Dataverse deposit
licence_of <- function(coll) if (coll == "runaways")
  list(list(name = "CC-BY-NC-SA-4.0", title = "Creative Commons Attribution-NonCommercial-ShareAlike 4.0",
            path = "https://creativecommons.org/licenses/by-nc-sa/4.0/"))

# ---- Field types ----
type_of <- function(x) {
  if (inherits(x, "Date")) "date"
  else if (is.logical(x)) "boolean"
  else if (is.integer(x)) "integer"
  else if (is.double(x)) if (all(is.na(x) | x == round(x))) "integer" else "number"
  else "string"
}
fields_for <- function(data, descriptions) {
  map(names(data), function(n) {
    f <- list(name = n, type = type_of(data[[n]]))
    desc <- descriptions[[n]]
    if (is.null(desc) || is.na(desc)) stop("No description for ", n)
    f$description <- desc
    f
  })
}
read_any <- function(path, delim = ",") {
  read_delim(file.path(rel, path), delim = delim, guess_max = Inf, na = "", show_col_types = FALSE, progress = FALSE)
}

table_resource <- function(path, name, title, description, coll, data, descriptions,
                           primary_key = NULL, foreign_keys = NULL, delim = ",") {
  r <- list(name = name, path = path, title = title, description = paste0(description, cite_note(coll)),
            format = "csv", mediatype = if (delim == ",") "text/csv" else "text/tab-separated-values",
            encoding = "utf-8", bytes = bytes(path), hash = md5(path))
  if (delim != ",") r$dialect <- list(delimiter = "\t")
  r$schema <- list(fields = fields_for(data, descriptions), missingValues = list(""))
  if (!is.null(primary_key)) r$schema$primaryKey <- primary_key
  if (!is.null(foreign_keys)) r$schema$foreignKeys <- foreign_keys
  r$sources <- cite[[coll]]
  r$licenses <- licence_of(coll)
  r
}
parquet_resource <- function(path, name, csv_name, coll) {
  r <- list(name = name, path = path, title = paste("Parquet copy of", csv_name),
            description = paste0("The same table as ", csv_name, ", in Parquet (zstd), with column types.", cite_note(coll)),
            format = "parquet", mediatype = "application/vnd.apache.parquet",
            bytes = bytes(path), hash = md5(path), sources = cite[[coll]])
  r$licenses <- licence_of(coll)    # absent (the package licence) except for the runaways
  r
}
named <- function(tbl, key = "variable", value = "description") set_names(as.list(tbl[[value]]), tbl[[key]])

resources <- list()
add <- function(r) resources[[length(resources) + 1]] <<- r

# ---------------------------------------------------------------------------
# Opgaaf
# ---------------------------------------------------------------------------
opg_vars <- read_any("data/opgaaf/opgaaf_variables.csv")
opg_desc <- named(opg_vars)
for (t in list(
  list(stem = "opgaaf_tax_units", title = "Opgaaf tax units",
       description = "One row per tax unit (declaration) in the opgaaf tax censuses, 1660-1844, ten districts. Sheet-level attributes (workbook, sheet, form type) are in opgaaf_sheet_inventory, joined on district and year.",
       fk = list(list(fields = list("district", "year"),
                      reference = list(resource = "opgaaf-sheet-inventory", fields = list("district", "year"))))),
  list(stem = "opgaaf_entries", title = "Opgaaf entries of multi-line tax units",
       description = "The transcribed lines of the 5,604 tax units that combine several lines; -E1 is the declaration. A tax unit with one line equals that line, so its line is not repeated here.",
       fk = list(list(fields = "tax_unit_chdr_id",
                      reference = list(resource = "opgaaf-tax-units", fields = "chdr_id")))))) {
  path <- paste0("data/opgaaf/", t$stem, ".csv")
  pq <- nanoparquet::read_parquet(file.path(rel, "data/opgaaf", paste0(t$stem, ".parquet")))
  add(table_resource(path, str_replace_all(t$stem, "_", "-"), t$title, t$description, "opgaaf",
                     pq, opg_desc, primary_key = "chdr_id", foreign_keys = t$fk))
}

sheet_desc <- list(
  district = "District of the workbook", year = "Year of the sheet",
  source_workbook = "File name of the transcribers' workbook (not published)",
  source_sheet = "Name of the sheet in the workbook",
  form_type = "Kind of return: opgaaf_declaration_return (ordinary declarations), capitation_tax_return, named_adult_servant_return or aggregate_houseful_production_return (aggregate returns for establishments)",
  n_header_rows = "Number of header rows above the data",
  first_data_row = "First spreadsheet row of data",
  summary_start_row = "Spreadsheet row where a section of summary totals begins; these rows are not tax units",
  n_columns = "Number of columns in the sheet",
  n_mapped_b = "Number of columns mapped to a variable with confidence B",
  n_unmapped_or_ambiguous = "Number of columns not mapped, or mapped with confidence C and not used",
  reason = "What the summary section beginning at summary_start_row holds")
registry_desc <- list(
  district = "District of the sheet", year = "Year of the sheet",
  source_column = "Column position in the sheet (V1 is the first column)",
  header = "Original column header, as transcribed; header levels joined with |",
  canonical_field = "Variable the column maps to in the opgaaf tables",
  measure_type = "What the variable measures (e.g. person_stock, asset_stock, identifier)",
  population_group = "Population group of a person count (settler, servant, slave, khoe, prizenegro, freeblack, ...)",
  sex = "Sex of a person count (male, female)",
  age_lower = "Lower age limit of a person count, as the form states it",
  age_upper = "Upper age limit of a person count, as the form states it",
  mapping_method = "How the header was mapped (header_dictionary, header_semantics, manual_header_override, unmapped; :duplicate_target where several columns map to one variable)",
  confidence = "B: mapped and structurally checked, used in the tables; C: not used",
  duplicate_target = "TRUE where more than one column of the sheet maps to the same variable",
  notes = "Notes on the mapping")
flags_desc <- list(
  tax_unit_chdr_id = "chdr_id of the tax unit the flag concerns; empty for excluded rows and sheet-level flags",
  district = "District of the sheet", year = "Year of the sheet",
  source_row = "Spreadsheet row", flag_level = "sheet, row or cell",
  canonical_field = "Variable concerned (cell flags)", source_column = "Column position in the sheet (cell flags)",
  raw_value = "Value as transcribed", flag_type = "Kind of problem",
  severity = "review, resolved, blocks_cell_use (the cell is NA in the tables) or error_prevented",
  detail = "Further detail, such as the header or the rule that raised the flag")
corr_desc <- list(
  district = "District of the sheet",
  year = "Year of the sheet; empty where a correction covers a range of sheets (named in reason)",
  correction_id = "Identifier of the correction", correction_level = "What was corrected: schema, schema_column, row_classification, folio_marker, cell_normalization or cell",
  source_row = "Spreadsheet row (row and cell corrections)", source_column = "Column position in the sheet",
  canonical_field = "Variable concerned", raw_value = "Value or layout before correction",
  corrected_value = "Value or layout after correction",
  correction_status = "applied, or row_excluded_pending_archival_image",
  reason = "Why the correction was made")
opgvar_desc <- list(
  variable = "Variable name in opgaaf_tax_units or opgaaf_entries", r_type = "Storage type in R",
  description = "Meaning of the variable", field_type_registry = "Whether the variable is numeric or text in the source",
  measure_type = "What the variable measures", population_group = "Population group of a person count",
  sex = "Sex of a person count", age_lower_values = "Lower age limits found across sheets",
  age_upper_values = "Upper age limits found across sheets",
  n_sheets_recorded = "Number of sheets in which the variable is recorded",
  definitions_vary_by_sheet = "TRUE where age limits or definitions differ between sheets",
  in_tax_units = "TRUE if the variable is a column of opgaaf_tax_units",
  in_entries = "TRUE if the variable is a column of opgaaf_entries")
for (t in list(
  list(f = "opgaaf_sheet_inventory", title = "Opgaaf sheet inventory", desc = sheet_desc, pk = list("district", "year"),
       description = "One row per district and year: the workbook and sheet transcribed, its form type and structure."),
  list(f = "opgaaf_schema_registry", title = "Opgaaf schema registry", desc = registry_desc, pk = list("district", "year", "source_column"),
       description = "Every original column header in every sheet, the variable it maps to and the confidence of the mapping."),
  list(f = "opgaaf_quality_flags", title = "Opgaaf quality flags", desc = flags_desc, pk = NULL,
       description = "Cell-, row- and sheet-level warnings and exclusions."),
  list(f = "opgaaf_corrections_log", title = "Opgaaf corrections log", desc = corr_desc, pk = "correction_id",
       description = "Every correction or interpretation applied to the transcription."),
  list(f = "opgaaf_archival_references", title = "Opgaaf archival references", pk = list("district", "year"),
       desc = list(district = "District", year = "Year of the return",
                   archive = "Archive holding the original: the Western Cape Archives and Records Service (Cape Town) or the Nationaal Archief (The Hague)",
                   reference = "The archive's reference: a volume of WCARS series J (J 183), or an inventory number in the VOC archive, 1.04.02 (VOC 1.04.02, inv. 4021)",
                   note = "Qualification: copies, scans, uncertain volumes"),
       description = "The archival source of each district-year: the volume or inventory number of the original return, from the transcribers' indexes, checked against the WCARS inventory of series J."),
  list(f = "opgaaf_variables", title = "Opgaaf variable list", desc = opgvar_desc, pk = "variable",
       description = "Every variable of the opgaaf tables: type, meaning, population group, sex and age limits."))) {
  path <- paste0("data/opgaaf/", t$f, ".csv")
  add(table_resource(path, str_replace_all(t$f, "_", "-"), t$title, t$description, "opgaaf",
                     read_any(path), t$desc, primary_key = t$pk))
}
add(parquet_resource("data/opgaaf/opgaaf_tax_units.parquet", "opgaaf-tax-units-parquet", "opgaaf_tax_units.csv", "opgaaf"))
add(parquet_resource("data/opgaaf/opgaaf_entries.parquet", "opgaaf-entries-parquet", "opgaaf_entries.csv", "opgaaf"))

# ---------------------------------------------------------------------------
# Emancipation and SAF
# ---------------------------------------------------------------------------
ema_vars <- read_any("data/emancipation/emancipation_variables.csv")
add(table_resource("data/emancipation/emancipation_persons.csv", "emancipation-persons",
                   "Slave emancipation records", "One row per record of an enslaved person in the 1834 emancipation registers and compensation claims.",
                   "emancipation", nanoparquet::read_parquet(d("emancipation", "emancipation_persons.parquet")),
                   named(ema_vars), primary_key = "chdr_id"))
var_list_desc <- list(table = "Table the variable belongs to", variable = "Variable name", type = "Storage type",
                      source_column = "Column of the source workbook the variable comes from ({n} is the marriage slot, 1-4)",
                      description = "Meaning of the variable")
add(table_resource("data/emancipation/emancipation_variables.csv", "emancipation-variables",
                   "Emancipation variable list", "Every variable of emancipation_persons, its source column and meaning.",
                   "emancipation", ema_vars, var_list_desc, primary_key = "variable"))
add(parquet_resource("data/emancipation/emancipation_persons.parquet", "emancipation-persons-parquet", "emancipation_persons.csv", "emancipation"))

saf_vars <- read_any("data/saf/saf_variables.csv")
add(table_resource("data/saf/saf_persons.csv", "saf-persons", "SAF persons",
                   "One row per person born up to 1870 in the South African Families genealogical database (version of 10 February 2014).",
                   "saf", nanoparquet::read_parquet(d("saf", "saf_persons.parquet")),
                   named(filter(saf_vars, table == "saf_persons")), primary_key = "chdr_id"))
add(table_resource("data/saf/saf_marriages.csv", "saf-marriages", "SAF marriages",
                   "One row per marriage of a principal, with the spouse's details (withheld where the spouse was born after 1870). principal_chdr_id is absent from saf_persons for 2,879 marriages whose principal was born after 1870.",
                   "saf", nanoparquet::read_parquet(d("saf", "saf_marriages.parquet")),
                   named(filter(saf_vars, table == "saf_marriages")), primary_key = "chdr_id"))
add(table_resource("data/saf/saf_variables.csv", "saf-variables", "SAF variable list",
                   "Every variable of saf_persons and saf_marriages, its source column and meaning.",
                   "saf", saf_vars, var_list_desc, primary_key = list("table", "variable")))
add(parquet_resource("data/saf/saf_persons.parquet", "saf-persons-parquet", "saf_persons.csv", "saf"))
add(parquet_resource("data/saf/saf_marriages.parquet", "saf-marriages-parquet", "saf_marriages.csv", "saf"))

# ---------------------------------------------------------------------------
# Collections added in version 1.1
# ---------------------------------------------------------------------------
pq <- function(coll, stem) nanoparquet::read_parquet(d(coll, paste0(stem, ".parquet")))
vars_of <- function(coll) read_any(paste0("data/", coll, "/", coll, "_variables.csv"))
add_table <- function(coll, stem, title, description, pk, fk = NULL, multi = FALSE) {
  v <- vars_of(coll)
  if (multi) v <- filter(v, table == stem)
  add(table_resource(paste0("data/", coll, "/", stem, ".csv"), str_replace_all(stem, "_", "-"), title, description,
                     coll, pq(coll, stem), named(v), primary_key = pk, foreign_keys = fk))
}
add_vars <- function(coll, title, multi = FALSE) {
  path <- paste0("data/", coll, "/", coll, "_variables.csv")
  add(table_resource(path, paste0(coll, "-variables"), title, paste("Every variable of the", coll, "tables, its source column and meaning."),
                     coll, read_any(path), if (multi) var_list_desc else var_list_desc[-1],
                     primary_key = if (multi) list("table", "variable") else "variable"))
}
add_pq <- function(coll, stem) add(parquet_resource(paste0("data/", coll, "/", stem, ".parquet"),
                                                    paste0(str_replace_all(stem, "_", "-"), "-parquet"), paste0(stem, ".csv"), coll))

add_table("runaways", "runaways_persons", "Runaway advertisements",
          "One row per person named in a runaway advertisement in De Zuid Afrikaan or the Government Gazette, 1830-1842, from Bergemann's Harvard Dataverse deposit. Licensed CC BY-NC-SA 4.0.",
          "chdr_id")
add_vars("runaways", "Runaway variable list"); add_pq("runaways", "runaways_persons")

goods_fk <- list(list(fields = "good", reference = list(resource = "prices-goods", fields = "good")))
add_table("prices", "prices_goods", "Auction price goods",
          "The 30 goods priced in the auction rolls, their asset type and class, and the Dutch terms searched for.", "good", multi = TRUE)
add_table("prices", "prices_annual", "Auction prices by year",
          "Median and mean unit price in rixdollars of each good sold at estate auctions, by year, 1718-1813. A derived series built from the MOOC10 auction rolls.",
          list("year", "good"), goods_fk, multi = TRUE)
add_table("prices", "prices_auction_goods", "Goods sold at each auction",
          "Number of units of each of the 30 goods sold at each estate auction, 1718-1813; mooc_id matches the document's n attribute in the auctions XML.",
          list("mooc_id", "year", "good"), goods_fk, multi = TRUE)
add_vars("prices", "Price variable list", multi = TRUE)
walk(c("prices_goods", "prices_annual", "prices_auction_goods"), ~add_pq("prices", .x))

add_table("petition1779", "petition1779_signatories", "1779 petition signatories",
          "One row per signatory of the 1779 Cape Patriots petition (WCARS C 2665), in the order they signed.", "chdr_id")
add_vars("petition1779", "Petition variable list"); add_pq("petition1779", "petition1779_signatories")


add_table("voortrekkers", "voortrekkers_persons", "Voortrekkers",
          "One row per trekker in the register transcribed from Visagie's Voortrekkerstamouers 1835-1845.", "chdr_id", multi = TRUE)
add_table("voortrekkers", "voortrekkers_marriages", "Voortrekker marriages",
          "One row per marriage of a trekker, with the spouse's details.", "chdr_id",
          list(list(fields = "principal_chdr_id", reference = list(resource = "voortrekkers-persons", fields = "chdr_id"))), multi = TRUE)
add(table_resource("data/voortrekkers/voortrekkers_realignments.csv", "voortrekkers-realignments", "Voortrekker realignments",
                   "Rows of the source sheet in which a block of dates and places was typed in the wrong columns, and how it was read.",
                   "voortrekkers", read_any("data/voortrekkers/voortrekkers_realignments.csv"),
                   list(chdr_id = "chdr_id of the trekker", source_row = "Row in the source sheet",
                        change = "Which block (person, m1-m5) was read from other columns, and how"), primary_key = "chdr_id"))
add_vars("voortrekkers", "Voortrekker variable list", multi = TRUE)
walk(c("voortrekkers_persons", "voortrekkers_marriages"), ~add_pq("voortrekkers", .x))

add_table("almanacs", "almanacs_entries", "Cape almanac directory entries",
          "One row per entry in the directories of the African Court Calendar, Cape Advertiser, Cape Almanac and Transvaal Almanac, 1813-1891.",
          "chdr_id")
add(table_resource("data/almanacs/almanacs_removed_repeats.csv", "almanacs-removed-repeats", "Almanac entries removed as repeats",
                   "Entries typed twice (identical in every column within an edition): the removed entry and the published entry it repeats.",
                   "almanacs", read_any("data/almanacs/almanacs_removed_repeats.csv"),
                   list(chdr_id = "Identifier the removed entry would have had", repeats = "chdr_id of the published entry it repeats"),
                   primary_key = "chdr_id"))
add_vars("almanacs", "Almanac variable list"); add_pq("almanacs", "almanacs_entries")

# ---------------------------------------------------------------------------
# XML: the file tables and one resource per file
# ---------------------------------------------------------------------------
names_desc <- list(new_name = "Published file name", original_name = "File name as supplied by the transcribers",
                   n_documents = "Number of documents (top-level div elements) in the file",
                   size_kb = "File size in kilobytes", md5 = "MD5 checksum of the published file")
xml_meta <- list(
  probate = list(title = "Probate inventories (MOOC8)", series = "MOOC8 probate inventories of the Orphan Chamber, 1673-1844"),
  auctions = list(title = "Estate auction rolls (MOOC10)", series = "MOOC10 estate auction rolls of the Orphan Chamber, 1691-1834"))
for (coll in names(xml_meta)) {
  path <- paste0("data/", coll, "/file_names.txt")
  add(table_resource(path, paste0(coll, "-file-names"), paste(xml_meta[[coll]]$title, "file list"),
                     "Each XML file: published name, original name, number of documents, size and MD5 checksum.",
                     coll, read_any(path, "\t"), names_desc, primary_key = "new_name", delim = "\t"))
  if (coll == "probate") {
    path <- "data/probate/corrections.txt"
    add(table_resource(path, "probate-corrections", "Probate corrections",
                       "Every change made to the transcribers' probate files: a duplicated copy of volume 10 removed from volume 1, and thirteen archival references corrected.",
                       coll, read_any(path, "\t"),
                       list(file = "Published file", from = "Reference before correction (or the documents removed)",
                            to = "Reference after correction", deceased = "First regularised name in the document's head",
                            reason = "Why the change was made", original_md5 = "MD5 checksum of the transcribers' original file"),
                       delim = "\t"))
  }
  if (coll == "auctions") {
    path <- "data/auctions/corrections.txt"
    add(table_resource(path, "auctions-corrections", "Auction corrections",
                       "The change made to the transcribers' auction files: the document type declaration, which gave a path on a transcriber's computer, removed from volumes 15-18.",
                       coll, read_any(path, "\t"),
                       list(file = "Published file", change = "What was changed",
                            original_md5 = "MD5 checksum of the transcribers' original file"),
                       primary_key = "file", delim = "\t"))
  }
  files <-read_any(path = paste0("data/", coll, "/file_names.txt"), "\t")
  for (k in seq_len(nrow(files))) {
    p <- paste0("data/", coll, "/xml/", files$new_name[k])
    add(list(name = str_to_lower(str_replace_all(str_remove(files$new_name[k], "[.]xml$"), "_", "-")),
             path = p, title = paste(xml_meta[[coll]]$title, str_remove(files$new_name[k], "[.]xml$")),
             description = paste0("TEI-style transcription XML of the ", xml_meta[[coll]]$series, ": ",
                                  files$n_documents[k], " documents. See data/", coll, "/README.md.", cite_note(coll)),
             format = "xml", mediatype = "application/xml", encoding = "utf-8",
             bytes = bytes(p), hash = md5(p), sources = cite[[coll]]))
  }
}

# ---------------------------------------------------------------------------
# Package
# ---------------------------------------------------------------------------
cff <- yaml::read_yaml(file.path(rel, "CITATION.cff"))
contributors <- map(cff$authors, function(a) {
  nm <- paste(c(a$`given-names`, a$`name-particle`, a$`family-names`), collapse = " ")
  list(title = nm, role = "author", organization = a$affiliation)
})
pkg <- list(
  profile = "data-package",
  name = "cape-historical-data",
  title = "Cape Historical Data Repository",
  id = paste0("https://doi.org/", cff$doi),
  version = release_version,
  description = paste(
    "Records on the Cape Colony, 1660-1891, released by LEAP (Laboratory for the Economics of Africa's Past), Stellenbosch University:",
    "cleaned tables of the opgaaf tax censuses (1660-1844, ten districts), the 1834 slave emancipation records, the South African Families genealogies (people born up to 1870),",
    "runaway slave advertisements (1830-1842), the 1779 Cape Patriots petition, the Voortrekker register and the Cape almanac directories (1813-1891);",
    "yearly prices of goods sold at estate auctions (1718-1813); and the transcription XML of the Orphan Chamber probate inventories (MOOC8) and estate auction rolls (MOOC10).",
    "Users must cite the paper(s) for each collection they use (each resource's sources) and this release.",
    "Licence CC BY 4.0, except the runaway advertisements (CC BY-NC-SA 4.0, the licence of their original deposit).",
    "Most of the records are transcriptions of documents held by the Western Cape Archives and Records Service, Cape Town (opgaafrollen, series J; Slave Office, SO 6 and SO 20; Master of the Orphan Chamber, MOOC 8 and MOOC 10; Council of Policy, C 2665), with early tax returns from the Nationaal Archief, The Hague (VOC archive, 1.04.02); the README lists the archival source of each collection.",
    "The transcription was funded by Riksbankens Jubileumsfond (the Bank of Sweden Tercentenary Foundation) through the Cape of Good Hope Panel project, grant M20-0041."),
  homepage = "https://github.com/leapstellenbosch/cape-historical-data",
  licenses = list(list(name = "CC-BY-4.0", title = "Creative Commons Attribution 4.0",
                       path = "https://creativecommons.org/licenses/by/4.0/")),
  keywords = cff$keywords,
  contributors = contributors,
  created = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  resources = resources)
stopifnot(!anyDuplicated(map_chr(resources, "name")),
          all(file.exists(file.path(rel, map_chr(resources, "path")))))
write_json(pkg, file.path(rel, "datapackage.json"), auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)
message("datapackage.json: ", length(resources), " resources, ",
        sum(map_int(resources, ~ length(.x$schema$fields))), " described fields")
