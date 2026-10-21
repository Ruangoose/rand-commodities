# Downloads the raw data into data-raw/ (git-ignored). Nothing here is committed: the repo publishes
# only derived results.
#
# Sources:
# - FRED, Federal Reserve Bank of St. Louis: exchange rates and dollar indices from the Federal Reserve
#   Board's H.10 release. Read from FRED's public CSV links, not its API.
# - The World Bank: Commodity Price Data (The Pink Sheet), monthly historical file.
# - Kenneth R. French Data Library: daily US stock market returns (one check only).

FRED_SERIES <- c(
  DEXSFUS    = "South African rand per US dollar, daily",
  EXSFUS     = "South African rand per US dollar, monthly average (checks the averaging)",
  DTWEXM     = "Nominal major currencies dollar index (goods only), daily, 1973-2019 (discontinued)",
  DTWEXAFEGS = "Nominal advanced foreign economies dollar index, daily, from 2006",
  DEXUSEU    = "US dollars per euro, daily, from 1999"
)

# The World Bank moves the file to a new address each year, so the address is read from its commodity
# markets page. The address below was current in October 2026 and is the fallback.
PINK_PAGE <- "https://www.worldbank.org/en/research/commodity-markets"
PINK_FALLBACK <- paste0("https://thedocs.worldbank.org/en/doc/74e8be41ceb20fa0da750cda2f6b9e4e-0050012026/",
                        "related/CMO-Historical-Data-Monthly.xlsx")

FRENCH_DAILY <- paste0("https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/ftp/",
                       "F-F_Research_Data_Factors_daily_CSV.zip")

download_all <- function(dir = "data-raw", refresh = FALSE) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  for (id in names(FRED_SERIES)) {
    dest <- file.path(dir, paste0(id, ".csv"))
    if (refresh || !file.exists(dest)) {
      fetch(paste0("https://fred.stlouisfed.org/graph/fredgraph.csv?id=", id), dest)
    }
  }
  dest <- file.path(dir, "CMO-Historical-Data-Monthly.xlsx")
  if (refresh || !file.exists(dest)) fetch(pink_sheet_url(), dest)
  dest <- file.path(dir, "F-F_Research_Data_Factors_daily_CSV.zip")
  if (refresh || !file.exists(dest)) fetch(FRENCH_DAILY, dest)
  invisible(dir)
}

pink_sheet_url <- function() {
  page <- tryCatch({
    tmp <- tempfile(fileext = ".html")
    fetch(PINK_PAGE, tmp)
    paste(readLines(tmp, warn = FALSE), collapse = "\n")
  }, error = function(e) "")
  hit <- regmatches(page, regexpr("https://[^\"']*CMO-Historical-Data-Monthly\\.xlsx", page))
  if (length(hit) == 1) hit else PINK_FALLBACK
}

fetch <- function(url, dest, tries = 3) {
  message("Downloading ", url)
  for (i in seq_len(tries)) {
    status <- tryCatch(utils::download.file(url, dest, mode = "wb", quiet = TRUE), error = function(e) 1)
    if (status == 0 && file.exists(dest) && file.size(dest) > 0) return(invisible(dest))
    Sys.sleep(2 * i)
  }
  stop("Download failed: ", url)
}
