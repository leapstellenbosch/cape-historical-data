# Load the Cape Historical Data Repository in R.
# Run from the repository folder. Needs readr, dplyr, stringr and xml2;
# nanoparquet (or arrow) for the faster Parquet files.
library(readr)
library(dplyr)
library(stringr)
library(xml2)

# Always read the CSV files with guess_max = Inf (or use the Parquet files):
# readr otherwise guesses column types from the first 1,000 rows, and values
# such as the claim number "508a" or variables that appear only in later
# forms are read as missing.

# Sum that stays NA when every value is missing (blank is missing, not zero)
sum_na <- function(x) if (all(is.na(x))) NA else sum(x, na.rm = TRUE)

# ---- Opgaaf tax censuses ----
units <- read_csv("data/opgaaf/opgaaf_tax_units.csv", guess_max = Inf)
# or, faster and with column types kept:
# units <- nanoparquet::read_parquet("data/opgaaf/opgaaf_tax_units.parquet")
sheets <- read_csv("data/opgaaf/opgaaf_sheet_inventory.csv", guess_max = Inf)

# Form type is a property of the sheet (one per district and year)
units <- left_join(units, select(sheets, district, year, form_type), by = c("district", "year"))

# Enslaved adults declared in Stellenbosch, by year
units |>
  filter(district == "Stellenbosch", form_type == "opgaaf_declaration_return") |>
  group_by(year) |>
  summarise(tax_units = n(),
            slave_men = sum_na(slave_men),
            slave_women = sum_na(slave_women))

# The lines of multi-line declarations
entries <- read_csv("data/opgaaf/opgaaf_entries.csv", guess_max = Inf)

# ---- Slave emancipation ----
ema <- read_csv("data/emancipation/emancipation_persons.csv", guess_max = Inf)
# Compensation is an award per claim, never summed over people. The distinct
# amounts of each claim; 26 claims have more than one (several owners, or
# slightly different entries): inspect them before adding up
claims <- ema |>
  filter(!is.na(claim_compensation), !is.na(lbs_claim_number)) |>
  distinct(lbs_claim_number, claim_compensation) |>
  add_count(lbs_claim_number, name = "n_amounts")
filter(claims, n_amounts > 1)

# ---- SAF genealogies ----
persons <- read_csv("data/saf/saf_persons.csv", guess_max = Inf)
marriages <- read_csv("data/saf/saf_marriages.csv", guess_max = Inf)
# Each person's parents' marriage. A few codes are shared by two people
# (see id_flag), so a code can match more than one marriage.
persons |>
  left_join(select(marriages, spouse_code, parents_marriage_year = marriage_year),
            by = c("mother_spouse_code" = "spouse_code"), relationship = "many-to-many")

# ---- Probate inventories and auction rolls (XML) ----
# One row per document: reference, date and deceased
read_documents <- function(file) {
  divs <- xml_find_all(read_xml(file), "/text/body/div")
  tibble(file = basename(file),
         reference = xml_attr(divs, "n"),
         date = xml_attr(xml_find_first(divs, "./head/date"), "value"),
         deceased = xml_attr(xml_find_first(divs, "./head/name"), "reg"))
}
probate <- bind_rows(lapply(list.files("data/probate/xml", full.names = TRUE), read_documents))

# The lots of one auction: item, buyer and price are the cells of each row
roll <- read_xml("data/auctions/xml/MOOC10_vol25.xml")
sale <- xml_find_first(roll, "/text/body/div[@n='MOOC10/25.2']")
lots <- lapply(xml_find_all(sale, ".//table/row"), function(r) xml_text(xml_find_all(r, "./cell")))
head(lots)

# ---- Runaway advertisements (licence CC BY-NC-SA 4.0) ----
runaways <- read_csv("data/runaways/runaways_persons.csv", guess_max = Inf)
count(runaways, newspaper, year = as.integer(format(publication_date, "%Y")))

# ---- Auction prices: join the yearly prices to the goods ----
goods <- read_csv("data/prices/prices_goods.csv")
prices <- read_csv("data/prices/prices_annual.csv") |> left_join(goods, by = "good")
filter(prices, good == "slaves") |> select(year, median_price, mean_price) |> tail()
# The goods counted at each auction join to the auction rolls on mooc_id
sold <- read_csv("data/prices/prices_auction_goods.csv")

# ---- 1779 petition ----
petition <- read_csv("data/petition1779/petition1779_signatories.csv")
count(petition, rank, sort = TRUE)

# ---- Voortrekkers ----
trekkers <- read_csv("data/voortrekkers/voortrekkers_persons.csv", col_types = cols(.default = "c"))
trek_marriages <- read_csv("data/voortrekkers/voortrekkers_marriages.csv", col_types = cols(.default = "c"))
# Dates are ISO text where they could be read, otherwise as transcribed:
# take the year where the date starts with one
trekkers |> mutate(birth_year = as.integer(str_extract(birth_date, "^1[6-9][0-9]{2}"))) |>
  count(trek_destination, sort = TRUE) |> head()

# ---- Almanac directories ----
almanacs <- read_csv("data/almanacs/almanacs_entries.csv", guess_max = Inf)
count(almanacs, publication, year)
