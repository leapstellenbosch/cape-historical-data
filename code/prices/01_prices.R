# Auction prices, 1718-1813: the goods, yearly unit prices and goods counted
# per auction behind Walters, Schoots and Fourie (2026, Cliometrica), from the
# authors' workbook SW_priceindex_Jan2026.xlsx. The workbook was built from the
# MOOC10 auction rolls; this is the one derived collection in the repository.
# Published: the 30-good classification, median and mean unit prices per good
# and year, and the number of each good sold at each auction. Not published:
# interpolated prices, weights, indices, and series copied from other studies.
# Run from the project root:
#   & 'C:/Program Files/R/R-4.5.2/bin/Rscript.exe' pipeline/prices/01_prices.R

here::i_am("PLAN.md")
library(tidyverse)
library(here)
library(xml2)

src <- here("sources", "raw", "prices", "SW_priceindex_Jan2026.xlsx")
out_dir <- here("release", "data", "prices")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
sheet <- function(s, ...) readxl::read_excel(src, s, col_types = "text", .name_repair = "minimal", ...)

# The workbook stores prices as single-precision floats (58.189998626708984);
# seven significant digits recover the values typed or computed
num <- function(x) signif(as.numeric(x), 7)

# ---------------------------------------------------------------------------
# 1. Goods: the classification and the Dutch terms searched for
# ---------------------------------------------------------------------------
cls <- sheet("goods_included_class")[1:30, c(1:3, 5)]
names(cls) <- c("good", "asset", "class", "dutch_terms")
goods <- cls %>%
  mutate(good = recode(good, jewelry = "jewellery"),   # spelled jewellery in the price sheets
         across(everything(), str_squish))
good_order <- names(sheet("median_prices", n_max = 0))[-1]
stopifnot(nrow(goods) == 30, setequal(goods$good, good_order), !anyNA(goods),
          all(goods$asset %in% c("productive", "household")),
          all(goods$class %in% c("equipment", "labour", "livestock", "luxury", "major", "minor")))
# Order as in the price sheets: productive goods by class, then household goods
goods <- goods %>% slice(match(good_order, good))

# ---------------------------------------------------------------------------
# 2. Yearly unit prices: median and mean, in rixdollars
# ---------------------------------------------------------------------------
long_prices <- function(s, value) {
  d <- sheet(s)
  stopifnot(identical(names(d), c("year", good_order)))
  d %>% filter(!is.na(year)) %>% pivot_longer(-year, names_to = "good", values_to = value) %>%
    mutate(year = as.integer(year), "{value}" := num(.data[[value]]))
}
prices_annual <- full_join(long_prices("median_prices", "median_price"),
                           long_prices("avg_prices", "mean_price"), by = c("year", "good")) %>%
  filter(!is.na(median_price) | !is.na(mean_price)) %>%   # good-years with no priced lot
  arrange(year, match(good, good_order))
stopifnot(all(between(prices_annual$year, 1718, 1813)),
          # a median and a mean exist together or not at all
          identical(is.na(prices_annual$median_price), is.na(prices_annual$mean_price)),
          all(prices_annual$median_price > 0), all(prices_annual$mean_price > 0),
          !anyDuplicated(prices_annual[c("year", "good")]))

# ---------------------------------------------------------------------------
# 3. Goods counted at each auction
# ---------------------------------------------------------------------------
cnt <- sheet("count")[, 1:32]            # columns 36-66 are a block of decade weights
stopifnot(identical(names(cnt), c("mooc_id", "year", good_order)))
cnt <- cnt %>% filter(str_detect(mooc_id, "^MOOC10/"))   # drops the summary rows at the foot
stopifnot(nrow(cnt) == 1515)
# The workbook writes half-numbered auctions as MOOC10/2.6_1/2 and the unnumbered
# ones as MOOC10/10.[not_numbered]; the XML has MOOC10/2.6 1/2 and
# MOOC10/10.[not numbered]. Use the XML's form so the two join.
cnt <- cnt %>% mutate(mooc_id = mooc_id %>% str_replace("_1/2$", " 1/2") %>%
                        str_replace(fixed("[not_numbered]"), "[not numbered]"))
# MOOC10/10.[not numbered] is shared by three auctions in the rolls; the two in the
# workbook are dated 1770 and 1771, so (mooc_id, year) identifies every auction
stopifnot(!anyDuplicated(cnt[c("mooc_id", "year")]))

prices_auction_goods <- cnt %>%
  pivot_longer(all_of(good_order), names_to = "good", values_to = "quantity") %>%
  mutate(year = as.integer(year), quantity = num(quantity)) %>%
  filter(quantity != 0) %>%
  arrange(match(paste(mooc_id, year), paste(cnt$mooc_id, cnt$year)), match(good, good_order))
stopifnot(!anyNA(prices_auction_goods), all(prices_auction_goods$quantity > 0),
          !anyDuplicated(prices_auction_goods[c("mooc_id", "year", "good")]))
# Quantities are whole numbers of units
stopifnot(all(prices_auction_goods$quantity == round(prices_auction_goods$quantity)))
prices_auction_goods <- mutate(prices_auction_goods, quantity = as.integer(quantity))

# Each auction should be a document in the published MOOC10 XML, dated in the same year
xml_year <- list.files(here("release", "data", "auctions", "xml"), full.names = TRUE) %>%
  map_dfr(~{ divs <- xml_find_all(read_xml(.x), "/text/body/div")
    tibble(mooc_id = xml_attr(divs, "n"),
           # a few documents are undated or carry a partial date; their year is NA
           xml_year = suppressWarnings(as.integer(str_sub(map_chr(divs, ~xml_attr(xml_find_first(.x, "./head/date"), "value")), 1, 4)))) })
ids <- distinct(cnt, mooc_id, year) %>% mutate(year = as.integer(year))
unmatched <- filter(ids, !mooc_id %in% xml_year$mooc_id)
year_ok <- semi_join(ids, xml_year, by = c("mooc_id", "year" = "xml_year"))
message("Auctions: ", nrow(ids), " (", n_distinct(prices_auction_goods$mooc_id, prices_auction_goods$year),
        " with at least one good); not in the MOOC10 XML: ", nrow(unmatched),
        "; in the XML but dated another year there: ", nrow(ids) - nrow(unmatched) - nrow(year_ok))
stopifnot(nrow(unmatched) == 0)
anti_join(ids, year_ok, by = c("mooc_id", "year")) %>% left_join(xml_year, by = "mooc_id") %>%
  write_csv(here("build", "prices_year_differs_from_xml.csv"), na = "")

# ---------------------------------------------------------------------------
# 4. Checks and output
# ---------------------------------------------------------------------------
redundant <- function(d) {
  cols <- names(d)
  pairs <- combn(cols, 2, simplify = FALSE)
  c(cols[map_lgl(d, ~all(is.na(.x)) || n_distinct(.x) == 1)],
    map_chr(keep(pairs, ~identical(d[[.x[1]]], d[[.x[2]]])), paste, collapse = "="))
}
stopifnot(length(redundant(goods)) == 0, length(redundant(prices_annual)) == 0,
          length(redundant(prices_auction_goods)) == 0)

write_tables <- function(d, name) {
  write_csv(d, file.path(out_dir, paste0(name, ".csv")), na = "")
  nanoparquet::write_parquet(d, file.path(out_dir, paste0(name, ".parquet")), compression = "zstd")
  message(name, ": ", nrow(d), " rows x ", ncol(d), " columns")
}
unlink(list.files(out_dir, pattern = "^prices_.*[.](csv|parquet)$", full.names = TRUE))
write_tables(goods, "prices_goods")
write_tables(prices_annual, "prices_annual")
write_tables(prices_auction_goods, "prices_auction_goods")

v <- function(table, variable, type, source_column, description)
  tibble(table = table, variable = variable, type = type, source_column = source_column, description = description)
variables <- bind_rows(
  v("prices_goods", "good", "character", "goods_included_class: items", "Name of the good; the key to good in the other two tables"),
  v("prices_goods", "asset", "character", "goods_included_class: asset", "productive or household"),
  v("prices_goods", "class", "character", "goods_included_class: classification", "Class used in the paper: equipment, labour, livestock (productive); luxury, major, minor (household)"),
  v("prices_goods", "dutch_terms", "character", "goods_included_class: dutch words (included)", "Dutch words searched for in the auction rolls to identify the good"),
  v("prices_annual", "year", "integer", "median_prices, avg_prices: year", "Year of the auctions"),
  v("prices_annual", "good", "character", "column names", "Good, as in prices_goods"),
  v("prices_annual", "median_price", "number", "median_prices", "Median unit price in rixdollars of lots of the good sold that year"),
  v("prices_annual", "mean_price", "number", "avg_prices", "Mean unit price in rixdollars of lots of the good sold that year"),
  v("prices_auction_goods", "mooc_id", "character", "count: mooc_id", "Archival reference of the auction (MOOC10/volume.item); the document's n attribute in the auctions XML"),
  v("prices_auction_goods", "year", "integer", "count: year", "Year of the auction, as used in the paper"),
  v("prices_auction_goods", "good", "character", "count: column names", "Good, as in prices_goods"),
  v("prices_auction_goods", "quantity", "integer", "count", "Number of units of the good sold at the auction; goods not sold there are omitted, so a missing row means zero"))
stopifnot(identical(filter(variables, table == "prices_goods")$variable, names(goods)),
          identical(filter(variables, table == "prices_annual")$variable, names(prices_annual)),
          identical(filter(variables, table == "prices_auction_goods")$variable, names(prices_auction_goods)))
write_csv(variables, file.path(out_dir, "prices_variables.csv"), na = "")
