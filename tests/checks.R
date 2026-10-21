# Checks run before any results are written. Each stops the run if it fails.

run_checks <- function(end) {
  check <- function(ok, what) {
    if (!isTRUE(ok)) stop("Check failed: ", what)
    message("  ok: ", what)
  }
  message("Running checks")

  # Data: averaging, the dollar join, the commodity indices and the sign of the rand.
  ex <- read_fred("EXSFUS")
  own <- to_monthly(read_fred("DEXSFUS"), "average")
  m <- intersect(format(ex$date, "%Y-%m"), names(own))
  check(max(abs(ex$value[match(m, format(ex$date, "%Y-%m"))] - own[m])) < 0.001,
        "monthly averages of the daily rand match FRED's own monthly averages (EXSFUS)")

  old <- to_monthly(read_fred("DTWEXM"), "average")
  new <- to_monthly(read_fred("DTWEXAFEGS"), "average")
  m <- intersect(names(old), names(new))
  check(stats::cor(diff(log(old[m])), diff(log(new[m]))) > 0.99,
        "the two dollar indices move together where they overlap (2006-2019)")

  pink <- read_pink_indices()
  y2010 <- pink[substr(pink$month, 1, 4) == "2010", c("energy", "base", "precious", "agri", "metals")]
  check(all(abs(colMeans(y2010) - 100) < 1), "Pink Sheet indices average 100 in 2010 (their base year)")

  d <- build_inputs(BASELINE$start, end)
  check(identical(d$month, format(seq(as.Date(paste0(BASELINE$start, "-01")), by = "month",
                                      length.out = nrow(d)), "%Y-%m")) && max(d$month) == end,
        "the sample has every month from start to end")
  check(d$rand[d$month == "2008-10"] < -10 && d$rand[d$month == "2001-12"] < -10,
        "the rand falls in October 2008 and December 2001 (a fall is negative)")

  # Models.
  set.seed(42)
  n <- 120
  sim <- data.frame(month = format(seq(as.Date("2000-01-01"), by = "month", length.out = n), "%Y-%m"),
                    dollar = stats::rnorm(n), base = stats::rnorm(n), energy = stats::rnorm(n))
  sim$rand <- 0.3 - 0.8 * sim$dollar + 0.2 * sim$base + stats::rnorm(n) +
    0.5 * c(0, stats::rnorm(n - 1))    # some autocorrelation in the errors
  reg <- c("dollar", "base", "energy")
  X <- as.matrix(sim[reg])

  f <- ols_fit(sim$rand, X, lag = 3)
  l <- stats::lm(rand ~ dollar + base + energy, data = sim)
  check(max(abs(f$coef - stats::coef(l))) < 1e-10, "OLS coefficients match lm()")

  # Newey-West, recomputed as a double sum over all pairs of months.
  Xc <- cbind(1, X)
  u <- Xc * stats::residuals(l)
  w <- pmax(1 - abs(outer(1:n, 1:n, "-")) / 4, 0)    # Bartlett weights, lag 3
  S <- t(u) %*% w %*% u
  B <- solve(crossprod(Xc))
  se <- sqrt(diag(B %*% S %*% B) * n / (n - 4))
  check(max(abs(f$se - se)) < 1e-10, "Newey-West standard errors match a direct double sum")

  ro <- rolling_fit(sim, reg, c("base", "energy"), 36)
  i <- 50:85
  l2 <- stats::lm(rand ~ dollar + base + energy, data = sim[i, ])
  r <- ro[ro$month == sim$month[85], ]
  check(max(abs(r$coef - stats::coef(l2))) < 1e-10, "a rolling window matches lm() on the same months")

  # With no drift, the Kalman filter is recursive least squares: smoothed coefficients equal OLS on the
  # whole sample, and filtered coefficients at month t equal OLS on months 1 to t.
  model <- tvp_model(sim, reg, Q = 0, H = 1)
  out <- KFAS::KFS(model, filtering = "state", smoothing = "state")
  check(max(abs(out$alphahat[n, ] - stats::coef(l))) < 1e-6 &&
          max(abs(out$alphahat[1, ] - stats::coef(l))) < 1e-6,
        "TVP model with no drift: smoothed coefficients equal OLS")
  l3 <- stats::lm(rand ~ dollar + base + energy, data = sim[1:60, ])
  check(max(abs(out$att[60, ] - stats::coef(l3))) < 1e-6,
        "TVP model with no drift: filtered coefficients equal recursive OLS")

  # The estimator recovers a known drift: base's coefficient rises from 0 to 0.6, the rest stay put.
  set.seed(7)
  n <- 400
  sim2 <- data.frame(month = format(seq(as.Date("1990-01-01"), by = "month", length.out = n), "%Y-%m"),
                     dollar = stats::rnorm(n, sd = 2), base = stats::rnorm(n, sd = 5))
  path <- seq(0, 0.6, length.out = n)
  sim2$rand <- -0.8 * sim2$dollar + path * sim2$base + stats::rnorm(n, sd = 2)
  fit <- tvp_fit(sim2, c("dollar", "base"))
  b <- fit$smoothed[fit$smoothed$term == "base", "coef"]
  check(mean(b[1:100]) < 0.25 && mean(b[301:400]) > 0.35 && sqrt(fit$q[["dollar"]]) < sqrt(fit$q[["base"]]),
        "TVP model recovers a rising coefficient in simulated data")
  invisible(TRUE)
}
