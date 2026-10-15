# Copy the original MOOC8 and MOOC10 XML into the release under tidy names,
# byte for byte, and write a table linking each new name to the original.
# Also checks that every file parses as XML. Then run 02_probate_corrections.R,
# which applies the approved probate corrections to the copies.
suppressMessages({library(dplyr); library(stringr); library(readr); library(xml2); library(tools)})
root <- here::here()
raw  <- file.path(root, "sources", "raw")
out  <- file.path(root, "release", "data")

# ---- Probate (MOOC8): MOOC8_10.01-76_v3.2.00.xml -> MOOC8_vol10.xml ----
p_files <- list.files(file.path(raw, "probate", "XML files"), pattern = "[.]xml$")
probate <- tibble(original_name = p_files) |>
  mutate(volume   = as.integer(str_match(original_name, "^MOOC8_([0-9]+)[.]")[, 2]),
         new_name = sprintf("MOOC8_vol%02d.xml", volume),
         src      = file.path(raw, "probate", "XML files", original_name))

# ---- Auctions (MOOC10): MOOC10_v20 (Indeks+1-92)_FN-XML.xml -> MOOC10_vol20.xml ----
a_files <- list.files(file.path(raw, "auctions"), pattern = "[.]xml$")
auctions <- tibble(original_name = a_files) |>
  mutate(vol_str   = str_match(original_name, "^MOOC10_v([0-9]+)[ _]")[, 2],
         variant_R = str_detect(original_name, "-R[.]xml$"),
         new_name  = case_when(
           str_detect(original_name, "Hoof Indeks")     ~ "MOOC10_index.xml",
           str_detect(original_name, "^MOOC10_v1-v5")   ~ "MOOC10_vol01-05.xml",
           str_detect(original_name, "^MOOC10_v6[+]v7") ~ "MOOC10_vol06-08.xml",
           TRUE ~ sprintf("MOOC10_vol%02d.xml", as.integer(vol_str))),
         src = file.path(raw, "auctions", original_name))
# Volumes 15-18 exist twice; the later "-R" files are corrected versions
# (same documents, with filled-in and corrected cells; see decision ledger).
dups <- auctions |> count(new_name) |> filter(n > 1) |> pull(new_name)
auctions <- auctions |> filter(!(new_name %in% dups) | variant_R)
stopifnot(!any(duplicated(auctions$new_name)), !any(duplicated(probate$new_name)))

check <- function(f) {
  doc <- tryCatch(read_xml(f), error = function(e) conditionMessage(e))
  if (is.character(doc)) return(c(parses = "no", n_documents = NA, note = doc))
  n  <- length(xml_find_all(doc, "/text/body/div"))
  dt <- any(grepl("<!DOCTYPE", readLines(f, n = 3, warn = FALSE)))
  c(parses = "yes", n_documents = n,
    note = if (dt) "external DTD declared (path on the transcriber's computer)" else "")
}

publish <- function(tbl, dir, label) {
  dest <- file.path(out, dir, "xml")
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  res <- t(vapply(tbl$src, check, character(3)))
  tbl <- tbl |> mutate(parses = res[, 1], n_documents = as.integer(res[, 2]), note = res[, 3])
  stopifnot(all(file.copy(tbl$src, file.path(dest, tbl$new_name), overwrite = TRUE)))
  tbl$md5 <- unname(md5sum(file.path(dest, tbl$new_name)))
  stopifnot(all(tbl$md5 == unname(md5sum(tbl$src))))   # byte-identical copies
  tbl$size_kb <- round(file.size(tbl$src) / 1024)
  map <- tbl |> arrange(new_name) |> select(new_name, original_name, n_documents, size_kb, md5)
  write_tsv(map, file.path(out, dir, "file_names.txt"), na = "")
  cat(label, ":", nrow(map), "files;", sum(tbl$parses == "yes"), "parse;",
      sum(tbl$note != "" & tbl$parses == "yes"), "declare an external DTD;",
      sum(tbl$n_documents, na.rm = TRUE), "top-level divs\n")
  print(tbl |> filter(parses == "no" | note != "") |> select(new_name, parses, note), n = 60)
  invisible(tbl)
}
p <- publish(probate, "probate", "Probate")
a <- publish(auctions, "auctions", "Auctions")
