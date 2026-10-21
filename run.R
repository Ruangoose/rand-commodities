# Reruns the whole study from a clean clone:
#   Rscript run.R            # uses data-raw/ if the downloads are already there
#   Rscript run.R --refresh  # downloads everything again first
#
# Steps: download the data, run the checks, fit the baseline (rolling regressions and the
# time-varying-parameter model), test whether the coefficients moved, rerun each check setting, then write
# the tables (output/tables), the chart data for the website (output/site) and rough charts
# (output/figures).

args <- commandArgs(trailingOnly = TRUE)
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)

# The last month in the study. The Pink Sheet adds a month at a time (and occasionally revises recent
# months), so the end is pinned to keep reruns comparable. Move it forward deliberately.
END <- "2026-09"

download_all(refresh = "--refresh" %in% args)

source("tests/checks.R")
run_checks(END)

message("Baseline")
base <- run_one(BASELINE, END)
tests <- constancy_tests(base$inputs, base$regressors, base$tvp)
checks <- run_checks_all(END)

write_outputs(base, checks, tests, END)
message("Done. Results are in output/.")
