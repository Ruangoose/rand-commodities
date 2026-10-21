# Is the rand still a commodity currency?

**How sensitive is the South African rand to commodity prices, once the US dollar is accounted for, and has
that changed over time?**

The rand is often called a commodity currency. This project tests how true that is, month by month from
April 1995 (the first full month after the financial rand was scrapped) to September 2026, with rolling
regressions and a time-varying-parameter model estimated with the Kalman filter.

The results are in [output/RESULTS.md](output/RESULTS.md), which every run rewrites.

## What I found
- **Yes, and more than it was.** Since about 2016 the rand has moved with base metal prices far more than
  before. Gold, platinum and oil barely move it once the dollar is accounted for.
- **Base metals carry the link.** With the dollar unchanged, a 10% rise in base metal prices went with a rand
  about 1% stronger in 1995-2015, and about 3% stronger in 2016-2026.
- **Commodities explain more of the rand's moves.** Beyond what the dollar explains, commodities accounted for
  about 1% of the rand's monthly variance in 1995-2005, 5% in 2006-2015 and 18% in 2016-2026.
- **How firm:** the rise shows up in every check below, but its size depends on the choices, and the
  statistical evidence for the change is moderate rather than overwhelming. Part of it is global risk
  appetite: adding US stock returns as a control cuts the 2016-2026 share from 18% to 11%.

None of this is a forecast, investment advice or a recommendation.

## Data
Downloaded by the code at run time. Only derived results are committed; the raw files stay in `data-raw/`,
which git ignores.

- **Exchange rates:** Board of Governors of the Federal Reserve System (US), H.10 Foreign Exchange Rates,
  retrieved from [FRED](https://fred.stlouisfed.org/), Federal Reserve Bank of St. Louis:
  - [DEXSFUS](https://fred.stlouisfed.org/series/DEXSFUS): South African rand to US dollar, daily;
  - [DTWEXM](https://fred.stlouisfed.org/series/DTWEXM): nominal major currencies US dollar index (goods
    only), daily, 1973-2019 (discontinued);
  - [DTWEXAFEGS](https://fred.stlouisfed.org/series/DTWEXAFEGS): nominal advanced foreign economies US dollar
    index, daily, from 2006;
  - [DEXUSEU](https://fred.stlouisfed.org/series/DEXUSEU): US dollars to euro, daily, from 1999 (a check);
  - [EXSFUS](https://fred.stlouisfed.org/series/EXSFUS): the rand's monthly average (checks the averaging).
- **Commodities:** The World Bank: Commodity Price Data (The Pink Sheet), monthly indices in nominal US
  dollars (2010 = 100), from the
  [World Bank's commodity markets page](https://www.worldbank.org/en/research/commodity-markets). Licensed
  CC BY 4.0. Used: energy, base metals (excluding iron ore), precious metals; and, in checks, agriculture,
  metals and minerals, and the platinum price.
- **US stocks (one check):** [Kenneth R. French Data Library](https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/data_library.html),
  by Eugene F. Fama and Kenneth R. French: daily Fama/French factors (market return = Mkt-RF + RF).

## Method
- **Monthly averages.** The Pink Sheet's indices are monthly averages, so the rand, the dollar and US stocks
  are averaged over each month too. Changes are 100 x log changes. A check confirms that the averages of the
  daily rand match FRED's own monthly averages.
- **The rand is measured in dollars,** so a rise is a stronger rand.
- **The dollar control** is the Fed's major currencies index to 2005, then its successor, the advanced foreign
  economies index, joined on monthly changes (their changes correlate 0.999 where they overlap). Both leave
  out the rand and other emerging-market currencies.
- **The equation:** the rand's monthly change on a constant, the dollar's change and the changes in the
  precious metals, base metals and energy indices.
- **Rolling regressions:** ordinary least squares over 60-month windows, with Newey-West standard errors
  (averaging makes monthly changes autocorrelated).
- **Time-varying-parameter model:** the same equation, with every coefficient following a random walk. The
  drift variances and the error variance are estimated by maximum likelihood with the Kalman filter
  ([KFAS](https://cran.r-project.org/package=KFAS)), and the coefficient paths are smoothed, with 95% bands.
- **Fixed periods:** 1995-2005, 2006-2015 and 2016-2026, with z-tests of the change between them.
- **Tests of whether the coefficients moved:** likelihood-ratio tests in the time-varying model (one
  coefficient at a time, with the boundary correction) and the Nyblom-Hansen stability test.
- **Choices tested,** one at a time: 36- and 120-month windows; starting in 1999; EUR/USD as the dollar
  control from 1999; month-end values instead of averages; agriculture added; US stock returns added as a
  control for global risk appetite; platinum instead of the precious metals index; iron ore included (the
  metals and minerals index); the 2008-09 and 2020 crashes left out; and the error variance allowed to vary
  over time. The baseline was fixed before any results were run. This is a check that the answer doesn't
  hang on one setting, not a search for the most striking result.

## Limits
- **Indices, not South Africa's own export basket.** The precious metals index is mostly gold (78%), with
  only 3% platinum and no palladium or rhodium; energy is mostly crude oil (85%), which South Africa imports.
- **Association, not cause.** Commodity prices and the rand both respond to global growth and risk appetite.
  A control for US stocks takes out some of that, not all of it.
- **The time-varying model is smooth by design.** With little information about how fast coefficients drift,
  maximum likelihood often sets small drifts to zero. The rolling regressions show the shorter swings.
- **Monthly averages** blur moves within a month, and the study is nominal (no inflation adjustment).

## Rerun it
Needs R (4.6 was used) and an internet connection.

```r
# in R, from the project folder
renv::restore()   # installs the pinned packages (KFAS, readxl, jsonlite and their dependencies)
```

```bash
Rscript run.R            # downloads the data if needed, runs the checks, writes output/
Rscript run.R --refresh  # downloads everything again first
```

The study ends in September 2026 (`END` in `run.R`). The Pink Sheet adds a month at a time and sometimes
revises recent months, so a later download can move results slightly. A full run takes a few minutes.

## What's here
- `run.R`: the entry script.
- `R/`: downloads, inputs, the models, settings, the study runner and outputs.
- `tests/checks.R`: checks run before any results are written (the averaging, the dollar join, OLS and
  Newey-West against independent calculations, the Kalman filter against recursive least squares, and a
  simulated drifting coefficient).
- `output/RESULTS.md`: all the tables.
- `output/tables/`: the same tables as CSV.
- `output/site/`: small JSON files that the charts on ruangoosen.co.za are drawn from.
- `output/figures/`: rough charts for checking.

## Licence
Code: MIT (see `LICENSE`). The data belong to their providers; see their terms. Commodity prices: The World
Bank: Commodity Price Data (The Pink Sheet), CC BY 4.0.
