# The baseline, fixed before any results were run (21 October 2026), and the checks, each changing one
# setting at a time. The checks test whether the answer hangs on a choice; they're not a search for the
# most striking result.

BASELINE <- list(
  start = "1995-04",        # the first full month after the financial rand was scrapped (13 March 1995)
  values = "average",       # monthly averages of daily values, like the Pink Sheet's indices
  dollar = "majors",        # the Fed's major currencies index, then its advanced economies successor
  commodities = c("precious", "base", "energy"),
  extra = character(0),     # further controls
  window = 60,              # months, for the rolling regressions
  vol = FALSE,              # TVP model: constant measurement variance
  drop = character(0)       # months left out
)

# The two sharpest global crashes in the sample, left out in one check: Lehman's collapse to the March 2009
# low, and the pandemic crash (February to May 2020).
CRASH_MONTHS <- c(format(seq(as.Date("2008-09-01"), as.Date("2009-03-01"), by = "month"), "%Y-%m"),
                  format(seq(as.Date("2020-02-01"), as.Date("2020-05-01"), by = "month"), "%Y-%m"))

CHECKS <- list(
  "36-month window"            = list(window = 36),
  "120-month window"           = list(window = 120),
  "Start in 1999"              = list(start = "1999-02"),
  "Start in 1999, EUR/USD"     = list(start = "1999-02", dollar = "eurusd"),
  "Month-end values"           = list(values = "month_end"),
  "Agriculture added"          = list(commodities = c("precious", "base", "energy", "agri")),
  "US stocks added"            = list(extra = "stocks"),
  "Platinum for precious"      = list(commodities = c("platinum", "base", "energy")),
  "Iron ore in (all metals)"   = list(commodities = c("precious", "metals", "energy")),
  "Without 2008-09 and 2020"   = list(drop = CRASH_MONTHS),
  "Volatility allowed to vary" = list(vol = TRUE)
)

# Which models each check affects: the window only changes the rolling regressions, and the volatility
# setting only the TVP model; neither changes the regressions over fixed periods.
check_applies <- function(name) {
  s <- CHECKS[[name]]
  list(rolling = is.null(s$vol), tvp = is.null(s$window), periods = is.null(s$vol) && is.null(s$window))
}

# Three sub-periods of about ten years each, for the fixed-period regressions and the summary tables.
periods_for <- function(start, end) {
  p <- list(c(start, "2005-12"), c("2006-01", "2015-12"), c("2016-01", end))
  names(p) <- vapply(p, function(r) paste0(substr(r[1], 1, 4), "-", substr(r[2], 1, 4)), "")
  p
}

TERM_LABELS <- c(
  const = "Constant", dollar = "Dollar", precious = "Precious metals", base = "Base metals",
  energy = "Energy", agri = "Agriculture", metals = "All metals and minerals", platinum = "Platinum",
  stocks = "US stocks"
)
