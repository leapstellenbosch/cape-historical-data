# Opgaaf build for the Cape Historical Data Repository: source inventory and
# constants. Ported unchanged from LEAP's internal release pipeline
# (25 September 2026). The internal release label stays "v2"
# and relative_path keeps v2's workbook references, so that the build can be
# checked cell by cell against v2; workbooks are read from sources/raw/opgaaf/.

library(dplyr)
library(purrr)
library(readr)
library(readxl)
library(openxlsx)
library(stringr)
library(tibble)
library(tidyr)
library(here)

release_version <- "v2"
release_date <- as.Date("2026-09-25")
release_dir <- here("build", "opgaaf")
dir.create(release_dir, recursive = TRUE, showWarnings = FALSE)

sources_v2 <- tribble(
  ~source_key, ~district, ~relative_path,
  "cape_early", "Cape", "Data/1 Cape district/From transcribers/Early Cape District - Including Full Index for Hague & Cape Archives September 2024.xlsx",
  "cape_late", "Cape", "Data/1 Cape district/From transcribers/Completed Cape Opgaafrolle with Index - 1800 to 1825.xlsx",
  "stellenbosch_early", "Stellenbosch", "Data/2 Stellenbosch/From transcribers/Stellenbosch-Drakenstein Earlier Opgaafrolle - Hague & Cape Archives - including Full Indexes June 2022.xlsx",
  "stellenbosch_1764", "Stellenbosch", "Data/2 Stellenbosch/From transcribers/Stellenbosch 1764 to 1779 plus new index.xlsx",
  "stellenbosch_1780", "Stellenbosch", "Data/2 Stellenbosch/From transcribers/Stellenbosch 1780 to 1844.xlsx",
  "swellendam", "Swellendam", "Data/3 Swellendam/From transcribers/Completed Opgaafrolle Swellendam - 1751 to 1838.xlsx",
  "graaff_reinet", "Graaff-Reinet", "Data/4 Graaff-Reinet/From transcribers/Completed Graaff Reinet Opgaafrolle with Index -  1787 to 1828.xlsx",
  "tulbagh", "Tulbagh", "Data/5 Tulbagh/From transcribers/Completed Tulbagh Opgaafrolle with Index.xlsx",
  "uitenhage", "Uitenhage", "Data/6 Uitenhage/From transcribers/Uitenhage Opgaafrolle - 1805 to.xlsx",
  "albany", "Albany", "Data/7 Albany/Completed Albany Opgaafrolle with Index (new).xlsx",
  "worcester", "Worcester", "Data/8 Worcester/From transcribers/Completed Opgaafrolle Worcester - 1820 to 1840.xlsx",
  "george", "George", "Data/9 George/Completed George Opgaafrolle with Index.xlsx",
  "clanwilliam", "Clanwilliam", "Data/10 Clanwilliam/Clanwilliam Opgaafrolle with Index.xlsx"
) %>%
  mutate(path = map_chr(str_replace(relative_path, "^Data/", "sources/raw/opgaaf/"), here))

stopifnot(all(file.exists(sources_v2$path)))

person_stock_fields <- c(
  "settler_men", "settler_women", "settler_sons", "settler_daughters",
  "settler_children", "servants",
  "slave_men", "slave_women", "slave_sons", "slave_daughters", "slave_children",
  "khoe_men", "khoe_women", "khoe_sons", "khoe_daughters", "khoe_children",
  "freeblack_men", "freeblack_women", "freeblack_sons", "freeblack_daughters", "freeblack_children",
  "prizenegro_men", "prizenegro_women", "prizenegro_sons", "prizenegro_daughters", "prizenegro_children"
)

identity_fields <- c(
  "entry_number_raw", "folio_raw", "add_info", "sub_district", "field_cornet",
  "names_men", "names_women", "names_combined", "surname", "given_names",
  "servant_names", "farm_name", "source_page_info"
)

# Land information varies between counts, place descriptions and transcriber
# notes. Preserve it verbatim here rather than coercing heterogeneous content.
land_context_fields <- c(
  "land_owned_raw", "land_quitrent_raw", "land_loan_raw",
  "distance_owned_raw", "distance_quitrent_raw", "distance_loan_raw",
  "agricultural_use_owned_raw", "agricultural_use_quitrent_raw",
  "agricultural_use_loan_raw"
)

asset_fields <- c(
  "horses", "horse_work", "horse_breeding", "horse_foals", "horse_pleasure",
  "cattle", "cattle_bull", "cattle_breeding", "cattle_work", "cattle_cows",
  "cattle_heifers", "cattle_calves", "sheep", "sheep_breeding", "sheep_wool",
  "sheep_wether", "goats", "pigs", "donkeys", "wagons", "carts",
  "wheat_seed", "wheat_vol", "barley_seed", "barley_vol", "rye_seed", "rye_vol",
  "oat_seed", "oat_vol", "maize_vol", "vines", "wine", "brandy"
)

continuous_quantity_fields <- c(
  "wheat_seed", "wheat_vol", "barley_seed", "barley_vol",
  "rye_seed", "rye_vol", "oat_seed", "oat_vol", "maize_vol",
  "hay_vol", "vines", "wine", "brandy"
)

discrete_stock_fields <- unique(c(
  person_stock_fields,
  "horses", "horse_work", "horse_breeding", "horse_foals", "horse_pleasure",
  "cattle", "cattle_bull", "cattle_breeding", "cattle_work", "cattle_cows",
  "cattle_heifers", "cattle_calves", "sheep", "sheep_breeding", "sheep_wool",
  "sheep_wether", "goats", "pigs", "donkeys", "wagons", "carts"
))

flow_fields <- c(
  "persons_born", "persons_married", "persons_died", "settlers_born", "settlers_died",
  "slaves_born", "slaves_died", "khoe_born", "khoe_died",
  "freeblacks_born", "freeblacks_died", "prizenegro_born", "prizenegro_died"
)

tax_amount_fields <- c(
  "opgaaf_tax_rixdollars", "opgaaf_tax_skillings", "opgaaf_tax_stuivers",
  "wagon_contribution_rixdollars", "wagon_contribution_skillings", "wagon_contribution_stuivers",
  "church_contribution_rixdollars", "church_contribution_skillings", "church_contribution_stuivers"
)

aggregate_person_fields <- c(
  "white_men", "white_women", "coloured_men", "coloured_women",
  "workers_farm", "workers_factory", "workers_retail",
  "taxable_men", "taxable_women", "taxable_servants"
)

canonical_fields_v2 <- unique(c(identity_fields, land_context_fields, person_stock_fields, aggregate_person_fields, asset_fields, flow_fields, tax_amount_fields))

# Employment counts are kept distinct from the other population blocks.
# Their overlap is unknown; do not add them to recorded_person_count_sum.
service_stock_fields <- as.vector(outer(c("khoe_in_service", "slave_in_service"),
                                        c("men", "sons", "women", "daughters"), paste, sep = "_"))
prize_origin_fields <- c("prizenegro_sons_imported", "prizenegro_daughters_imported",
                         "prizenegro_sons_colony_born", "prizenegro_daughters_colony_born")
discrete_stock_fields <- unique(c(discrete_stock_fields, service_stock_fields, prize_origin_fields))
canonical_fields_v2 <- unique(c(canonical_fields_v2, service_stock_fields, prize_origin_fields))

# Complete named declarations lacking a transcriber number. No evidence of a
# subordinate relationship: do not automatically attach to the previous name.
independent_unnumbered_rows_v2 <- tribble(
  ~source_key, ~sheet, ~source_row, ~reason,
  "clanwilliam", "1809", 276L, "Distinct named man/spouse and full declaration after entry 252; number blank",
  "clanwilliam", "1811", 293L, "Distinct named man with own male and horse counts after entry 54; number blank",
  "clanwilliam", "1812", 268L, "Distinct named man/spouse, family, assets and farm between entries 29 and 30; number blank"
)

# Known sheet-level boundaries found in the audit. These are deliberately
# conservative: rows at and below the boundary remain traceable in the flags,
# but are not declarations in the clean entry file.
summary_boundaries_v2 <- tribble(
  ~source_key, ~sheet, ~summary_start_row, ~reason,
  "graaff_reinet", "1809", 1236L, "Cumulative/summary totals section; no declaration names",
  "tulbagh", "1807", 502L, "Field-cornetcy/regional summary totals section"
)

# Cell values that are almost certainly transcription mistakes but cannot be
# reconstructed without consulting the archival image. Parsed value is NA.
unresolved_cells_v2 <- tribble(
  ~source_key, ~sheet, ~source_row, ~source_column, ~canonical_field, ~raw_value, ~reason,
  "swellendam", "1824", 883L, "V8", "settler_daughters", "2005", "Implausible demographic value; archival image required to distinguish 2, 5, blank, or another reading",
  "cape_early", "1722", 140L, "V8", "settler_daughters", "250", "Implausible demographic value; archival image required",
  "cape_early", "1722", 140L, "V9", "servants", "400", "Implausible demographic value; archival image required",
  "stellenbosch_1780", "1835", 1252L, "V8", NA_character_, "302", "Implausible value in demographic block; exact field and value require archival image"
)

# Explicit mappings for forms whose semantics cannot safely be inferred from
# generic demographic vocabulary. These overrides are based on the transcribed
# headers and are confidence B until checked against archival images.
registry_overrides_v2 <- tribble(
  ~source_key, ~sheet, ~source_column, ~canonical_field, ~field_type, ~population_group, ~sex, ~measure_type, ~override_note,
  "stellenbosch_1780", "1839", "V1", "entry_number_raw", "character", NA, NA, "identifier", "Named-adult/servant form",
  "stellenbosch_1780", "1839", "V2", "add_info", "character", NA, NA, "identifier", "Named-adult/servant form",
  "stellenbosch_1780", "1839", "V3", "names_men", "character", "settler", "male", "named_person", "Named Christian men above 16",
  "stellenbosch_1780", "1839", "V4", "names_women", "character", "settler", "female", "named_person", "Named Christian women above 20",
  "stellenbosch_1780", "1839", "V5", "field_cornet", "character", NA, NA, "identifier", "District and field-cornetcy",
  "stellenbosch_1780", "1839", "V6", "farm_name", "character", NA, NA, "identifier", "Residence/farm",
  "stellenbosch_1780", "1839", "V7", "servant_coachman", "numeric", "servant", NA, "person_stock", "Coachman category",
  "stellenbosch_1780", "1839", "V8", "servant_personal", "numeric", "servant", NA, "person_stock", "Personal servant/boy category",
  "stellenbosch_1780", "1839", "V9", "servant_home", "numeric", "servant", NA, "person_stock", "House servant/boy category",
  "stellenbosch_1780", "1839", "V10", "servant_cook", "numeric", "servant", NA, "person_stock", "Cook category",
  "stellenbosch_1780", "1841", "V1", "entry_number_raw", "character", NA, NA, "identifier", "Aggregate houseful/production form",
  "stellenbosch_1780", "1841", "V2", "add_info", "character", NA, NA, "identifier", "Transcriber information",
  "stellenbosch_1780", "1841", "V3", "names_men", "character", "settler", NA, "named_person", "Property holder",
  "stellenbosch_1780", "1841", "V4", "names_women", "character", "settler", "female", "named_person", "Named Christian women above 20",
  "stellenbosch_1780", "1841", "V5", "field_cornet", "character", NA, NA, "identifier", "District and field-cornetcy",
  "stellenbosch_1780", "1841", "V6", "white_men", "numeric", "white", "male", "person_stock", "White houseful men, all ages as defined by form",
  "stellenbosch_1780", "1841", "V7", "white_women", "numeric", "white", "female", "person_stock", "White houseful women, all ages as defined by form",
  "stellenbosch_1780", "1841", "V8", "coloured_men", "numeric", "coloured", "male", "person_stock", "Coloured houseful men, all ages as defined by form",
  "stellenbosch_1780", "1841", "V9", "coloured_women", "numeric", "coloured", "female", "person_stock", "Coloured houseful women, all ages as defined by form",
  "stellenbosch_1780", "1841", "V10", "workers_farm", "numeric", NA, NA, "worker_stock", "Persons used in agriculture",
  "stellenbosch_1780", "1841", "V11", "workers_factory", "numeric", NA, NA, "worker_stock", "Persons used in factories",
  "stellenbosch_1780", "1841", "V12", "workers_retail", "numeric", NA, NA, "worker_stock", "Persons used in trade",
  "stellenbosch_1780", "1841", "V13", "persons_born", "numeric", NA, NA, "person_flow", "Born during reporting year",
  "stellenbosch_1780", "1841", "V14", "persons_died", "numeric", NA, NA, "person_flow", "Died during reporting year",
  "stellenbosch_1780", "1841", "V15", "persons_married", "numeric", NA, NA, "person_flow", "Married during reporting year"
)

# The 1842 and 1843 forms repeat the 1841 layout exactly.
registry_overrides_v2 <- bind_rows(
  registry_overrides_v2,
  registry_overrides_v2 %>% filter(sheet == "1841") %>% mutate(sheet = "1842"),
  registry_overrides_v2 %>% filter(sheet == "1841") %>% mutate(sheet = "1843"),
  tribble(
    ~source_key, ~sheet, ~source_column, ~canonical_field, ~field_type, ~population_group, ~sex, ~measure_type, ~override_note,
    "stellenbosch_1780", "1844", "V1", "entry_number_raw", "character", NA, NA, "identifier", "Aggregate houseful/production form",
    "stellenbosch_1780", "1844", "V2", "add_info", "character", NA, NA, "identifier", "Additional information",
    "stellenbosch_1780", "1844", "V3", "names_men", "character", "settler", NA, "named_person", "Property holder",
    "stellenbosch_1780", "1844", "V4", "field_cornet", "character", NA, NA, "identifier", "District and field-cornetcy",
    "stellenbosch_1780", "1844", "V5", "white_men", "numeric", "white", "male", "person_stock", "White houseful men",
    "stellenbosch_1780", "1844", "V6", "white_women", "numeric", "white", "female", "person_stock", "White houseful women",
    "stellenbosch_1780", "1844", "V7", "coloured_men", "numeric", "coloured", "male", "person_stock", "Coloured houseful men",
    "stellenbosch_1780", "1844", "V8", "coloured_women", "numeric", "coloured", "female", "person_stock", "Coloured houseful women",
    "stellenbosch_1780", "1844", "V9", "workers_farm", "numeric", NA, NA, "worker_stock", "Persons used in agriculture",
    "stellenbosch_1780", "1844", "V10", "workers_factory", "numeric", NA, NA, "worker_stock", "Persons used in factories",
    "stellenbosch_1780", "1844", "V11", "workers_retail", "numeric", NA, NA, "worker_stock", "Persons used in trade",
    "stellenbosch_1780", "1844", "V12", "persons_born", "numeric", NA, NA, "person_flow", "Born during reporting year",
    "stellenbosch_1780", "1844", "V13", "persons_died", "numeric", NA, NA, "person_flow", "Died during reporting year",
    "stellenbosch_1780", "1844", "V14", "persons_married", "numeric", NA, NA, "person_flow", "Married during reporting year"
  )
)

# George 1818-1822 repeats a detailed production and land layout. Generic
# header matching cannot distinguish paired columns such as horses by use or
# grain sown versus harvested, so state those semantics explicitly.
george_1818_1822_layout <- tribble(
  ~source_column, ~canonical_field, ~field_type, ~measure_type, ~override_note,
  "V2",  "source_page_info",               "character", "identifier",      "Transcriber image/page reference",
  "V19", "horse_work",                     "numeric",   "asset_stock",     "Wagon and riding horses",
  "V20", "horse_breeding",                 "numeric",   "asset_stock",     "Breeding horses",
  "V21", "cattle_work",                    "numeric",   "asset_stock",     "Working cattle",
  "V22", "cattle_breeding",                "numeric",   "asset_stock",     "Breeding cattle",
  "V23", "sheep_wether",                   "numeric",   "asset_stock",     "Wether sheep",
  "V24", "sheep_breeding",                 "numeric",   "asset_stock",     "Breeding sheep",
  "V25", "sheep_wool",                     "numeric",   "asset_stock",     "Wool sheep",
  "V26", "donkeys",                        "numeric",   "asset_stock",     "Donkeys",
  "V27", "goats",                          "numeric",   "asset_stock",     "Goats",
  "V28", "pigs",                           "numeric",   "asset_stock",     "Pigs",
  "V29", "wheat_seed",                     "numeric",   "production_flow", "Wheat sown",
  "V30", "barley_seed",                    "numeric",   "production_flow", "Barley sown",
  "V31", "rye_seed",                       "numeric",   "production_flow", "Rye sown",
  "V32", "oat_seed",                       "numeric",   "production_flow", "Oats sown",
  "V33", "wheat_vol",                      "numeric",   "production_flow", "Wheat harvested",
  "V34", "barley_vol",                     "numeric",   "production_flow", "Barley harvested",
  "V35", "rye_vol",                        "numeric",   "production_flow", "Rye harvested",
  "V36", "oat_vol",                        "numeric",   "production_flow", "Oats harvested",
  "V37", "vines",                          "numeric",   "production_flow", "Vines",
  "V38", "wine",                           "numeric",   "production_flow", "Wine produced",
  "V39", "brandy",                         "numeric",   "production_flow", "Brandy produced",
  "V40", "wagons",                         "numeric",   "asset_stock",     "Wagons",
  "V41", "carts",                          "numeric",   "asset_stock",     "Carts",
  "V42", "land_owned_raw",                 "character", "land_context",    "Land owned; preserved verbatim",
  "V43", "land_quitrent_raw",              "character", "land_context",    "Quitrent land; preserved verbatim",
  "V44", "land_loan_raw",                  "character", "land_context",    "Loan land; preserved verbatim",
  "V45", "farm_name",                      "character", "identifier",      "Farm or place name",
  "V46", "distance_owned_raw",             "character", "land_context",    "Distance for owned land; preserved verbatim",
  "V47", "distance_quitrent_raw",          "character", "land_context",    "Distance for quitrent land; preserved verbatim",
  "V48", "distance_loan_raw",              "character", "land_context",    "Distance for loan land; preserved verbatim",
  "V49", "agricultural_use_owned_raw",      "character", "land_context",    "Agricultural use of owned land; preserved verbatim",
  "V50", "agricultural_use_quitrent_raw",   "character", "land_context",    "Agricultural use of quitrent land; preserved verbatim",
  "V51", "agricultural_use_loan_raw",       "character", "land_context",    "Agricultural use of loan land; preserved verbatim"
)

george_1818_1822_overrides <- tidyr::crossing(
  source_key = "george",
  sheet = as.character(1818:1822),
  george_1818_1822_layout
) %>%
  mutate(population_group = NA_character_, sex = NA_character_) %>%
  select(source_key, sheet, source_column, canonical_field, field_type,
         population_group, sex, measure_type, override_note)

registry_overrides_v2 <- bind_rows(registry_overrides_v2, george_1818_1822_overrides)

# These otherwise nameless rows continue the immediately preceding George
# declaration. Their values are genuine demographic/livestock cells, not
# headings or totals. Keeping the exceptions explicit makes the decision fully
# auditable and prevents broad inference rules from absorbing section labels.
forced_continuation_rows_v2 <- tribble(
  ~source_key, ~sheet, ~source_row, ~reason,
  "george", "1818", 786L, "Khoe women/daughters continued from preceding declaration",
  "george", "1819", 797L, "Livestock continued from preceding declaration",
  "george", "1821", 1051L, "Livestock continued from preceding declaration"
)

# Cape 1821 calls the Khoe block only "In Dienst Hebbende". Its location and
# four-part age/sex structure are unambiguous on the form but not recoverable
# from generic word matching, so it is stated explicitly here.
registry_overrides_v2 <- bind_rows(
  registry_overrides_v2,
  tribble(
    ~source_key, ~sheet, ~source_column, ~canonical_field, ~field_type, ~population_group, ~sex, ~measure_type, ~override_note,
    "cape_late", "1821", "V2", "names_men", "character", "settler", "male", "named_person", "Combined head/inhabitant names column",
    "cape_late", "1821", "V3", "names_women", "character", "settler", "female", "named_person", "Named women column",
    "cape_late", "1821", "V4", "field_cornet", "character", NA, NA, "identifier", "Field-cornet column",
    "cape_late", "1821", "V5", "settler_men", "numeric", "settler", "male", "person_stock", "Free-family men",
    "cape_late", "1821", "V6", "settler_women", "numeric", "settler", "female", "person_stock", "Free-family women",
    "cape_late", "1821", "V7", "settler_sons", "numeric", "settler", "male", "person_stock", "Free-family sons",
    "cape_late", "1821", "V8", "settler_daughters", "numeric", "settler", "female", "person_stock", "Free-family daughters",
    "cape_late", "1821", "V9", "servants", "numeric", "servant", NA, "person_stock", "European servants",
    "cape_late", "1821", "V10", "khoe_men", "numeric", "khoe", "male", "person_stock", "In-service Khoe men above 16",
    "cape_late", "1821", "V11", "khoe_sons", "numeric", "khoe", "male", "person_stock", "In-service Khoe males below 16",
    "cape_late", "1821", "V12", "khoe_women", "numeric", "khoe", "female", "person_stock", "In-service Khoe women above 14",
    "cape_late", "1821", "V13", "khoe_daughters", "numeric", "khoe", "female", "person_stock", "In-service Khoe females below 14"
  )
)
