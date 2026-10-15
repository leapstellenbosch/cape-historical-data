# Apply the auction (MOOC10) correction approved by Johan on 15 October 2026,
# after 01_rename_and_check.R has copied the originals into the release:
# remove the document type declaration (<!DOCTYPE ...>) from volumes 15-18.
# Each declared a DTD by a path on a transcriber's computer (volume 18 named
# the transcriber's user folder); the DTD is not supplied, parsers ignore it,
# and nothing else depends on it. Edits are made on the original bytes, so
# everything else in each file stays exactly as transcribed. Writes
# release/data/auctions/corrections.txt and updates the checksums in
# file_names.txt.
suppressMessages({library(dplyr); library(stringr); library(readr); library(xml2); library(tools); library(purrr)})
root <- here::here()
src  <- file.path(root, "sources", "raw", "auctions")
out  <- file.path(root, "release", "data", "auctions")
map  <- read_tsv(file.path(out, "file_names.txt"), col_types = cols(.default = "c"))

read_bytes  <- function(f) { x <- rawToChar(readBin(f, "raw", file.size(f))); Encoding(x) <- "UTF-8"; x }
write_bytes <- function(x, f) writeBin(charToRaw(enc2utf8(x)), f)
original <- function(new) file.path(src, map$original_name[map$new_name == new])

files <- sprintf("MOOC10_vol%02d.xml", 15:18)
pat   <- '<!DOCTYPE text SYSTEM "[^"]*">'
divs  <- function(d) map_chr(xml_find_all(d, "/text/body/div"), ~ as.character(.x))

for (f in files) {
  txt <- read_bytes(original(f))
  stopifnot(str_count(txt, regex(pat)) == 1)
  new <- sub(pat, "", txt, useBytes = TRUE)
  Encoding(new) <- "UTF-8"
  # Only the declaration is gone: bytes and parsed documents otherwise identical
  stopifnot(nchar(txt, "bytes") - nchar(new, "bytes") == nchar(str_extract(txt, pat), "bytes"),
            !grepl("DOCTYPE", new, fixed = TRUE),
            identical(divs(read_xml(txt)), divs(read_xml(new))))
  write_bytes(new, file.path(out, "xml", f))
}

stopifnot(!any(map_lgl(list.files(file.path(out, "xml"), full.names = TRUE),
                       ~ grepl("DOCTYPE", read_bytes(.x), fixed = TRUE))))

# ---- Log and file table ----
log <- tibble(file = files, change = "document type declaration removed (path to a DTD on a transcriber's computer; DTD not supplied)",
              original_md5 = unname(md5sum(map_chr(files, original))))
write_tsv(log, file.path(out, "corrections.txt"), na = "")

map <- map |> mutate(
  size_kb = as.character(round(file.size(file.path(out, "xml", new_name)) / 1024)),
  md5 = unname(md5sum(file.path(out, "xml", new_name))))
write_tsv(map, file.path(out, "file_names.txt"), na = "")
cat("Auctions: DOCTYPE removed from", paste(files, collapse = ", "), "\n")
