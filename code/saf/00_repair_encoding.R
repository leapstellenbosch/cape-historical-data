# Repair the SAF workbook's garbled accents ("mojibake").
#
# The sheet's text was once stored in Windows-1252, read back as DOS code
# page 437, saved as UTF-8 and finally read as Windows-1252 again. So "ë"
# (1252 byte EB) became cp437 "δ", whose UTF-8 bytes CE B4 read as "Î´";
# "ü" became "â\u0081¿", the apostrophe "Ã†" and quotation marks "Ã´ ... Ã¶".
# repair_encoding() undoes the four steps. A cell is changed only if every
# step succeeds and redoing the four steps on the repaired text gives back the
# cell exactly, so no repair can lose information; cells that fail are kept as
# they are.

# Windows-1252 bytes 80-9F; NA marks the five undefined bytes, which the
# garbling carried through as the C1 control characters U+0081 etc.
cp1252_high <- c(0x20AC, NA, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
                 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, NA, 0x017D, NA,
                 NA, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
                 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, NA, 0x017E, 0x0178)
cp1252_decode <- function(bytes) {
  b <- as.integer(bytes)
  cp <- b
  hi <- which(b >= 0x80 & b <= 0x9F)
  mapped <- cp1252_high[b[hi] - 0x7F]
  cp[hi] <- ifelse(is.na(mapped), b[hi], mapped)
  cp
}
cp1252_encode <- function(cp) {
  out <- cp
  big <- cp > 0xFF
  out[big] <- match(cp[big], cp1252_high) + 0x7F
  # a code point in 80-9F is a byte only where 1252 leaves that byte undefined
  c1 <- which(cp >= 0x80 & cp <= 0x9F)
  out[c1] <- ifelse(is.na(cp1252_high[cp[c1] - 0x7F]), cp[c1], NA)
  if (anyNA(out)) NULL else as.raw(out)
}
# code page 437, bytes 80-FF, as Unicode code points
cp437_high <- c(
  0x00C7, 0x00FC, 0x00E9, 0x00E2, 0x00E4, 0x00E0, 0x00E5, 0x00E7, 0x00EA, 0x00EB, 0x00E8, 0x00EF, 0x00EE, 0x00EC, 0x00C4, 0x00C5,
  0x00C9, 0x00E6, 0x00C6, 0x00F4, 0x00F6, 0x00F2, 0x00FB, 0x00F9, 0x00FF, 0x00D6, 0x00DC, 0x00A2, 0x00A3, 0x00A5, 0x20A7, 0x0192,
  0x00E1, 0x00ED, 0x00F3, 0x00FA, 0x00F1, 0x00D1, 0x00AA, 0x00BA, 0x00BF, 0x2310, 0x00AC, 0x00BD, 0x00BC, 0x00A1, 0x00AB, 0x00BB,
  0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x2561, 0x2562, 0x2556, 0x2555, 0x2563, 0x2551, 0x2557, 0x255D, 0x255C, 0x255B, 0x2510,
  0x2514, 0x2534, 0x252C, 0x251C, 0x2500, 0x253C, 0x255E, 0x255F, 0x255A, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256C, 0x2567,
  0x2568, 0x2564, 0x2565, 0x2559, 0x2558, 0x2552, 0x2553, 0x256B, 0x256A, 0x2518, 0x250C, 0x2588, 0x2584, 0x258C, 0x2590, 0x2580,
  0x03B1, 0x00DF, 0x0393, 0x03C0, 0x03A3, 0x03C3, 0x00B5, 0x03C4, 0x03A6, 0x0398, 0x03A9, 0x03B4, 0x221E, 0x03C6, 0x03B5, 0x2229,
  0x2261, 0x00B1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00F7, 0x2248, 0x00B0, 0x2219, 0x00B7, 0x221A, 0x207F, 0x00B2, 0x25A0, 0x00A0)
cp437_encode <- function(cp) {
  out <- cp
  hi <- cp >= 0x80
  out[hi] <- match(cp[hi], cp437_high) + 0x7F
  if (anyNA(out)) NULL else as.raw(out)
}
cp437_decode <- function(bytes) {
  cp <- as.integer(bytes)
  hi <- cp >= 0x80
  cp[hi] <- cp437_high[cp[hi] - 0x7F]
  cp
}

# The garbling, step by step, and its inverse
garble <- function(cp) {
  step1 <- cp1252_encode(cp); if (is.null(step1)) return(NULL)   # text -> 1252 bytes
  step2 <- cp437_decode(step1)                                    # bytes read as cp437
  step3 <- charToRaw(intToUtf8(step2))                            # saved as UTF-8
  as.integer(cp1252_decode(step3))                                # bytes read as 1252
}
repair_one <- function(x) {
  cp <- utf8ToInt(x)
  if (all(cp < 0x80)) return(x)
  b <- cp1252_encode(cp); if (is.null(b)) return(x)               # undo step 4
  s <- rawToChar(b); Encoding(s) <- "UTF-8"
  if (!validUTF8(s)) return(x)                                    # undo step 3
  b2 <- cp437_encode(utf8ToInt(s))                                # undo step 2
  if (is.null(b2)) {
    # A few cells (occupations) went through steps 3 and 4 only: UTF-8 read
    # as 1252 ("â€™" for the apostrophe)
    redo <- cp1252_encode(utf8ToInt(s))
    if (!is.null(redo) && identical(as.integer(cp1252_decode(charToRaw(s))), cp)) return(s)
    return(x)
  }
  fixed <- as.integer(cp1252_decode(b2))                          # undo step 1
  if (anyNA(fixed) || !identical(garble(fixed), cp)) return(x)    # must be exact
  intToUtf8(fixed)
}
repair_encoding <- function(v) {
  out <- v
  todo <- which(!is.na(v) & !stringi::stri_enc_isascii(v))
  out[todo] <- vapply(v[todo], repair_one, character(1), USE.NAMES = FALSE)
  out
}
