# Writes everything in output/:
#   RESULTS.md       all the tables, rewritten by every run
#   tables/*.csv     the same tables as CSV
#   site/*.json      the chart data and figures for the website
#   figures/*.png    rough charts for checking (base R graphics)

Z95 <- stats::qnorm(0.975)

write_outputs <- function(base, checks, tests, end, dir = "output") {
  for (d in c("tables", "site", "figures")) dir.create(file.path(dir, d), showWarnings = FALSE, recursive = TRUE)
  tabs <- results_tables(base, checks, tests)
  for (name in names(tabs)) {
    utils::write.csv(tabs[[name]], file.path(dir, "tables", paste0(gsub("_", "-", name), ".csv")),
                     row.names = FALSE)
  }
  write_results_md(tabs, base, end, file.path(dir, "RESULTS.md"))
  write_site_json(base, checks, tests, tabs, end, file.path(dir, "site"))
  write_figures(base, checks, file.path(dir, "figures"))
  invisible(tabs)
}

# --- Tables -------------------------------------------------------------------------------------------

results_tables <- function(base, checks, tests) {
  full <- base$full
  periods <- base$periods
  terms <- setdiff(unique(periods$term), "const")

  # Has a coefficient changed between periods? Each pair of periods is compared with a z-test on the two
  # separate estimates (the periods don't overlap, so their errors are treated as independent).
  pnames <- unique(periods$period)
  change <- do.call(rbind, lapply(terms, function(tm) {
    p <- periods[periods$term == tm, ]
    do.call(rbind, lapply(list(c(1, 3), c(2, 3), c(1, 2)), function(ij) {
      a <- p[ij[1], ]
      b <- p[ij[2], ]
      z <- (b$coef - a$coef) / sqrt(a$se^2 + b$se^2)
      data.frame(term = tm, from = a$period, to = b$period, change = b$coef - a$coef, z = z,
                 p = 2 * stats::pnorm(-abs(z)))
    }))
  }))

  runs <- c(list(Baseline = base), checks)
  # Runs that start later have a shorter first period, so the side-by-side tables label the periods by
  # position ("to 2005") rather than by their exact years.
  slots <- c("to 2005", "2006-2015", "2016-2026")
  period_runs <- runs[vapply(runs, function(r) !is.null(r$periods), TRUE)]
  check_table <- do.call(rbind, lapply(names(period_runs), function(name) {
    r <- period_runs[[name]]
    p <- r$periods
    rows <- lapply(seq_along(unique(p$period)), function(k) {
      pp <- unique(p$period)[k]
      x <- p[p$period == pp, ]
      get <- function(tm) if (length(tm) && tm %in% x$term) x$coef[x$term == tm] else NA_real_
      com <- r$settings$commodities
      metal <- intersect(com, c("base", "metals"))
      prec <- intersect(com, c("precious", "platinum"))
      data.frame(run = name, period = pp, slot = slots[k], n = x$n[1], dollar = get("dollar"),
                 precious = get(prec), base = get(metal), energy = get("energy"),
                 r2 = x$r2[1], r2_commodities = x$r2_commodities[1])
    })
    do.call(rbind, rows)
  }))

  stability <- do.call(rbind, lapply(names(period_runs), function(name) {
    s <- period_runs[[name]]$stability
    data.frame(run = name, term = names(s), L = unname(s))
  }))

  with_slots <- function(pm) {
    pm$slot <- slots[match(pm$period, unique(pm$period))]
    pm
  }
  tvp_runs <- runs[vapply(runs, function(r) !is.null(r$tvp), TRUE)]
  tvp_means <- do.call(rbind, lapply(names(tvp_runs), function(name) {
    r <- tvp_runs[[name]]
    pm <- with_slots(path_means(r$tvp$smoothed, periods_for(r$settings$start, max(r$inputs$month))))
    pm$run <- name
    pm[pm$term != "const", c("run", "period", "slot", "term", "coef")]
  }))
  tvp_params <- do.call(rbind, lapply(names(tvp_runs), function(name) {
    r <- tvp_runs[[name]]
    data.frame(run = name, term = names(r$tvp$q), drift_sd = sqrt(r$tvp$q), loglik = r$tvp$loglik,
               resid_sd = sqrt(r$tvp$h), row.names = NULL)
  }))

  roll_runs <- runs[vapply(runs, function(r) !is.null(r$rolling), TRUE)]
  rolling_means <- do.call(rbind, lapply(names(roll_runs), function(name) {
    r <- roll_runs[[name]]
    pm <- with_slots(path_means(r$rolling, periods_for(r$settings$start, max(r$inputs$month))))
    pm$run <- name
    pm[pm$term != "const", c("run", "period", "slot", "term", "coef")]
  }))

  list(full_sample = full, periods = periods, period_changes = change, constancy = tests,
       stability = stability, checks = check_table, tvp_means = tvp_means, tvp_params = tvp_params,
       rolling_means = rolling_means)
}

# One row per run, one column per period slot.
by_slot <- function(df, value) {
  w <- stats::reshape(df[c("run", "slot", value)], idvar = "run", timevar = "slot", direction = "wide")
  names(w) <- sub(paste0("^", value, "\\."), "", names(w))
  w
}

# --- RESULTS.md ---------------------------------------------------------------------------------------

md_table <- function(df, digits = 2) {
  fmt <- function(v) {
    if (is.numeric(v)) ifelse(is.na(v), "", formatC(v, format = "f", digits = digits)) else as.character(v)
  }
  cells <- as.data.frame(lapply(df, fmt), stringsAsFactors = FALSE, check.names = FALSE)
  head <- paste0("| ", paste(names(df), collapse = " | "), " |")
  rule <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  body <- apply(cells, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  c(head, rule, body, "")
}

label <- function(term) ifelse(term %in% names(TERM_LABELS), TERM_LABELS[term], term)

write_results_md <- function(tabs, base, end, path) {
  d <- base$inputs
  wide <- function(df, value = "coef") {
    df$term <- label(df$term)
    w <- stats::reshape(df[c("term", "period", value)], idvar = "term", timevar = "period",
                        direction = "wide")
    names(w) <- sub(paste0("^", value, "\\."), "", names(w))
    w
  }
  p <- tabs$periods
  per <- p[p$term != "const", ]
  per_tab <- wide(per)
  per_se <- wide(per, "se")
  r2 <- unique(p[c("period", "n", "r2", "r2_commodities")])

  f <- tabs$full_sample
  full_tab <- data.frame(Term = label(f$term), Coefficient = f$coef, `Std error` = f$se,
                         t = f$coef / f$se, check.names = FALSE)

  ch <- tabs$period_changes
  ch_tab <- data.frame(Term = label(ch$term), From = ch$from, To = ch$to, Change = ch$change, z = ch$z,
                       p = ch$p, check.names = FALSE)

  ct <- tabs$constancy
  ct_tab <- data.frame(Term = label(ct$term), `Drift sd a month` = ct$drift_sd, LR = ct$lr, p = ct$p,
                       check.names = FALSE)

  ck <- tabs$checks
  ck_base <- by_slot(ck, "base")
  ck_prec <- by_slot(ck, "precious")
  ck_en <- by_slot(ck, "energy")
  ck_r2 <- by_slot(transform(ck, r2_commodities = 100 * r2_commodities), "r2_commodities")

  tm <- tabs$tvp_means
  tm_base <- by_slot(tm[tm$term %in% c("base", "metals"), ], "coef")
  rm <- tabs$rolling_means
  rm_base <- by_slot(rm[rm$term %in% c("base", "metals"), ], "coef")

  st <- tabs$stability
  st$term <- label(st$term)
  st_tab <- stats::reshape(st, idvar = "run", timevar = "term", direction = "wide")
  names(st_tab) <- sub("^L\\.", "", names(st_tab))

  ro <- base$rolling
  last <- ro[ro$month == max(ro$month), ]
  first <- ro[ro$month == min(ro$month), ]

  lines <- c(
    "# Results",
    "",
    sprintf("Rewritten by `run.R`. Sample: %s to %s, %d months. Changes are monthly, in percent (100 x log",
            d$month[1], d$month[nrow(d)], nrow(d)),
    "change), of monthly averages. The rand is measured in dollars, so a rise is a stronger rand. The dollar",
    "is the Fed's major currencies index (to 2005), then its advanced foreign economies index; a rise is a",
    "stronger dollar. Commodity indices are the World Bank's, in US dollars.",
    "",
    "A coefficient of 0.2 on base metals means that in a month when base metal prices rose 10% more than",
    "usual, with the dollar unchanged, the rand typically rose about 2% more.",
    "",
    "Standard errors are Newey-West. \"Commodities' extra R2\" is how much of the rand's monthly variance the",
    "commodity terms explain beyond the dollar (and any other controls) alone.",
    "",
    "## Whole sample (OLS)",
    "",
    md_table(full_tab, 3),
    sprintf("R2 %.3f; commodities' extra R2 %.3f.", f$r2[1], f$r2_commodities[1]),
    "",
    "## By period (OLS)",
    "",
    "Coefficients:",
    "",
    md_table(per_tab, 3),
    "Standard errors:",
    "",
    md_table(per_se, 3),
    "Fit:",
    "",
    md_table(data.frame(period = r2$period, months = as.character(r2$n), R2 = r2$r2,
                        `Commodities' extra R2` = r2$r2_commodities, check.names = FALSE), 3),
    "## Has the sensitivity changed? (z-tests between periods)",
    "",
    md_table(ch_tab, 3),
    "## Time-varying-parameter model",
    "",
    "Every coefficient follows a random walk; the drift variances and the error variance are estimated by",
    "maximum likelihood (Kalman filter, KFAS), and the paths below are smoothed (they use the whole sample).",
    "",
    "Drift and tests that a coefficient never moved (likelihood ratio, one at a time with the boundary",
    "correction; \"all\" tests every drift at once against chi-squared(5), which is conservative):",
    "",
    md_table(ct_tab, 4),
    "Nyblom-Hansen stability test, one coefficient at a time (from the constant-coefficient regression;",
    "critical values 0.353 at 10%, 0.470 at 5%, 0.748 at 1%; larger means the coefficient moved):",
    "",
    md_table(st_tab, 3),
    "Average smoothed coefficient by period, baseline:",
    "",
    md_table(wide(tm[tm$run == "Baseline", c("term", "period", "coef")]), 3),
    "## Rolling regressions",
    "",
    sprintf("Window %d months. First window ends %s, last %s.", BASELINE$window, first$month[1],
            last$month[1]),
    "",
    "Average rolling coefficient by period, baseline:",
    "",
    md_table(wide(rm[rm$run == "Baseline", c("term", "period", "coef")]), 3),
    sprintf("Latest window (to %s): R2 %.3f, commodities' extra R2 %.3f; base metals %.3f (s.e. %.3f).",
            last$month[1], last$r2[1], last$r2_commodities[1], last$coef[last$term == "base"],
            last$se[last$term == "base"]),
    "",
    "## Checks, one setting at a time",
    "",
    "The first period runs from each run's start to 2005. The window checks change only the rolling",
    "regressions, and the volatility check only the TVP model, so they're missing from the OLS tables.",
    "",
    "Base metals (\"All metals and minerals\" in that check), OLS by period:",
    "",
    md_table(ck_base, 3),
    "Precious metals (platinum in that check), OLS by period:",
    "",
    md_table(ck_prec, 3),
    "Energy, OLS by period:",
    "",
    md_table(ck_en, 3),
    "Commodities' extra R2, OLS by period, in percent:",
    "",
    md_table(ck_r2, 1),
    "Base metals, TVP model, average smoothed coefficient by period:",
    "",
    md_table(tm_base, 3),
    "Base metals, rolling regressions, average coefficient by period:",
    "",
    md_table(rm_base, 3),
    "TVP drift (standard deviation a month) by run:",
    "",
    md_table(stats::reshape(transform(tabs$tvp_params[c("run", "term", "drift_sd")], term = label(term)),
                            idvar = "run", timevar = "term", direction = "wide") |>
               stats::setNames(c("run", label(unique(tabs$tvp_params$term)))), 4)
  )
  writeLines(unlist(lines), path)
}

# --- Site JSON ----------------------------------------------------------------------------------------

r6 <- function(x) round(x, 6)

path_json <- function(path, months, terms) {
  stats::setNames(lapply(terms, function(tm) {
    x <- path[path$term == tm, ]
    i <- match(months, x$month)
    list(coef = r6(x$coef[i]), lo = r6(x$coef[i] - Z95 * x$se[i]), hi = r6(x$coef[i] + Z95 * x$se[i]))
  }), terms)
}

write_site_json <- function(base, checks, tests, tabs, end, dir) {
  d <- base$inputs
  months <- d$month
  terms <- c("dollar", base$settings$commodities)
  ro <- base$rolling
  rr <- unique(ro[c("month", "r2", "r2_commodities")])
  i <- match(months, rr$month)
  sens <- list(
    months = months,
    band = 0.95,
    tvp = path_json(base$tvp$smoothed, months, terms),
    tvp_filtered = path_json(base$tvp$filtered, months, terms),
    rolling = c(path_json(ro, months, terms),
                list(r2 = r6(rr$r2[i]), r2_commodities = r6(rr$r2_commodities[i]))),
    window = base$settings$window
  )
  jsonlite::write_json(sens, file.path(dir, "sensitivity.json"), auto_unbox = TRUE, na = "null",
                       digits = NA)

  # The month before the sample's first change is the base for the levels chart.
  lv <- build_levels(prev_month(base$settings$start), end)
  levels <- list(months = lv$month, usd_per_zar = r6(lv$usd_per_zar), base = lv$base,
                 precious = lv$precious, energy = lv$energy, metals = lv$metals)
  jsonlite::write_json(levels, file.path(dir, "levels.json"), auto_unbox = TRUE, na = "null", digits = NA)

  summary <- list(
    sample = list(start = months[1], end = months[length(months)], months = length(months)),
    full = rows_by_term(tabs$full_sample),
    periods = lapply(split(tabs$periods, tabs$periods$period), rows_by_term),
    period_changes = lapply(split(tabs$period_changes, tabs$period_changes$term), function(x) {
      stats::setNames(lapply(seq_len(nrow(x)), function(j) {
        list(from = x$from[j], to = x$to[j], change = r6(x$change[j]), z = r6(x$z[j]), p = r6(x$p[j]))
      }), paste0(x$from, "_", x$to))
    }),
    constancy = stats::setNames(lapply(seq_len(nrow(tests)), function(j) {
      list(drift_sd = r6(tests$drift_sd[j]), lr = r6(tests$lr[j]), p = r6(tests$p[j]))
    }), tests$term),
    stability = as.list(r6(base$stability)),
    tvp_means = tvp_means_json(tabs$tvp_means),
    rolling_means = tvp_means_json(tabs$rolling_means),
    rolling_last = rolling_point(ro, max(ro$month)),
    rolling_first = rolling_point(ro, min(ro$month)),
    checks = lapply(split(tabs$checks, tabs$checks$run), function(x) {
      stats::setNames(lapply(seq_len(nrow(x)), function(j) {
        as.list(lapply(x[j, c("n", "dollar", "precious", "base", "energy", "r2", "r2_commodities")], r6))
      }), x$period)
    }),
    extremes = extremes(d)
  )
  jsonlite::write_json(summary, file.path(dir, "summary.json"), auto_unbox = TRUE, na = "null",
                       digits = NA, pretty = TRUE)
}

rows_by_term <- function(x) {
  out <- stats::setNames(lapply(seq_len(nrow(x)), function(j) {
    list(coef = r6(x$coef[j]), se = r6(x$se[j]))
  }), x$term)
  c(out, list(n = x$n[1], from = x$from[1], to = x$to[1], r2 = r6(x$r2[1]),
              r2_commodities = r6(x$r2_commodities[1])))
}

tvp_means_json <- function(x) {
  lapply(split(x, x$run), function(r) {
    lapply(split(r, r$term), function(t) stats::setNames(as.list(r6(t$coef)), t$period))
  })
}

rolling_point <- function(ro, month) {
  x <- ro[ro$month == month, ]
  c(list(month = month, r2 = r6(x$r2[1]), r2_commodities = r6(x$r2_commodities[1])),
    stats::setNames(lapply(seq_len(nrow(x)), function(j) list(coef = r6(x$coef[j]), se = r6(x$se[j]))),
                    x$term))
}

# The rand's biggest monthly moves, for the write-up.
extremes <- function(d) {
  i <- order(d$rand)[1:3]
  j <- order(-d$rand)[1:3]
  list(falls = lapply(i, function(k) list(month = d$month[k], rand = r6(d$rand[k]))),
       rises = lapply(j, function(k) list(month = d$month[k], rand = r6(d$rand[k]))))
}

# --- Rough charts -------------------------------------------------------------------------------------

month_num <- function(m) as.numeric(substr(m, 1, 4)) + (as.numeric(substr(m, 6, 7)) - 0.5) / 12

write_figures <- function(base, checks, dir) {
  gold <- "#c9a227"
  silver <- "#7d8590"
  claret <- "#b3263c"
  terms <- c("base", "precious", "energy", "dollar")
  s <- base$tvp$smoothed
  ro <- base$rolling

  grDevices::png(file.path(dir, "sensitivities.png"), width = 1400, height = 1000, res = 130)
  graphics::par(mfrow = c(2, 2), mar = c(3, 4, 3, 1), las = 1)
  for (tm in terms) {
    x <- s[s$term == tm, ]
    t <- month_num(x$month)
    lo <- x$coef - Z95 * x$se
    hi <- x$coef + Z95 * x$se
    r <- ro[ro$term == tm, ]
    yl <- range(c(lo, hi, r$coef - Z95 * r$se, r$coef + Z95 * r$se, 0), na.rm = TRUE)
    graphics::plot(t, x$coef, type = "n", ylim = yl, xlab = "", ylab = "", main = label(tm))
    graphics::polygon(c(t, rev(t)), c(lo, rev(hi)), col = grDevices::adjustcolor(gold, 0.25), border = NA)
    graphics::lines(t, x$coef, col = gold, lwd = 2.5)
    graphics::lines(month_num(r$month), r$coef, col = silver, lwd = 1.3, lty = 1)
    graphics::abline(h = 0, col = "grey60")
  }
  graphics::mtext("Rand's sensitivity: TVP model (gold, 95% band) and 60-month rolling OLS (grey)",
                  outer = TRUE, line = -1.4, cex = 0.9)
  grDevices::dev.off()

  grDevices::png(file.path(dir, "rolling-windows.png"), width = 1400, height = 1000, res = 130)
  graphics::par(mfrow = c(2, 1), mar = c(3, 4, 3, 1), las = 1)
  wins <- list(`36` = checks[["36-month window"]]$rolling, `60` = ro, `120` = checks[["120-month window"]]$rolling)
  cols <- c(`36` = silver, `60` = gold, `120` = claret)
  yl <- range(unlist(lapply(wins, function(w) w$coef[w$term == "base"])), 0)
  graphics::plot(NA, xlim = range(month_num(base$inputs$month)), ylim = yl, xlab = "", ylab = "",
                 main = "Base metals: rolling OLS by window (36, 60, 120 months)")
  for (w in names(wins)) {
    x <- wins[[w]][wins[[w]]$term == "base", ]
    graphics::lines(month_num(x$month), x$coef, col = cols[w], lwd = if (w == "60") 2.5 else 1.5)
  }
  graphics::abline(h = 0, col = "grey60")
  graphics::legend("topleft", legend = paste(names(wins), "months"), col = cols, lwd = 2, bty = "n")
  graphics::plot(NA, xlim = range(month_num(base$inputs$month)), ylim = c(0, 0.45), xlab = "", ylab = "",
                 main = "Share of the rand's monthly moves explained by commodities beyond the dollar (R2)")
  for (w in names(wins)) {
    x <- unique(wins[[w]][c("month", "r2_commodities")])
    graphics::lines(month_num(x$month), x$r2_commodities, col = cols[w], lwd = if (w == "60") 2.5 else 1.5)
  }
  grDevices::dev.off()

  grDevices::png(file.path(dir, "checks-base-metals.png"), width = 1400, height = 800, res = 130)
  graphics::par(mar = c(3, 4, 3, 1), las = 1)
  runs <- c(list(Baseline = base), checks)
  runs <- runs[vapply(runs, function(r) !is.null(r$tvp), TRUE)]
  pal <- grDevices::hcl.colors(length(runs), "Dark 3")
  graphics::plot(NA, xlim = range(month_num(base$inputs$month)), ylim = c(-0.1, 0.45), xlab = "", ylab = "",
                 main = "Base metals sensitivity, TVP model: baseline and each check")
  for (k in seq_along(runs)) {
    x <- runs[[k]]$tvp$smoothed
    x <- x[x$term %in% c("base", "metals"), ]
    graphics::lines(month_num(x$month), x$coef, col = if (k == 1) gold else pal[k],
                    lwd = if (k == 1) 3 else 1.3)
  }
  graphics::abline(h = 0, col = "grey60")
  graphics::legend("topleft", legend = names(runs), col = c(gold, pal[-1]), lwd = 2, bty = "n", cex = 0.7,
                   ncol = 2)
  grDevices::dev.off()

  lv <- build_levels(prev_month(base$settings$start), max(base$inputs$month))
  grDevices::png(file.path(dir, "levels.png"), width = 1400, height = 800, res = 130)
  graphics::par(mar = c(3, 4, 3, 1), las = 1)
  t <- month_num(lv$month)
  idx <- function(v) 100 * v / v[1]
  graphics::plot(t, idx(lv$usd_per_zar), type = "l", log = "y", ylim = c(15, 600), col = gold, lwd = 2.5,
                 xlab = "", ylab = "", main = sprintf("Levels, %s = 100 (log scale)", lv$month[1]))
  graphics::lines(t, idx(lv$base), col = silver, lwd = 2)
  graphics::lines(t, idx(lv$precious), col = claret, lwd = 1.3)
  graphics::lines(t, idx(lv$energy), col = "grey40", lwd = 1.3)
  graphics::legend("topleft", legend = c("Rand in US dollars", "Base metals", "Precious metals", "Energy"),
                   col = c(gold, silver, claret, "grey40"), lwd = 2, bty = "n")
  grDevices::dev.off()

  grDevices::png(file.path(dir, "twelve-month-changes.png"), width = 1400, height = 800, res = 130)
  graphics::par(mar = c(3, 4, 3, 4), las = 1)
  ch <- function(v) c(rep(NA, 12), 100 * (v[-(1:12)] / v[1:(length(v) - 12)] - 1))
  rand12 <- ch(lv$usd_per_zar)
  base12 <- ch(lv$base)
  graphics::plot(t, rand12, type = "l", col = gold, lwd = 2.5, ylim = c(-45, 45), xlab = "", ylab = "",
                 main = sprintf("Change over 12 months, %%: rand in dollars (gold, left) and base metals (grey, right, %s)",
                                "scaled by half"))
  graphics::lines(t, base12 / 2, col = silver, lwd = 2)
  graphics::axis(4, at = seq(-40, 40, 20), labels = seq(-80, 80, 40))
  graphics::abline(h = 0, col = "grey60")
  grDevices::dev.off()
}
