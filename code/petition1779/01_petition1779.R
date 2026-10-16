# The 1779 Cape Patriots petition: one row per signatory, in the order they
# signed, from the transcription used by Schoots and Fourie ("Protest from
# Above"), sheet 2 of 404_signatories.xlsx. Records only: the census-match
# flag and census index in sheet 3 are record linkage and are not published.
# Run from the project root:
#   & 'C:/Program Files/R/R-4.5.2/bin/Rscript.exe' pipeline/petition1779/01_petition1779.R

here::i_am("PLAN.md")
library(tidyverse)
library(here)

src <- here("sources", "raw", "petition1779", "404_signatories.xlsx")
out_dir <- here("release", "data", "petition1779")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

raw <- readxl::read_excel(src, "Sheet2", col_types = "text")
stopifnot(nrow(raw) == 404, identical(names(raw), c("All details", "Name", "Further Description", "Rank", "Notes")),
          !anyNA(raw$`All details`), !anyNA(raw$Rank))

# "All details" is the signature line as transcribed; Name, Further Description,
# Rank and Notes split it. Two rows lost the name in the split; it is taken back
# from the full line. Two others are left as they are: "Jacobus R" and "Johannes
# Nieuw", rank "oud Burger", read "Jacobus Roud Burger" and "Johannes Nieuwoud
# Burger" in the full line, so the surname may be Nieuwoud(t) and the rank Burger.
p <- raw %>%
  mutate(across(everything(), str_squish),
         rest = str_squish(str_remove(`All details`, paste0(" ", fixed(Rank), "( ", coalesce(Notes, ""), ")?$"))),
         full_name = str_squish(if_else(is.na(`Further Description`), rest,
                                        str_remove(rest, paste0(" ", `Further Description`, "$")))))
repaired <- p %>% filter(is.na(Name))
message("Names restored from the full line: ", paste0(coalesce(repaired$Name, "(empty)"), " -> ", repaired$full_name, collapse = "; "))
stopifnot(nrow(repaired) == 2)

petition <- p %>%
  mutate(name = coalesce(Name, full_name)) %>%
  transmute(chdr_id = sprintf("PET-%03d", row_number()),
            name, name_suffix = `Further Description`, rank = Rank, note = Notes)
stopifnot(!anyNA(petition$name), !anyDuplicated(petition$chdr_id))

redundant <- function(d) {
  cols <- names(d)
  pairs <- combn(cols, 2, simplify = FALSE)
  c(cols[map_lgl(d, ~all(is.na(.x)) || n_distinct(.x) == 1)],
    map_chr(keep(pairs, ~identical(d[[.x[1]]], d[[.x[2]]])), paste, collapse = "="))
}
stopifnot(length(redundant(petition)) == 0)

write_csv(petition, file.path(out_dir, "petition1779_signatories.csv"), na = "")
nanoparquet::write_parquet(petition, file.path(out_dir, "petition1779_signatories.parquet"), compression = "zstd")
message("Signatories: ", nrow(petition))

v <- function(variable, type, source_column, description)
  tibble(variable = variable, type = type, source_column = source_column, description = description)
variables <- bind_rows(
  v("chdr_id", "character", "", "Repository identifier, never changed: PET- and the signatory's position on the petition (PET-001 signed first)"),
  v("name", "character", "Name", "Name as signed"),
  v("name_suffix", "character", "Further Description", "Patronymic or distinguishing suffix written after the name (Jansz, de Jonge, de Oude)"),
  v("rank", "character", "Rank", "Rank or office given after the name: Burger, Heemraad, Burgerraad, militia and church offices; oud = former"),
  v("note", "character", "Notes", "Transcriber's note, e.g. signed with x"))
stopifnot(identical(variables$variable, names(petition)))
write_csv(variables, file.path(out_dir, "petition1779_variables.csv"), na = "")
