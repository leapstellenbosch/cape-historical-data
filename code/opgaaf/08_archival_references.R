# Archival reference of every opgaaf district-year: the volume in the Western
# Cape Archives and Records Service (WCARS, series J, "opgaafrollen") or, for
# the early returns, the inventory number in the archive of the Dutch East India
# Company at the Nationaal Archief, The Hague (VOC, 1.04.02). The references are
# those recorded by the transcribers in the index sheets of their workbooks (and,
# for returns read from the Hague scans, the scan's address on the worksheet).
# Writes release/data/opgaaf/opgaaf_archival_references.csv.
# Run from the project root, after run_opgaaf.R:
#   & 'C:/Program Files/R/R-4.5.2/bin/Rscript.exe' pipeline/opgaaf/08_archival_references.R

here::i_am("PLAN.md")
library(tidyverse)
library(here)

raw_dir <- here("sources", "raw", "opgaaf")
out_dir <- here("release", "data", "opgaaf")
sheets <- read_csv(file.path(out_dir, "opgaaf_sheet_inventory.csv"), show_col_types = FALSE) %>%
  select(district, year, source_workbook, source_sheet)
workbook_path <- function(wb) {
  p <- list.files(raw_dir, recursive = TRUE, full.names = TRUE)
  p <- p[basename(p) == wb]
  stopifnot(length(p) >= 1)
  p[1]
}

# District names used in the transcribers' indexes
district_of <- function(x) case_when(
  str_detect(x, regex("kaap|^cape", ignore_case = TRUE)) ~ "Cape",
  str_detect(x, regex("stellenbosch|drakenstein", ignore_case = TRUE)) ~ "Stellenbosch",
  str_detect(x, regex("graaff", ignore_case = TRUE)) ~ "Graaff-Reinet",
  TRUE ~ str_squish(x))

# Every index sheet: district, year, the archive's reference, the Hague link, comments
read_index <- function(path) {
  map_dfr(str_subset(readxl::excel_sheets(path), regex("index|indeks", ignore_case = TRUE)), function(s) {
    d <- readxl::read_excel(path, s, col_names = FALSE, col_types = "text", .name_repair = "minimal")
    hr <- which(apply(d, 1, function(r) any(str_detect(r, regex("^\\s*year\\s*$", ignore_case = TRUE)), na.rm = TRUE)))[1]
    h <- str_squish(as.character(unlist(d[hr, ])))
    col <- function(pattern) { i <- which(str_detect(h, regex(pattern, ignore_case = TRUE)))[1]; if (is.na(i)) rep(NA_character_, nrow(d) - hr) else d[[i]][-(1:hr)] }
    tibble(index_sheet = s,
           district = col("^district"), year = suppressWarnings(as.integer(col("^year$"))),
           reference = col("^(ref|reference|ref\\.|archival source)$"), link = col("^link$"),
           comment = col("^comments?$")) %>%
      fill(district) %>%
      filter(!is.na(year)) %>%
      mutate(district = district_of(district), hague = str_detect(index_sheet, regex("hague", ignore_case = TRUE)))
  })
}

# A Hague reference: the scan address (.../1.04.02/invnr/4110/file/...) or the
# transcribers' short form for the muster rolls ("F4115", inventory number 4115)
hague_invnr <- function(x) coalesce(str_match(x, "1\\.04\\.02/invnr/([0-9]+)")[, 2], str_match(x, "^\\s*F([0-9]{4})\\s*$")[, 2])
sheet_hague_link <- function(path, sheet) {
  d <- readxl::read_excel(path, sheet, col_names = FALSE, col_types = "text", .name_repair = "minimal")
  inv <- unique(na.omit(str_match(na.omit(unlist(d)), "1\\.04\\.02/invnr/([0-9]+)")[, 2]))
  if (length(inv)) paste(inv, collapse = "; ") else NA_character_
}

wbs <- unique(sheets$source_workbook)
index <- map_dfr(wbs, ~read_index(workbook_path(.x)) %>% mutate(source_workbook = .x))

# Normalise a WCARS reference as written (J089, J394/J395 (2), J1 & J2, J/183)
norm_j <- function(x) {
  j <- str_extract_all(coalesce(x, ""), "J\\s*/?\\s*[0-9]+")
  map_chr(j, ~if (length(.x)) paste(paste("J", as.integer(str_extract(.x, "[0-9]+"))), collapse = "; ") else NA_character_)
}

refs <- sheets %>%
  left_join(index %>% filter(!hague) %>% select(source_workbook, district, year, reference, comment),
            by = c("source_workbook", "district", "year"), multiple = "first") %>%
  left_join(index %>% filter(hague) %>% select(source_workbook, district, year, link, hague_comment = comment),
            by = c("source_workbook", "district", "year"), multiple = "first") %>%
  mutate(wcars = norm_j(reference),
         voc = hague_invnr(link),
         # returns marked "See Link", or with no index entry: the scan address on the worksheet
         voc = if_else(is.na(voc) & is.na(wcars),
                       map2_chr(source_workbook, source_sheet, ~sheet_hague_link(workbook_path(.x), .y)), voc),
         muster = str_detect(coalesce(comment, hague_comment, ""), regex("muster roll", ignore_case = TRUE)))

opgaaf_archival_references <- refs %>%
  transmute(district, year = as.integer(year),
            archive = case_when(!is.na(wcars) ~ "Western Cape Archives and Records Service",
                                !is.na(voc) ~ "Nationaal Archief, The Hague",
                                TRUE ~ NA_character_),
            reference = case_when(!is.na(wcars) ~ wcars,
                                  !is.na(voc) ~ paste0("VOC 1.04.02, inv. ", voc),
                                  TRUE ~ NA_character_),
            note = case_when(
              # checked against the WCARS inventory of series J (inventory 1/5, Potgieter and Visagie 1974)
              district == "George" & year == 1826 ~ "as in the transcribers' index; the WCARS inventory gives J 107 as Graaff-Reinet 1787, so the George volume is uncertain",
              reference == "J 183" ~ "J 183 holds copies made in 1882 (Theal), not the original returns",
              district == "Cape" & year == 1800 ~ "J 38 holds entries 1-586; J 37 holds entries 587-658",
              district == "Swellendam" & year == 1752 ~ "dated c.1752 in the WCARS inventory",
              muster & !is.na(wcars) ~ "transcribed from scans of the original",
              muster ~ "from the copies sent to the Netherlands (muster rolls)",
              TRUE ~ NA_character_)) %>%
  arrange(district, year)

stopifnot(nrow(opgaaf_archival_references) == nrow(sheets), !anyNA(opgaaf_archival_references$reference),
          !anyDuplicated(opgaaf_archival_references[c("district", "year")]))
message("District-years: ", nrow(opgaaf_archival_references),
        "; WCARS: ", sum(str_starts(opgaaf_archival_references$archive, "Western")),
        "; Nationaal Archief: ", sum(str_starts(opgaaf_archival_references$archive, "Nationaal")))
write_csv(opgaaf_archival_references, file.path(out_dir, "opgaaf_archival_references.csv"), na = "")
