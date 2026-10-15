source(here::here("pipeline", "opgaaf", "00_config.R"))
s <- read_csv(file.path(release_dir, "validation_summary_v2.csv"), show_col_types = FALSE, guess_max = Inf)
a <- read_csv(file.path(release_dir, "addition_validation_tests.csv"), show_col_types = FALSE, guess_max = Inf)
stopifnot(s$release_tests_all_pass, all(a$passed))
preserved <- read_csv(file.path(release_dir, "preserved_inputs_md5.csv"), show_col_types = FALSE, guess_max = Inf)
stopifnot(identical(unname(tools::md5sum(vapply(preserved$path, here, character(1)))), preserved$md5))
doc <- readLines(here("pipeline", "opgaaf", "codebook_template.md"), encoding = "UTF-8")
doc <- str_replace_all(doc, c("@UNITS@" = format(s$n_tax_units, big.mark = ",", trim = TRUE),
  "@ENTRIES@" = format(s$n_clean_entries, big.mark = ",", trim = TRUE),
  "@TESTS@" = as.character(s$tests_total + nrow(a))))
writeLines(doc, file.path(release_dir, "codebook_v2.md"), useBytes = TRUE)
writeLines(c(paste("Release validated:", release_version),
             paste("Built:", Sys.time()), paste("Checks passed:", s$tests_total + nrow(a)),
             "All preserved raw-source and v1 file hashes unchanged."),
           file.path(release_dir, "BUILD_COMPLETE.txt"))
