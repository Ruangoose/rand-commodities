# The two models:
# 1. Rolling regressions: ordinary least squares over a moving window, with Newey-West standard errors.
# 2. A time-varying-parameter regression: the same equation, but every coefficient follows a random walk.
#    Estimated by maximum likelihood with the Kalman filter (KFAS), then smoothed.
#
# Both regress the rand's monthly change on the dollar's and the commodity indices' changes:
#   rand_t = a_t + b_t * dollar_t + c_t' * commodities_t + e_t

suppressPackageStartupMessages(library(KFAS))

# Newey-West lag length (the usual rule of thumb). Monthly averages make changes autocorrelated, so the
# lag is never below 1.
nw_lag <- function(n) max(1L, floor(4 * (n / 100)^(2 / 9)))

ols_fit <- function(y, X, lag = NULL) {
  keep <- stats::complete.cases(y, X)    # months left out by a check have no rand value
  y <- y[keep]
  X <- cbind(const = 1, X[keep, , drop = FALSE])
  if (is.null(lag)) lag <- nw_lag(length(y))
  n <- nrow(X)
  k <- ncol(X)
  XtX_inv <- solve(crossprod(X))
  b <- drop(XtX_inv %*% crossprod(X, y))
  e <- drop(y - X %*% b)
  # Newey-West (Bartlett weights), with the n / (n - k) small-sample factor.
  u <- X * e
  S <- crossprod(u)
  for (l in seq_len(lag)) {
    G <- crossprod(u[(l + 1):n, , drop = FALSE], u[1:(n - l), , drop = FALSE])
    S <- S + (1 - l / (lag + 1)) * (G + t(G))
  }
  V <- XtX_inv %*% S %*% XtX_inv * n / (n - k)
  r2 <- 1 - sum(e^2) / sum((y - mean(y))^2)
  list(coef = b, se = sqrt(diag(V)), r2 = r2, resid = e, n = n)
}

# Share of the rand's monthly variance that the commodity terms add, beyond the dollar alone.
r2_added <- function(y, X, commodities) {
  full <- ols_fit(y, X)$r2
  base <- ols_fit(y, X[, setdiff(colnames(X), commodities), drop = FALSE])$r2
  full - base
}

rolling_fit <- function(dat, regressors, commodities, window) {
  n <- nrow(dat)
  ends <- seq(window, n)
  rows <- lapply(ends, function(t) {
    i <- (t - window + 1):t
    y <- dat$rand[i]
    X <- as.matrix(dat[i, regressors])
    f <- ols_fit(y, X)
    data.frame(month = dat$month[t], term = names(f$coef), coef = f$coef, se = f$se,
               r2 = f$r2, r2_commodities = r2_added(y, X, commodities), row.names = NULL)
  })
  out <- do.call(rbind, rows)
  out$window <- window
  out
}

# Time-varying-parameter regression in KFAS. Every coefficient (the constant included) is a random walk
# with its own variance; the measurement error has a constant variance, or one that moves with `vol` (a
# relative variance per month, averaging 1). The variances are estimated by maximum likelihood; the
# starting coefficients are diffuse. `Q` and `H` fix the variances instead (used by the checks).
tvp_model <- function(dat, regressors, Q = 0, H = 1, vol = NULL) {
  y <- dat$rand
  X <- cbind(const = 1, as.matrix(dat[regressors]))
  k <- ncol(X)
  n <- nrow(X)
  Z <- array(t(X), dim = c(1, k, n))
  Hm <- if (is.null(vol)) matrix(H) else array(H * vol, dim = c(1, 1, n))
  # SSModel finds its model terms by name, so SSMcustom can't carry a KFAS:: prefix here.
  SSModel(y ~ -1 + SSMcustom(Z = Z, T = diag(k), R = diag(k), Q = diag(Q, k),
                             a1 = matrix(0, k), P1 = diag(0, k), P1inf = diag(k),
                             state_names = colnames(X)),
          H = Hm)
}

# `fixed` names coefficients held constant (their drift variance is 0), for the tests of constancy.
tvp_fit <- function(dat, regressors, fixed = character(0), vol = NULL) {
  terms <- c("const", regressors)
  k <- length(terms)
  free <- which(!terms %in% fixed)
  model <- tvp_model(dat, regressors, vol = vol)
  update <- function(pars, model) {
    q <- rep(0, k)
    q[free] <- exp(pars[seq_along(free)])
    model$Q[, , 1] <- diag(q, k)
    h <- exp(pars[length(free) + 1])
    model$H[1, 1, ] <- if (is.null(vol)) h else h * vol
    model
  }
  # Start from the full-sample OLS residual variance, with coefficient drift of a tenth, a third or a
  # hundredth of a standard error a month. Several starts guard against a local optimum; the best
  # likelihood wins.
  ols <- ols_fit(dat$rand, as.matrix(dat[regressors]))
  s2 <- var(ols$resid)
  starts <- list(
    c(log((ols$se[free] / 10)^2), log(s2)),
    c(log((ols$se[free] / 3)^2), log(s2 * 0.8)),
    c(log((ols$se[free] / 100)^2), log(s2))
  )
  fits <- lapply(starts, function(s) {
    fitSSM(model, inits = s, updatefn = update, method = if (length(s) > 1) "BFGS" else "Brent",
           lower = if (length(s) > 1) -Inf else log(s2) - 5,
           upper = if (length(s) > 1) Inf else log(s2) + 5)
  })
  ll <- vapply(fits, function(f) -f$optim.out$value, 0)
  best <- fits[[which.max(ll)]]
  out <- KFS(best$model, filtering = "state", smoothing = c("state", "disturbance"))
  list(
    model = best$model,
    loglik = max(ll),
    loglik_starts = ll,
    q = stats::setNames(diag(best$model$Q[, , 1]), terms),
    h = if (is.null(vol)) drop(best$model$H) else mean(best$model$H[1, 1, ]),
    smoothed = states_frame(dat$month, terms, out$alphahat, out$V),
    filtered = states_frame(dat$month, terms, out$att, out$Ptt),
    resid = as.numeric(out$epshat)
  )
}

# Likelihood-ratio tests that a coefficient never moved (its drift variance is zero), one coefficient at a
# time, and for all of them together. Zero is the edge of the allowed range, so the one-at-a-time p-value
# halves the chi-squared(1) tail (Self and Liang, 1987); the joint test uses chi-squared(k), which is
# conservative.
constancy_tests <- function(dat, regressors, full) {
  terms <- c("const", regressors)
  one <- do.call(rbind, lapply(terms, function(tm) {
    r <- tvp_fit(dat, regressors, fixed = tm)
    lr <- max(0, 2 * (full$loglik - r$loglik))
    data.frame(term = tm, drift_sd = sqrt(full$q[[tm]]), lr = lr,
               p = 0.5 * stats::pchisq(lr, 1, lower.tail = FALSE), row.names = NULL)
  }))
  r <- tvp_fit(dat, regressors, fixed = terms)
  lr <- max(0, 2 * (full$loglik - r$loglik))
  rbind(one, data.frame(term = "all", drift_sd = NA, lr = lr,
                        p = stats::pchisq(lr, length(terms), lower.tail = FALSE)))
}

# Nyblom-Hansen test of parameter stability, one coefficient at a time (Hansen, 1992): the locally most
# powerful test against coefficients that follow a random walk. Built from the full-sample OLS scores,
# with a Newey-West long-run variance. Large values mean the coefficient moved; the 10%, 5% and 1%
# critical values are 0.353, 0.470 and 0.748.
stability_test <- function(dat, regressors) {
  keep <- stats::complete.cases(dat[c("rand", regressors)])
  X <- cbind(const = 1, as.matrix(dat[keep, regressors]))
  f <- ols_fit(dat$rand[keep], X[, -1, drop = FALSE])
  n <- nrow(X)
  lag <- nw_lag(n)
  scores <- X * f$resid
  vapply(stats::setNames(seq_len(ncol(X)), colnames(X)), function(j) {
    s <- scores[, j]
    lrv <- sum(s^2)
    for (l in seq_len(lag)) lrv <- lrv + 2 * (1 - l / (lag + 1)) * sum(s[(l + 1):n] * s[1:(n - l)])
    sum(cumsum(s)^2) / (n * lrv)
  }, 0)
}

# Relative variance of the rand's surprises month by month, for the check that lets volatility vary: a
# centred 13-month average of squared residuals from constant-coefficient OLS, scaled to average 1.
relative_vol <- function(dat, regressors, span = 13) {
  e2 <- ols_fit(dat$rand, as.matrix(dat[regressors]))$resid^2
  h <- (span - 1) / 2
  v <- vapply(seq_along(e2), function(t) mean(e2[max(1, t - h):min(length(e2), t + h)]), 0)
  v / mean(v)
}

states_frame <- function(months, terms, est, V) {
  do.call(rbind, lapply(seq_along(terms), function(j) {
    data.frame(month = months, term = terms[j], coef = as.numeric(est[, j]),
               se = sqrt(pmax(V[j, j, ], 0)), row.names = NULL)
  }))
}

# OLS within fixed sub-periods.
period_fits <- function(dat, regressors, commodities, periods) {
  do.call(rbind, lapply(names(periods), function(p) {
    r <- periods[[p]]
    i <- dat$month >= r[1] & dat$month <= r[2]
    y <- dat$rand[i]
    X <- as.matrix(dat[i, regressors])
    f <- ols_fit(y, X)
    data.frame(period = p, from = min(dat$month[i]), to = max(dat$month[i]), n = f$n,
               term = names(f$coef), coef = f$coef, se = f$se, r2 = f$r2,
               r2_commodities = r2_added(y, X, commodities), row.names = NULL)
  }))
}
