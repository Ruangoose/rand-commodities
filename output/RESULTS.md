# Results

Rewritten by `run.R`. Sample: 1995-04 to 2026-09, 378 months. Changes are monthly, in percent (100 x log
change), of monthly averages. The rand is measured in dollars, so a rise is a stronger rand. The dollar
is the Fed's major currencies index (to 2005), then its advanced foreign economies index; a rise is a
stronger dollar. Commodity indices are the World Bank's, in US dollars.

A coefficient of 0.2 on base metals means that in a month when base metal prices rose 10% more than
usual, with the dollar unchanged, the rand typically rose about 2% more.

Standard errors are Newey-West. "Commodities' extra R2" is how much of the rand's monthly variance the
commodity terms explain beyond the dollar (and any other controls) alone.

## Whole sample (OLS)

| Term | Coefficient | Std error | t |
|---|---|---|---|
| Constant | -0.440 | 0.171 | -2.574 |
| Dollar | -0.795 | 0.133 | -5.987 |
| Precious metals | 0.010 | 0.049 | 0.209 |
| Base metals | 0.154 | 0.042 | 3.684 |
| Energy | 0.036 | 0.032 | 1.146 |

R2 0.288; commodities' extra R2 0.057.

## By period (OLS)

Coefficients:

| term | 1995-2005 | 2006-2015 | 2016-2026 |
|---|---|---|---|
| Dollar | -0.786 | -0.711 | -0.988 |
| Precious metals | 0.015 | 0.049 | -0.098 |
| Base metals | 0.122 | 0.086 | 0.319 |
| Energy | -0.018 | 0.070 | 0.045 |

Standard errors:

| term | 1995-2005 | 2006-2015 | 2016-2026 |
|---|---|---|---|
| Dollar | 0.217 | 0.273 | 0.200 |
| Precious metals | 0.080 | 0.082 | 0.079 |
| Base metals | 0.068 | 0.068 | 0.065 |
| Energy | 0.043 | 0.051 | 0.044 |

Fit:

| period | months | R2 | Commodities' extra R2 |
|---|---|---|---|
| 1995-2005 | 129 | 0.159 | 0.014 |
| 2006-2015 | 120 | 0.359 | 0.047 |
| 2016-2026 | 129 | 0.434 | 0.179 |

## Has the sensitivity changed? (z-tests between periods)

| Term | From | To | Change | z | p |
|---|---|---|---|---|---|
| Dollar | 1995-2005 | 2016-2026 | -0.201 | -0.682 | 0.495 |
| Dollar | 2006-2015 | 2016-2026 | -0.277 | -0.817 | 0.414 |
| Dollar | 1995-2005 | 2006-2015 | 0.075 | 0.215 | 0.830 |
| Precious metals | 1995-2005 | 2016-2026 | -0.112 | -0.998 | 0.318 |
| Precious metals | 2006-2015 | 2016-2026 | -0.146 | -1.279 | 0.201 |
| Precious metals | 1995-2005 | 2006-2015 | 0.034 | 0.296 | 0.767 |
| Base metals | 1995-2005 | 2016-2026 | 0.197 | 2.086 | 0.037 |
| Base metals | 2006-2015 | 2016-2026 | 0.233 | 2.462 | 0.014 |
| Base metals | 1995-2005 | 2006-2015 | -0.036 | -0.376 | 0.707 |
| Energy | 1995-2005 | 2016-2026 | 0.063 | 1.016 | 0.310 |
| Energy | 2006-2015 | 2016-2026 | -0.026 | -0.380 | 0.704 |
| Energy | 1995-2005 | 2006-2015 | 0.088 | 1.325 | 0.185 |

## Time-varying-parameter model

Every coefficient follows a random walk; the drift variances and the error variance are estimated by
maximum likelihood (Kalman filter, KFAS), and the paths below are smoothed (they use the whole sample).

Drift and tests that a coefficient never moved (likelihood ratio, one at a time with the boundary
correction; "all" tests every drift at once against chi-squared(5), which is conservative):

| Term | Drift sd a month | LR | p |
|---|---|---|---|
| Constant | 0.0008 | 0.0039 | 0.4751 |
| Dollar | 0.0008 | 0.0023 | 0.4811 |
| Precious metals | 0.0001 | 0.0030 | 0.4782 |
| Base metals | 0.0077 | 1.4495 | 0.1143 |
| Energy | 0.0077 | 0.9061 | 0.1706 |
| all |  | 4.2226 | 0.5178 |

Nyblom-Hansen stability test, one coefficient at a time (from the constant-coefficient regression;
critical values 0.353 at 10%, 0.470 at 5%, 0.748 at 1%; larger means the coefficient moved):

| run | Constant | Dollar | Precious metals | Base metals | Energy | Agriculture | US stocks | Platinum | All metals and minerals |
|---|---|---|---|---|---|---|---|---|---|
| Baseline | 0.106 | 0.102 | 0.040 | 0.461 | 0.207 |  |  |  |  |
| Start in 1999 | 0.086 | 0.029 | 0.036 | 0.407 | 0.151 |  |  |  |  |
| Start in 1999, EUR/USD | 0.046 | 0.066 | 0.041 | 0.322 | 0.143 |  |  |  |  |
| Month-end values | 0.125 | 0.322 | 0.176 | 0.232 | 0.165 |  |  |  |  |
| Agriculture added | 0.102 | 0.111 | 0.051 | 0.469 | 0.190 | 0.122 |  |  |  |
| US stocks added | 0.094 | 0.070 | 0.032 | 0.535 | 0.192 |  | 0.685 |  |  |
| Platinum for precious | 0.108 | 0.109 |  | 0.481 | 0.206 |  |  | 0.371 |  |
| Iron ore in (all metals) | 0.113 | 0.089 | 0.038 |  | 0.199 |  |  |  | 0.493 |
| Without 2008-09 and 2020 | 0.154 | 0.093 | 0.057 | 0.462 | 0.102 |  |  |  |  |

Average smoothed coefficient by period, baseline:

| term | 1995-2005 | 2006-2015 | 2016-2026 |
|---|---|---|---|
| Base metals | 0.102 | 0.153 | 0.222 |
| Dollar | -0.796 | -0.797 | -0.797 |
| Energy | -0.001 | 0.033 | 0.051 |
| Precious metals | 0.008 | 0.008 | 0.008 |

## Rolling regressions

Window 60 months. First window ends 2000-03, last 2026-09.

Average rolling coefficient by period, baseline:

| term | 1995-2005 | 2006-2015 | 2016-2026 |
|---|---|---|---|
| Base metals | 0.088 | 0.090 | 0.230 |
| Dollar | -0.849 | -0.861 | -0.857 |
| Energy | 0.013 | 0.017 | 0.070 |
| Precious metals | -0.049 | 0.057 | -0.052 |

Latest window (to 2026-09): R2 0.639, commodities' extra R2 0.273; base metals 0.321 (s.e. 0.076).

## Checks, one setting at a time

The first period runs from each run's start to 2005. The window checks change only the rolling
regressions, and the volatility check only the TVP model, so they're missing from the OLS tables.

Base metals ("All metals and minerals" in that check), OLS by period:

| run | to 2005 | 2006-2015 | 2016-2026 |
|---|---|---|---|
| Baseline | 0.122 | 0.086 | 0.319 |
| Start in 1999 | 0.161 | 0.086 | 0.319 |
| Start in 1999, EUR/USD | 0.220 | 0.120 | 0.327 |
| Month-end values | 0.154 | 0.038 | 0.188 |
| Agriculture added | 0.108 | 0.083 | 0.302 |
| US stocks added | 0.134 | -0.055 | 0.280 |
| Platinum for precious | 0.160 | 0.093 | 0.276 |
| Iron ore in (all metals) | 0.107 | 0.106 | 0.315 |
| Without 2008-09 and 2020 | 0.122 | 0.077 | 0.314 |

Precious metals (platinum in that check), OLS by period:

| run | to 2005 | 2006-2015 | 2016-2026 |
|---|---|---|---|
| Baseline | 0.015 | 0.049 | -0.098 |
| Start in 1999 | -0.042 | 0.049 | -0.098 |
| Start in 1999, EUR/USD | 0.011 | 0.084 | -0.061 |
| Month-end values | -0.136 | 0.015 | -0.096 |
| Agriculture added | 0.007 | 0.045 | -0.097 |
| US stocks added | 0.011 | 0.175 | -0.090 |
| Platinum for precious | -0.101 | -0.001 | 0.009 |
| Iron ore in (all metals) | 0.024 | 0.043 | -0.085 |
| Without 2008-09 and 2020 | 0.015 | 0.049 | -0.084 |

Energy, OLS by period:

| run | to 2005 | 2006-2015 | 2016-2026 |
|---|---|---|---|
| Baseline | -0.018 | 0.070 | 0.045 |
| Start in 1999 | -0.014 | 0.070 | 0.045 |
| Start in 1999, EUR/USD | -0.015 | 0.096 | 0.060 |
| Month-end values | -0.012 | 0.036 | 0.057 |
| Agriculture added | -0.016 | 0.067 | 0.040 |
| US stocks added | -0.020 | 0.035 | 0.032 |
| Platinum for precious | -0.009 | 0.070 | 0.050 |
| Iron ore in (all metals) | -0.015 | 0.063 | 0.045 |
| Without 2008-09 and 2020 | -0.018 | 0.083 | -0.008 |

Commodities' extra R2, OLS by period, in percent:

| run | to 2005 | 2006-2015 | 2016-2026 |
|---|---|---|---|
| Baseline | 1.4 | 4.7 | 17.9 |
| Start in 1999 | 1.7 | 4.7 | 17.9 |
| Start in 1999, EUR/USD | 3.7 | 12.7 | 22.7 |
| Month-end values | 1.7 | 1.0 | 6.5 |
| Agriculture added | 1.7 | 4.7 | 18.1 |
| US stocks added | 1.5 | 3.8 | 10.9 |
| Platinum for precious | 2.6 | 4.4 | 17.0 |
| Iron ore in (all metals) | 1.0 | 5.1 | 18.9 |
| Without 2008-09 and 2020 | 1.4 | 4.4 | 13.2 |

Base metals, TVP model, average smoothed coefficient by period:

| run | to 2005 | 2006-2015 | 2016-2026 |
|---|---|---|---|
| Baseline | 0.102 | 0.153 | 0.222 |
| Start in 1999 | 0.118 | 0.150 | 0.219 |
| Start in 1999, EUR/USD | 0.163 | 0.185 | 0.233 |
| Month-end values | 0.086 | 0.099 | 0.132 |
| Agriculture added | 0.091 | 0.142 | 0.214 |
| US stocks added | 0.046 | 0.073 | 0.184 |
| Platinum for precious | 0.121 | 0.164 | 0.221 |
| Iron ore in (all metals) | 0.114 | 0.165 | 0.229 |
| Without 2008-09 and 2020 | 0.088 | 0.147 | 0.243 |
| Volatility allowed to vary | 0.118 | 0.159 | 0.212 |

Base metals, rolling regressions, average coefficient by period:

| run | to 2005 | 2006-2015 | 2016-2026 |
|---|---|---|---|
| Baseline | 0.088 | 0.090 | 0.230 |
| 36-month window | 0.080 | 0.097 | 0.224 |
| 120-month window | 0.111 | 0.093 | 0.206 |
| Start in 1999 | 0.141 | 0.090 | 0.230 |
| Start in 1999, EUR/USD | 0.197 | 0.125 | 0.249 |
| Month-end values | 0.063 | 0.089 | 0.094 |
| Agriculture added | 0.071 | 0.093 | 0.212 |
| US stocks added | 0.103 | -0.002 | 0.202 |
| Platinum for precious | 0.131 | 0.142 | 0.194 |
| Iron ore in (all metals) | 0.082 | 0.079 | 0.251 |
| Without 2008-09 and 2020 | 0.088 | 0.070 | 0.244 |

TVP drift (standard deviation a month) by run:

| run | Constant | Dollar | Precious metals | Base metals | Energy | Agriculture | US stocks | Platinum | All metals and minerals |
|---|---|---|---|---|---|---|---|---|---|
| Baseline | 0.0008 | 0.0008 | 0.0001 | 0.0077 | 0.0077 |  |  |  |  |
| Start in 1999 | 0.0008 | 0.0004 | 0.0002 | 0.0078 | 0.0075 |  |  |  |  |
| Start in 1999, EUR/USD | 0.0008 | 0.0007 | 0.0002 | 0.0063 | 0.0103 |  |  |  |  |
| Month-end values | 0.0013 | 0.0271 | 0.0008 | 0.0052 | 0.0022 |  |  |  |  |
| Agriculture added | 0.0007 | 0.0005 | 0.0001 | 0.0079 | 0.0069 | 0.0004 |  |  |  |
| US stocks added | 0.0001 | 0.0001 | 0.0001 | 0.0099 | 0.0003 |  | 0.0215 |  |  |
| Platinum for precious | 0.0015 | 0.0012 |  | 0.0070 | 0.0073 |  |  | 0.0047 |  |
| Iron ore in (all metals) | 0.0009 | 0.0007 | 0.0001 |  | 0.0077 |  |  |  | 0.0074 |
| Without 2008-09 and 2020 | 0.0016 | 0.0004 | 0.0001 | 0.0096 | 0.0001 |  |  |  |  |
| Volatility allowed to vary | 0.0183 | 0.0455 | 0.0000 | 0.0059 | 0.0097 |  |  |  |  |

