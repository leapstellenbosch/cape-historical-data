# Build the opgaaf tables from the transcribers' workbooks and write the public
# files. Run from the project root:
#   & 'C:/Program Files/R/R-4.5.2/bin/Rscript.exe' pipeline/opgaaf/run_opgaaf.R
# Stages 00-06 are the v2 release pipeline, unchanged except for paths. Stage 07
# checks the build against v2 (when CHDR_REFERENCE_DATA points to the folder
# holding v1/ and v2/) and writes release/data/opgaaf/.

here::i_am("PLAN.md")
source(here::here("pipeline", "opgaaf", "00_config.R"))
completion_marker <- file.path(release_dir, "BUILD_COMPLETE.txt")
if (file.exists(completion_marker)) unlink(completion_marker)
preserved_before <- tools::md5sum(sources_v2$path)
readr::write_csv(tibble::tibble(path = substring(names(preserved_before), nchar(here::here()) + 2L),
                                md5 = unname(preserved_before)),
                 file.path(release_dir, "preserved_inputs_md5.csv"))

source(here::here("pipeline", "opgaaf", "01_build_schema_registry.R"))
source(here::here("pipeline", "opgaaf", "02_extract_clean_entries.R"))
source(here::here("pipeline", "opgaaf", "03_build_tax_units.R"))
source(here::here("pipeline", "opgaaf", "04_document_and_validate.R"))
source(here::here("pipeline", "opgaaf", "05_validate_additions.R"))

stopifnot(identical(preserved_before, tools::md5sum(sources_v2$path)))
message("Raw workbook hashes unchanged")
source(here::here("pipeline", "opgaaf", "06_release_documentation.R"))
source(here::here("pipeline", "opgaaf", "07_public_release.R"))
