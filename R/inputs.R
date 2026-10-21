# Turns the raw downloads into one monthly table of changes, in percent (100 x log change):
#   rand      the rand in US dollars (a rise means a stronger rand)
#   dollar    the dollar against the major currencies (a rise means a stronger dollar)
#   precious, base, energy, agri, metals   World Bank commodity price indices, in US dollars
#   platinum  the World Bank's platinum price (one check only)
#   stocks    the US stock market's total return (one check only)
#
# Monthly values are averages of daily values by default, because the Pink Sheet's indices are monthly
# averages. `values = "month_end"` takes the last daily value of each month instead (a check).

read_fred <- function(id, dir = "data-raw") {
  x <- utils::read.csv(file.path(dir, paste0(id, ".csv")), stringsAsFactors = FALSE,
                       na.strings = c("", "."))
  names(x) <- c("date", "value")
  x$date <- as.Date(x$date)
  x[!is.na(x$value), ]
}

# Daily values to one value per month ("YYYY-MM"), either the mean or the last value.
to_monthly <- function(daily, values = c("average", "month_end")) {
  values <- match.arg(values)
  month <- format(daily$date, "%Y-%m")
  f <- if (values == "average") mean else function(v) v[length(v)]
  out <- tapply(daily$value, month, f)
  stats::setNames(as.numeric(out), names(out))
}

read_pink_indices <- function(dir = "data-raw") {
  f <- file.path(dir, "CMO-Historical-Data-Monthly.xlsx")
  raw <- suppressMessages(readxl::read_excel(f, sheet = "Monthly Indices", col_names = FALSE,
                                             col_types = "text"))
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)
  rows <- grepl("^[0-9]{4}M[0-9]{2}$", raw[[1]])
  # The column labels sit on several header rows (one per level of the index tree); each column has one.
  head <- raw[seq_len(min(which(rows)) - 1), , drop = FALSE]
  labels <- vapply(head, function(col) {
    v <- trimws(col[!is.na(col)])
    if (length(v)) v[length(v)] else ""
  }, "")
  pick <- function(pattern) {
    j <- grep(pattern, labels, ignore.case = TRUE)
    if (length(j) != 1) stop("Pink Sheet: expected one column matching ", pattern, ", found ", length(j))
    as.numeric(raw[rows, j])
  }
  month <- sub("M", "-", raw[rows, 1])
  out <- data.frame(
    month = month,
    energy = pick("^Energy$"),
    agri = pick("^Agriculture"),
    metals = pick("^Metals +& +Minerals"),
    base = pick("^Base Metals"),
    precious = pick("^Precious Metals"),
    stringsAsFactors = FALSE
  )
  prices <- read_pink_prices(dir, c(platinum = "^Platinum$"))
  out$platinum <- prices$platinum[match(out$month, prices$month)]
  out
}

# Single prices from the "Monthly Prices" sheet, by column name (one check uses platinum).
read_pink_prices <- function(dir, patterns) {
  f <- file.path(dir, "CMO-Historical-Data-Monthly.xlsx")
  raw <- suppressMessages(readxl::read_excel(f, sheet = "Monthly Prices", col_names = FALSE,
                                             col_types = "text"))
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)
  rows <- grepl("^[0-9]{4}M[0-9]{2}$", raw[[1]])
  labels <- trimws(unlist(raw[min(which(rows)) - 2, ]))    # names sit two rows above the data, units one
  out <- data.frame(month = sub("M", "-", raw[rows, 1]), stringsAsFactors = FALSE)
  for (key in names(patterns)) {
    j <- grep(patterns[[key]], labels, ignore.case = TRUE)
    if (length(j) != 1) stop("Pink Sheet prices: expected one column matching ", patterns[[key]])
    out[[key]] <- suppressWarnings(as.numeric(raw[rows, j]))
  }
  out
}

# US stock market total return index from the French library's daily factors (Mkt-RF + RF).
read_french_daily <- function(dir = "data-raw") {
  zip <- file.path(dir, "F-F_Research_Data_Factors_daily_CSV.zip")
  inner <- utils::unzip(zip, list = TRUE)$Name[1]
  lines <- readLines(unz(zip, inner), warn = FALSE)
  lines <- lines[grepl("^\\s*[0-9]{8}\\s*,", lines)]
  x <- utils::read.csv(text = lines, header = FALSE, stringsAsFactors = FALSE)
  date <- as.Date(as.character(x[[1]]), "%Y%m%d")
  ret <- (x[[2]] + x[[5]]) / 100
  data.frame(date = date, value = cumprod(1 + ret))
}

pct_change <- function(level) c(NA, 100 * diff(log(level)))

# The dollar control: the Fed's major currencies index until 2005, then its successor, the advanced
# foreign economies index. Joined on monthly changes, so the two indices' levels needn't match.
dollar_majors <- function(values, dir = "data-raw", switch_month = "2006-02") {
  old <- to_monthly(read_fred("DTWEXM", dir), values)
  new <- to_monthly(read_fred("DTWEXAFEGS", dir), values)
  d_old <- stats::setNames(pct_change(old), names(old))
  d_new <- stats::setNames(pct_change(new), names(new))
  months <- sort(union(names(d_old), names(d_new)))
  out <- ifelse(months < switch_month, d_old[months], d_new[months])
  stats::setNames(out, months)
}

build_inputs <- function(start, end, values = "average", dollar = "majors", dir = "data-raw") {
  zar <- to_monthly(read_fred("DEXSFUS", dir), values)
  rand <- stats::setNames(-pct_change(zar), names(zar))    # rand per dollar -> dollars per rand
  usd <- switch(dollar,
    majors = dollar_majors(values, dir),
    eurusd = {
      eu <- to_monthly(read_fred("DEXUSEU", dir), values)   # dollars per euro
      stats::setNames(-pct_change(eu), names(eu))
    },
    stop("Unknown dollar control: ", dollar))
  pink <- read_pink_indices(dir)
  com <- data.frame(month = pink$month[-1], lapply(pink[-1], function(v) diff(log(v)) * 100))
  stk <- to_monthly(read_french_daily(dir), values)
  stocks <- stats::setNames(pct_change(stk), names(stk))

  months <- com$month[com$month >= start & com$month <= end]
  out <- data.frame(
    month = months,
    rand = unname(rand[months]),
    dollar = unname(usd[months]),
    com[match(months, com$month), c("precious", "base", "energy", "agri", "metals", "platinum")],
    stocks = unname(stocks[months]),
    row.names = NULL
  )
  core <- c("rand", "dollar", "precious", "base", "energy")
  if (anyNA(out[core])) {
    bad <- out$month[!stats::complete.cases(out[core])]
    stop("Missing values in ", paste(head(bad), collapse = ", "))
  }
  out
}

prev_month <- function(m) format(as.Date(paste0(m, "-01")) - 1, "%Y-%m")

# Levels for the second chart: the rand in dollars and the commodity indices, monthly averages.
build_levels <- function(start, end, dir = "data-raw") {
  zar <- to_monthly(read_fred("DEXSFUS", dir), "average")
  pink <- read_pink_indices(dir)
  months <- pink$month[pink$month >= start & pink$month <= end]
  data.frame(month = months, usd_per_zar = 1 / unname(zar[months]),
             pink[match(months, pink$month), -1], row.names = NULL)
}
