# The release's creators and the works to cite with each collection, in one
# place. Sourced by 00_citation_files.R (which writes CITATION.cff and
# .zenodo.json) and by 03_datapackage.R. release/references.bib holds the same
# works in BibTeX and is kept by hand.

release_version <- "1.1"
release_date <- "2026-10-16"   # set to the day the GitHub release is published

# Creators: the authors of the collection papers (Johan, 13 Oct 2026): Fourie
# and Green first, then alphabetical by full surname, particles included.
# Affiliations as on the papers.
creators <- tribble(
  ~family,       ~particle,  ~given,         ~affiliation,
  "Fourie",      NA,         "Johan",        "Stellenbosch University",
  "Green",       NA,         "Erik",         "Stellenbosch University; Lund University",
  "Bergemann",   NA,         "Karl",         "Stellenbosch University",
  "Brown",       NA,         "Gabriel",      "Stellenbosch University",
  "Burger",      NA,         "Christiaan",   "Stellenbosch University",
  "Cilliers",    NA,         "Jeanne",       "Lund University",
  "Wit",         "de",       "Chris",        "Independent researcher",
  "Ekama",       NA,         "Kate",         "Stellenbosch University",
  "Greyling",    NA,         "Jan",          "Stellenbosch University",
  "Heese",       NA,         "Hans",         "Stellenbosch University",
  "Liebenberg",  NA,         "Helena",       "Tracing History Trust",
  "Links",       NA,         "Calumet",      "Stellenbosch University",
  "Martin",      NA,         "Lisa-Cheree",  "Stellenbosch University",
  "Martins",     NA,         "Igor",         "Lund University",
  "McCants",     NA,         "Anne E.",      "Massachusetts Institute of Technology",
  "Pretorius",   NA,         "Jan-Hendrik",  "Stellenbosch University",
  "Rijpma",      NA,         "Auke",         "Utrecht University",
  "Ross",        NA,         "Robert",       "Stellenbosch University; Leiden University",
  "Schoots",     NA,         "Jonathan",     "Stellenbosch University; Lund University",
  "Linde",       "van der",  "Paul",         "Stellenbosch University; Radboud University",
  "Fintel",      "von",      "Dieter",       "Stellenbosch University",
  "Walters",     NA,         "Leoné",        "University of Cape Town")

# Works to cite, by collection. role "paper" is a paper users must cite;
# "source" is the original from which the data were taken.
a <- function(...) { x <- c(...); map(str_split(x, ", "), ~list(family = .x[1], given = .x[2])) }
works <- list(
  list(key = "FourieGreen2018", coll = "opgaaf", role = "paper", type = "article",
       authors = a("Fourie, Johan", "Green, Erik"), title = "Building the Cape of Good Hope Panel",
       journal = "The History of the Family", year = 2018, volume = 23, issue = 3, start = 493, end = 502,
       doi = "10.1080/1081602X.2018.1509367"),
  list(key = "FourieEtAl2024", coll = "opgaaf", role = "paper", type = "article",
       authors = a("Fourie, Johan", "Green, Erik", "Burger, Christiaan", "de Wit, Chris", "Ekama, Kate", "Greyling, Jan",
                   "Heese, Hans", "Pretorius, Jan-Hendrik", "Ross, Robert", "von Fintel, Dieter"),
       title = "'Waar is beter dorp in Zuid Africa dan Stellenbos?': What the Stellenbosch-Drakenstein Tax Censuses Reveal",
       journal = "South African Historical Journal", year = 2024, volume = 76, issue = 4, start = 420, end = 446,
       doi = "10.1080/02582473.2025.2500410"),
  list(key = "RijpmaEtAl2020", coll = "opgaaf", role = "paper", type = "article",
       authors = a("Rijpma, Auke", "Cilliers, Jeanne", "Fourie, Johan"), title = "Record linkage in the Cape of Good Hope Panel",
       journal = "Historical Methods: A Journal of Quantitative and Interdisciplinary History", year = 2020, volume = 53,
       issue = 2, start = 112, end = 129, doi = "10.1080/01615440.2018.1517030"),
  list(key = "Fourie2013", coll = "probate", role = "paper", type = "article", authors = a("Fourie, Johan"),
       title = "The remarkable wealth of the Dutch Cape Colony: measurements from eighteenth-century probate inventories",
       journal = "The Economic History Review", year = 2013, volume = 66, issue = 2, start = 419, end = 448,
       doi = "10.1111/j.1468-0289.2012.00662.x"),
  list(key = "FourieEtAl2025", coll = "auctions", role = "paper", type = "article",
       authors = a("Fourie, Johan", "Liebenberg, Helena", "Schoots, Jonathan", "van der Linde, Paul"),
       title = "Auction records, consumer culture and social networks in the Cape Colony, 1701-1825",
       journal = "South African Journal of Cultural History", year = 2025, volume = 39, issue = 1, start = 27, end = 49,
       doi = "10.54272/sach.2025.v39n1a2"),
  list(key = "Cilliers2021", coll = "saf", role = "paper", type = "article", authors = a("Cilliers, Jeanne"),
       title = "The South African Families database", journal = "Historical Life Course Studies", year = 2021,
       volume = 11, start = 97, end = 111, doi = "10.51964/hlcs11095"),
  list(key = "CilliersEtAl2025", coll = "saf", role = "paper", type = "article",
       authors = a("Cilliers, Jeanne", "Green, Erik", "McCants, Anne E.", "Rijpma, Auke"),
       title = "Wealth and marriage at the Cape: consanguineous unions as a strategy", journal = "The History of the Family",
       year = 2025, volume = 30, issue = 2, start = 258, end = 284, doi = "10.1080/1081602X.2025.2478381"),
  list(key = "EkamaEtAl2021", coll = "emancipation", role = "paper", type = "article",
       authors = a("Ekama, Kate", "Fourie, Johan", "Heese, Hans", "Martin, Lisa-Cheree"),
       title = "When Cape slavery ended: Introducing a new slave emancipation dataset",
       journal = "Explorations in Economic History", year = 2021, volume = 81, start = 101390, doi = "10.1016/j.eeh.2021.101390"),
  list(key = "MartinsEtAl2023", coll = "emancipation", role = "paper", type = "article",
       authors = a("Martins, Igor", "Cilliers, Jeanne", "Fourie, Johan"),
       title = "Legacies of loss: The health outcomes of slaveholder compensation in the British Cape Colony",
       journal = "Explorations in Economic History", year = 2023, volume = 89, start = 101506, doi = "10.1016/j.eeh.2022.101506"),
  list(key = "Bergemann2025", coll = "runaways", role = "paper", type = "article", authors = a("Bergemann, Karl"),
       title = "Creating the Cape Colony Runaway Advertisements Datasets, 1830-1842",
       journal = "Journal of Slavery and Data Preservation", year = 2025, volume = 6, issue = 1, start = 1, end = 14,
       doi = "10.14321/jsdp.6.1.0001"),
  list(key = "BergemannEtAl2026", coll = "runaways", role = "paper", type = "article",
       authors = a("Bergemann, Karl", "Brown, Gabriel", "Fourie, Johan"),
       title = "Running towards: Labour market incentives for runaway slaves in the British Cape Colony, 1830-1838",
       journal = "Asia-Pacific Economic History Review", year = 2026, doi = "10.1111/aehr.70034"),
  list(key = "BergemannEtAl2025data", coll = "runaways", role = "source", type = "data",
       authors = a("Bergemann, Karl", "Ekama, Kate", "Fourie, Johan"), title = "Cape Colony Runaway Advertisements, 1830-1842",
       publisher = "Harvard Dataverse", year = 2025, doi = "10.7910/DVN/R1IAFM"),
  list(key = "WaltersEtAl2026", coll = "prices", role = "paper", type = "article",
       authors = a("Walters, Leoné", "Schoots, Jonathan", "Fourie, Johan"),
       title = "Prices and living standards: evidence from Cape Colony auction rolls", journal = "Cliometrica", year = 2026,
       doi = "10.1007/s11698-026-00339-9"),
  list(key = "SchootsFourie2026", coll = "petition1779", role = "paper", type = "report",
       authors = a("Schoots, Jonathan", "Fourie, Johan"),
       title = "Protest from above: Elite decoupling and public petitioning in the VOC Cape Colony",
       institution = "Stellenbosch University", note = "Working paper", year = 2026),
  list(key = "Baartman2011", coll = "petition1779", role = "source", type = "thesis", authors = a("Baartman, Teunis"),
       title = "Fighting for the spoils: Cape burgerschap and faction disputes in Cape Town in the 1770s",
       institution = "University of Cape Town", note = "PhD thesis", year = 2011),
  list(key = "FourieLinks2026", coll = "voortrekkers", role = "paper", type = "article",
       authors = a("Fourie, Johan", "Links, Calumet"), title = "Selection into the Great Trek",
       journal = "European Review of Economic History", year = 2026, note = "Forthcoming"),
  list(key = "Visagie2011", coll = "voortrekkers", role = "source", type = "book", authors = a("Visagie, Jan C."),
       title = "Voortrekkerstamouers 1835-1845", publisher = "Protea Boekhuis", note = "2nd edition, Pretoria (1st edition: Universiteit van Suid-Afrika, 2000)",
       year = 2011),
  list(key = "RossMartin2021", coll = "almanacs", role = "paper", type = "article",
       authors = a("Ross, Robert", "Martin, Lisa-Cheree"),
       title = "Accommodation and resistance: The housing of Cape Town's enslaved and freed population before and after emancipation",
       journal = "Journal of Southern African Studies", year = 2021, volume = 47, issue = 3, start = 417, end = 435,
       doi = "10.1080/03057070.2021.1904751"))

# A short reference: Ekama, K., Fourie, J., ... (2021). Title. Journal 81: 101390.
initials <- function(given) paste0(str_sub(str_split_1(given, "[ -]"), 1, 1), ".", collapse = "")
short_ref <- function(w) {
  au <- map_chr(w$authors, ~paste0(.x$family, ", ", str_replace_all(initials(.x$given), "\\.(?=[A-Z])", ". ")))
  au <- if (length(au) == 1) au else paste(paste(head(au, -1), collapse = ", "), "and", tail(au, 1))
  where <- if (!is.null(w$journal)) {
    paste0(w$journal, if (!is.null(w$volume)) paste0(" ", w$volume), if (!is.null(w$issue)) paste0("(", w$issue, ")"),
           if (!is.null(w$start)) paste0(": ", w$start, if (!is.null(w$end)) paste0("-", w$end)),
           if (!is.null(w$note)) paste0(" (", tolower(w$note), ")"))
  } else paste(c(w$note, w$institution, w$publisher), collapse = ", ")
  paste0(au, " (", w$year, "). ", w$title, ". ", where)
}

# Archival sources, by collection: where the original records are held, with
# the archive's reference codes (checked against the WCARS inventories and the
# papers, 16 Oct 2026; see docs/decision_ledger.md). WCARS = Western Cape
# Archives and Records Service, Cape Town.
archives <- list(
  opgaaf = c("WCARS, opgaafrollen (returns for taxation purposes), series J (inventory 1/5), volumes J 1-J 438; the volume of each district-year is in opgaaf_archival_references.csv",
             "Nationaal Archief, The Hague, archive of the Dutch East India Company (VOC), 1.04.02, Overgekomen brieven en papieren (Cape), inv. nos 3994-4276, for returns not preserved in Cape Town"),
  emancipation = c("WCARS, Slave Office (SO, inventory 1/21): SO 20, Slave Compensation Office (valuation lists by district, e.g. SO 20/10 for Graaff-Reinet), and SO 6, registers of slaves",
                   "The National Archives (UK), T 71, Office of Registry of Colonial Slaves and Slave Compensation Commission, via the Legacies of British Slavery database (compensation awards)"),
  saf = c("Genealogical Institute of South Africa (GISA), Suid-Afrikaanse Geslagsregisters, compiled from Dutch Reformed Church baptism and marriage registers, court marriage records (card index at WCARS), and death notices in estate files (at WCARS, MOOC 6/9)"),
  probate = c("WCARS, Master of the Orphan Chamber (MOOC, inventory 1/3): MOOC 8/1-8/48, inventories, general series, 1673-1834; MOOC 8/49-8/74, inventories and appraisements, 1780-1834; MOOC 8/75, unbound inventories, 1673-1825"),
  auctions = c("WCARS, Master of the Orphan Chamber (MOOC, inventory 1/3): MOOC 10/1-10/47, vendue rolls, 1691-1834, and an index to the vendue rolls (MOOC 10/48, loose rolls, is not included)"),
  prices = c("WCARS, Master of the Orphan Chamber, vendue rolls MOOC 10/2-10/24 and 10/26 (1718-1813)"),
  runaways = c("De Zuid Afrikaan, issues 1-740 (1830-1842), and the Cape of Good Hope Government Gazette, issues 1251-1932 (1830-1842), from the collections of Stellenbosch University Library, supplemented by the National Library of South Africa, Cape Town, and HathiTrust (record 100931470)"),
  petition1779 = c("WCARS, Council of Policy (C, inventory 1/1), C 2665 (burgher complaints, 1716-1782), pp. 2-9"),
  voortrekkers = c("Visagie, Voortrekkerstamouers 1835-1845, compiled from the Cape officials' lists of emigrants, other archival sources and GISA genealogies; the book gives the sources of each entry"),
  almanacs = c("The printed almanacs and directories (African Court Calendar, Cape Almanac and others); a full set of the Cape directories and almanacs, 1800-1902, is held by the National Library of South Africa, Cape Town; editions were transcribed from copies at WCARS and the National Library"))
