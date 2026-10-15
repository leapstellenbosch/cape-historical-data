# Apply the probate (MOOC8) corrections approved by Johan on 15 October 2026,
# after 01_rename_and_check.R has copied the originals into the release:
#   1. remove the copy of volume 10 from the end of MOOC8_vol01.xml;
#   2. correct thirteen archival references (div @n) that repeat another
#      document's reference or carry the wrong volume number.
# Edits are made on the original bytes, so everything else in each file stays
# exactly as transcribed. Writes release/data/probate/corrections.txt and
# updates the counts and checksums in file_names.txt.
suppressMessages({library(dplyr); library(stringr); library(readr); library(xml2); library(tools); library(purrr)})
root <- here::here()
src  <- file.path(root, "sources", "raw", "probate", "XML files")
out  <- file.path(root, "release", "data", "probate")
map  <- read_tsv(file.path(out, "file_names.txt"), col_types = cols(.default = "c"))

read_bytes  <- function(f) { x <- rawToChar(readBin(f, "raw", file.size(f))); Encoding(x) <- "UTF-8"; x }
write_bytes <- function(x, f) writeBin(charToRaw(enc2utf8(x)), f)
original <- function(new) file.path(src, map$original_name[map$new_name == new])

# ---- The corrections ----
# `deceased` is the first regularised name in the document's head, checked
# before the change. Repeated references are corrected in file order.
fixes <- tribble(
  ~file,             ~from,                    ~to,                       ~deceased,                          ~reason,
  "MOOC8_vol03.xml", "MOOC8/3.54",             "MOOC8/3.54a",             "Pijl, Pieter",                     "two estates numbered 3.54; letters added in file order",
  "MOOC8_vol03.xml", "MOOC8/3.54",             "MOOC8/3.54b",             "Smit, Jan",                        "two estates numbered 3.54; letters added in file order",
  "MOOC8_vol06.xml", "MOOC8/4.24",             "MOOC8/6.24",              "Zeijl, Johanna van",               "wrong volume number; filed between 6.23 and 6.25",
  "MOOC8_vol07.xml", "MOOC8/8.44",             "MOOC8/7.44",              "Schelde, Maria van der",           "wrong volume number; filed between 7.43c and 7.45a",
  "MOOC8_vol19.xml", "MOOC8/20.20",            "MOOC8/19.20",             "Sitterd, Andries van",             "wrong volume number; filed between 19.19 and 19.21",
  "MOOC8_vol19.xml", "MOOC8/10.35",            "MOOC8/19.35",             "Wijk, Gerrit van",                 "wrong volume number; filed between 19.34 and 19.36",
  "MOOC8_vol44.xml", "MOOC8/4.14",             "MOOC8/44.14",             "Janzen, Johanna Maria",            "wrong volume number; filed between 44.13 and 44.15",
  "MOOC8_vol56.xml", "MOOC8/54.4a",            "MOOC8/56.4a",             "Forster, Dorothea Maria",          "wrong volume number; part a of 56.4 (56.4b follows)",
  "MOOC8_vol59.xml", "MOOC8/69.52a",           "MOOC8/59.52a",            "Snijman, Jacomina",                "wrong volume number; part a of 59.52 (59.52b follows)",
  "MOOC8_vol61.xml", "MOOC8/61_no number 01",  "MOOC8/61_no number 01a",  "Cloete, Gerrit",                   "two documents of one estate with one reference; letters added in file order",
  "MOOC8_vol61.xml", "MOOC8/61_no number 01",  "MOOC8/61_no number 01b",  "Cloete, Gerrit",                   "two documents of one estate with one reference; letters added in file order",
  "MOOC8_vol71.xml", "MOOC8/1.12a",            "MOOC8/71.12a",            "Merwe, Johannes Marthinus van der","wrong volume number; part a of 71.12 (71.12b follows)",
  "MOOC8_vol73.xml", "MOOC8/37.11",            "MOOC8/73.11",             "Burger, Barend Hendrik",           "wrong volume number; filed between 73.10 and 73.12"
)

first_name <- function(txt, ref) {
  doc <- read_xml(txt)
  div <- xml_find_first(doc, sprintf("/text/body/div[@n='%s']", ref))
  xml_attr(xml_find_first(div, "./head/name"), "reg")
}

edited <- character()
for (f in unique(fixes$file)) {
  txt <- read_bytes(original(f))
  for (k in which(fixes$file == f)) {
    fx  <- fixes[k, ]
    pat <- sprintf('n="%s"', fx$from)
    stopifnot(str_count(txt, fixed(pat)) >= 1,
              str_count(txt, fixed(sprintf('n="%s"', fx$to))) == 0,
              str_trim(first_name(txt, fx$from)) == fx$deceased)
    txt <- sub(pat, sprintf('n="%s"', fx$to), txt, fixed = TRUE, useBytes = TRUE)
    Encoding(txt) <- "UTF-8"
  }
  write_bytes(txt, file.path(out, "xml", f))
  edited <- c(edited, f)
}

# ---- Remove the copy of volume 10 from volume 1 ----
# Volume 1's 87 documents are followed by all 114 documents of volume 10,
# identical to MOOC8_vol10.xml apart from whitespace. Cut from the first
# volume-10 div to the closing </body>.
v1  <- read_bytes(original("MOOC8_vol01.xml"))
v10 <- read_xml(original("MOOC8_vol10.xml"))
start <- regexpr('\t\t<div n="MOOC8/10.1">', v1, fixed = TRUE)
end   <- regexpr("\t</body>", v1, fixed = TRUE)
stopifnot(start > 0, end > start)
copy  <- read_xml(paste0("<text><body>", substr(v1, start, end - 1), "</body></text>"))
norm  <- function(d) map_chr(xml_find_all(d, "/text/body/div"),
                             ~ str_squish(as.character(.x, options = c("format", "no_declaration"))))
stopifnot(identical(gsub("\\s+", "", norm(copy)), gsub("\\s+", "", norm(v10))))
v1 <- paste0(substr(v1, 1, start - 1), substr(v1, end, nchar(v1)))
write_bytes(v1, file.path(out, "xml", "MOOC8_vol01.xml"))
edited <- c("MOOC8_vol01.xml", edited)

# ---- Checks on the whole published series ----
docs <- map_dfr(file.path(out, "xml", map$new_name), function(f) {
  divs <- xml_find_all(read_xml(f), "/text/body/div")
  tibble(file = basename(f), n = xml_attr(divs, "n"))
})
docs <- docs |> mutate(file_vol = as.integer(str_match(file, "vol([0-9]+)")[, 2]),
                       ref_vol  = as.integer(str_match(n, "^MOOC8/([0-9]+)")[, 2]))
stopifnot(!anyDuplicated(docs$n),
          sum(docs$file == "MOOC8_vol01.xml") == 87,
          all(docs$file_vol == docs$ref_vol))
cat("Probate:", nrow(docs), "documents, all references unique and in their own volume's file\n")

# ---- Log and file table ----
orig_md5 <- tibble(file = edited, original_md5 = unname(md5sum(map_chr(edited, original))))
log <- bind_rows(
  tibble(file = "MOOC8_vol01.xml", from = "all MOOC8/10.* documents", to = "",
         deceased = "", reason = "copy of volume 10 (114 documents) removed; identical to MOOC8_vol10.xml"),
  fixes) |>
  left_join(orig_md5, by = "file")
write_tsv(log, file.path(out, "corrections.txt"), na = "")

counts <- count(docs, file, name = "n_docs")
map <- map |> left_join(counts, by = c("new_name" = "file")) |>
  mutate(n_documents = as.character(n_docs),
         size_kb = as.character(round(file.size(file.path(out, "xml", new_name)) / 1024)),
         md5 = unname(md5sum(file.path(out, "xml", new_name)))) |>
  select(-n_docs)
write_tsv(map, file.path(out, "file_names.txt"), na = "")
cat("Edited", length(edited), "files:", paste(edited, collapse = ", "), "\n")
