# Runaway advertisements, 1830-1842: one row per person named in a runaway
# advertisement in De Zuid Afrikaan or the Government Gazette. Source: Karl
# Bergemann's Harvard Dataverse deposit (doi:10.7910/DVN/R1IAFM, version 1,
# files dated 2025-04-17). Records only: the "assigned" columns (modern
# ethnicity, resemblance and Enslaved.org skill categories) and the derived
# days absconded are dropped.
# Run from the project root:
#   & 'C:/Program Files/R/R-4.5.2/bin/Rscript.exe' pipeline/runaways/01_runaways.R

here::i_am("PLAN.md")
library(tidyverse)
library(here)

src_dir <- here("sources", "raw", "runaways")
out_dir <- here("release", "data", "runaways")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_paper <- function(file, code) {
  read_csv(file.path(src_dir, file), col_types = cols(.default = "c"), locale = locale(encoding = "UTF-8"),
           name_repair = "minimal") %>%
    select(-which(names(.) == "")) %>%           # a trailing empty column
    filter(!if_all(everything(), is.na)) %>%     # the Gazette file ends in 154 empty rows
    mutate(paper = code)
}
raw <- bind_rows(read_paper("CCRA-ZA_Data_20250417.csv", "ZA"),
                 read_paper("CCRA-GG_Data_20250417.csv", "GG"))
stopifnot(sum(raw$paper == "ZA") == 551, sum(raw$paper == "GG") == 330,
          all(raw$EVENT == "Runaway Advertisement"),
          # NUMBER is Bergemann's reference within each newspaper (ZA1, GG114a), unique and
          # never empty, so it carries the identifier. The Gazette numbers have gaps (7-11 and
          # others were dropped from the deposit) and one inserted case, 114a.
          !anyDuplicated(paste(raw$paper, raw$NUMBER)), all(str_detect(raw$NUMBER, "^[0-9]+[a-z]?$")),
          # the publication date is given twice; the two agree
          identical(as.Date(raw$`FULL DATE`),
                    as.Date(paste(raw$YEAR, match(raw$MONTH, month.name), raw$DAY, sep = "-"))))

# In the source, 0 means "not stated" in every column
not_stated <- function(x) na_if(na_if(str_squish(x), "0"), "")
as_int <- function(x) { x <- not_stated(x); stopifnot(all(str_detect(na.omit(x), "^[0-9]+$"))); as.integer(x) }

runaways <- raw %>%
  transmute(
    chdr_id = paste0("RUN-", paper, "-", str_pad(NUMBER, 3, pad = "0")),
    newspaper = recode(paper, ZA = "De Zuid Afrikaan", GG = "Government Gazette"),
    publication_date = as.Date(`FULL DATE`),
    name = not_stated(`RUNAWAY NAME`),
    sex = not_stated(SEX),
    age = as_int(AGE),
    flight_year = as_int(`FLIGHT YEAR`),
    flight_month = match(not_stated(`FLIGHT MONTH`), month.name),
    time_absconded = not_stated(`TOTAL TIME ABSCONDED (TTA)`),
    ethnic_descriptor = not_stated(`ETHNIC DESCIPTOR`),
    presents_as = not_stated(`RESEMBLANCE/PRESENTS AS`),
    physical_description = not_stated(`PHYSICAL DESCRIPTORS`),
    other_description = not_stated(`NON-PHYSICAL DESCRIPTORS`),
    clothing = not_stated(CLOTHING),
    items_taken = not_stated(`OTHER ITEMS`),
    skill_occupation = not_stated(`SKILL/OCCUPATION`),
    intentions = not_stated(`INTENTION/SUPPOSITIONS`),
    sightings = not_stated(`ACTUAL SIGHTINGS`),
    location = not_stated(`LOCATION DETAIL`),
    advertiser = not_stated(`ENSLAVER/ADVERTISER`),
    reward = not_stated(`REWARD OFFERED`),
    full_text = not_stated(`FULL TEXT`))

stopifnot(
  # every non-empty flight month is an English month name
  sum(!is.na(runaways$flight_month)) == sum(!is.na(not_stated(raw$`FLIGHT MONTH`))),
  all(runaways$sex %in% c("M", "F", NA)),
  all(between(runaways$flight_year, 1800, 1842), na.rm = TRUE),
  all(between(year(runaways$publication_date), 1830, 1842)),
  !anyDuplicated(runaways$chdr_id))
message("Runaways: ", nrow(runaways), " people (", sum(runaways$newspaper == "De Zuid Afrikaan"), " ZA, ",
        sum(runaways$newspaper == "Government Gazette"), " GG); full text on ", sum(!is.na(runaways$full_text)))
message("Sex: ", paste(names(table(runaways$sex, useNA = "a")), table(runaways$sex, useNA = "a"), collapse = ", "))

redundant <- function(d) {
  cols <- names(d)
  pairs <- combn(cols, 2, simplify = FALSE)
  c(cols[map_lgl(d, ~all(is.na(.x)) || n_distinct(.x) == 1)],
    map_chr(keep(pairs, ~identical(d[[.x[1]]], d[[.x[2]]])), paste, collapse = "="))
}
stopifnot(length(redundant(runaways)) == 0)

write_csv(runaways, file.path(out_dir, "runaways_persons.csv"), na = "")
nanoparquet::write_parquet(runaways, file.path(out_dir, "runaways_persons.parquet"), compression = "zstd")

v <- function(variable, type, source_column, description)
  tibble(variable = variable, type = type, source_column = source_column, description = description)
variables <- bind_rows(
  v("chdr_id", "character", "NUMBER", "Repository identifier, never changed: RUN-, the newspaper (ZA or GG) and the reference number in Bergemann's dataset (RUN-ZA-001 is ZA1, RUN-GG-114a is GG114a)"),
  v("newspaper", "character", "SOURCE", "De Zuid Afrikaan or the (Cape of Good Hope) Government Gazette"),
  v("publication_date", "date", "FULL DATE", "Date the advertisement was published"),
  v("name", "character", "RUNAWAY NAME", "Name of the person who fled, as printed"),
  v("sex", "character", "SEX", "M or F, as recorded"),
  v("age", "integer", "AGE", "Age in years as stated in the advertisement"),
  v("flight_year", "integer", "FLIGHT YEAR", "Year of flight, where the advertisement states or implies it"),
  v("flight_month", "integer", "FLIGHT MONTH", "Month of flight (1-12)"),
  v("time_absconded", "character", "TOTAL TIME ABSCONDED (TTA)", "Time between flight and advertisement, as transcribed (y years, m months, w weeks, d days)"),
  v("ethnic_descriptor", "character", "ETHNIC DESCIPTOR", "Origin or ethnic description as printed, e.g. Mozambique, Cape, Prize Negro"),
  v("presents_as", "character", "RESEMBLANCE/PRESENTS AS", "Identity the person was said to pass as or resemble"),
  v("physical_description", "character", "PHYSICAL DESCRIPTORS", "Physical description"),
  v("other_description", "character", "NON-PHYSICAL DESCRIPTORS", "Other traits or demeanour"),
  v("clothing", "character", "CLOTHING", "Clothing worn or taken"),
  v("items_taken", "character", "OTHER ITEMS", "Other items taken"),
  v("skill_occupation", "character", "SKILL/OCCUPATION", "Skills, occupation and languages as printed"),
  v("intentions", "character", "INTENTION/SUPPOSITIONS", "The advertiser's supposition about where the person went or what they intended"),
  v("sightings", "character", "ACTUAL SIGHTINGS", "Sightings after flight"),
  v("location", "character", "LOCATION DETAIL", "Location given in the advertisement, usually the advertiser's home or farm"),
  v("advertiser", "character", "ENSLAVER/ADVERTISER", "Enslaver or person who placed the advertisement, as transcribed (surname, initials)"),
  v("reward", "character", "REWARD OFFERED", "Reward as printed (Rd/Rds = rixdollars; pound sterling); editorial notes in brackets"),
  v("full_text", "character", "FULL TEXT", "Transcription of the advertisement, with some shorthand; given once, on the first person, where one advertisement names several people"))
stopifnot(identical(variables$variable, names(runaways)))
write_csv(variables, file.path(out_dir, "runaways_variables.csv"), na = "")
