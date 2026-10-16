# Write release/CITATION.cff and release/.zenodo.json from the registry in
# citations.R: the version, the creators and the works to cite. The release
# DOIs and the Zenodo description are kept here too.
here::i_am("PLAN.md")
suppressMessages({library(tidyverse); library(here); library(jsonlite)})
source(here("pipeline", "package", "citations.R"))

rel <- here("release")
concept_doi <- "10.5281/zenodo.23397436"
version_dois <- c("1.0" = "10.5281/zenodo.23397437", "1.1" = "10.5281/zenodo.23419842")   # add each new version's DOI after its release
keywords <- c("Cape Colony", "economic history", "tax censuses", "opgaafrollen", "slavery", "emancipation",
              "runaway slaves", "genealogy", "Great Trek", "probate inventories", "auctions", "prices",
              "petitions", "directories", "South Africa")

# ---------------------------------------------------------------------------
# CITATION.cff
# ---------------------------------------------------------------------------
cff_person <- function(family, particle = NA, given, affiliation = NULL) {
  p <- list(`family-names` = family)
  if (!is.na(particle)) p$`name-particle` <- particle
  p$`given-names` <- given
  if (!is.null(affiliation)) p$affiliation <- affiliation
  p
}
split_family <- function(name) {
  m <- str_match(name, "^((?:van der|van|von|de|du|le) )?(.+)$")
  list(particle = str_trim(m[, 2]), family = m[, 3])
}
cff_work <- function(w) {
  r <- list(type = w$type, title = w$title,
            authors = map(w$authors, function(p) { s <- split_family(p$family); cff_person(s$family, s$particle, p$given) }))
  if (!is.null(w$journal)) r$journal <- w$journal
  if (!is.null(w$publisher)) r$publisher <- list(name = w$publisher)
  if (!is.null(w$institution)) r$institution <- list(name = w$institution)
  r$year <- as.integer(w$year)
  for (f in c("volume", "issue", "start", "end")) if (!is.null(w[[f]])) r[[f]] <- as.integer(w[[f]])
  if (!is.null(w$note)) r$notes <- w$note
  if (!is.null(w$doi)) r$doi <- w$doi
  r
}
cff <- list(
  `cff-version` = "1.2.0",
  message = "If you use these data, cite the paper(s) for each collection you use (see README and references below) and this release.",
  type = "dataset",
  title = "Cape Historical Data Repository",
  version = release_version,
  doi = concept_doi,
  `date-released` = release_date,
  identifiers = c(list(list(type = "doi", value = concept_doi, description = "All versions (resolves to the latest)")),
                  imap(unname(version_dois), ~list(type = "doi", value = .x, description = paste("Version", names(version_dois)[.y])))),
  license = c("CC-BY-4.0", "CC-BY-NC-SA-4.0"),   # the second for data/runaways/ only
  `repository-code` = "https://github.com/leapstellenbosch/cape-historical-data",
  keywords = keywords,
  authors = pmap(creators, function(family, particle, given, affiliation) cff_person(family, particle, given, affiliation)),
  references = map(works, cff_work))
yaml::write_yaml(cff, file.path(rel, "CITATION.cff"), indent.mapping.sequence = FALSE)
# yaml writes strings unquoted where safe; check the file reads back the same
stopifnot(identical(yaml::read_yaml(file.path(rel, "CITATION.cff"))$version, release_version),
          length(yaml::read_yaml(file.path(rel, "CITATION.cff"))$authors) == nrow(creators))

# ---------------------------------------------------------------------------
# .zenodo.json
# ---------------------------------------------------------------------------
zname <- function(family, particle, given) paste0(if (!is.na(particle)) paste0(particle, " "), family, ", ", given)
funding <- paste(
  "The transcription was funded by Riksbankens Jubileumsfond (the Bank of Sweden Tercentenary Foundation) through the",
  "Cape of Good Hope Panel project, 'The establishment, growth and legacy of a settler colony: Quantitative panel studies",
  "of the political economy of Cape Colony' (grant M20-0041).")
description <- paste0(
  "<p>Records on the Cape Colony, 1660-1891, released by LEAP (Laboratory for the Economics of Africa's Past), Stellenbosch University. ",
  "Cleaned tables (CSV and Parquet) of the opgaaf tax censuses (1660-1844, ten districts; 325,628 tax units), ",
  "the 1834 slave emancipation records (36,417 records), the South African Families genealogies (213,953 people born up to 1870 and 153,568 marriages), ",
  "runaway slave advertisements (881 people, 1830-1842), the 1779 Cape Patriots petition (404 signatories), ",
  "the Voortrekker register (2,313 trekkers and 2,978 marriages) and the Cape almanac directories (97,391 entries, 1813-1891); ",
  "yearly prices of 30 goods sold at estate auctions (1718-1813); ",
  "and the transcription XML of the Orphan Chamber probate inventories (MOOC8; 5,953 documents, 1673-1844) and estate auction rolls (MOOC10; 3,266 auctions, 1691-1834). ",
  "Every file and column is described in the collections' READMEs and in datapackage.json.</p>",
  "<p>Users must cite the paper(s) for each collection they use, listed in the README and below, and this release. ",
  "The runaway advertisements are released under CC BY-NC-SA 4.0, the licence of their original deposit; everything else is CC BY 4.0.</p>",
  "<p>Most of the records are transcriptions of documents held by the Western Cape Archives and Records Service, Cape Town (opgaafrollen, series J; Slave Office, SO 6 and SO 20; Master of the Orphan Chamber, MOOC 8 and MOOC 10; Council of Policy, C 2665), with early tax returns from the Nationaal Archief, The Hague (VOC archive, 1.04.02); the README lists the archival source of each collection.</p>",
  "<p>", funding, "</p>")
zen <- list(
  title = "Cape Historical Data Repository",
  upload_type = "dataset",
  version = release_version,
  license = "cc-by-4.0",
  description = description,
  notes = funding,
  creators = pmap(creators, function(family, particle, given, affiliation) list(name = zname(family, particle, given), affiliation = affiliation)),
  keywords = keywords,
  related_identifiers = map(keep(works, ~!is.null(.x$doi)), ~list(
    identifier = .x$doi, relation = if (.x$role == "source") "isDerivedFrom" else "isDocumentedBy", scheme = "doi")))
write_json(zen, file.path(rel, ".zenodo.json"), auto_unbox = TRUE, pretty = 2)
message("CITATION.cff and .zenodo.json: version ", release_version, ", ", nrow(creators), " creators, ",
        length(works), " works (", sum(map_lgl(works, ~!is.null(.x$doi))), " with a DOI)")
