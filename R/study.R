# Runs one set of settings through both models.

run_one <- function(s, end, tvp = TRUE, rolling = TRUE) {
  dat <- build_inputs(s$start, end, s$values, s$dollar)
  regressors <- c("dollar", s$commodities, s$extra)
  keep <- stats::complete.cases(dat[c("rand", regressors)])
  # A control can end a month or two early (the French library lags); gaps anywhere else are an error.
  if (any(!keep) && any(diff(which(keep)) != 1 | !keep[1])) stop("Gaps inside the sample")
  dat <- dat[keep, ]
  # Months a check leaves out keep their place in time, with no rand value: the regressions skip them and
  # the Kalman filter treats them as missing.
  dat$rand[dat$month %in% s$drop] <- NA
  periods <- periods_for(s$start, max(dat$month))
  out <- list(settings = s, inputs = dat, regressors = regressors,
              full = period_fits(dat, regressors, s$commodities, list(all = range(dat$month))),
              periods = period_fits(dat, regressors, s$commodities, periods))
  if (rolling) out$rolling <- rolling_fit(dat, regressors, s$commodities, s$window)
  if (tvp) {
    vol <- if (isTRUE(s$vol)) relative_vol(dat, regressors) else NULL
    out$tvp <- tvp_fit(dat, regressors, vol = vol)
  }
  out$stability <- stability_test(dat, regressors)
  out
}

run_checks_all <- function(end) {
  lapply(stats::setNames(names(CHECKS), names(CHECKS)), function(name) {
    a <- check_applies(name)
    s <- modifyList(BASELINE, CHECKS[[name]])
    message("Check: ", name)
    r <- run_one(s, end, tvp = a$tvp, rolling = a$rolling)
    if (!a$periods) r$periods <- NULL
    r
  })
}

# Averages of a coefficient path within each sub-period, for comparing runs side by side.
path_means <- function(path, periods) {
  do.call(rbind, lapply(names(periods), function(p) {
    r <- periods[[p]]
    x <- path[path$month >= r[1] & path$month <= r[2], ]
    stats::aggregate(coef ~ term, data = x, FUN = mean) |>
      transform(period = p)
  }))
}
