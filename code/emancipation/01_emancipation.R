# Slave emancipation records: one row per enslaved person in the 1834
# registers and compensation claims. Records only: the research coding in the
# workbook (name categories, HISCO, origin regions, owner origin dummies,
# logs and squares) is dropped. See docs/schemas.md, section 3.
# Run from the project root:
#   & 'C:/Program Files/R/R-4.5.2/bin/Rscript.exe' pipeline/emancipation/01_emancipation.R

here::i_am("PLAN.md")
library(tidyverse)
library(here)

src <- here("sources", "raw", "emancipation", "Slave Emancipation Dataset.xlsx")
out_dir <- here("release", "data", "emancipation")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

raw <- readxl::read_excel(src, sheet = "Sheet1", guess_max = Inf)
stopifnot(nrow(raw) == 36417,
          # ages and owner indicators are whole numbers, so as.integer loses nothing
          all(raw$Age == round(raw$Age), na.rm = TRUE),
          all(c(raw$Owner_minor, raw$Owner_deceased) %in% c(0, 1, NA)))

ema <- raw %>%
  # EMA-00001 is the first data row (spreadsheet row 2), so no separate row column
  mutate(chdr_id = sprintf("EMA-%05d", row_number())) %>%
  transmute(
    chdr_id,
    name = Name,
    age = if_else(Age < 0, NA_real_, Age),  # one age of -1 (row 27602)
    sex = Gender,
    occupation = Occupation,
    origin = Origin_exact,
    lbs_claim_number = UCL,
    owner_surname = Owner_surname,
    owner_given_names = Owner_name,
    owner_note = Owner_note,
    owner_minor = as.integer(Owner_minor),
    owner_deceased = as.integer(Owner_deceased),
    place_a = Place_a,
    place_b = Place_b,
    valuation = Valuation,
    claim_compensation = Compensation,
    district = District_name,
    comments = Comments) %>%
  mutate(across(where(is.character), str_squish),
         across(where(is.character), ~na_if(.x, "")),
         # 76 occupations read "NA" (not available); R and pandas would read
         # the text as missing anyway, so it is published as missing
         occupation = na_if(occupation, "NA"),
         # money to the 15 significant digits Excel shows: some cells hold
         # binary noise from formulas (42.449999999999996 for 42.45)
         across(c(valuation, claim_compensation), ~signif(.x, 15)),
         age = as.integer(age),
         lbs_claim_number = str_remove_all(lbs_claim_number, " "))  # "508 a" -> "508a"

# Checks
stopifnot(!anyDuplicated(ema$chdr_id),
          all(ema$sex %in% c("F", "M", NA)),
          all(ema$owner_minor %in% 0:1), all(ema$owner_deceased %in% 0:1),
          all(ema$age >= 0, na.rm = TRUE),
          all(ema$valuation >= 0, na.rm = TRUE), all(ema$claim_compensation >= 0, na.rm = TRUE),
          # no value is so high that it must be in rixdollars rather than pounds
          max(ema$valuation, na.rm = TRUE) < 300)
whitespace_changes <- sum(map2_int(select(raw, Name, Occupation, Origin_exact, UCL, Owner_surname, Owner_name,
                                          Owner_note, Place_a, Place_b, District_name, Comments),
                                   select(ema, name, occupation, origin, lbs_claim_number, owner_surname,
                                          owner_given_names, owner_note, place_a, place_b, district, comments),
                                   ~sum(.x != .y, na.rm = TRUE)))
message("Cells changed by whitespace trimming: ", whitespace_changes)
message("Claim numbers that are not plain digits: ",
        paste(unique(na.omit(ema$lbs_claim_number[!str_detect(ema$lbs_claim_number, "^[0-9]+$")])), collapse = ", "))

# Compensation is the award for a whole claim, entered on one row of it
claims <- ema %>% filter(!is.na(lbs_claim_number)) %>%
  group_by(lbs_claim_number) %>%
  summarise(n = n(), n_comp = sum(!is.na(claim_compensation)), .groups = "drop")
message("Claims: ", nrow(claims), "; with compensation on exactly one row: ", sum(claims$n_comp == 1),
        "; on more than one row: ", sum(claims$n_comp > 1), "; none: ", sum(claims$n_comp == 0))

write_csv(ema, file.path(out_dir, "emancipation_persons.csv"), na = "")
nanoparquet::write_parquet(ema, file.path(out_dir, "emancipation_persons.parquet"), compression = "zstd")

variables <- tribble(
  ~variable, ~type, ~source_column, ~description,
  "chdr_id", "character", "", "Repository identifier, never changed: EMA- and the record's position in the workbook (EMA-00001 is spreadsheet row 2)",
  "name", "character", "Name", "Name of the enslaved person, as recorded",
  "age", "integer", "Age", "Age in years, as recorded; one impossible value (-1) set to NA",
  "sex", "character", "Gender", "F or M; NA where not recorded",
  "occupation", "character", "Occupation", "Occupation as recorded; 'Not Specified' where the source gives none; NA where the workbook reads 'NA' (76 records)",
  "origin", "character", "Origin_exact", "Place of origin as recorded (Cape = born in the colony); NA where not recorded",
  "lbs_claim_number", "character", "UCL", "Compensation claim number, as used by the Legacies of British Slavery database (UCL); links people in one claim",
  "owner_surname", "character", "Owner_surname", "Surname of the slaveholder",
  "owner_given_names", "character", "Owner_name", "Given names of the slaveholder",
  "owner_note", "character", "Owner_note", "Qualifier recorded with the owner's name (e.g. sr, jr, oorlede, Weduwee, 'sv' = son of)",
  "owner_minor", "integer", "Owner_minor", "1 if the owner is recorded as a minor",
  "owner_deceased", "integer", "Owner_deceased", "1 if the owner is recorded as deceased (the estate held the person)",
  "place_a", "character", "Place_a", "Place of residence (farm or town), as recorded",
  "place_b", "character", "Place_b", "Wider locality, as recorded",
  "valuation", "numeric", "Valuation", "Appraised value of the person, as recorded; pounds sterling, though some may be rixdollars; not converted",
  "claim_compensation", "numeric", "Compensation", "Compensation awarded for the claim (not the person), usually entered on one row of the claim, sometimes once per owner; 26 claims have more than one amount (see README); do not sum across people. Pounds sterling with shillings and pence as decimal fractions, as recorded",
  "district", "character", "District_name", "District of registration (11 districts)",
  "comments", "character", "Comments", "Notes in the workbook, including payment notes and source references such as BPP=5")
stopifnot(identical(variables$variable, names(ema)))
write_csv(variables, file.path(out_dir, "emancipation_variables.csv"), na = "")

message("Emancipation: ", nrow(ema), " records written to release/data/emancipation/")
