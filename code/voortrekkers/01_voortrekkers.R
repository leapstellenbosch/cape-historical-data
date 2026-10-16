# Voortrekker register: the trekkers and their marriages, from the workbook
# compiled for Fourie and Links ("Selection into the Great Trek"), which
# transcribes J.C. Visagie, Voortrekkerstamouers 1835-1845. The wide sheet (one
# row per trekker, up to five marriages side by side) is split into persons and
# marriages. In some rows a marriage block was typed one column to the left or
# right of its headings; those blocks are realigned by the types of their cells
# (dates, genealogical numbers, text). Dates are written as ISO 8601 where the
# source can be read unambiguously, and otherwise kept as transcribed.
# Run from the project root:
#   & 'C:/Program Files/R/R-4.5.2/bin/Rscript.exe' pipeline/voortrekkers/01_voortrekkers.R

here::i_am("PLAN.md")
library(tidyverse)
library(here)

src <- here("sources", "raw", "voortrekkers", "Voortrekkers 2.xlsx")
out_dir <- here("release", "data", "voortrekkers")
build_dir <- here("build", "voortrekkers")
walk(c(out_dir, build_dir), dir.create, recursive = TRUE, showWarnings = FALSE)

# Read each cell with its own type, so cells Excel stores as dates (all after
# 1900: Excel cannot store earlier dates) come back as dates rather than as day
# numbers, and are written as ISO dates. Text and numbers are kept as written.
cell_text <- function(x) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) NA_character_
  # an Excel date after 1950 cannot be right for this register (it comes from a
  # mistyped entry); it is kept, marked, rather than passed off as a date
  else if (inherits(x, "POSIXct")) paste0(if (as.integer(format(x, "%Y", tz = "UTC")) > 1950) "EXCEL DATE ",
                                          format(x, "%Y-%m-%d", tz = "UTC"))
  else if (is.numeric(x)) format(x, scientific = FALSE, trim = TRUE, digits = 15)
  else as.character(x)
}
raw_list <- readxl::read_excel(src, "Main", col_types = "list", .name_repair = "minimal")
n_excel_dates <- sum(map_int(raw_list, ~sum(map_lgl(.x, inherits, "POSIXct"))))
raw <- as_tibble(map(raw_list, ~map_chr(.x, cell_text)), .name_repair = "minimal")
message("Cells stored by Excel as dates (converted to ISO): ", n_excel_dates)
stopifnot(nrow(raw) == 2702, ncol(raw) == 80,
          # columns 1 and 3 are the same surname; 2 is it without spaces
          identical(raw[[1]], raw[[3]]), identical(str_remove_all(raw[[1]], " "), raw[[2]]))
heads <- names(raw)               # kept for the variable list; columns are used by position
names(raw) <- paste0("c", seq_along(raw))
raw$source_row <- seq_len(nrow(raw)) + 1L
# The trekkers fill rows 2-2314. Below them are empty rows and, in row 2703, a
# stray fragment of spouse details with no trekker; it is not published.
people_rows <- !is.na(raw[[1]])
stopifnot(sum(people_rows) == 2313, all(raw$source_row[people_rows] <= 2314),
          sum(rowSums(!is.na(raw[!people_rows, 1:80])) > 0) == 1)
fragment <- raw[!people_rows & rowSums(!is.na(raw[1:80])) > 0, ]
raw <- raw[people_rows, ]
cells <- as.matrix(raw[1:80])
cells[] <- str_squish(cells)
cells[cells == ""] <- NA

# ---------------------------------------------------------------------------
# 1. Realign the date-and-place blocks
# ---------------------------------------------------------------------------
# Type of a cell: a genealogical number (a1b2c3..., also within a note such as
# "POSSIBLY b6c7d2e2"), a date, a bare number, or text (a place or a name)
cell_type <- function(x) case_when(
  is.na(x) ~ NA_character_,
  (str_detect(x, "^[(?]*[a-zA-Z][0-9(?]") & !str_detect(x, "^[A-Z]{2}")) |
    str_detect(x, "[a-zA-Z][0-9]+[a-zA-Z][0-9?(]") ~ "code",
  # a date has a year 1600-1999, or day/month/year, also with typos such as
  # 115/07/1821 or a missing separator (01/021821)
  str_detect(x, "(^|[^0-9])1[6-9][0-9]{2}([^0-9]|$)|[0-9]+[/.-][0-9]+[/.-][0-9]{3,5}|^[0-9]{1,2}[/.-][0-9]{5,6}$") ~ "date",
  # a bare number (e.g. an age at death) fits no field, so it is never moved
  str_detect(x, "^[0-9]{1,3}$") ~ "number",
  TRUE ~ "text")
expect <- c(m_place = "text", m_date = "date", first = "text", surname = "text", number = "code",
            bplace = "text", birth = "date", tplace = "text", bapt = "date", dplace = "text", death = "date")
spouse_fields <- names(expect)
# The sheet's own layout: the person's dates, then marriage blocks. Blocks 3 and
# 4 have no column for the spouse's birth place. Two rows carry a fifth marriage
# in the unheaded columns 71-80 (no marriage place).
layout <- list(
  person = c(bplace = 9, birth = 10, tplace = 12, bapt = 13, dplace = 16, death = 18),
  m1 = c(m_place = 20, m_date = 21, first = 23, surname = 24, number = 25, bplace = 26, birth = 27,
         tplace = 28, bapt = 29, dplace = 30, death = 31),
  m2 = setNames(38:48, spouse_fields))
# Columns 49-68 and 71-80 form one run holding marriages 3, 4 and 5 (69 and 70
# are the notes and leaders columns); a block may take one more or one fewer
# column than its headings allow, which moves the blocks after it
run <- c(49:68, 71:80)
run_blocks <- list(m3 = list(start = 1, fields = setdiff(spouse_fields, "bplace")),
                   m4 = list(start = 11, fields = setdiff(spouse_fields, "bplace")),
                   m5 = list(start = 21, fields = setdiff(spouse_fields, "m_place")))

# types are worked out once for the whole sheet; scoring then only compares
types <- matrix(cell_type(as.vector(cells)), nrow(cells))
score <- function(t, fields) {
  e <- expect[fields]
  sum(t == e, na.rm = TRUE) - 2 * sum(t != e, na.rm = TRUE)
}
# Candidate readings of a block: its fields taken from consecutive positions
# from start; or the fields from p onwards read one or two columns to the left
# or right; or field p alone read from a neighbouring column. A field whose cell
# is taken by another is left empty, which is allowed only where that cell is of
# the wrong type for the field (a date in a place column, say), so names and
# places are never re-labelled as one another.
candidates <- function(fields, n_pos, start) {
  idx <- seq_along(fields)
  base <- start + idx - 1
  out <- list(list(pos = base, shift = 0, from = 1, to = 1, kind = "layout"))
  for (p in idx) for (q in p:length(idx)) for (s in c(-2, -1, 1, 2)) {
    moved <- idx >= p & idx <= q
    pos <- base + ifelse(moved, s, 0)
    pos[!moved & pos %in% pos[moved]] <- NA
    out[[length(out) + 1]] <- list(pos = pos, shift = s, from = p, to = q,
                                   kind = if (p == q) "cell" else if (q == length(idx)) "suffix" else "range")
  }
  keep(out, ~all(.x$pos >= 1 & .x$pos <= n_pos, na.rm = TRUE) && !anyDuplicated(na.omit(.x$pos)))
}
# Years of a reading's dates must run in order: birth and baptism before the
# marriage and the death, the marriage before the death. Each break costs 3.
year_of <- function(x) as.integer(str_extract(x, "1[6-9][0-9]{2}"))
out_of_order <- function(vals, fields) {
  y <- setNames(year_of(vals), fields)
  g <- function(f) if (f %in% fields) y[[f]] else NA_integer_
  pairs <- list(c("birth", "bapt"), c("birth", "m_date"), c("bapt", "m_date"), c("birth", "death"),
                c("bapt", "death"), c("m_date", "death"))
  # baptism follows birth within a few years
  sum(map_lgl(pairs, ~isTRUE(g(.x[1]) > g(.x[2])))) + isTRUE(g("bapt") - g("birth") > 20)
}
# The event a field belongs to; a cell read from another field's column should
# preferably stay with the same event (a date under "place of death" is the death)
event <- c(m_place = "marriage", m_date = "marriage", first = "spouse", surname = "spouse", number = "spouse",
           bplace = "birth", birth = "birth", tplace = "baptism", bapt = "baptism", dplace = "death", death = "death")
event_changes <- function(cand, fields, st) {
  base <- st + seq_along(fields) - 1
  moved <- which(!is.na(cand$pos) & cand$pos != base)
  from_field <- fields[match(cand$pos[moved], base)]
  sum(!is.na(from_field) & event[from_field] != event[fields[moved]])
}
# Best reading: matching types score +1, wrong types -2, a non-empty cell of the
# block's own range left unread -2, dates out of order -3; a move costs 0.5 per
# column and 0.1 per field moved, so a tie keeps the sheet's layout and
# otherwise prefers the smallest move
best_reading <- function(v, tv, fields, starts, used, own) {
  # fast path: the sheet's layout fits (no wrong types, nothing left over)
  base <- starts[1] + seq_along(fields) - 1
  if (all(base <= length(v))) {
    t0 <- tv[base]
    if (!any(t0 != expect[fields], na.rm = TRUE) && !any(!is.na(v[setdiff(own, base)]) & !used[setdiff(own, base)]) &&
        !any(used[base] & !is.na(v[base])))
      return(list(pos = base, shift = 0, from = 1, to = 1, kind = "layout", score = score(t0, fields), start = starts[1], fields = fields))
  }
  best <- NULL
  for (st in starts) for (cand in candidates(fields, length(v), st)) {
    pos <- cand$pos[!is.na(cand$pos)]
    if (any(used[pos] & !is.na(v[pos]))) next
    # a field emptied by the move must have held a cell of the wrong type; the one
    # exception is a spouse's first names typed under the marriage place, which may
    # move into the first-names field
    emptied <- which(is.na(cand$pos))
    own_t <- tv[st + emptied - 1]
    name_moves <- "first" %in% fields && "m_place" %in% fields &&
      identical(cand$pos[fields == "first"], st + which(fields == "m_place") - 1)
    protected <- !is.na(own_t) & own_t == expect[fields[emptied]] & !(fields[emptied] == "m_place" & name_moves)
    if (any(protected)) next
    left <- setdiff(own, pos)
    vals <- v[cand$pos]
    # a spouse normally has both a first name and a surname
    half_named <- all(c("first", "surname") %in% fields) &&
      xor(is.na(vals[fields == "first"]), is.na(vals[fields == "surname"]))
    n_moved <- if (cand$shift == 0) 0 else cand$to - cand$from + 1
    sc <- score(tv[cand$pos], fields) - 2 * sum(!is.na(v[left]) & !used[left]) - 3 * out_of_order(vals, fields) -
      0.5 * abs(cand$shift) - 0.1 * n_moved - 0.5 * (st != starts[1]) - 0.25 * half_named -
      0.05 * event_changes(cand, fields, st)
    if (is.null(best) || sc > best$score) best <- c(cand, list(score = sc, start = st, fields = fields))
  }
  best
}

realign_row <- function(r) {
  out <- list(); log <- character()
  for (b in names(layout)) {
    v <- cells[r, layout[[b]]]; tv <- types[r, layout[[b]]]; fields <- names(layout[[b]])
    best <- best_reading(v, tv, fields, 1, rep(FALSE, length(v)), seq_along(v))
    out[[b]] <- setNames(v[best$pos], fields)
    if (best$shift != 0) log <- c(log, sprintf("%s: %s read %d column(s) %s", b,
                                               if (best$kind == "cell") fields[best$from] else paste(fields[best$from], "to", fields[best$to]),
                                               abs(best$shift), if (best$shift > 0) "right" else "left"))
  }
  v <- cells[r, run]; tv <- types[r, run]; used <- rep(FALSE, length(v)); next_start <- 1
  for (b in names(run_blocks)) {
    nb <- run_blocks[[b]]
    own <- nb$start:min(length(v), nb$start + length(nb$fields) - 1)
    starts <- unique(c(nb$start, next_start))
    opts <- list(nb$fields)
    if (b != "m5") opts[[2]] <- spouse_fields             # with the spouse's birth place
    best <- NULL
    for (f in opts) {
      cand <- best_reading(v, tv, f, starts, used, own)
      if (length(f) != length(nb$fields) && !is.null(cand)) cand$score <- cand$score - 0.5
      if (!is.null(cand) && (is.null(best) || cand$score > best$score)) best <- cand
    }
    vals <- setNames(rep(NA_character_, length(spouse_fields)), spouse_fields)
    vals[best$fields] <- v[best$pos]
    out[[b]] <- vals
    filled <- best$pos[!is.na(best$pos) & !is.na(v[best$pos])]
    used[filled] <- TRUE
    if (length(filled) && (best$start != nb$start || best$shift != 0 || length(best$fields) != length(nb$fields)))
      log <- c(log, sprintf("%s: read from columns %s", b, paste(run[range(filled)], collapse = "-")))
    next_start <- if (length(filled)) max(filled) + 1 else nb$start + length(nb$fields)
  }
  list(out = out, log = log, lost = run[!used & !is.na(v)])
}

aligned <- map(seq_len(nrow(cells)), realign_row)
# every non-empty cell of the marriage run is read by some block
stopifnot(all(map_int(aligned, ~length(.x$lost)) == 0))

# One correction by hand: in row 2306 the third wife's death date (17/1/1898)
# sits one column too far right, where it reads as a fourth marriage. The stray
# fragment in row 2703 repeats this wife's details with the date in place.
i <- which(raw$source_row == 2306)
stopifnot(identical(unname(aligned[[i]]$out$m4["m_date"]), "17/1/1898"), sum(!is.na(aligned[[i]]$out$m4)) == 1,
          is.na(aligned[[i]]$out$m3["death"]), fragment[[58]] == "17/1/1898")
aligned[[i]]$out$m3["death"] <- "17/1/1898"
aligned[[i]]$out$m4["m_date"] <- NA
aligned[[i]]$log <- c(str_subset(aligned[[i]]$log, "^m4", negate = TRUE),
                      "m3: death read 1 column(s) right (by hand; the fragment in row 2703 confirms it)")

# ---------------------------------------------------------------------------
# 2. Dates: ISO 8601 where unambiguous, otherwise as transcribed
# ---------------------------------------------------------------------------
months <- c(JANUARY = 1, JANUARIE = 1, JAN = 1, FEBRUARY = 2, FEBRUARIE = 2, FEB = 2, MARCH = 3, MAART = 3, MAR = 3,
            APRIL = 4, APR = 4, MAY = 5, MEI = 5, JUNE = 6, JUNIE = 6, JUN = 6, JULY = 7, JULIE = 7, JUL = 7,
            AUGUST = 8, AUGUSTUS = 8, AUG = 8, SEPTEMBER = 9, SEPT = 9, SEP = 9, OCTOBER = 10, OKTOBER = 10,
            OCT = 10, OKT = 10, NOVEMBER = 11, NOV = 11, DECEMBER = 12, DESEMBER = 12, DEC = 12, DES = 12)
ymd <- function(y, m, d) {
  dt <- as.Date(sprintf("%04d-%02d-%02d", y, m, d), format = "%Y-%m-%d")
  if_else(!is.na(dt) & y >= 1600 & y <= 1999, format(dt, "%Y-%m-%d"), NA_character_)
}
iso_one <- function(x) {
  x <- toupper(str_squish(x))
  out <- rep(NA_character_, length(x))
  m <- str_match(x, "^([0-9]{1,2})[/.-]([0-9]{1,2})[/.-]([0-9]{4})$")             # day/month/year
  out <- coalesce(out, ymd(as.integer(m[, 4]), as.integer(m[, 3]), as.integer(m[, 2])))
  m <- str_match(x, "^([0-9]{1,2})[/.-]([0-9]{4})$")                             # month/year
  ok <- is.na(out) & !is.na(m[, 1]) & as.integer(m[, 2]) %in% 1:12 & between(as.integer(m[, 3]), 1600, 1999)
  out[ok] <- sprintf("%s-%02d", m[ok, 3], as.integer(m[ok, 2]))
  m <- str_match(x, "^([0-9]{4})$")                                             # year
  ok <- is.na(out) & !is.na(m[, 1]) & between(as.integer(m[, 2]), 1600, 1999)
  out[ok] <- m[ok, 2]
  m <- str_match(x, "^(?:([0-9]{1,2}) )?([A-Z]+)\\.? ([0-9]{4})$")              # (day) MONTH year
  mo <- unname(months[m[, 3]])
  ok <- is.na(out) & !is.na(m[, 1]) & !is.na(mo) & between(as.integer(m[, 4]), 1600, 1999)
  day <- ok & !is.na(m[, 2])
  out[day] <- ymd(as.integer(m[day, 4]), mo[day], as.integer(m[day, 2]))
  mon <- ok & is.na(m[, 2])
  out[mon] <- sprintf("%s-%02d", m[mon, 4], mo[mon])
  out
}
iso_date <- function(x) {
  x <- str_squish(x)
  out <- iso_one(x)
  # a range "a - b" becomes an ISO interval a/b when both ends can be read
  rng <- str_match(x, "^(.+?) ?- ?(.+)$")
  a <- iso_one(rng[, 2]); b <- iso_one(rng[, 3])
  ok <- is.na(out) & !is.na(a) & !is.na(b)
  out[ok] <- paste0(a[ok], "/", b[ok])
  coalesce(out, x)    # Excel's own dates arrive as YYYY-MM-DD and are kept
}
stopifnot(identical(iso_date(c("07/01/1817", "28/11/1804 - 29/11/1804", "SEPT 1835", "1835", "04/1823", "CA 1813", "1905-05-12")),
                    c("1817-01-07", "1804-11-28/1804-11-29", "1835-09", "1835", "1823-04", "CA 1813", "1905-05-12")))

# ---------------------------------------------------------------------------
# 3. Persons and marriages
# ---------------------------------------------------------------------------
chdr <- sprintf("VTR-%04d", raw$source_row - 1L)
col <- function(j) cells[, j]
fld <- function(b, f) map_chr(aligned, ~unname(.x$out[[b]][f]))
voortrekkers_persons <- tibble(
  chdr_id = chdr,
  genealogical_number = col(6),
  surname = col(1),
  first_names = col(4),
  birth_place = fld("person", "bplace"),
  birth_date = iso_date(fld("person", "birth")),
  baptism_place = fld("person", "tplace"),
  baptism_date = iso_date(fld("person", "bapt")),
  death_place = fld("person", "dplace"),
  death_date = iso_date(fld("person", "death")),
  ward = col(32),
  district = col(33),
  trek_date = iso_date(col(34)),
  trek_party = col(36),
  trek_destination = col(37),
  notes = col(69),
  leaders = col(70))

voortrekkers_marriages <- map_dfr(1:5, function(k) {
  b <- paste0("m", k)
  tibble(principal_chdr_id = chdr, marriage_order = k,
         marriage_place = fld(b, "m_place"), marriage_date = iso_date(fld(b, "m_date")),
         spouse_first_names = fld(b, "first"), spouse_surname = fld(b, "surname"),
         spouse_genealogical_number = fld(b, "number"),
         spouse_birth_place = fld(b, "bplace"), spouse_birth_date = iso_date(fld(b, "birth")),
         spouse_baptism_place = fld(b, "tplace"), spouse_baptism_date = iso_date(fld(b, "bapt")),
         spouse_death_place = fld(b, "dplace"), spouse_death_date = iso_date(fld(b, "death")))
}) %>%
  filter(!if_all(marriage_place:spouse_death_date, is.na)) %>%
  mutate(chdr_id = paste0(principal_chdr_id, "-M", marriage_order), .before = 1) %>%
  arrange(principal_chdr_id, marriage_order)

realignments <- tibble(chdr_id = chdr, source_row = raw$source_row,
                       change = map_chr(aligned, ~paste(.x$log, collapse = "; "))) %>%
  filter(change != "")

is_iso <- function(x) str_detect(x, "^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?(/[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?)?$")
kept <- c(unlist(voortrekkers_persons[c("birth_date", "baptism_date", "death_date", "trek_date")]),
          unlist(voortrekkers_marriages[c("marriage_date", "spouse_birth_date", "spouse_baptism_date", "spouse_death_date")])) %>%
  na.omit()
message("Dates: ", length(kept), "; ISO: ", sum(is_iso(kept)), "; kept as transcribed: ", sum(!is_iso(kept)))
write_csv(tibble(value = kept[!is_iso(kept)]) %>% count(value, sort = TRUE), file.path(build_dir, "dates_kept_as_written.csv"))
stopifnot(!anyDuplicated(voortrekkers_persons$chdr_id), !anyDuplicated(voortrekkers_marriages$chdr_id),
          !anyDuplicated(paste(voortrekkers_persons$surname, voortrekkers_persons$genealogical_number)),
          all(voortrekkers_marriages$principal_chdr_id %in% voortrekkers_persons$chdr_id),
          sum(voortrekkers_marriages$marriage_order == 5) == 2)
message("Persons: ", nrow(voortrekkers_persons), "; marriages: ", nrow(voortrekkers_marriages),
        " (", paste(table(voortrekkers_marriages$marriage_order), collapse = "/"), " by order); rows realigned: ", nrow(realignments))

redundant <- function(d) {
  cols <- names(d)
  pairs <- combn(cols, 2, simplify = FALSE)
  c(cols[map_lgl(d, ~all(is.na(.x)) || n_distinct(.x) == 1)],
    map_chr(keep(pairs, ~identical(d[[.x[1]]], d[[.x[2]]])), paste, collapse = "="))
}
stopifnot(length(redundant(voortrekkers_persons)) == 0, length(redundant(voortrekkers_marriages)) == 0)

write_tables <- function(d, name) {
  write_csv(d, file.path(out_dir, paste0(name, ".csv")), na = "")
  nanoparquet::write_parquet(d, file.path(out_dir, paste0(name, ".parquet")), compression = "zstd")
  message(name, ": ", nrow(d), " rows x ", ncol(d), " columns")
}
unlink(list.files(out_dir, pattern = "^voortrekkers_.*[.](csv|parquet)$", full.names = TRUE))
write_tables(voortrekkers_persons, "voortrekkers_persons")
write_tables(voortrekkers_marriages, "voortrekkers_marriages")
write_csv(realignments, file.path(out_dir, "voortrekkers_realignments.csv"), na = "")

# ---------------------------------------------------------------------------
# 4. Variable list
# ---------------------------------------------------------------------------
v <- function(table, variable, type, source_column, description)
  tibble(table = table, variable = variable, type = type, source_column = source_column, description = description)
date_note <- "ISO 8601 (YYYY, YYYY-MM, YYYY-MM-DD, or an interval a/b) where the source can be read unambiguously, otherwise as transcribed (e.g. CA 1813, BEFORE 1839)"
P <- "voortrekkers_persons"; M <- "voortrekkers_marriages"
variables <- bind_rows(
  v(P, "chdr_id", "character", "", "Repository identifier, never changed: VTR- and the row in the source sheet less one (VTR-0001 is row 2)"),
  v(P, "genealogical_number", "character", "number (ORIGINAL)", "Number in Visagie's register (b1c2d3...: a letter per generation and the birth order), as transcribed with any query marks; the progenitor's a1 is implied where absent"),
  v(P, "surname", "character", "SURNAME (oorspronklik)", "Surname as in the register"),
  v(P, "first_names", "character", "NAME", "First names as in the register, with nicknames in brackets and Sr./Jr."),
  v(P, "birth_place", "character", "BIRTH PLACE", "Place of birth"),
  v(P, "birth_date", "character", "dob", paste0("Date of birth: ", date_note)),
  v(P, "baptism_place", "character", "BAPTISED PLACE", "Place of baptism"),
  v(P, "baptism_date", "character", "BAPTISE date", paste0("Date of baptism: ", date_note)),
  v(P, "death_place", "character", "PLACE (†)", "Place of death"),
  v(P, "death_date", "character", "dod", paste0("Date of death: ", date_note, "; dates Excel had stored as day numbers are converted")),
  v(P, "ward", "character", "WYK", "Ward (wyk) of residence before the Trek"),
  v(P, "district", "character", "DISTRIK", "District of residence before the Trek"),
  v(P, "trek_date", "character", "MOVE ON", paste0("When the person left: ", date_note)),
  v(P, "trek_party", "character", "MOVE WITH", "Leader or party the person trekked with, as written (spellings vary)"),
  v(P, "trek_destination", "character", "MOVE TO", "Destination, as written (Natal, Transoranje, OVS, ...)"),
  v(P, "notes", "character", "NOTES", "Notes from the register, mostly in Afrikaans (battles, family ties)"),
  v(P, "leaders", "character", "LEADERS", "Marks trek leaders"),
  v(M, "chdr_id", "character", "", "Repository identifier, never changed: the person's chdr_id and -M{marriage_order}"),
  v(M, "principal_chdr_id", "character", "", "chdr_id of the trekker in voortrekkers_persons"),
  v(M, "marriage_order", "integer", "", "First to fifth marriage, from the block of columns in the sheet"),
  v(M, "marriage_place", "character", "M. PLACE, S.M. PLACE, T.M. PLACE, F.M. PLACE", "Place of marriage"),
  v(M, "marriage_date", "character", "M. DATE, S.M. DATE, T.M. DATE, F.M. DATE", paste0("Date of marriage: ", date_note)),
  v(M, "spouse_first_names", "character", "M. TO and its repeats", "Spouse's first names"),
  v(M, "spouse_surname", "character", "SURNAME", "Spouse's surname"),
  v(M, "spouse_genealogical_number", "character", "NUMBER", "Spouse's number in the register, where the spouse is also a descendant"),
  v(M, "spouse_birth_place", "character", "BIRTH PLACE", "Spouse's place of birth"),
  v(M, "spouse_birth_date", "character", "BORN (*)", paste0("Spouse's date of birth: ", date_note)),
  v(M, "spouse_baptism_place", "character", "BAPTISE PLACE", "Spouse's place of baptism"),
  v(M, "spouse_baptism_date", "character", "BAPTISED (≈)", paste0("Spouse's date of baptism: ", date_note)),
  v(M, "spouse_death_place", "character", "PLACE (†)", "Spouse's place of death"),
  v(M, "spouse_death_date", "character", "DIED (†)", paste0("Spouse's date of death: ", date_note, "; Excel day numbers converted")))
stopifnot(identical(filter(variables, table == P)$variable, names(voortrekkers_persons)),
          identical(filter(variables, table == M)$variable, names(voortrekkers_marriages)))
write_csv(variables, file.path(out_dir, "voortrekkers_variables.csv"), na = "")
