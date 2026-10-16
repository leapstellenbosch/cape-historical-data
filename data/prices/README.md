# Auction prices, 1718–1813

Prices of 30 goods sold at estate auctions in the Cape Colony, from the MOOC10
auction rolls (the `auctions` collection of this repository). For each good
and year the collection gives the median and mean unit price in rixdollars, and
for each of 1,513 auctions the number of units of each good sold.

**This is the repository's one derived collection.** The other collections
hold records; these tables are the prices behind Walters, Schoots and Fourie
(2026), computed by the authors from the auction rolls. The price indices of
the paper are not included; they can be rebuilt from these tables.

**Cite:** Walters, L., Schoots, J. and Fourie, J. (2026), "Prices and living
standards: evidence from Cape Colony auction rolls", *Cliometrica*,
doi:[10.1007/s11698-026-00339-9](https://doi.org/10.1007/s11698-026-00339-9).
Cite also the auction rolls: Fourie, J., Liebenberg, H., Schoots, J. and van
der Linde, P. (2025), *South African Journal of Cultural History* 39(1), 27–49,
doi:[10.54272/sach.2025.v39n1a2](https://doi.org/10.54272/sach.2025.v39n1a2).

**Archival source:** the estate auction rolls (*vendurollen*) of the Master
of the Orphan Chamber, Western Cape Archives and Records Service (WCARS), Cape Town, **MOOC 10/2–10/24 and 10/26**
(1718–1813), as transcribed for the Tracing History Trust. (The paper
describes the source as MOOC 10/1–16; the auctions in these tables come from
the volumes listed here.)

## Files

| File | Contents |
|---|---|
| `prices_goods.csv` | The 30 goods: asset type (productive or household), class, and the Dutch words searched for (also as `.parquet`) |
| `prices_annual.csv` | Median and mean unit price of each good in each year in which it was sold: 2,259 good-years, 1718–1813 |
| `prices_auction_goods.csv` | The number of units of each good sold at each auction: 15,453 rows, 1,513 auctions |
| `prices_variables.csv` | Every variable, its source and meaning |

The tables join on `good`. `mooc_id` in `prices_auction_goods` is the
archival reference of the auction and matches the document's `n` attribute in
`data/auctions/xml/` (half-numbered auctions are written `MOOC10/2.6 1/2`, as
in the XML). Three auctions in volume 10 share the reference
`MOOC10/10.[not numbered]`; the two included here are told apart by `year`
(1770 and 1771).

## Reading the data

- **Prices are in rixdollars** (1 rixdollar = 8 schellingen = 48 stuivers).
- A unit price comes only from a lot of one item or of identical items; lots
  with zero price were excluded. A good with no priced lot in a year has no
  row in `prices_annual`; the paper fills such gaps by interpolation, which is
  not done here.
- Some goods are rarely sold (fire tongs in 25 years, violins in 32), so their
  yearly medians rest on few lots.
- In `prices_auction_goods`, goods not sold at an auction have no row: a
  missing row means zero.
- `year` is the year of the auction as used in the paper; it agrees with the
  date of the document in the auction XML for every auction.

## How the file was made

From the authors' workbook (`SW_priceindex_Jan2026.xlsx`), the pipeline in
`code/prices/` takes the goods classification, the yearly median and mean
prices and the counts per auction. The workbook stores numbers as
single-precision floats (58.189998626708984); they are rounded to seven
significant digits, which recovers the values (58.19). Auction references are
written as in the XML, and every auction was checked against the XML. Left
out: interpolated prices, weights, expenditure shares, the indices and the
series from other studies that the workbook copies (consumer prices, pacht
prices, shipping, GDP).
