# Copy the cleaning and packaging code into release/code/, so the published
# repository holds the code that made every file. release/code/README.md is
# written by hand and kept.
here::i_am("PLAN.md")
library(here)

dest <- here("release", "code")
old <- setdiff(list.files(dest, full.names = TRUE, all.files = TRUE, no.. = TRUE),
               file.path(dest, "README.md"))
unlink(old, recursive = TRUE)

for (part in c("opgaaf", "emancipation", "saf", "runaways", "prices", "petition1779",
               "voortrekkers", "almanacs", "xml", "package")) {
  files <- list.files(here("pipeline", part), pattern = "[.](R|md|ps1)$")
  dir.create(file.path(dest, part), showWarnings = FALSE)
  stopifnot(all(file.copy(here("pipeline", part, files), file.path(dest, part, files), overwrite = TRUE)))
}
cat("Code copied:", length(list.files(dest, recursive = TRUE)) - 1, "files\n")
