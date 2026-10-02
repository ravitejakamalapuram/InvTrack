# InvTrack findings register (October 2026)

Every finding from the review, grouped by area and sorted by severity. Severity is the verifier's final call. The action item that resolves each finding is listed, and the plan is in [ACTION_PLAN.md](ACTION_PLAN.md). Totals: 280 kept, 1 refuted.

| Area | Critical | High | Medium | Low |
|---|---|---|---|---|
| CALC · Core return formulae (XIRR/MOIC/CAGR/projections/tax) | 1 | 3 | 8 | 4 |
| PLAN · Planning formulae (FIRE/goals/income projection) | 2 | 4 | 7 | 5 |
| ANLY · Aggregate analytics, reports, currency & number presentation | 1 | 2 | 7 | 7 |
| INV · Correctness bugs: investment feature | 1 | 5 | 8 | 6 |
| PLAT · Correctness bugs: auth, settings, import/export, notifications, startup | 0 | 8 | 8 | 2 |
| SEC · Security, privacy & compliance (incl. public-claim accuracy) | 1 | 3 | 7 | 8 |
| ARCH · Architecture, state management, performance & cost | 1 | 3 | 15 | 5 |
| UX · UX, accessibility & localisation | 0 | 3 | 11 | 14 |
| MON · Monetization & business model | 0 | 2 | 7 | 9 |
| MKT · Marketing, positioning & ASO | 1 | 2 | 8 | 8 |
| ADOPT · User adoption, activation, retention & growth loops | 0 | 6 | 8 | 3 |
| QA · Tests, CI/CD, dependencies, repo hygiene & docs accuracy | 0 | 2 | 5 | 14 |
| GAP1 · Archive semantics: archived investments vanish from all money totals, goals, FIRE and FY/tax report | 0 | 3 | 7 | 3 |
| GAP2 · Money stored without a currency (FIRE settings et al.) and the base-currency switch end to end | 0 | 2 | 4 | 2 |
| GAP3 · Notification opt-out integrity and the unreviewed settings screens (consent, trust, in-app update, prod debug tools) | 0 | 4 | 6 | 4 |
| GAP4 · Unit economics: Firebase/FX cost per active user and at scale vs proposed pricing | 0 | 2 | 5 | 3 |

## CALC · Core return formulae (XIRR/MOIC/CAGR/projections/tax)

### CALC-01 · critical · Open investments have no current/terminal value, so XIRR, MOIC, absolute return and portfolio XIRR are badly wrong for every open FD, P2P loan or bond

- **Status:** Confirmed · effort L · action A10
- **Where:** `lib/core/calculations/modules/financial_module.dart:55-119`; `lib/core/calculations/financial_calculator.dart:87-99`; `lib/core/calculations/xirr_solver.dart:150-151`
- **Evidence:** CashFlowType has only invest/returnFlow/income/fee (transaction_entity.dart:7-11). InvestmentEntity has no current-value or valuation field. calculateStats (financial_module.dart:55-119) builds XIRR, MOIC and absolute return only from recorded flows and never adds a dated terminal inflow for status==open. Note the PRD (docs/InvTracker_PRD.md:109,119) specified a 'Current Value' type and FinancialCalculator's own docs (financial_calculator.dart:19,75,301) use a non-existent CashFlowType.currentValue. I ported the …
- **Impact:** Most users of an alt-investment tracker hold open positions (running FDs, P2P, bonds, chit funds). For each of them the headline metrics are wrong: healthy FDs show -75% to -85% IRR in red on the list card, MOIC near 0x, and a -52% portfolio XIRR on the overview. The same stats feed portfolio health, smart insights, the goals and FIRE screens and the XIRR sort. This is the …
- **Fix:** As proposed. Add a dated valuation (CURRENT_VALUE flow or valuation snapshot), with an estimated default for FD/RD from expectedRate and compounding and outstanding principal for P2P/bonds. Append it as a terminal inflow dated today for open investments in XIRR, MOIC and absolute return, and keep 'Net cash position' as a separate, clearly labelled metric. Until that ships, show 'XIRR needs current value' instead of 0.0% or a negative IRR for open positions with no terminal flow.
- **Numeric check:** My python port of xirr_solver.dart, with Excel-style XIRR as the reference. S1: app 0.0, so the UI shows '0.0%', MOIC 0.00x and badge -100.0%. Correct: accrued 1,07,185.90, XIRR 7.186%. S2 (8 quarterly payouts of 1,875 from 2024-10-02): app -75.67% via Newton, MOIC 0.15x. Correct with a 1L terminal value: 7.714%. S3 …

### CALC-03 · high · FIRE progress uses lifetime gross 'totalInvested' as current portfolio value and as monthly savings, which overstates progress whenever capital is recycled

- **Status:** Confirmed · effort M · action A11
- **Where:** `lib/features/fire_number/presentation/providers/fire_providers.dart:86-96`; `lib/features/fire_number/presentation/providers/fire_providers.dart:109-118`; `lib/features/fire_number/presentation/providers/fire_providers.dart:164-167`
- **Evidence:** `final currentPortfolioValue = stats.totalInvested;` (line 92). `_estimateMonthlySavings` returns `stats.totalInvested / months` (line 117). totalInvested is the sum of every INVEST + FEE ever, including closed investments whose capital came back (financial_module.dart:82-84). Python example (aggregates.py): FD of 10L matures and is rolled over twice (10L to 10.75L to 11.556L, recorded as RETURN + INVEST), plus 20k of fees. totalInvested = Rs 32,50,625 while actual deployed capital is Rs 11,55,625, so FIRE …
- **Impact:** FIRE users (a marketed feature) see inflated progress and an earlier FIRE date. Every FD rollover, P2P re-lend or chit-fund cycle compounds the error.
- **Fix:** As proposed. Use the sum over open investments of current value, or max(0, invested - principal returned) per open investment as a fallback. Exclude closed investments. Base monthly savings on trailing-12-month net new money.
- **Numeric check:** Rollover example: 10L + 10.75L + 11.55625L invested plus 20k fees = 32,50,625 counted by the app, against about 11,55,625 actually deployed, an overstatement of 2.81x. A single closed P2P loan of 10L, fully repaid, contributes 10L to FIRE progress in the app versus 0 correct.

### CALC-04 · high · Investment list card shows unconverted (native-currency) amounts and XIRR under the base-currency symbol, while the detail screen shows converted values

- **Status:** Confirmed · effort M · action A13
- **Where:** `lib/features/investment/presentation/widgets/investment_card.dart:50-62`; `lib/features/investment/presentation/widgets/investment_card.dart:421-445`; `lib/features/investment/presentation/providers/investment_stats_provider.dart:21-66`
- **Evidence:** The card watches investmentBasicStatsProvider and investmentXirrProvider (card lines 57, 62). These call calculateStats / calculateXirrFromCashFlows on raw CashFlowEntity amounts with no FX step (stats provider lines 61, 77). The card then formats with currencyFormatProvider, which is the base currency (line 50). The detail screen uses multiCurrencyInvestmentStatsProvider, which converts at historical rates (detail screen line 72). The list sort for non-XIRR keys also uses the raw map (list_state lines 196-224), …
- **Impact:** NRI and multi-currency users (a marketed 40+ currency feature) see two different numbers for the same investment, and amount sorting is in mixed units. Both undermine trust.
- **Fix:** As proposed: back the card and all sorts with one batched, converted stats map.
- **Numeric check:** $1,000 on 2024-10-01 returned as $1,100 on 2026-10-01. Card: '+₹100' and XIRR (1.1)^(1/2)-1 = 4.88%. Detail at 83.8 and then 88.0: -83,800 and +96,800, net +₹13,000, XIRR (96800/83800)^(1/2)-1 = 7.48%.

### CALC-05 · high · Missing currency silently defaults to 'USD' (CSV import, Firestore reads, notifier), so INR amounts get converted as dollars; failed FX lookups silently keep unconverted amounts

- **Status:** Confirmed · effort S · action A03
- **Where:** `lib/features/bulk_import/data/services/simple_csv_parser.dart:268-276`; `lib/features/bulk_import/presentation/screens/import_confirmation_screen.dart:99-100`; `lib/features/settings/data/services/data_import_service.dart:461-462`
- **Evidence:** The CSV parser treats a missing or empty Currency column as `'USD'` (simple_csv_parser.dart:274-275). The import screen uses `row.currency ?? 'USD'`, and Firestore deserialisation uses `data['currency'] as String? ?? 'USD'`. For an Indian user (base INR) who imports a bank or Excel CSV without a Currency column, every amount is stored as USD. The multi-currency providers then multiply by about 88: Rs 1,00,000 shows as about Rs 88,00,000 on Overview and Detail, while the card (CALC-04) shows the raw Rs 1L. …
- **Impact:** Overview totals, FIRE and goals become roughly 88x too large for INR-denominated imports, which is India's primary use case for bulk import. FX outages produce silently mixed-unit XIRR and totals.
- **Fix:** As proposed. Default to currencyCodeProvider at parse and import time, also set the investment's currency on import, show the assumed currency on the confirmation screen, and backfill missing currency fields with the user's base currency rather than USD. Exclude flows with no resolvable rate and show a banner.
- **Numeric check:** An INR-base user imports a CSV without a Currency column containing an INVEST of 1,00,000. It is stored as USD 1,00,000 and converted at about 88, so Overview, FIRE and Goals show about ₹88,00,000, while the card (CALC-04) shows ₹1,00,000.

### CALC-02 · medium · Portfolio health 'Returns' score averages per-investment XIRRs (invested-weighted) instead of using a merged-flow portfolio XIRR; Performance report uses a simple average

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A21
- **Where:** `lib/features/portfolio_health/domain/services/portfolio_health_calculator.dart:98-153`; `lib/features/portfolio_health/presentation/providers/portfolio_health_provider.dart:66-83`; `lib/features/reports/data/services/performance_report_service.dart:43-56`
- **Evidence:** The health calculator sums `weightedXirr += stat.xirr * stat.totalInvested` and computes `avgXirr = weightedXirr / totalInvested` (lines 104, 119). PerformanceReportService computes `averageXIRR = totalXIRR / performances.length` (line 85). It also sets currentValue = |totalInvested - totalReturned| (lines 46, 56), which is not a value at all. Python example (scratchpad/CALC/aggregates.py): A is Rs 10L at 8% for 1 year; B is Rs 10k with a 3% gain in 30 days (XIRR 43.28%). Simple average = 25.64%, invested-weighted …
- **Impact:** The Portfolio Health score is a headline engagement feature and tells typical Indian FD/P2P users their money is losing value. Averaging IRRs is mathematically invalid: it ignores timing and amounts, and a tiny short-dated position can swing the score. The performance report is currently unreachable from the UI (only the provider defines it), but would mislead if wired up.
- **Fix:** Fix CALC-01 first; it drives the 'negative returns' message. Then compute the returns component as one XIRR over merged base-currency flows plus terminal values. Delete PerformanceReport.currentValue or redefine it before wiring the performance report into the UI.
- **Numeric check:** A: -10L to +10.8L over 1 year, XIRR 8.000%. B: -10k to +10.3k over 30 days, XIRR 43.28%. Simple average 25.64%, invested-weighted 8.349%, merged-flow 8.024%. Score formula for avgXirr -16.7%: 20 + (-0.167/0.20)*20 = 3.3, as the reviewer stated.
- **Verifier:** The code matches the description. portfolio_health_calculator.dart:101-119 computes avgXirr = sum(xirr*totalInvested)/sum(totalInvested), and performance_report_service.dart:83-85 takes a simple average with currentValue = |invested - returned| (lines 46, 56). The health provider does use …

### CALC-06 · medium · Unlabelled 'approximate return' fallback, absurd annualisation of very short holdings, and >1000% XIRR displayed as '0.0%'

- **Status:** Confirmed · effort M · action A09
- **Where:** `lib/core/calculations/xirr_solver.dart:253-259`; `lib/core/calculations/xirr_solver.dart:371-378`; `lib/core/calculations/xirr_solver.dart:429-475`
- **Evidence:** When no root lies in [-0.99, 10], `_bisection` returns `_calculateApproximateReturn`, a CAGR on (total in / total out) over the first-to-last span that ignores intermediate timing. The result goes to the UI exactly like a real XIRR, with no flag. The python port shows this path is taken for the S4 portfolio in CALC-01 (-52.6%). The `simpleReturn < -1` branch (line 471) is unreachable because inflows are always >= 0. Short-holding results from the port (edge.py): a 1-day 0.5% gain shows '+517.5%'; a 10-day 3% gain …
- **Impact:** Invoice-discounting and P2P users (30-90 day tenures, a core segment) see wildly annualised figures. A 1000%+ IRR is shown as 0.0%, and a timing-blind approximation is presented as XIRR.
- **Fix:** Return a result type, for example XirrResult {value, method: exact|approximate|undefined, reason}, instead of a bare double that maps null to 0.0. In the UI: (a) when holding period < 365 days (or < 90), show the absolute return as the primary figure with 'annualised' secondary, or show the XIRR with an info badge; (b) show '>1000%' instead of '0.0%' or blank; (c) label approximate results 'approx.'; (d) show '-' when undefined. Remove the dead `simpleReturn / timeSpanYears` branch. Example: -1L then +1.02L three days later should display 'Return +2.0% (3 days)' with 'annualised >1000%' as a tooltip.
- **Numeric check:** From my port: a 1-day 0.5% gain gives 517.47% (Newton). A 10-day 3% gain gives 194.14% (Newton). A 3-day 2% gain gives 1012.64% through the APPROX path, which the UI displays as '0.0%' on detail and hero and as blank on the card. The S4 portfolio takes the APPROX path and shows -52.58%.

### CALC-07 · medium · MOIC and absolute return double-count rolled-over capital (and silently include fees in 'invested')

- **Status:** Confirmed · effort S · action A15
- **Where:** `lib/core/calculations/modules/financial_module.dart:82-86`; `lib/core/calculations/modules/financial_module.dart:101-103`; `lib/features/investment/domain/entities/investment_stats.dart:191-195`
- **Evidence:** totalInvested sums every negative signed amount and totalReturned every positive one (financial_module.dart:82-86). MOIC = totalReturned / totalInvested. An FD rollover recorded the natural way (RETURN 10.75L and INVEST 10.75L on the same day, inside one investment) is netted correctly by XIRR, because same-day grouping in xirr_solver.dart:164-176 gives 7.49% (python check). MOIC and absolute return are not netted: invested = 10L + 10.75L = 20.75L and returned = 10.75L + 11.556L = 22.31L, so MOIC = 1.075x and …
- **Impact:** Any reinvested or recycled position (FD auto-renewal, P2P re-lending, chit funds) under-reports its multiple and absolute return, which is inconsistent with the XIRR shown beside it.
- **Fix:** Define paid-in capital as the peak cumulative net outflow, max over t of sum(outflows - inflows up to t), or net out same-day RETURN/INVEST pairs before summing. Then MOIC = (sum of distributions + current value - recycled amount) / paid-in. Document that fees are part of paid-in (net MOIC). Rollover example: paid-in 10L, value 11.556L, MOIC 1.156x, absolute 15.6%.
- **Numeric check:** Flows: -10L on 2023-01-01, +10.75L and -10.75L on 2024-01-01, +11.55625L on 2025-01-01. XIRR 7.489% (netted). App: invested 20.75L, returned 22.30625L, MOIC 1.075x, absolute return 7.5%. True cumulative: 1.1556x and 15.56%.

### CALC-08 · medium · FD/RD projector: annual compounding when none chosen, lump-sum formula used for Recurring Deposits, fractional-quarter compounding, months-only tenure

- **Status:** Confirmed · effort M · action A16
- **Where:** `lib/core/calculations/investment_projector.dart:16-41`; `lib/core/calculations/investment_projector.dart:28`; `lib/core/calculations/investment_projector.dart:68`
- **Evidence:** `final periodsPerYear = compounding?.periodsPerYear ?? 1;` falls back to annual. Choosing the Fixed Deposit type without a template (add_investment_screen.dart:446 only sets _selectedType) leaves _compoundingFrequency null. Python (projector.py) at 7%: 1y gives 1,07,000 vs bank quarterly 1,07,186; 5y gives 1,40,255 vs 1,41,478, an error of Rs 1,223 per lakh. The RD template (investment_template.dart:157-172) runs through the same lump-sum formula, so the 'Per Rs1L' card says interest Rs 6,660. For Rs 1L deposited …
- **Impact:** New users see wrong 'Estimated Returns' on the add form. RD projections are badly overstated. The projector is also the natural engine for CALC-01 accrued values, so these errors would propagate.
- **Fix:** Default FD compounding to quarterly (RBI/bank convention) when type is fixedDeposit and nothing is chosen. Add an RD formula, M = sum over k of I*(1+r/4)^((n-k)/3) for k = 0..n-1, used when the template is RD or a recurring flag is set. Compound full quarters and pay simple interest on the residual days. Use simple interest for tenures under 6 months. Accept tenure in days. Show the projection for the user's actual principal once the first INVEST exists.
- **Numeric check:** At 7% for 1 year: annual 1,07,000 vs quarterly 1,07,185.90. At 5 years: 1,40,255.17 vs 1,41,477.82, a difference of ₹1,223 per lakh. RD at 6.5% quarterly over 12 months: app shows interest 6,660.16; the correct installment formula (sum of 8,333.33*(1.01625)^(n/3) for n=1..12, minus 1L) gives 3,572.05, so the app …

### CALC-09 · medium · TaxAndBasisCalculator fabricates capital gains (flat 10% of every RETURN) with a single 365-day rule; it does not match Indian tax law as of Oct 2026, and tests pin the wrong behaviour

- **Status:** Confirmed · effort L · action A60
- **Where:** `lib/core/calculations/tax_and_basis_calculator.dart:74-103`; `lib/features/reports/data/services/fy_report_service.dart:225-239`; `lib/features/reports/domain/entities/fy_report.dart:57-104`
- **Evidence:** `final gain = cf.amount * assumedGainPercentage;` (default 0.10, and FY service passes 0.10 at line 237), with `if (holdingDays < 365) short else long`. Holding is measured from investment start, not from the lot sold. Every RETURN is counted, including FD/P2P/bond principal repayments that are not capital gains at all. Example: a Rs 5L FD maturing with RETURN 5.4L is reported as Rs 54,000 of capital gains; the real figure is Rs 0 capital gains and Rs 40,000 of slab-taxed interest. FYReport.totalTaxableIncome then …
- **Impact:** If FY/tax reports are surfaced (a stated product feature), Indian users would get fabricated STCG/LTCG figures, a legal-adjacent risk that would also embarrass the app in ITR season.
- **Fix:** As proposed. Before wiring FY reports, remove the assumed-gain approach or hide the capital-gains section, and replace the test that pins the assumed percentage.
- **Numeric check:** A ₹5L FD maturing with RETURN 5.4L becomes 5.4L*0.10 = ₹54,000 of 'capital gains'. Correct: 0 capital gains and ₹40,000 of interest taxed at slab rates.

### CALC-10 · medium · FY report window double-counts 31-Mar and 1-Apr flows, and FY XIRR ignores opening and closing portfolio value

- **Status:** Confirmed with corrections · effort M · action A60
- **Where:** `lib/features/reports/data/services/fy_report_service.dart:42-68`; `lib/features/reports/data/services/fy_report_service.dart:213-222`; `lib/features/reports/data/services/fy_report_service.dart:310-366`
- **Evidence:** Here startLimit = fyStart - 1 day (31-Mar 00:00) and endLimit = fyEnd + 1 day (1-Apr 23:59:59 of the next year), filtered with isAfter/isBefore. Python check (fy_window.py): a flow at 2025-04-01 00:00 is counted in both FY2024-25 and FY2025-26, and a flow at 2025-03-31 10:15 is also counted in both. Add-transaction defaults to DateTime.now() with a time of day (add_transaction_screen.dart:62). The 1-Apr flow falls into FY2024-25 totals but into no monthly bucket, so totals do not equal the sum of months. …
- **Impact:** Latent today (FY report renders empty sections), but 1-Apr is the commonest date for Indian FD maturities and FY-start investments, so once wired up every FY total near the boundary would be double-counted, and FY XIRR would be meaningless.
- **Fix:** As proposed, but drop the INCOME-in-portfolio-value point. Fix the hard-coded FY label now, since it is user-visible; fix the rest before wiring the FY report.
- **Numeric check:** FY2024-25 window: (2024-03-31 00:00, 2025-04-01 23:59:59). FY2025-26 window: (2025-03-31 00:00, 2026-04-01 23:59:59). A flow at 2025-04-01 00:00 and a flow at 2025-03-31 10:15 both fall inside both windows.
- **Verifier:** The window bug is real. startLimit = 31-Mar 00:00 of fyYear and endLimit = 1-Apr 23:59:59 of fyYear+1, filtered with isAfter/isBefore (fy_report_service.dart:62-66). So a 1-Apr 00:00 flow is counted in both adjacent FYs, and a 31-Mar flow with a time of day is counted in both. A 31-Mar 00:00 flow (date-picker default) …

### CALC-14 · medium · Calculation tests are loose and pin incorrect behaviour; key scenarios untested

- **Status:** Confirmed · effort M · action A19
- **Where:** `test/core/calculations/xirr_solver_test.dart:7-20`; `test/core/calculations/xirr_solver_test.dart:151-162`; `test/core/calculations/tax_and_basis_calculator_test.dart:100-145`
- **Evidence:** XIRR tests use closeTo(x, 0.01), a ±1 percentage point tolerance, with no Excel-pinned golden values. 'should handle all outflows' accepts `anyOf(isNull, lessThan(0))`, which bakes in the CALC-01 behaviour. The tax test asserts shortTerm == 300.0 (the fabricated 10%). The FY filter test avoids the 31-Mar and 1-Apr boundaries. Nothing tests open investments with a terminal value, short-holding display, >1000% display, card-vs-detail currency parity, rollover MOIC, or the RD projection.
- **Impact:** Regressions in money math can ship unnoticed, and fixes for CALC-01, CALC-07 and CALC-09 will conflict with tests that assert the wrong behaviour.
- **Fix:** Add a golden-file suite of 20-30 cash-flow series with Excel XIRR to 1e-6 (including S1-S4 from CALC-01, rollover, short holding, multi-root), FY boundary tests, and projector cases checked against bank calculators. Rewrite the tests that pin the 10% assumed gain and the null XIRR for open investments.

### CALC-V01 · medium · New transactions default to the user's base currency, not the investment's currency, so payouts on a foreign-currency investment are silently recorded in the base currency

- **Status:** Added by verifier · effort S · action A03
- **Where:** `lib/features/investment/presentation/screens/add_transaction_screen.dart:80-82`; `lib/features/investment/presentation/screens/add_transaction_screen.dart:386-388`
- **Evidence:** initState says '// Default to investment's currency for new cash flows // We'll fetch this from the investment in the build method' and then sets `_selectedCurrency = ref.read(currencyCodeProvider);`, the base currency. Nothing in build() or anywhere else in the file reassigns _selectedCurrency from the investment; the only other write is the manual selector at line 388.
- **Impact:** An INR-base user with a USD investment who adds a $50 interest payout without changing the selector stores ₹50, which understates income about 88x in the converted totals and makes XIRR and MOIC for that investment wrong. Every cash flow added to a non-base-currency investment needs a manual currency change.
- **Fix:** Read the investment (investmentByIdProvider) and default _selectedCurrency to investment.currency for new cash flows. Show a warning when the chosen currency differs from the investment's currency.

### CALC-11 · low · XIRR day count floors millisecond differences of non-normalised local DateTimes (time of day and DST give 364 instead of 365 days)

- **Status:** Confirmed · effort S · action A15
- **Where:** `lib/core/calculations/xirr_solver.dart:156-176`; `lib/features/investment/presentation/screens/add_transaction_screen.dart:62`; `lib/features/investment/presentation/providers/investment_notifier.dart:432-441`
- **Evidence:** `t = ((ms - firstMs) ~/ 86400000) / 365.0`. The convention is Excel's actual/365, which is correct, but stored dates keep their time of day: the default `DateTime _selectedDate = DateTime.now()` is never normalised before save. Python check (edge.py): invest on 2025-04-01 at 21:30 and return Rs 1.08L on 2026-04-01 at 00:00. The floor gives 364 days and XIRR 8.0228%, versus Excel's 8.0000%. DST zones (NRI users) lose an hour across a spring-forward, with the same off-by-one-day effect.
- **Impact:** Small XIRR deviations (about 0.02pp per year, larger for short holdings) versus the spreadsheets users compare against; also feeds the FY boundary bug in CALC-10.
- **Fix:** Normalise all cash-flow dates to date-only on save (DateTime.utc(y,m,d)). In the solver use day = DateTime.utc(d.year,d.month,d.day).difference(DateTime.utc(d0...)).inDays, then /365.0. Add an Excel-parity golden test pinned to 1e-6.
- **Numeric check:** Invest 2025-04-01 21:30, receive 1.08L on 2026-04-01 00:00. The app counts 364 days, giving XIRR 8.0228%; Excel's date-only XIRR is 8.0000%.

### CALC-12 · low · Duration and maturity helpers are inconsistent: duration never extends to today for open investments, and the entity maturity date overflows month ends

- **Status:** Confirmed · effort S · action A15
- **Where:** `lib/features/investment/domain/entities/investment_stats.dart:250-256`; `lib/features/investment/presentation/widgets/investment_detail_stats_section.dart:68`; `lib/features/investment/domain/entities/investment_entity.dart:360-370`
- **Evidence:** durationYears uses `lastCashFlowDate ?? DateTime.now()`, but lastCashFlowDate is always set whenever firstCashFlowDate is, so the documented 'to now if ongoing' never happens. An open FD with one INVEST a year ago shows MOIC subtitle '<1mo'. InvestmentEntity.calculatedMaturityDate builds DateTime(y, m+tenure, d), which Dart normalises: 31-Jan + 1 month gives 3-Mar, and 31-Aug + 6 months gives 3-Mar (python check). InvestmentProjector.calculateMaturityDate correctly clamps to 28/29-Feb. Health liquidity scoring …
- **Impact:** Wrong holding-period subtitle on every open single-flow investment; maturity/liquidity buckets off by a few days at month ends.
- **Fix:** Duration end = today for open investments and the closedAt / last flow for closed ones. Make calculatedMaturityDate delegate to InvestmentProjector.calculateMaturityDate.
- **Numeric check:** DateTime(2026, 2, 31) normalises to 2026-03-03, a 3-day overshoot. Single INVEST one year ago: span 0 days, shown as '<1mo' instead of '1.0y'.

### CALC-13 · low · No money rounding policy: float accumulation can flip the sign of break-even positions

- **Status:** Confirmed · effort S · action A15
- **Where:** `lib/core/calculations/modules/financial_module.dart:82-86`; `lib/core/calculations/financial_calculator.dart:240-242`; `lib/features/investment/presentation/widgets/investment_card.dart:411-435`
- **Evidence:** Amounts are doubles summed with no rounding to paise. Python: ten payouts of Rs 10.10 sum to 100.99999999999999. Against an invest of Rs 101.00, net = -1.4e-14, so `isPositive = stats.netCashFlow >= 0` is false and the card shows '-Rs0' in red with the trending-down icon and '-0.0%'. Rupee-level sums are otherwise exact enough.
- **Impact:** Cosmetic but trust-eroding on fully repaid P2P loans and break-even closes.
- **Fix:** Round aggregates to 2 decimals (or store integer paise), and treat |net| < 0.005 as zero for sign and colour.
- **Numeric check:** sum([10.10]*10) = 100.99999999999999. Net against 101.00 = -1.42e-14, so the card shows '-₹0' in red.

### CALC-15 · low · Calculator API hygiene: null XIRR collapses to 0.0, CAGR is unused and can return NaN, and docs reference non-existent cash-flow types

- **Status:** Confirmed · effort S · action A09
- **Where:** `lib/core/calculations/financial_calculator.dart:17-19`; `lib/core/calculations/financial_calculator.dart:75`; `lib/core/calculations/financial_calculator.dart:98`
- **Evidence:** `XirrSolver.calculateXirr(...) ?? 0.0` (financial_calculator.dart:98 and financial_module.dart:15) makes 'undefined' indistinguishable from a true 0%. calculateCAGR has no call sites outside lib/core/calculations; it returns 0.0 for invalid input and NaN when endValue < 0, since pow of a negative base with a fractional exponent. Doc comments use CashFlowType.buy, .dividend and .currentValue, none of which exist. The XIRR header claims 'Total loss: returns approximate annualized loss rate' through a branch that …
- **Impact:** Misleading for future contributors and AI-assisted edits; 0.0 masking is the root cause of the '0.0%' displays in CALC-01 and CALC-06.
- **Fix:** Return double? (or a XirrResult) through FinancialCalculator and the module, and render '-' for null. Delete or guard calculateCAGR, and use it only for single-lump-sum displays. Fix the doc examples to use invest/income/returnFlow.

## PLAN · Planning formulae (FIRE/goals/income projection)

### PLAN-01 · critical · FIRE 'current portfolio' is lifetime gross INVEST+FEE, so principal that has matured or been reinvested is counted again

- **Status:** Confirmed · effort M · action A11
- **Where:** `lib/features/fire_number/presentation/providers/fire_providers.dart:89-97`; `lib/features/fire_number/presentation/providers/fire_providers.dart:166`; `lib/features/investment/presentation/providers/multi_currency_providers.dart:258-285`
- **Evidence:** fire_providers.dart:92 has `final currentPortfolioValue = stats.totalInvested;`, where stats comes from multiCurrencyGlobalStatsProvider. InvestmentStats.totalInvested is documented as 'Sum of INVEST + FEE (money out)' across validCashFlowsProvider, which includes every non-archived investment, open or CLOSED. RETURN flows (matured principal coming back) are never subtracted. generateProjections (line 166) uses the same number.
- **Impact:** This hits anyone who rolls over FDs, P2P, bonds or chit funds, which is the core audience. I ported the code to Python (scratchpad/PLAN/fire.py, scenario S3). A ₹10L FD is renewed every year at 7% from 2020 (6 INVEST flows, each matching the previous RETURN). The app sums ₹71.5L of 'portfolio', but the user actually holds ₹14.0L. With default settings (FIRE number ₹1.83Cr) the …
- **Fix:** As proposed. Measure the portfolio as net deployed capital of OPEN investments: sum of max(0, INVEST - RETURN) per investment, with an optional accrual at expectedRate. Exclude FEE. Add a manual 'other assets' field. Show how the portfolio figure is built in the UI.
- **Numeric check:** My own python port (scratchpad/PLAN-verify/fire.py): a 10L FD rolled over yearly at 7%, 6 INVEST flows from 2020 to 2025. The app's totalInvested is Rs 71,53,291. Default FIRE number = 1.5Cr core + 3L emergency + 30L healthcare = Rs 1,83,00,000, so the app shows 39.09% progress. Coast number is 80.1L and 71.5L is …

### PLAN-08 · critical · Corpus goal progress counts only money received back (RETURN+INCOME), so funded goals show near 0% and projections are years off

- **Status:** Confirmed · effort M · action A12
- **Where:** `lib/features/goals/presentation/providers/goal_progress_provider.dart:36-39`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:114-127`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:165-199`
- **Evidence:** _calculateNetValue sums cf.amount for every type other than INVEST and FEE. The comment says 'net value (returns + income - invested - fees)', but nothing is subtracted or added for invested capital. Velocity is (RETURN+INCOME) ÷ months since first flow, and projection is linear: `remaining / monthlyVelocity` × 30 days. GoalType.targetAmount is described as 'Accumulate a specific corpus'. The FAQ string promises 'show how much you need to save', but there is no required-contribution calculation anywhere in …
- **Impact:** Scenario G1 (scratchpad/PLAN/goals.py): goal '₹10L corpus', with ₹10L placed in a 7.5% quarterly-payout FD in Jan 2025. As of 2 Oct 2026 the goal shows ₹1.31L of ₹10L (13.1%) and 'On track for Sep 2038'. The user has actually held ₹10L since day 1. When a cumulative FD matures, progress jumps from 0% to 100% in one step and fires milestone notifications. The weekly 'Goal at …
- **Fix:** As proposed. Value corpus goals at net deployed capital of open linked investments plus accrual (or a user-entered value). Project with compounding. Add a 'required per month' figure. Update the tests that encode returns-only semantics.
- **Numeric check:** G1: 10L FD at 7.5% with quarterly payouts of Rs 18,750, start 1 Jan 2025. 7 payouts by 2 Oct 2026 = Rs 1,31,250, i.e. 13.1%. Velocity = 131,250/22 months = Rs 5,966/mo, so the projected date is 2038-09-18 (the app's linear formula). The user has actually held 10L since day 1, which is 100%. Required-PMT example: 10L …

### PLAN-02 · high · FIRE monthly savings is guessed as totalInvested ÷ days between first and last cash flow, which explodes for new users and is zero for single-flow users

- **Status:** Confirmed (reviewer said critical) · effort S · action A11
- **Where:** `lib/features/fire_number/presentation/providers/fire_providers.dart:96`; `lib/features/fire_number/presentation/providers/fire_providers.dart:109-118`; `lib/features/fire_number/presentation/providers/fire_providers.dart:167`
- **Evidence:** `final months = stats.lastCashFlowDate!.difference(stats.firstCashFlowDate!).inDays / 30; if (months <= 0) return 0; return stats.totalInvested / months;`. This uses gross lifetime invested (recycled principal included), divides by the span ending at the LAST cash flow rather than today, and returns 0 when all flows fall on the same day.
- **Impact:** New users get absurd projections on their first screens. Scenario S2: two ₹5L INVEST flows on 20 and 30 Sep 2026 give months = 0.333 and savings = ₹30,00,000/month. The app then shows projected FIRE age 31 (current age 30) and monthlyGap = −₹29.4L. A user who logs one lump sum gets savings = 0 and FIRE age 100. A long-tenure user with recycled FDs (S3) gets ₹97,900/month of …
- **Fix:** Use trailing-12-month net new money (INVEST - RETURN of principal, today-anchored, floored at 0) or a user-declared monthly SIP. Show 'not enough history' when history is under about 3 months. Note in the copy that Need/Month is independent of this estimate.
- **Numeric check:** S2: two 5L INVEST flows 10 days apart give months = 0.333 and savings = Rs 30,00,000/mo. With PV 10L the app projects age 31 (5.69 months to target). requiredMonthlySavings = Rs 56,511 and monthlyGap = -Rs 29,43,489. With a declared Rs 50k/mo the projected age is 47 (194 months). A single-date user gets savings = 0 …

### PLAN-03 · high · Projected FIRE age is hard-coded to 100 when savings are 0 (ignores compounding), and the projected date is rounded up to whole years

- **Status:** Confirmed · effort S · action A11
- **Where:** `lib/features/fire_number/domain/services/fire_calculation_service.dart:226-263`; `lib/features/fire_number/domain/services/fire_calculation_service.dart:120-125`; `lib/features/fire_number/presentation/screens/fire_dashboard_screen.dart:409-412`
- **Evidence:** Line 234: `if (monthlySavings <= 0) return 100; // Never if not saving`. Line 262: `return currentAge + (months / 12).ceil();`, capped at 600 months (age+50). Lines 121-124: `projectedFireDate = DateTime.now().add(Duration(days: (projectedFireAge - settings.currentAge) * 365))`, so the date is derived from the rounded-up age, not from the computed months.
- **Impact:** Scenario S4: a ₹50L corpus with zero (or not-yet-estimable, see PLAN-02) savings shows 'Projected FIRE Age: Age 100'. With the default 5.66% real return the corpus reaches ₹1.83Cr in ln(183/50)/ln(1+0.0566/12)/12 = 22.98 years, i.e. age 53. A 13-month solve displays as now + 730 days (Oct 2028) instead of Nov 2027. Any result past 50 years is silently displayed as age+50.
- **Fix:** As proposed. Solve months for PMT = 0 with ln(FV/PV)/ln(1+r). Build the date from months using addMonths with clamping. Show 'not reachable' instead of 'Age 100'/age+50.
- **Numeric check:** S4: PV 50L, PMT 0, real return 5.660% (Fisher: 1.12/1.06 - 1). n = ln(183/50)/ln(1+0.0566/12)/12 = 22.976 years, i.e. age 53 versus the app's 100. A 13-month solve gives ceil(13/12) = 2 years, i.e. now + 730 days, not now + 13 months.

### PLAN-04 · high · FIRE status ignores the timeline, and the 'Action Needed' card tells users with a surplus to invest more

- **Status:** Confirmed · effort S · action A11
- **Where:** `lib/features/fire_number/domain/services/fire_calculation_service.dart:274-299`; `lib/features/fire_number/presentation/screens/fire_dashboard_screen.dart:499-562`; `lib/features/fire_number/presentation/screens/fire_dashboard_screen.dart:355-366`
- **Evidence:** Status comes only from progress %: `>=75 ahead`, `>=25 onTrack`, else `behind`. yearsToFire is passed in but unused, and the enum docs ('More than 20% behind schedule') describe a schedule comparison that does not happen. For non-positive statuses the card renders `'Invest ${formatCompactCurrency(monthlyGap.abs(), ...)}/month more to stay on track.'`, with monthlyGap = required − current, which can be negative.
- **Impact:** Scenario S5: age 28, target 50, 20% funded, saving ₹60k/month against ₹10.8k required (projected FIRE at 40, 10 years early). The app shows an amber 'Behind Schedule' badge and 'Invest ₹49.2K/month more to stay on track'. ₹49.2K is the user's surplus. With the inflated savings from PLAN-02, almost every new user sees this contradictory advice. 'On Track' users are told 'you'll …
- **Fix:** As proposed. Base status on projected versus target age, and render 'Invest X more' only when monthlyGap > 0.
- **Numeric check:** S5: age 28, target 50, PV = 20% of 1.83Cr = 36.6L. Coast number = 54.5L, PV is below it, so status = behind. Required = Rs 10,765/mo, actual 60k gives a gap of -49.2K, and the card says 'Invest Rs 49.2K/month more'. The projected age at 60k/mo is 40. S2 likewise: status behind (5.5%), gap -29.4L, card says 'Invest Rs …

### PLAN-09 · high · Income goal 'monthly income' averages over the span between first and last payout, inflating lumpy (annual or quarterly) income up to 12x; its projection mixes units

- **Status:** Confirmed · effort S · action A12
- **Where:** `lib/features/goals/presentation/providers/goal_progress_provider.dart:129-163`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:52-64`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:309-321`
- **Evidence:** `daysDiff = (maxDateMs - minDateMs) ~/ 86400000; monthsDiff = (daysDiff / 30.0).ceil(); months = max(1, monthsDiff); return totalIncome / months;`. For income goals, projectedDate = (targetMonthlyIncome − monthlyIncome) ÷ monthlyVelocity, where velocity is total RETURN+INCOME rupees per month. Milestone notifications pass `targetValue: goal.targetAmount` (the corpus field) even for income goals.
- **Impact:** G2: a ₹10L bond paying ₹75,000 once a year gives a computed monthly income of ₹75,000 instead of ₹6,250. A '₹10k/month passive income' goal shows 100% 'Goal Achieved! 🎉' and sends the achievement notification. G3: two quarterly ₹18,750 payouts give ₹9,375/month instead of ₹6,250 (50% high). Income from investments closed years ago still counts (G5: ₹20.7k/month from a closed …
- **Fix:** As proposed. Use trailing-12-month INCOME/12, or a forward run-rate per open investment. Exclude closed investments. Do not compute a linear date from mixed units. Pass targetMonthlyIncome to notifications.
- **Numeric check:** G2: a single Rs 75,000 annual payout gives months = 1 and Rs 75,000/mo, versus a true Rs 6,250/mo. A 10k/mo goal then shows as achieved. G3: two quarterly Rs 18,750 payouts 91 days apart give ceil(3.03) = 4 and Rs 9,375/mo, versus a true Rs 6,250 (+50%). These match the reviewer.

### PLAN-05 · medium · FIRE stores a fixed 'current age' that never advances, so years-to-FIRE, required savings and coast number freeze at setup time

- **Status:** Confirmed (reviewer said high) · effort S · action A11
- **Where:** `lib/features/fire_number/domain/entities/fire_settings_entity.dart:137`; `lib/features/fire_number/domain/entities/fire_settings_entity.dart:181`; `lib/features/fire_number/presentation/screens/fire_setup_screen.dart:36-37`
- **Evidence:** `final int currentAge;` is persisted, and `int get yearsToFire => targetFireAge - currentAge;`. There is no birth date or year, and no adjustment by createdAt/updatedAt. The dashboard shows '$yearsToFire years left'.
- **Impact:** Example: a user set up in Oct 2024 at age 30, target 45, with a ₹20L portfolio. In Oct 2026 the app still says '15 years left', 'Need/Month ₹48,255' and coast number ₹80.1L. The true figures for 13 years are ₹61,518/month (27% more) and coast ₹89.5L. The plan quietly gets more optimistic every year for every long-term user.
- **Fix:** Store birthYear/DOB and derive age at calculation time. Migrate with birthYear = createdAt.year - currentAge. Prompt the user when the target age has passed.
- **Numeric check:** PV 20L, defaults. 15 years gives required Rs 48,255/mo and coast Rs 80.13L. 13 years gives Rs 61,518/mo (+27.5%) and coast Rs 89.45L. These match the reviewer.

### PLAN-06 · medium · FIRE number is 30.5x expenses, not the '25x' the UI claims; buffers are hidden; 4% SWR default is aggressive for India; several FIRE inputs are dead

- **Status:** Confirmed with corrections · effort M · action A11
- **Where:** `lib/features/fire_number/domain/services/fire_calculation_service.dart:42-68`; `lib/features/fire_number/domain/entities/fire_settings_entity.dart:136-171`; `lib/features/fire_number/domain/entities/fire_settings_entity.dart:53-66`
- **Evidence:** The FIRE number is core (annual × 100/SWR) + emergencyMonths (default 6) × monthly expenses + healthcareBuffer (default 20%) × core. Neither buffer is editable in the setup or settings screens, and the breakdown fields (coreRetirementCorpus, emergencyFundNeeded, healthcareCorpusNeeded) are never displayed. The tooltip says 'Based on 25x your annual expenses' regardless of SWR. SWR defaults to 4.0. postRetirementReturn, lifeExpectancy, monthlyPassiveIncome and expectedPension are never used in calculations or …
- **Impact:** Default user (₹50k/month expenses) sees a FIRE number of ₹1.83Cr, which is 30.5x annual expenses (effective SWR 3.28%), next to text saying 25x. They cannot reconcile or adjust it. If they choose SWR 3% (closer to Indian research), it rises to ₹2.43Cr, a 33% jump with no explanation. Choosing 'Barista FIRE' or 'Coast FIRE' gives the same target as Regular.
- **Fix:** Show the breakdown and use the real multiplier in the copy. Make the buffers editable or remove them. Either expose passive income/pension (already wired into the formula) or remove them. Implement or remove the Coast/Barista types. Delete the unused projection providers. A 3.5% SWR default for INR is a reasonable product choice but not a defect.
- **Numeric check:** Rs 50k/mo: core 1.5Cr + healthcare 30L + emergency 3L = Rs 1.83Cr = 30.5x annual expenses (effective SWR 3.28%). SWR 3% gives Rs 2.43Cr (+32.8%).
- **Verifier:** Confirmed: FIRE number = core x (1 + 20%) + 6 months of expenses, i.e. 30.5x annual expenses. The tooltip in fire_stats_card.dart:53 hard-codes 'Based on 25x'. The healthcare and emergency buffers, postRetirementReturn and lifeExpectancy cannot be edited (no screen references them). Coast/Barista expenseMultiplier is …

### PLAN-07 · medium · FIRE age editors can produce invalid slider ranges, and settings saves fail silently on validation errors

- **Status:** Confirmed · effort S · action A11
- **Where:** `lib/features/fire_number/presentation/screens/fire_setup_screen.dart:241-270`; `lib/features/fire_number/presentation/screens/fire_setup_screen.dart:317-323`; `lib/features/fire_number/presentation/screens/fire_settings_screen.dart:370-440`
- **Evidence:** Setup: current age can go to 70 while the target slider uses `min: (_currentAge + 5)` and `max: 70`, and _targetFireAge (default 45) is never re-clamped. At current age 50 the slider value 45 is below min 55; at 66-70, min exceeds max. Settings: `minAge = isCurrentAge ? 18 : settings.currentAge + 5; maxAge = 80`, and onPressed does `Navigator.pop(ctx); await ...saveSettings(updated);` with no try/catch, while the notifier rethrows FireSettingsValidationException. The validator allows target == current, despite its …
- **Impact:** A 50-year-old raising their age in setup triggers Slider assertion failures in debug builds and an out-of-range slider in release, then a validator error on save. In settings, setting current age at or above target closes the sheet and silently does nothing; the exception surfaces as an unhandled async error. At current age ≥ 76 the target editor has min 81 > max 80.
- **Fix:** As proposed. Re-clamp the target when current age changes. Use bounds max(currentAge+1, ...). Catch FireSettingsValidationException in the settings sheet. Make the validator use <=.
- **Numeric check:** Not applicable (not a formula).

### PLAN-10 · medium · Goal amounts mix currencies: reports, health score and notifications use the unconverted calculator, and progress text shows goal-currency target with the base-currency symbol

- **Status:** Confirmed · effort S · action A12
- **Where:** `lib/features/goals/domain/entities/goal_progress.dart:96-101`; `lib/features/goals/domain/entities/goal_progress.dart:133-142`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:357-393`
- **Evidence:** `double get targetAmount => goal.targetAmount;` is in goal currency, while currentAmount from calculateMultiCurrency is in base currency. getProgressMessage prints `$symbol${currentAmount} of $symbol${targetAmount}`. goalProgressProvider/allGoalsProgressProvider (used by reports and portfolio health) and the milestone checker call the non-converting GoalProgressCalculator.calculate, which sums raw amounts across currencies. checkAndShowGoalMilestone defaults `currency = 'INR'` and is called without it.
- **Impact:** Example: INR base, USD goal of $12,000 (≈₹10L), ₹2.5L of linked returns. The ring shows 25%, but the text reads '₹2.5L of ₹12K' and remainingAmount is negative-clamped. Health-score goal alignment and FY goal reports compare INR sums against USD targets, and USD/EUR users receive ₹-formatted milestone notifications.
- **Fix:** As proposed. Carry the converted target in GoalProgress and route reports, health and notifications through the converting path.
- **Numeric check:** USD goal of $12,000, INR base, Rs 2.5L returns. Ring = 2.5L/(12,000 x ~83 = Rs 9.96L) = about 25%. The text reads 'Rs 2.5L of Rs 12K', and remainingAmount = max(0, 12,000 - 2,50,000) = 0.

### PLAN-12 · medium · Income projection has no generator: nothing ever creates expected cash flows, so the ungated 'Upcoming' tab on every investment is always empty

- **Status:** Confirmed with corrections (reviewer said high) · effort L · action A42
- **Where:** `lib/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart:178-185`; `lib/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart:249-271`; `lib/features/investment/presentation/screens/investment_detail_screen.dart:332-338`
- **Evidence:** createExpectedCashFlow and bulkCreateExpectedCashFlows have no callers anywhere in lib/, test/, integration_test/ or functions/src. smartAmountPredictorProvider is never read. SmartAmountPredictor._getFixedAmount returns 0.0 in both branches ('will be enhanced later'). Stored statuses never move from upcoming to dueSoon, gracePeriod or overdue because nothing writes them, and overdueDaysAfter is never used. The calendar and dashboard card are behind FeatureFlag.incomeGuardian (default off). The investment-detail …
- **Impact:** Every user opening any FD, bond or P2P investment, even one with incomeFrequency, expectedRate and startDate filled in, sees an 'Upcoming' tab with 'No Expected Payments – This investment has no predicted income payments'. 'Income projection' is a headline feature, yet it is visibly empty. The Income Guardian alerts, calendar and payment-reliability metrics can never produce …
- **Fix:** Short term (S): hide the Upcoming segment behind the incomeGuardian flag. Longer term (L): build the deterministic generator as described, with month-anchored dates and status computed at read time.
- **Numeric check:** Recommended payout formula check: 10L x 7.5% x 3/12 = Rs 18,750 per quarter (correct).
- **Verifier:** Confirmed: createExpectedCashFlow/bulkCreateExpectedCashFlows have no callers in lib/, test/ or functions/src. smartAmountPredictorProvider is never read. _getFixedAmount returns 0.0 in both branches. The 'Upcoming' segment (investment_detail_segment_control.dart:50-59) and ExpectedIncomeSection …

### PLAN-13 · medium · Income Guardian background services run for all users regardless of the feature flag and query collections with no declared Firestore indexes

- **Status:** Confirmed with corrections · effort S · action A42
- **Where:** `lib/app/app.dart:26`; `lib/features/income_projection/presentation/providers/income_guardian_service_providers.dart:83-102`; `lib/features/income_projection/data/services/income_guardian_sync_service.dart:62-64`
- **Evidence:** IncomeGuardianServiceInitializer wraps the whole app and starts the monitor and sync services whenever the user is authenticated (settings.enabled defaults to true). It does not check isIncomeGuardianEnabledProvider. On every app session, _processedCashFlows starts empty, so for EVERY historical INCOME cash flow the sync runs `watchExpectedCashFlowsByInvestment(id).first`, a where(investmentId)+orderBy(expectedDate) query, with no try/catch. firestore.indexes.json declares only investments, cashflows, …
- **Impact:** A P2P user with 500 monthly income entries triggers about 500 Firestore queries (billed at ≥1 read each, even when empty) on every launch, adding startup work and cost for a disabled feature. Unless the indexes were created by hand in the console, these queries and the monitor's streams fail with FAILED_PRECONDITION. The resulting uncaught async errors land in Crashlytics, and …
- **Fix:** Gate the initializer on the flag. Query expected flows once per investment, not once per cash flow, and use a watermark. Add try/catch. Declare the indexes in firestore.indexes.json so the repo matches production.
- **Numeric check:** 500 INCOME flows give 500 queries per cold start, each billed at least 1 read even when empty.
- **Verifier:** Confirmed: app.dart:26 wraps the whole app in IncomeGuardianServiceInitializer. It checks only isAuthenticated, not the feature flag, and starts the monitor and sync services. On the first watchAllCashFlows emission of each session, _processedCashFlows is empty, so the sync runs one …

### PLAN-V1 · medium · Goals with no stored currency fall back to 'USD', so INR users' legacy or CSV-restored goal targets are converted as dollars

- **Status:** Added by verifier · effort S · action A03
- **Where:** `lib/features/goals/data/models/goal_model.dart:54`; `lib/features/goals/domain/entities/goal_entity.dart:159`; `lib/features/goals/presentation/providers/goals_provider.dart:153-155`
- **Evidence:** GoalModel.fromFirestore reads `currency: data['currency'] as String? ?? 'USD'`. The entity constructor and GoalNotifier.createGoal also default to 'USD'. The goals CSV parser defaults to 'USD' when the column is missing or empty ('Default for old exports without currency column'). calculateMultiCurrency then converts goal.targetAmount from goal.currency to the base currency.
- **Impact:** Take an INR-base user whose goal doc predates the currency field, or who restores an old export: a target of 10,00,000 is treated as $10,00,000 (about Rs 8.3Cr). The goal card and details then show about 1/83 of the true progress, while reports and health (non-converting path) show a different percentage. How many users this hits depends on how many goals exist without a …
- **Fix:** When currency is missing, default to the user's base currency (or the currency of the linked investments), not 'USD'. Add a one-time migration that writes the base currency into goal docs that lack the field.

### PLAN-11 · low · The same investment counts in full toward every goal it matches, so goal totals double-count the portfolio

- **Status:** Confirmed with corrections (reviewer said medium) · effort M · action A12
- **Where:** `lib/features/goals/presentation/providers/goal_progress_provider.dart:95-112`; `lib/features/goals/domain/entities/goal_entity.dart:40-65`
- **Evidence:** _getLinkedInvestments returns allInvestments for mode `all`, or filters by type/ID. There is no allocation share, so one FD linked to 'House' (all), 'Emergency' (byType FD) and 'Car' (selected) contributes 100% to each.
- **Impact:** A user with ₹10L across three goals can see all three at 100%, summing to ₹30L of 'progress'. Aggregate stats such as averageProgress and onTrackGoals in GoalsSummary and the health-score goal component are inflated.
- **Fix:** Low priority. Show an 'also counted in other goals' chip first. Add allocation percentages only if users ask for them.
- **Numeric check:** Not applicable.
- **Verifier:** The mechanism is real: _getLinkedInvestments (lines 96-112) returns all investments for mode 'all' with no allocation share, so one investment counts fully in every goal it matches. This is a design limitation rather than a formula error. Each goal shows its own view, and many tracking apps allow overlapping goal …

### PLAN-14 · low · Income trend analyzer compares the partial current month with full months, giving false 'income declined 100%' insights (latent: screen not routed)

- **Status:** Confirmed · effort S · action A21
- **Where:** `lib/features/income_projection/data/services/income_trend_analyzer.dart:92-147`; `lib/features/income_projection/data/services/income_trend_analyzer.dart:150-192`; `lib/features/income_projection/data/services/income_trend_analyzer.dart:205-208`
- **Evidence:** The monthly series ends at the current calendar month (`for i = 11..0: DateTime(now.year, now.month - i, 1)`). MoM is `(last − secondLast)/secondLast`, and QoQ/6-month average include the in-progress month. `investments.firstWhere(..., orElse: () => investments.first)` misattributes, or throws on an empty list. IncomeTrendReportScreen is not referenced by app_router.dart or any other screen.
- **Impact:** Not user-visible today. Once wired: on 2 Oct with steady ₹10k/month P2P income, MoM = −100% and the insight reads 'Income declined 100.0% last month. Review your investments.' QoQ shows −33.3% and the 6-month average ₹8,333 instead of ₹10,000. Any quarterly-payout investment produces ±100% swings every month.
- **Fix:** As proposed. Fix before routing the screen.
- **Numeric check:** Steady Rs 10k/mo on 2 Oct (no payout yet in October): MoM = (0-10k)/10k = -100%. QoQ = (20k-30k)/30k = -33.3%. 6-month average = 50k/6 = Rs 8,333.

### PLAN-15 · low · Prediction and date helpers: CV computed without a square root, Dart DateTime month overflow (Jan 31 + 1 month = Mar 3), and maturity date drift

- **Status:** Confirmed with corrections · effort S · action A16
- **Where:** `lib/features/income_projection/data/services/smart_amount_predictor.dart:189-217`; `lib/features/income_projection/data/services/smart_amount_predictor.dart:155-168`; `lib/features/income_projection/data/services/smart_amount_predictor.dart:99-136`
- **Evidence:** _calculateVariance: `final stdDev = variance > 0 ? variance.abs().toDouble() : 0.0;` gives variance ÷ mean, which depends on currency units (₹18,750 ± 50 gives 0.067 instead of 0.0019; ₹10k ± 2k caps at 1.0). _learnPlatformDelay builds `DateTime(expectedYear, adjustedMonth, previous.day)`, which overflows for day 29-31. calculatedMaturityDate uses `DateTime(start.year, start.month + tenureMonths, start.day)`. The income-reminder scheduler chains _addMonthsSafely from the previous clamped date, so day 31 drifts to …
- **Impact:** Latent for the predictor: the tolerance band picks ±12/15% instead of ±8% (scratchpad/PLAN/income.py). A 31 Jan monthly payout gives an 'expected' date of 3 Mar, recording a false platform delay. Live: a 6-month FD started 31 Aug 2025 shows maturity 3 Mar 2026 instead of 28 Feb 2026, which feeds portfolio-health liquidity. Monthly reminders for a 31st-day payout move to the …
- **Fix:** Add one clamped addMonths helper and use it for maturity dates (the live path). Fix CV with sqrt. The reminder behaviour needs no urgent change.
- **Numeric check:** Amounts [18700, 18750, 18800]: code CV = 1666.7/18750 = 0.089, correct CV = 40.8/18750 = 0.0022. Maturity for 31 Aug 2025 + 6 months: code gives 3 Mar 2026, correct is 28 Feb 2026.
- **Verifier:** Confirmed: _calculateVariance uses variance (not sqrt) divided by mean, which is unit-dependent; the predictor is unused. _learnPlatformDelay builds DateTime(year, month, previous.day), which overflows. calculatedMaturityDate (investment_entity.dart:360-369) overflows: DateTime(2025, 14, 31) gives 3 Mar 2026. It feeds …

### PLAN-16 · low · Planning formulas have weak tests: assertions are mostly 'greater than 0', and the providers that pick the inputs are untested

- **Status:** Confirmed with corrections · effort S · action A19
- **Where:** `test/features/fire_number/domain/services/fire_calculation_service_test.dart:41`; `test/features/fire_number/domain/services/fire_calculation_service_test.dart:122-126`; `test/features/fire_number/domain/services/fire_calculation_service_test.dart:229`
- **Evidence:** Assertions such as `expect(result.requiredMonthlySavings, greaterThanOrEqualTo(0))` and `expect(result.projectedFireAge, greaterThan(testSettings.currentAge))`. No test exists for fire_providers.dart (_estimateMonthlySavings, choice of totalInvested), for goal velocity/projection, or for income-goal averaging. The goal tests encode the returns-only progress semantics (expected 25% from a single RETURN flow).
- **Impact:** Every bug in PLAN-01 to PLAN-05, PLAN-08 and PLAN-09 passes the current suite. The tests lock in the wrong semantics, so fixes will look like regressions.
- **Fix:** Add golden-number and provider tests alongside the PLAN-01/02/08/09 fixes, not as a separate work item.
- **Numeric check:** Golden values I verified independently: FIRE 1.83Cr, required Rs 64,767/mo for 15 years at PV 0, and 22.976 years for 50L at PMT 0.
- **Verifier:** Partly overstated: the FIRE service tests do have exact-value checks: fireNumber closeTo 18.3M, and breakdown/emergency/healthcare closeTo at lines 58-61, 118, 204, 276 and 291. The projection and savings assertions are weak, as cited: lines 122-126 and 229 use greaterThan(0), and line 239 uses …

### PLAN-17 · low · Unwired ReinvestmentAdvisor hard-codes product suggestions ('P2P Lending (12-14%)') and mislabels the 'top performer'

- **Status:** Confirmed · effort S · action A42
- **Where:** `lib/features/income_projection/data/services/reinvestment_advisor.dart:108-153`; `lib/features/income_projection/presentation/providers/income_analysis_providers.dart:18-20`
- **Evidence:** reinvestmentAdvisorProvider is never read. _generateSuggestions adds a fixed 'P2P Lending (12-14%)' with expectedReturn 13.0 for amounts ≥ ₹10,000. 'topPerformer' is `activeInvestments.first`, not ranked by return. `investments.firstWhere(..., orElse: () => investments.first)` misattributes income.
- **Impact:** No user impact today. If surfaced, unsolicited product and return recommendations from a tracking app risk being treated as investment advice (SEBI IA rules), and the P2P return claim is a product-risk issue.
- **Fix:** Delete it, or reframe it as neutral idle-cash information before it is ever surfaced.
- **Numeric check:** Not applicable.

## ANLY · Aggregate analytics, reports, currency & number presentation

### ANLY-01 · critical · Home hero card shows healthy open portfolios as about -95% return and -98% XIRR because no aggregate includes a current or terminal value

- **Status:** Confirmed · effort L · action A09, A10
- **Where:** `lib/features/overview/presentation/widgets/hero_card.dart:95-97`; `lib/features/overview/presentation/widgets/hero_card.dart:243-265`; `lib/features/overview/presentation/widgets/hero_card.dart:306-308`
- **Evidence:** The hero headline is stats.netCashFlow (returned - invested). The badge is absoluteReturn = (returned-invested)/invested*100, and 'XIRR' is formatXirr(stats.xirr). multiCurrencyGlobalStats sends every cash flow of open and closed investments into calculateStats(), which builds XIRR from historical flows only. InvestmentEntity has no current-value field, and grep finds no terminal, accrued or valuation value anywhere in lib/. When there is no root, XirrSolver falls back to _calculateApproximateReturn. The toggle …
- **Impact:** Almost every user with open FDs, bonds or P2P loans sees a large red loss and an XIRR near -98% on the home screen while actually earning about 7%. This is the most visible number in the app, it undermines trust and retention, and it feeds the health score (ANLY-07) and the Reports insights.
- **Fix:** Short term (S effort): in the hero, show XIRR and return % only for the realized/closed set, or label the 'All' view 'Net cash flow' and replace the XIRR with '—' plus a 'needs current value' hint whenever open investments have no valuation. Medium term: add the PRD's 'Current Value' (valuation) entry, dated, per open investment. Auto-derive it for FDs and bonds as principal outstanding plus accrued interest. Use it as a synthetic terminal inflow at its date for XIRR, MOIC and return %.
- **Numeric check:** My python port of XirrSolver (scratchpad/ANLY-verify/xirr.py) uses -10,00,000 on 2026-01-01 and +17,500 on 2026-04-01, 07-01 and 10-01. The app's path (Newton from the smart guess) returns XIRR = -99.32%. The reviewer said -98.1%, which is close but not exact. Badge: (52,500-10,00,000)/10,00,000 = -94.75%. Adding a …

### ANLY-02 · high · One failed FX rate makes the whole batch fall back to an arbitrary cached rate, or to the raw foreign amount (an implicit 1.0 rate)

- **Status:** Confirmed · effort M · action A14
- **Where:** `lib/core/services/currency_conversion_service.dart:433-447`; `lib/core/services/currency_conversion_service.dart:457-491`; `lib/core/utils/batch_currency_converter.dart:76-91`
- **Evidence:** batchConvertHistorical throws CurrencyConversionException as soon as any single (date, currency) rate is missing. BatchCurrencyConverter catches this and calls _convertWithLastKnownRates for ALL cash flows, discarding the historical rates that did succeed. That method uses result.add(cf) ('Keep original if no cached rate') at line 225 and again on error at line 231, so the cash flow keeps its foreign amount and is summed as base currency. getLastKnownRate returns the FIRST matching entry in the insertion-ordered …
- **Impact:** Multi-currency users see totals that are wrong by up to the FX rate. Example: a USD 10,000 cash flow is counted as Rs10,000 instead of about Rs8,80,000 (88x understated) whenever any one rate fails, for example offline on first launch, after the circuit breaker opens, or for any unsupported currency (ANLY-03). The hero says 'All amounts shown in Rs (INR)' with no warning. When …
- **Fix:** As proposed. Return a partial map plus a failures list from batchConvertHistorical and apply the fallback only to the failed keys, using the nearest-date cached rate for the same pair and then the live rate. Never pass an unconverted amount through: exclude it and set isApproximate on the stats so the UI can show a banner. Track the latest rate per pair explicitly, add the exchangeRates (from, to, fetchedAt DESC) index, and parse with (x as num).toDouble().
- **Numeric check:** A USD 10,000 flow with no cached rate ends up as 10,000 in the base INR total, against about 8,80,000 at 88 INR/USD, an 88x understatement. This is code-traced, not run.

### ANLY-03 · high · 14 of the 40 offered currencies, including AED and SAR (the main NRI currencies), have no historical FX source

- **Status:** Confirmed with corrections · effort M · action A14
- **Where:** `lib/core/services/currency_conversion_service.dart:183-188`; `lib/core/services/currency_conversion_service.dart:760-803`; `lib/core/utils/currency_utils.dart:132-176`
- **Evidence:** Historical rates come only from Frankfurter v1 (https://api.frankfurter.dev/v1/{date}). The fallback exchangerate-api is used for live rates only: 'if (date != null) { throw ... Historical rates not available from fallback API }'. Frankfurter v1 serves only the 31 ECB currencies (AUD BGN BRL CAD CHF CNY CZK DKK EUR GBP HKD HUF IDR ILS INR ISK JPY KRW MXN MYR NOK NZD PHP PLN RON SEK SGD THB TRY USD ZAR). The app's _currencySymbols also offers AED, SAR, TWD, VND, BDT, PKR, LKR, ARS, CLP, COP, PEN, NGN, KES and EGP, …
- **Impact:** Gulf-based NRIs, a core segment for an INR-first alternative-investment tracker, never get historical FX conversion. All their flows use one live or stale rate or the raw amount. Their XIRR ignores FX movement, and through ANLY-02 their USD and GBP holdings are degraded too.
- **Fix:** Migrate historical lookups to Frankfurter v2, which covers AED, SAR, PKR, BDT and others, or derive pegged currencies (AED 3.6725, SAR 3.75 per USD) from USD crosses. Also restrict auto-detected base currencies to the set the conversion pipeline supports, or fall back to INR or USD for others. Add a test for an AED-base user with INR flows.
- **Numeric check:** Pegged cross-rate check: 82.9/3.6725 = 22.57 AED to INR, which matches the reviewer. I could not call the live API (egress blocked).
- **Verifier:** The '14 of the 40 offered currencies' framing is wrong. The cash-flow and investment CurrencySelector offers only the 16 currencies in LocaleDetectionService.getSupportedCurrencies (locale_detection_service.dart:276-294), and AED and SAR are the only ones without ECB data. The Settings base-currency picker offers 14, …

### ANLY-04 · medium · Home analytics cards and Smart Insights add up raw foreign-currency amounts while the hero card is converted

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A13
- **Where:** `lib/features/investment/presentation/providers/investment_analytics_provider.dart:91-142`; `lib/features/investment/presentation/providers/investment_analytics_provider.dart:146-199`; `lib/features/investment/presentation/providers/investment_analytics_provider.dart:202-249`
- **Evidence:** monthlyCashFlowTrendProvider, investmentTypeDistributionProvider, yoyComparisonProvider and recentlyClosedInvestmentsProvider all read validCashFlowsProvider and sum cf.amount directly, with no batchConvert call. Recently-closed rows use calculateStats(invCashFlows) on unconverted flows. smartInsightsProvider passes allCashFlowsStreamProvider, which is raw and also includes archived investments' flows, to SmartInsightsService, and that service formats the sums with the base currency symbol. In the same …
- **Impact:** A user holding USD 10,000 and Rs5,00,000 sees a distribution bar of 98% INR / 2% USD instead of 36% / 64%. The monthly trend and YoY figures understate USD flows 88x, and the recently-closed P&L and IRR for USD investments are labelled in Rs. Smart Insights 'This month: Rs X' adds USD and INR together and includes archived investments.
- **Fix:** Add one memoised 'converted valid cash flows' provider (batchConvert to the base currency) and build the trend, distribution, YoY, recently-closed and insights providers from it. Drop the archived-flows part of the finding.
- **Numeric check:** USD 10,000 at 88 = 8,80,000 plus INR 5,00,000 gives a correct split of 63.8% USD / 36.2% INR. The app computes 10,000/5,10,000 = 1.96% USD and 98.0% INR, which matches the reviewer.
- **Verifier:** Confirmed: monthlyCashFlowTrendProvider, investmentTypeDistributionProvider, yoyComparisonProvider and recentlyClosedInvestmentsProvider (investment_analytics_provider.dart) sum raw cf.amount from validCashFlowsProvider with no batchConvert. They are rendered ungated on the home screen (overview_screen.dart:216-231) …

### ANLY-05 · medium · Reports tab: 7 of 8 report cards open an empty 'No data' screen, the FY card label is hardcoded to 2023-24, and the CSV/PDF export pipeline is unreachable and broken

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A42
- **Where:** `lib/features/reports/data/services/report_builder_service.dart:146-228`; `lib/features/reports/presentation/screens/reports_home_screen.dart:234`; `lib/features/reports/presentation/screens/reports_home_screen.dart:337-341`
- **Evidence:** Every report card calls _navigateToReport, which routes to DynamicReportScreen through ReportBuilderService. _buildMonthlyIncome, _buildFyReport, _buildPerformance, _buildGoalProgress, _buildMaturityCalendar, _buildActionRequired and _buildPortfolioHealth return DynamicReportData(sections: []), so the screen shows 'No sections to display' with an 'Add your first investment' button. The fully implemented FYReportService, MonthlyIncomeService, PerformanceReportService and others are reachable only through providers …
- **Impact:** Any user or tester who enables Reports sees a feature that looks broken. The FY report, the most useful lever for Indian adoption (tax time), cannot be reached. Exports cannot be triggered, and would crash or produce garbled output if they could.
- **Fix:** Before enabling reports_tab, wire each card to its existing service and provider or remove the stub cards. Compute the FY label from DateTime.now(). Fix or delete the dynamic-typed exporters: use typed entities, numeric CSV cells plus a currency column, xirr*100 for percentages, and an embedded Unicode font for the PDF. Add a widget test that opens every card.
- **Numeric check:** Not applicable (not a formula).
- **Verifier:** All the factual claims hold. Seven builders in report_builder_service.dart:146-228 return empty sections, and DynamicReportScreen shows 'No sections to display' (dynamic_report_screen.dart:49-54). The FY subtitle is l10n.currentFY('2023','24') (reports_home_screen.dart:234). The weekly summary KPIs use …

### ANLY-06 · medium · FY report: April 1 and late-March flows double-counted, FY XIRR ignores opening and closing values, capital gains invented as 10% of proceeds, interest found only by note text

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A60
- **Where:** `lib/features/reports/data/services/fy_report_service.dart:42-43`; `lib/features/reports/data/services/fy_report_service.dart:62-67`; `lib/features/reports/data/services/fy_report_service.dart:76-84`
- **Evidence:** (a) The window is startLimit = fyStart - 1 day (Mar 31 00:00) and endLimit = fyEnd + 1 day (Apr 1 23:59:59) with strict isAfter and isBefore. The checks.py port in section 4 shows a flow at 2026-04-01 00:00 lands in both FY2025-26 and FY2026-27, and a flow at 2026-03-31 15:00 also lands in both. Time-stamped flows are common because add_transaction_screen defaults _selectedDate = DateTime.now(). The double-counted Apr 1 flows show up in the totals but not in the Apr-Mar monthly breakdown, so the totals do not …
- **Impact:** If wired up (see ANLY-05), users would copy wrong figures into ITR planning: double-counted April flows, invented STCG/LTCG, missing interest income, and a meaningless FY XIRR. That is a reputational and possibly legal-misinformation risk for an India-first finance app.
- **Fix:** As proposed, before the FY report is exposed. Use a half-open [Apr 1, next Apr 1) window on local dates. Bracket period XIRR with an opening and a closing value. Delete the 10% capital-gains assumption. Classify interest by investment type (FD, bond, P2P as 'income from other sources'). Label the output 'for reference — verify with AIS/26AS'.
- **Numeric check:** Port check (scratchpad/ANLY-verify/fy.py). New 1L FD opened 2025-06-01 with three payouts of 1,750: the app's FY XIRR is -99.31% (reviewer said -98.1%). Adding a closing value of 1,00,583 on 2026-03-31 gives 7.22%, which matches the reviewer. An existing 5L FD with only in-FY monthly payouts gets null from XirrSolver, …
- **Verifier:** Code confirmed. startLimit is Mar 31 00:00 and endLimit is Apr 1 23:59:59 of the following year, with strict isAfter/isBefore (fy_report_service.dart:62-67), so flows on Apr 1 and late on Mar 31 fall into two FYs. add_transaction_screen.dart:62 defaults the date to DateTime.now(), which includes a time. A date chosen …

### ANLY-09 · medium · Year-over-Year home card compares calendar YTD with the full previous year and shows investing more as a red decline

- **Status:** Confirmed · effort S · action A21
- **Where:** `lib/features/investment/presentation/providers/investment_analytics_provider.dart:202-249`; `lib/features/investment/domain/entities/investment_stats.dart:211-216`; `lib/features/overview/presentation/widgets/overview_analytics.dart:304-306`
- **Evidence:** thisYear = flows with date >= Jan 1 (no upper bound, so future-dated flows count). lastYear = the full previous calendar year. Net = returned - invested. isImproved = thisYearNet > lastYearNet, and the label is '${netChange}% vs last year'. checks.py section 10: last year invested 6L and received 50k (net -5.5L), this YTD invested 9L and received 60k (net -8.4L) gives '-53% vs last year' in red with a trending_down icon. Years are calendar years, not the Indian FY.
- **Impact:** Shown on the home screen for every user with two years of data. Saving more money is presented as getting worse, and in early-year months YTD is always compared against a full 12 months.
- **Fix:** As proposed. Compare like-for-like windows (FY-to-date against the same span of the previous FY) and show invested, income and net separately. Colour by income or returns received, not net cash flow.
- **Numeric check:** Last year net = 50k - 6L = -5.5L; this YTD net = 60k - 9L = -8.4L. netChange = (-8.4 + 5.5)/5.5*100 = -52.7%, shown as '-53% vs last year' in red with trending_down. This matches.

### ANLY-10 · medium · Currency switch prefetches only live rates, then the dashboard fires one concurrent historical request per (date, currency) with no throttling, which trips the circuit breaker

- **Status:** Confirmed with corrections · effort M · action A14
- **Where:** `lib/features/settings/presentation/providers/currency_switch_provider.dart:288-306`; `lib/core/services/currency_conversion_service.dart:396-431`; `lib/core/services/currency_conversion_service.dart:99-138`
- **Evidence:** _switchCurrencyImmediate calls conversionService.getRate(from, to) with no date, which is the live rate, and reports success. The stats providers, however, call batchConvertHistorical, which builds one getHistoricalRate future per unique (date, currency) all at once (uniqueRates.putIfAbsent creates the futures immediately) and then waits on Future.wait. Switching INR to USD for a user with 300 distinct cash-flow dates starts 300 Firestore reads plus 300 HTTP calls in parallel. The CircuitBreaker opens after 5 …
- **Impact:** After a currency switch, multi-currency totals may be computed with fallback rates (wrong numbers) even though the switch UI said 'success'. Latency is high on mobile networks.
- **Fix:** Keep historical rate docs when the base currency changes, since the key already includes the target currency. Prefetch the needed historical rates during the switch using Frankfurter's time-series endpoint (/{start}..{end}?base=X&symbols=Y), one request per pair, with bounded concurrency and a progress state. Report success only after historical conversion has completed.
- **Numeric check:** Not a formula. For N unique dates with an empty cache: N Firestore doc reads plus N HTTP calls per concurrent provider.
- **Verifier:** Confirmed. The switch flow prefetches only live rates through getRate(from, to) with no date (currency_switch_provider.dart:288-306) and reports success. SettingsNotifier.setCurrency calls clearCache(), which deletes every cached exchangeRates doc, including immutable historical ones …

### ANLY-11 · medium · Locale mapping produces non-Latin digits and Arabic words in an English UI, and en_IN compact gives odd strings like 'Rs0.999Cr' and 'Rs1KCr'

- **Status:** Confirmed · effort S · action A18
- **Where:** `lib/core/utils/currency_utils.dart:179-223`; `lib/core/utils/currency_utils.dart:579-591`; `lib/core/utils/currency_utils.dart:598-615`
- **Evidence:** A standalone Dart run against intl 0.20.2 (scratchpad/ANLY/fmt) gives: bn_BD (BDT) full '১২,৩৪,৫৬৭৳' (Bengali digits). ar_EG (EGP) '١٬٢٣٤٬٥٦٧ E£' (Arabic-Indic digits). ar_AE (AED) compact '1.23 مليون د.إ'. ar_SA compact '1.23 مليون ﷼'. si_LK compact 'Rsමි1.23'. ur_PK compact 'Rs 12.3 لاکھ'. en_IN compact: 9,994,999 becomes 'Rs0.999Cr', 1e10 becomes 'Rs1KCr'. Compact always shows 3 significant digits (123,456,789.9 becomes 'Rs12.3Cr', 'Rs1.23L') even though decimalDigits is 2. Full en_IN formatting is correct: …
- **Impact:** AED and SAR users (Gulf NRIs) and BDT, EGP and LKR users see mixed-script, partly unreadable amounts. Indian users with portfolios near 1 crore see 'Rs0.999Cr' on the hero.
- **Fix:** As proposed. Use en_IN or en_US number locales with Latin digits for all currencies, with the symbol supplied separately. Write a custom Indian compact formatter (L and Cr, 2 decimals, promote 100.00 L to 1.00 Cr), plus golden tests for the boundary values.
- **Numeric check:** My run: AED compact '1.23 مليون د.إ'; BDT full '১২,৩৪,৫৬৭.০০৳'; EGP full '١٬٢٣٤٬٥٦٧٫٠٠ E£'; LKR compact 'Rsමි1.23'; PKR compact '₨ 12.3 لاکھ'. en_IN compact: 9,994,999 gives '₹0.999Cr', 1e10 gives '₹1KCr', 123,456,789.9 gives '₹12.3Cr'. Also 99,999 gives '₹1L' (rounded up past the lakh boundary). All match the …

### ANLY-V1 · medium · Historical FX lookups bypass request coalescing, so every multi-currency stats provider fetches the same rates again

- **Status:** Added by verifier · effort S · action A14
- **Where:** `lib/core/services/currency_conversion_service.dart:289-322`; `lib/core/services/currency_conversion_service.dart:412-417`; `lib/features/investment/presentation/providers/multi_currency_providers.dart:61`
- **Evidence:** Request coalescing (_inflightRequests) is implemented only in getRate(). batchConvertHistorical calls getHistoricalRate(...) and getLiveRate(...) directly when it builds uniqueRates, so it gets no cross-call deduplication. Eight providers in multi_currency_providers.dart call engine.currency.batchConvert, including the per-investment family plus global, open and closed stats. Several run at the same time on the overview screen, and the portfolio-health provider watches the per-investment stats for every …
- **Impact:** Duplicate network and Firestore reads multiply latency and cost and raise the chance of timeouts. Any failure then triggers the whole-batch fallback to stale or raw amounts (ANLY-02), so this makes wrong multi-currency totals more likely.
- **Fix:** Route batchConvertHistorical through getRate(date: ...), or add a shared in-flight map keyed by 'historical_{date}_{from}_{to}' in getHistoricalRate. Better still, have one memoised converted-cash-flows provider that all stats providers derive from.

### ANLY-07 · low · Portfolio health score: returns component built on cash-flow-only XIRR, a free 25 points for an empty portfolio, crude type-only HHI and liquidity measured on cost basis

- **Status:** Confirmed with corrections (reviewer said medium) · effort M · action A21
- **Where:** `lib/features/portfolio_health/domain/services/portfolio_health_calculator.dart:97-153`; `lib/features/portfolio_health/domain/services/portfolio_health_calculator.dart:180-216`; `lib/features/portfolio_health/domain/services/portfolio_health_calculator.dart:261-327`
- **Evidence:** Returns weights stat.xirr by totalInvested across ALL investments (closed and archived included, unlike the other components). For open FDs the XIRR is about -98% (ANLY-01), so max(0, 20 + (-0.98/0.20)*20) = 0. With no investments the result is returns 0, diversification 0, liquidity 0, goals 100 ('No goals = no misalignment') and actions 100, so overall = 0.15*100 + 0.10*100 = 25 ('Poor'). Diversification uses type-level HHI on gross totalInvested (cost, including principal already returned): 1 type scores 0, two …
- **Impact:** When enabled, a typical single-type FD investor with no goals scores about 37/100 'Poor' (checks.py section 2). With a correct 7.02% XIRR the same portfolio would score about 56 'Fair'. Users get alarming 'Negative returns detected, consider cutting losses' advice on safe FDs, and an empty account is shown as Poor 25.
- **Fix:** Fix before enabling the flag. Return 'not enough data' for empty or partially loaded stats and do not auto-save partial scores. Give no goals or no investments a neutral score rather than 100. Feed the returns component a valuation-aware XIRR. Delete the duplicate reports PortfolioHealthService.
- **Numeric check:** Single open FD, no goals, XIRR about -99%: returns = max(0, 20 + (-0.99/0.20)*20) = 0, diversification 0 (HHI 1), liquidity 60 (ratio 0), goals 100, actions 100. Overall = 0.2*60 + 0.15*100 + 0.1*100 = 37, which matches. With XIRR 7.02% and 6% inflation, returns = 60 + (0.0102/0.05)*20 = 64.08 and overall = 0.3*64.08 …
- **Verifier:** The formulas are confirmed in portfolio_health_calculator.dart. Returns are weighted by totalInvested using cash-flow-only XIRR. An empty portfolio gets goals 100 and actions 100, so 0.15*100 + 0.10*100 = 25. Diversification is type-only HHI, and liquidity counts only calculatedMaturityDate within 90 days. The TODO …

### ANLY-08 · low · Smart Insights: top-ups trigger an URGENT 'declining in value' alert, the weekly card shows returns under a 'Net invested' label, 'sources' counts every transaction, maturity alerts miss tenure-based FDs

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A21
- **Where:** `lib/features/reports/data/services/smart_insights_service.dart:245-290`; `lib/features/reports/data/services/smart_insights_service.dart:101-111`; `lib/features/reports/data/services/smart_insights_service.dart:137-145`
- **Evidence:** The declining alert compares (returned-invested)/invested before and after 30 days ago. Adding new capital lowers the ratio. checks.py section 7: invested 1L, received 50k, then a 1L top-up gives old -50%, now -75%, decline -25 points, which is an URGENT 'Declining in value -25.0%' (and percentage points are shown as '%'). The weekly insight uses subtitle l10n.netInvestedThisWeek ('Net invested this week') but its value is '+returns', returnFlow only, and income is ignored. Monthly secondaryValue …
- **Impact:** Insights that are wrong or alarming erode trust: a user who adds money is told the investment is urgently declining. Counts and labels contradict each other, and the most useful alert (an upcoming FD maturity) is missed for tenure-based FDs.
- **Fix:** Suppress the declining alert when there is an INVEST flow in the window (or drop it until valuation exists). Make the weekly label match the value. Count distinct investmentIds for 'sources'. Use calculatedMaturityDate and status == open defensively. Use half-open windows and localise the strings.
- **Numeric check:** Invested 1L, received 50k, then a 1L top-up: old = (50k-100k)/100k = -50%, now = (50k-200k)/200k = -75%, decline = -25 points, below -20, so URGENT. This matches.
- **Verifier:** Confirmed. The declining insight compares (returned-invested)/invested before and now, so a top-up triggers it (smart_insights_service.dart:245-290). The weekly card's value is the returns total, under the 'Net invested this week' label (app_en.arb:4451). sourcesCount increments for every cash flow in the month. …

### ANLY-12 · low · Long-press 'exact amount' shows a double minus and a hardcoded Rupee symbol on the YoY and Recently-Closed cards

- **Status:** Confirmed · effort S · action A13
- **Where:** `lib/core/widgets/compact_amount_text.dart:54`; `lib/core/widgets/compact_amount_text.dart:61-73`; `lib/core/widgets/compact_amount_text.dart:102-104`
- **Evidence:** CompactAmountText defaults currencySymbol to the Rupee sign. YoYComparisonCard and RecentlyClosedCard pass amount: net (signed), compactText of the absolute value and prefix '-' but no currencySymbol. _fullFormattedAmount adds '-' when amount < 0, and the snackbar and clipboard then use '$prefix$fullAmount', which gives '--Rs5,50,000.00'. A USD-base user sees 'Rs' in the long-press view.
- **Impact:** Wrong symbol and sign in the exact-amount popup and the copied text.
- **Fix:** As proposed.
- **Numeric check:** amount = -5,50,000 with prefix '-' gives '-' + '-₹5,50,000.00' = '--₹5,50,000.00'.

### ANLY-13 · low · Privacy mode hides the hero visually, but its Semantics label still reads the net position and return % aloud

- **Status:** Confirmed · effort S · action A49
- **Where:** `lib/features/overview/presentation/widgets/hero_card.dart:99-113`
- **Evidence:** semanticLabel = AccessibilityUtils.statCardLabel(... value: formatCurrencyForScreenReader(netPosition, ...), subtitle: 'Return: ...') is built without checking privacyModeProvider, and it wraps the whole GlassHeroCard. The inner CompactAmountText correctly switches to 'Hidden amount' in privacy mode.
- **Impact:** With TalkBack, or any accessibility-service app or screen recorder that reads the semantics tree, the masked portfolio value is still exposed, which defeats the purpose of privacy mode.
- **Fix:** Pass the privacy state into statCardLabel (as investmentCardLabel already does with shouldMask) and audit the other statCardLabel callers.
- **Numeric check:** Not applicable.

### ANLY-14 · low · ITR filing reminder in Action Required can never fire

- **Status:** Confirmed · effort S · action A60
- **Where:** `lib/features/reports/data/services/action_required_service.dart:149-165`
- **Evidence:** currentFY = month >= 4 ? year : year-1, and deadline = DateTime(currentFY+1, 7, 31). Between April and July, currentFY is the current year, so the deadline computed is next year's July 31 (more than 365 days away). Between January and March the deadline is at least 122 days away. The 'daysUntilTax <= 90' condition is therefore never true. checks.py section 8 counts 0 firing days across 2026-2027.
- **Impact:** A key India-specific engagement moment (the July ITR deadline) is lost, and the Action Required count on the Reports home is never driven by it.
- **Fix:** As proposed: deadline = July 31 of the current year, rolled forward once it has passed, with the due date kept in remote config for CBDT extensions.
- **Numeric check:** Minimum daysUntilTax: on 2027-03-31 the deadline is 2027-07-31, 122 days away; on 2026-04-01 it is 2027-07-31, 486 days away. It is never 90 or less.

### ANLY-15 · low · Orphaned report services contain fabricated numbers and should not be wired up as-is

- **Status:** Confirmed · effort S · action A42
- **Where:** `lib/features/reports/data/services/performance_report_service.dart:45-56`; `lib/features/reports/data/services/performance_report_service.dart:130-140`; `lib/features/reports/data/services/monthly_income_service.dart:56-59`
- **Evidence:** PerformanceReportService sets currentValue = (totalInvested - totalReturned).abs() ('Estimate current value'). Milestones get achievedAt = now - (milestone/10) days, with the comment 'assume milestones were achieved recently'. Top and bottom performers are ranked by cash-flow-only XIRR, so a 5-day-old investment with an early payout ranks top. MonthlyIncomeService groups income 'by type' using the free-text note. None of these services convert currency. FY top performers use only in-FY flows.
- **Impact:** These are currently unreachable (see ANLY-05), but wiring them up as-is would publish invented dates and values.
- **Fix:** As proposed. Fix these before wiring the services up.
- **Numeric check:** Not applicable.

### ANLY-16 · low · Health score ring rounds 79.6 up to '80' but the tier says 'Good', and the trend chart truncates to 79

- **Status:** Confirmed · effort S · action A21
- **Where:** `lib/features/portfolio_health/presentation/widgets/portfolio_health_dashboard_card.dart:278-284`; `lib/features/portfolio_health/domain/entities/portfolio_health_score.dart:27-33`; `lib/features/portfolio_health/presentation/widgets/health_score_trend_chart.dart:274`
- **Evidence:** The ring displays score.round() while ScoreTier.fromScore deliberately uses the raw double (79.6 gives 'good'). The trend tooltip uses spot.y.toInt() (79). The X axis uses snapshot index, not time, even though snapshots are saved every 5 minutes whenever the score changes by more than 1 point.
- **Impact:** A user sees '80 - Good' next to an 'Excellent from 80' legend, and the ring and chart disagree by 1 point.
- **Fix:** As proposed.
- **Numeric check:** 79.6: round() = 80, tier 'good' (79.6 < 80), toInt() = 79. This matches.

## INV · Correctness bugs: investment feature

### INV-01 · critical · Merging investments re-tags every cash flow as USD, so INR totals come out about 88x too high

- **Status:** Confirmed · effort S · action A03, A04
- **Where:** `lib/features/investment/presentation/providers/investment_notifier.dart:566-576`; `lib/features/investment/presentation/providers/investment_notifier.dart:583-595`; `lib/features/investment/domain/entities/transaction_entity.dart:116`
- **Evidence:** mergeInvestments() builds `InvestmentEntity(... createdAt: now, updatedAt: now)` with no `currency:`. It also builds each copied flow as `CashFlowEntity(id:..., investmentId: newInvestmentId, type: cf.type, amount: cf.amount, date: cf.date, notes: ..., createdAt: now)` with no `currency: cf.currency`. Both constructors default to `currency = 'USD'`. All stats go through `engine.currency.batchConvert(cashFlows, baseCurrency: userBaseCurrency)`, which converts from `cf.currency`. The merged investment also drops …
- **Impact:** Take an Indian user (base currency INR) who merges two INR FDs: invest ₹5,00,000 and invest ₹3,00,000. The new flows are stored as USD 500,000 and USD 300,000. Converted at about ₹88/USD, the merged investment shows ₹7.04 crore invested instead of ₹8 lakh, and the portfolio, goals and FY totals inflate the same way. The data is permanently re-tagged: the originals are deleted …
- **Fix:** Copy every field: `currency: cf.currency` on each copied flow, and on the merged investment take `currency` from the source investments (if they disagree, use the base currency). Carry over maturity, income frequency and startDate = earliest startDate. Add a unit test: merging two INR investments must keep sum(amount) and currency per flow unchanged. Repair existing data with a one-off check: merged investments (notes start with 'Merged from:') whose flows are all 'USD' while the user's base currency is not USD.
- **Numeric check:** python3: the true invested total is 500,000 + 300,000 = INR 800,000. The app stores USD 800,000 and converts at about 88, giving INR 70,400,000 (7.04 crore), roughly 88x too high. The exact factor depends on the historical rate on each flow date (about 83-88).

### INV-02 · high · Add Cash Flow defaults to the user's base currency instead of the investment's currency, so one investment can hold mixed currencies

- **Status:** Confirmed · effort S · action A03
- **Where:** `lib/features/investment/presentation/screens/add_transaction_screen.dart:79-83`; `lib/features/investment/presentation/screens/add_transaction_screen.dart:351`; `lib/features/investment/presentation/screens/add_transaction_screen.dart:425`
- **Evidence:** initState comments 'Default to investment's currency for new cash flows. We'll fetch this from the investment in the build method', then sets `_selectedCurrency = ref.read(currencyCodeProvider);`, and build() never fetches the investment. The amount field's `prefixText: currencySymbol` and the preview's `currencyFormat.format(amount)` always use the base currency, even after the user picks another currency in the selector. A grep shows `investment.currency` is never read for calculations; it is only written and …
- **Impact:** An INR-base user tracking a USD investment (US stocks or a USD bond, currency set to USD on the add screen) types 1000 for a $1,000 purchase. It is saved as ₹1,000, so the investment shows about ₹1K invested instead of about ₹88K. XIRR then mixes a USD return against an INR investment and comes out wildly positive. The preview still shows ₹ after the user switches the selector …
- **Fix:** Pass the investment, or its currency, into AddTransactionScreen and initialise `_selectedCurrency = investment.currency` for new flows. Bind the prefix and preview to `_selectedCurrency` (getCurrencySymbol(_selectedCurrency)). If the chosen currency differs from the investment currency, show a one-line warning.
- **Numeric check:** A $1,000 purchase on a USD investment, entered with an INR base, is saved as INR 1,000. The correct value is about INR 88,000, so invested is understated about 88x.

### INV-03 · high · List card, list sorting and 'recently closed' show raw unconverted sums with the base-currency symbol, so they disagree with the detail screen

- **Status:** Confirmed · effort M · action A13
- **Where:** `lib/features/investment/presentation/widgets/investment_card.dart:55-62`; `lib/features/investment/presentation/widgets/investment_card.dart:425`; `lib/features/investment/presentation/providers/investment_stats_provider.dart:21-66`
- **Evidence:** InvestmentCard reads `investmentBasicStatsProvider` / `investmentXirrProvider`. These come from `activeInvestmentBasicStatsMapProvider` (`calculateStats(flows, includeXirr: false)`) and `_calculateAllXirrs`, which run on raw `cf.amount` with no batchConvert. The card then renders them with `currencyFormat.formatCompact(stats.netCashFlow.abs())` in the base currency. The detail screen uses `multiCurrencyInvestmentStatsProvider`, which does convert. Archived investments use `archivedInvestmentStatsProvider` with the …
- **Impact:** A USD investment (invest $10,000, return $11,000) shows '+₹1K' on the list card but '+₹88K' on its detail screen. Sorting by Total Invested ranks a $50,000 holding below a ₹60,000 FD. Once an archived USD investment is opened, its detail shows $ amounts labelled ₹. Any investment with mixed-currency flows (see INV-02) shows a meaningless card XIRR.
- **Fix:** Run one batch conversion per snapshot, converting validCashFlows to the base currency once with the existing batchConvert. Feed that list into activeInvestmentBasicStatsMapProvider, the XIRR map, recentlyClosed and archived stats. Delete the deprecated raw providers so nothing can fall back to them.
- **Numeric check:** USD flows: invest 10,000, return 11,000. The card shows net +1,000 with a rupee symbol (about +INR 1K). The detail screen shows 1,000 x ~88 = +INR 88,000.

### INV-05 · high · Editing an investment cannot clear optional fields (notes, maturity date, income frequency, rate, platform...), and reminders come back on next launch

- **Status:** Confirmed · effort S · action A22
- **Where:** `lib/features/investment/domain/entities/investment_entity.dart:381-427`; `lib/features/investment/presentation/providers/investment_notifier.dart:156-174`; `lib/features/investment/presentation/providers/investment_notifier.dart:193-207`
- **Evidence:** updateInvestment does `existing.copyWith(notes: notes?.trim(), maturityDate: maturityDate, incomeFrequency: incomeFrequency, startDate: ..., expectedRate: ..., platform: ...)`, and copyWith uses `maturityDate: maturityDate ?? this.maturityDate` (same `??` pattern for every nullable field). When the user taps the clear (x) button, the screen sends null, so the old value is kept and written back. Meanwhile the notifier sees `maturityDate == null` and cancels the reminders.
- **Impact:** A user removes a wrong maturity date, or sets Income Frequency to 'None' and saves. The app says 'Investment updated successfully', but the detail screen still shows the old maturity card and 'Matured N days ago'. On the next launch, rescheduleAllNotifications re-creates the maturity and income reminders the user removed. Clearing notes or the expected rate is also impossible, …
- **Fix:** Have updateInvestment build a new InvestmentEntity explicitly from the form values (do not use copyWith for nullable fields). Or add copyWith sentinels or `clearMaturityDate`-style flags. Add a regression test: edit with maturityDate=null must persist `maturityDate: null`.

### INV-06 · high · Income reminders are pushed a full period out on every launch and every investment change, so engaged users never receive them

- **Status:** Confirmed · effort M · action A08
- **Where:** `lib/features/investment/presentation/widgets/notification_sync_initializer.dart:92-107`; `lib/core/notifications/handlers/investment_notification_handler.dart:322-340`; `lib/core/notifications/handlers/investment_notification_handler.dart:73-75`
- **Evidence:** NotificationSyncInitializer listens to allInvestmentsProvider and calls rescheduleAllNotifications(investments) on first load and on every emission (debounced 2 s). That calls `scheduleIncomeReminder(investmentId, investmentName, monthsBetweenPayments)` without lastIncomeDate, which takes the branch `nextIncomeDate = _addMonthsSafely(now, monthsBetweenPayments, hour: 9)`. addCashFlow for an INCOME flow also never reschedules the reminder with the new last-income date.
- **Impact:** A monthly-interest P2P or FD investor who opens the app or edits anything at least once a month has the reminder reset to 'one month from now' each time, so it never fires. A user who records interest on the 5th still gets reminded on whatever date the last app open implied. One of the advertised 'smart notification' features is broken for exactly the retained users.
- **Fix:** In rescheduleAllNotifications, pass the last INCOME date per investment (computed from validCashFlowsProvider), or derive the schedule from startDate + k*period. Skip rescheduling when the schedule inputs (incomeFrequency, maturityDate, status, last income date) have not changed. Call _scheduleIncomeReminder after adding, editing or deleting an INCOME flow.

### INV-V1 · high · CSV bulk import tags every row as USD when the optional Currency column is missing or blank, and the preview shows the base-currency symbol

- **Status:** Added by verifier · effort S · action A03
- **Where:** `lib/features/bulk_import/data/services/simple_csv_parser.dart:269-276`; `lib/features/bulk_import/presentation/screens/import_confirmation_screen.dart:81-103`; `lib/features/bulk_import/presentation/screens/import_confirmation_screen.dart:270`
- **Evidence:** simple_csv_parser.dart:274-276: `final currency = (currencyRaw == null || currencyRaw.isEmpty) ? 'USD' : currencyRaw.toUpperCase();`. The template service documents Currency as an optional column. import_confirmation_screen creates InvestmentEntity with no currency (so it defaults to 'USD') and CashFlowEntity with `row.currency ?? 'USD'`. The preview formats row.amount with the base-currency currencyFormat (line 270), so the user sees ₹ before saving. data_import_service.dart does the same (`row.currency ?? …
- **Impact:** An Indian user imports their own spreadsheet (Date, Investment Name, Type, Amount) without a Currency column, or leaves the cells blank. Every flow is stored as USD and converted at about 88x, so a ₹10 lakh portfolio shows as about ₹8.8 crore across dashboard, goals, FIRE and FY reports. Bulk import is the main path for onboarding an existing portfolio, so this hits activation …
- **Fix:** Default a missing or blank currency to the user's base currency (currencyCodeProvider) when parsing, and set the InvestmentEntity currency from the rows (falling back to base). Show the currency per row in the confirmation preview. Add a test: a CSV without a Currency column and an INR base imports as INR.

### INV-04 · medium · An archived investment's screen still allows add, edit and delete of cash flows, but these hit the active collection: silent no-ops, a stuck UI and orphaned flows

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A23
- **Where:** `lib/features/investment/presentation/screens/investment_detail_screen.dart:64-66`; `lib/features/investment/presentation/screens/investment_detail_screen.dart:437-446`; `lib/features/investment/presentation/screens/investment_detail_screen.dart:451-482`
- **Evidence:** For archived investments the screen lists `archivedCashFlowsByInvestmentProvider`, but the FAB is shown whenever `!isClosed`, and edit/delete go through `investmentNotifierProvider` → `_cashFlowsRef.doc(id).update(...)`, `_cashFlowsRef.doc(id).delete()` and `_cashFlowsRef.doc(cashFlow.id).set(...)`. These only touch the ACTIVE `cashflows` collection. `_deleteCashFlow` is fire-and-forget and shows 'Transaction deleted' unconditionally.
- **Impact:** (1) Open an archived (open-status) investment, tap + and add ₹10,000 income. The app says 'Transaction added successfully', but nothing appears, because the flow went to the active collection. A retry creates a duplicate, and all of them reappear (duplicated) on unarchive. (2) Swipe-delete an archived flow: the toast says 'Transaction deleted' and the Dismissible collapses, …
- **Fix:** Pass `isReadOnly: isClosed || isArchived` to CashFlowCardWidget, and hide the FAB when the investment is archived. Show an 'Unarchive to edit' banner. Await deleteCashFlow and show the toast only after it succeeds.
- **Verifier:** Confirmed: the FAB is shown whenever !isClosed (detail_screen:437), regardless of isArchived. CashFlowCardWidget gets no read-only flag; only DocumentListWidget receives isReadOnly. add, update and delete all target _cashFlowsRef (repo:430-447). validCashFlowsProvider (investment_providers.dart:162-185) filters out …

### INV-07 · medium · Deleting, bulk-deleting or merging investments orphans attachments, metadata and reminders; merge also breaks goal links

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A23
- **Where:** `lib/features/investment/data/repositories/firestore_investment_repository.dart:249-257`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:527-585`; `lib/features/investment/presentation/providers/document_notifier.dart:200-212`
- **Evidence:** A grep shows DocumentNotifier.deleteAllDocumentsForInvestment is never called anywhere in lib/. deleteInvestment/bulkDelete only delete cash flows and the investment doc. bulkDelete and mergeInvestments (which calls `repo.deleteInvestment(id)` directly) never call _cancelIncomeReminder/_cancelMaturityReminders. rescheduleAllNotifications only schedules and never cancels for ids that no longer exist. Merge never rewrites `goal.linkedInvestmentIds`, and getGoalsForInvestment() is defined but unused.
- **Impact:** (1) Every deleted investment leaves its PDFs and images (up to 10 MB each) under documents/<uid>/<investmentId>/ forever, plus `documents` Firestore records that still count toward the user's storage. (2) Bulk-deleting or merging FDs keeps firing 'FD X matures in 7 days' for investments that no longer exist, and tapping the notification fails. (3) A goal linked to the 2 merged …
- **Fix:** Add one deletion service used by single delete, bulk delete and merge. It should cancel reminders, delete the local files and document records, and remove the deleted id from goals via getGoalsForInvestment. For merge, remap goal links and document records to the new id. In rescheduleAllNotifications, cancel reminders for ids that are no longer present.
- **Verifier:** Confirmed: DocumentNotifier.deleteAllDocumentsForInvestment (document_notifier.dart:200) has no callers in lib/. getGoalsForInvestment (firestore_goal_repository.dart:163) is unused. bulkDelete (notifier:399-414) and merge (605-607, which calls repo.deleteInvestment directly) never cancel reminders, while the single …

### INV-08 · medium · Swipe-to-delete and swipe-to-archive in the list fire and forget, show success unconditionally and leak errors

- **Status:** Confirmed with corrections · effort S · action A26
- **Where:** `lib/features/investment/presentation/screens/investment_list_screen.dart:418-451`; `lib/core/widgets/swipe_actions.dart:196-198`; `lib/core/widgets/swipe_actions.dart:213-215`
- **Evidence:** The `onDelete: () { ref.read(investmentNotifierProvider.notifier).deleteInvestment(investment.id); }` future is not awaited, and SwipeActions immediately runs `AppFeedback.showSuccess(context, deleteConfig!.successMessage)`. The repository deliberately throws NetworkException.noConnection when it cannot enumerate cash flows, 'so the user can retry'. That throw is now an unhandled async error and the user sees 'Investment deleted'. Bulk delete and merge in the action bar await without try/catch: on error there is …
- **Impact:** Offline with a cold cache (fresh install or after clearing the cache), the user swipe-deletes and sees 'Investment deleted', but the investment is still there after the stream updates, or reappears. The error goes to the zone handler instead of the user. Failed merges or bulk deletes give no feedback at all.
- **Fix:** Make the callbacks Future-returning and await them. Show success or AppException.userMessage. Wrap bulkDelete and merge in try/catch. Separately, note that an empty cache result lets deleteInvestment proceed and can orphan server-only cash flows.
- **Verifier:** Confirmed: the onDelete/onArchive callbacks (investment_list_screen.dart:418-451) are not awaited. SwipeActions._confirmDismiss (swipe_actions.dart:196-198 and 213-215) shows success unconditionally. The notifier rethrows, so any failure becomes an unhandled async error. The action-bar bulkDelete (86-97) and merge …

### INV-09 · medium · After unarchiving, the detail screen stays open with a stale entity, so a later Delete silently deletes nothing

- **Status:** Confirmed · effort S · action A23
- **Where:** `lib/features/investment/presentation/screens/investment_detail_screen.dart:929-932`; `lib/features/investment/presentation/screens/investment_detail_screen.dart:612-617`; `lib/features/investment/presentation/screens/investment_detail_screen.dart:62-72`
- **Evidence:** `if (!isArchived && mounted) { navigator.pop(); }` keeps the screen open after unarchive, but every decision reads the constructor snapshot `widget.investment.isArchived` (still true). Delete then calls `notifier.deleteArchivedInvestment(id)`, which queries archivedCashflows (now empty) and deletes a non-existent archived doc. That succeeds, so 'Investment deleted' is shown and the screen pops. The screen also keeps watching archivedCashFlowsByInvestmentProvider, so the list shows 'No Cash Flows Yet'.
- **Impact:** The user unarchives, then decides to delete from the same screen. They are told it was deleted, but the investment and all its flows are still in the active list. The options sheet also still offers 'Unarchive' a second time, and the transaction list looks empty.
- **Fix:** Pop after unarchive as well, or watch the live investment (investmentByIdProvider or a stream of the doc) and derive isArchived/isClosed from it instead of widget.investment. Have deleteArchivedInvestment throw DataException.notFound when the archived doc does not exist.

### INV-11 · medium · Every cash-flow save waits on full-collection reads of all investments and all cash flows whenever the user has any goal (slow saves plus Firestore read cost)

- **Status:** Confirmed · effort S · action A26
- **Where:** `lib/features/investment/presentation/providers/investment_notifier.dart:452-458`; `lib/features/investment/presentation/providers/investment_notifier.dart:815-829`; `lib/features/investment/presentation/providers/investment_notifier.dart:775-784`
- **Evidence:** addCashFlow awaits `_checkGoalMilestonesAfterCashFlow()`, which runs `goalRepository.watchActiveGoals().first`, then `investmentRepository.getAllInvestments()` and `investmentRepository.getAllCashFlows()`. These are default-source get() calls (server first) on the whole collections, before returning to the screen that is showing the save spinner. INCOME/RETURN flows additionally await getInvestmentById + getCashFlowsByInvestment.
- **Impact:** A user with 1 goal, 40 investments and 2,000 cash flows pays about 2,040 billed document reads per saved transaction. On a weak 3G/'lie-fi' connection the Save button can spin for many seconds, because Firestore waits for the server before falling back to cache. As a solo founder on the pay-as-you-go plan, this scales read costs linearly with power users.
- **Fix:** Don't await milestone checks in the save path (unawaited, after state = data). Compute progress from the already-loaded validCashFlowsProvider / allInvestmentsProvider state instead of new server reads, or use GetOptions(source: Source.cache).
- **Numeric check:** 1 goal + 40 investments + 2,000 flows gives about 2,041 document reads per saved flow (1 goal + 40 + 2,000), plus the per-investment reads for INCOME/RETURN flows.

### INV-12 · medium · The income-reminder notification opens Add Cash Flow pre-set to INVEST (the 'income' hint is dropped), so payouts get recorded as outflows

- **Status:** Confirmed · effort S · action A08
- **Where:** `lib/core/notifications/notification_payload.dart:108-113`; `lib/core/notifications/notification_navigator.dart:168-205`; `lib/features/investment/presentation/screens/add_transaction_screen.dart:63`
- **Evidence:** The payload parser maps 'income_reminder' to `NotificationPayloadType.addCashFlow` with `params: {'flowType': 'income'}`. _navigateToAddCashFlow receives params but pushes `AddTransactionScreen(investmentId: investmentId)` without initialType, so `_selectedType = CashFlowType.invest`. It also does not check whether the investment is closed or archived.
- **Impact:** A user taps 'Interest due for X', types ₹4,500 and saves without noticing the type chip. The ₹4,500 is booked as money invested instead of income: net position drops by ₹9,000 relative to the truth, MOIC falls, and XIRR swings sharply negative for that investment.
- **Fix:** Map params['flowType'] to CashFlowType and pass `initialType: CashFlowType.income` (plus the investment's currency, see INV-02). Block navigation, or show a message, for closed or archived investments.
- **Numeric check:** INR 4,500 interest recorded as INVEST: the correct net change is +4,500, the app records -4,500, a 9,000 swing in net position. MOIC and XIRR fall accordingly.

### INV-15 · medium · Attachment picker loads every selected file fully into RAM before the 10 MB check; a multi-file failure part-way leaves partial saves, and retrying duplicates them

- **Status:** Confirmed · effort S · action A65
- **Where:** `lib/features/investment/presentation/widgets/add_document_sheet.dart:354-380`; `lib/features/investment/presentation/providers/document_notifier.dart:88-95`; `lib/features/investment/presentation/widgets/add_document_sheet.dart:809-855`
- **Evidence:** For each picked file the sheet runs `final bytes = await file.readAsBytes();`. The size limit (`bytes.length > 10 * 1024 * 1024`) is only checked later in addDocument. _saveMultipleDocuments loops `await addDocument(...)`; on the first exception it shows `AppFeedback.showError(context, e.toString())` (which renders `ValidationException: File size 12582912 exceeds max 10485760`, i.e. technicalMessage) and keeps the full list. Files already saved are not removed from `_multipleFiles`.
- **Impact:** Selecting six 80 MB scanned property PDFs puts about 480 MB on the Dart heap, and low-end Android phones get OOM-killed. If file 3 of 5 is too large, files 1-2 are saved. The user removes file 3 and taps Save again, and files 1-2 are attached twice. The user also sees a developer-style error string.
- **Fix:** Check `platformFile.size` (FilePicker provides it) before reading, and reject files over 10 MB up front with a friendly message. Remove each file from `_multipleFiles` once it is saved, and show `AppException.userMessage` instead of toString().

### INV-17 · medium · Firestore documents with no currency field default to 'USD' while the app's default base currency is INR

- **Status:** Confirmed · effort S · action A03, A04
- **Where:** `lib/features/investment/data/repositories/firestore_investment_repository.dart:660-661`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:687-688`; `lib/features/settings/presentation/providers/settings_provider.dart:55`
- **Evidence:** Both mappers use `data['currency'] as String? ?? 'USD'`, the notifier falls back to `currency ?? 'USD'`, but the settings default is `prefs.getString('currency') ?? 'INR'`. No migration code for the currency field exists (grep for 'migrat' finds none touching cashflows).
- **Impact:** Any cash flow written before the multi-currency field existed, or by a code path that omits it (merge: INV-01), is treated as USD. It is converted at about 88x for INR users, inflating every total, XIRR input and FY figure. The git history in this clone is too shallow (50 commits) to confirm whether such legacy docs exist in production, so treat this as a latent risk.
- **Fix:** Make missing currency resolve to the user's base currency at read time, or better, run a one-time migration that stamps the profile's preferredCurrency on docs lacking the field. Make `currency` a required constructor argument on CashFlowEntity and InvestmentEntity so the compiler catches omissions.

### INV-10 · low · Archive and unarchive commit an unchunked batch of 2 + 2N writes (N = cash flows), which exceeds the 500-op batch limit at 250 or more flows

- **Status:** Confirmed with corrections (reviewer said medium) · effort M · action A23
- **Where:** `lib/features/investment/data/repositories/firestore_investment_repository.dart:194-207`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:229-242`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:486-487`
- **Evidence:** archiveInvestment adds `batch.set(archived)` + `batch.delete(active)` plus, for each cash flow, `batch.set(_archivedCashFlowsRef...)` + `batch.delete(cfDoc.reference)` into a single WriteBatch. The same file's bulkImport documents 'Firestore batch has a limit of 500 operations per batch' and chunks; archive does not.
- **Impact:** A P2P lending or chit-fund investment with daily or weekly repayment entries (250+ flows over a few years, common for LenDenClub-style EMIs) cannot be archived or unarchived; the batch commit is rejected with INVALID_ARGUMENT. Online, the user gets 'Failed to archive'. Offline, the 3 s timeout reports success, then the server rejects the queued batch and the local cache rolls …
- **Fix:** Low priority. Confirm the current limit in the Firestore console or docs. If it is gone, remove the stale 500 comment in bulkImport. In the long term, consider an isArchived field instead of moving documents between collections.
- **Verifier:** The code matches the description: archiveInvestment and unarchiveInvestment (repo:194-207, 229-242) put 2 + 2N operations in one unchunked WriteBatch, while bulkImport assumes a 500-op limit. The impact is doubtful. Firestore removed the 500-writes-per-commit limit in 2023, and the current quota results show only the …

### INV-13 · low · Maturity date picker cannot select past dates, so already-matured holdings cannot be backfilled; an auto-calculated past date hits a debug assert

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A65
- **Where:** `lib/features/investment/presentation/screens/add_investment_screen.dart:224-231`; `lib/features/investment/presentation/screens/add_investment_screen.dart:152-170`
- **Evidence:** `showDatePicker(initialDate: _maturityDate ?? now+365d, firstDate: DateTime.now(), ...)`. _updateAutoCalculatedMaturityDate sets `_maturityDate = startDate + tenure`, which can be in the past (start 2023-01-10, tenure 12 → 2024-01-10). Opening the picker then violates `initialDate >= firstDate` (assert in debug; in release every day is disabled until the user scrolls forward). Editing an FD whose maturity already passed has the same problem.
- **Impact:** New users onboarding an existing portfolio (the main activation path) cannot record that an FD matured last year. They either leave the date blank (losing the 'Matured' state and FY context) or enter a wrong future date that triggers bogus maturity reminders.
- **Fix:** Use `firstDate: _startDate ?? DateTime(2000)` and clamp initialDate to be at least firstDate. Validate maturity > startDate. Schedule reminders only for future dates.
- **Verifier:** Confirmed: _selectMaturityDate (add_investment_screen.dart:224-231) uses firstDate: DateTime.now(), so the picker cannot choose a past date. If the auto-calculated or existing _maturityDate is in the past, initialDate < firstDate violates Flutter's assert in debug builds; in release the picker opens on a month where …

### INV-14 · low · closedAt is set to the time 'Close' was tapped, not when the money came back, and a pending server timestamp can be overwritten with null

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A23
- **Where:** `lib/features/investment/data/repositories/firestore_investment_repository.dart:157-165`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:589-599`; `lib/features/reports/data/services/fy_report_service.dart:331-333`
- **Evidence:** closeInvestment writes `'closedAt': FieldValue.serverTimestamp()`. The FY report uses `investment.closedAt!.isBefore(date)` to decide whether a holding existed at FY end. Until the server timestamp resolves (offline), snapshots return closedAt = null. A subsequent updateInvestment rebuilds the doc from that entity and writes `'closedAt': null` via `.update(_investmentToFirestore(...))`, permanently erasing the close date.
- **Impact:** A user who closes, today (Oct 2026), a bond that actually exited in Feb 2025 (final RETURN dated 2025-02-10) gets an FY2024-25 report that still counts the bond as held on 31-Mar-2025. If they closed offline and then edited the investment, closedAt is lost entirely.
- **Fix:** Low priority. Default closedAt to the date of the last RETURN flow, written as a client Timestamp, and do not write closedAt from updateInvestment.
- **Verifier:** Confirmed in code: closeInvestment (repo:157-165) uses FieldValue.serverTimestamp(), so closedAt is when Close was tapped. _investmentToFirestore (repo:596-598) writes 'closedAt': null when the entity's closedAt is null, so an offline close followed by an offline edit can erase it. The impact is overstated. closedAt …

### INV-16 · low · Cash-flow rows always print the amount with the base-currency symbol, whatever the flow's own currency

- **Status:** Confirmed · effort S · action A13
- **Where:** `lib/features/investment/presentation/widgets/cash_flow_card_widget.dart:282`; `lib/features/investment/presentation/widgets/cash_flow_card_widget.dart:216-221`
- **Evidence:** `final amountText = '${isOutflow ? '-' : '+'}${currencyFormat.formatSmart(cashFlow.amount)}';` uses the base-currency NumberFormat for the native amount. Only the small grey sub-line shows the real currency ('1 USD = 88.1 INR • ₹88,100'). A FutureBuilder with an inline `getRate(...)` future also re-queries the rate on every rebuild.
- **Impact:** A $1,000 USD flow shows in bold as '-₹1,000' with the converted ₹88,100 in tiny text, so users misread their history and 'fix' amounts that were correct.
- **Fix:** Format the primary amount with the flow's currency symbol (formatCurrency(amount, currency: cashFlow.currency)) and keep the converted base amount as the secondary line. Cache the rate future in a provider.family keyed by (currency, date).

### INV-18 · low · Amount validation accepts unbounded values, and the input blocks decimal-comma keyboards

- **Status:** Confirmed · effort S · action A65
- **Where:** `lib/features/investment/presentation/screens/add_transaction_screen.dart:355-366`; `lib/features/investment/presentation/providers/investment_notifier.dart:677-681`; `lib/core/config/app_constants.dart:24`
- **Evidence:** The formatter is `RegExp(r'^\d*\.?\d*')` with maxAmountLength = 20, so '99999999999999999999' (1e20) passes `parsed <= 0` and _validateAmount (`if (amount <= 0)`). The `,` decimal key on EU/LatAm keyboards is silently dropped. _validateAmount does not reject NaN or Infinity for non-UI callers (bulk import, merge).
- **Impact:** A fat-finger extra-digit entry (₹1,00,00,000 instead of ₹1,00,000) is accepted silently and distorts portfolio totals and goal progress. NRI users on European locales type '1234,56' and get 123456.
- **Fix:** Add a sanity cap (e.g. 1e12 in any currency) with a confirm dialog for amounts above 100x the investment's current total. Reject `!amount.isFinite`. Accept a ',' decimal separator by normalising it to '.' when the locale uses a decimal comma.

### INV-V2 · low · Goal-milestone check after each cash-flow add computes progress from raw, unconverted amounts

- **Status:** Added by verifier · effort S · action A12
- **Where:** `lib/features/investment/presentation/providers/investment_notifier.dart:815-840`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:14-120`
- **Evidence:** _checkGoalMilestonesAfterCashFlow passes repository getAllCashFlows() output directly to GoalProgressCalculator.calculate, which sums cf.amount against goal.targetAmount with no batchConvert. goal_progress_provider's UI path does convert (batchConverter.batchConvert at ~272).
- **Impact:** For users with USD (or mis-tagged USD) flows, or a goal in a different currency, goal milestone and alert notifications fire at the wrong time and disagree with the % shown in the Goals screen. Single-currency INR users are unaffected.
- **Fix:** Reuse the converted goal-progress provider (or batchConvert first) in the milestone check, and take the data from already-loaded state instead of fresh server reads (see INV-11).

## PLAT · Correctness bugs: auth, settings, import/export, notifications, startup

### PLAT-01 · high · Guest 'Sign out' permanently orphans all guest data behind a generic 'Are you sure?' prompt

- **Status:** Confirmed (reviewer said critical) · effort S · action A05
- **Where:** `lib/features/settings/presentation/screens/settings_screen.dart:165-174`; `lib/features/settings/presentation/screens/settings_screen.dart:200-224`; `lib/l10n/app_en.arb:287`
- **Evidence:** The Sign Out tile is shown to every user, including anonymous ones (settings_screen.dart:165-174). _handleSignOut (200-224) shows signOutConfirmMessage = "Are you sure you want to sign out?" (arb:287) and then calls authRepository.signOut(), which runs only _googleSignIn.signOut() and _firebaseAuth.signOut() (repo:167-171). Nothing checks user.isAnonymous. Nothing warns that an anonymous Firebase user cannot sign back in. Nothing offers a backup or the 'link to Google' flow first.
- **Impact:** A guest who wants to 'switch to Google' is likely to go Settings > Sign out > Sign in with Google. That path gives them a new UID with an empty portfolio, and the guest's investments, cash flows, goals and documents become unreachable forever: the data stays on Firestore under the old anonymous UID, but nobody can access or delete it. The same happens to a guest who signs out …
- **Fix:** As proposed: for anonymous users, replace the dialog with a choice of Link Google / Export then sign out / Delete data then sign out. Plain sign-out should need an explicit 'my data will be lost' confirmation. Add a widget test.

### PLAT-02 · high · 'Backup & Sign In' merge flow for an existing Google account loses or strands guest data

- **Status:** Confirmed · effort M · action A05
- **Where:** `lib/features/auth/presentation/dialogs/backup_merge_dialog.dart:41-44`; `lib/features/auth/presentation/dialogs/backup_merge_dialog.dart:62-133`; `lib/features/settings/data/services/data_export_service.dart:218-224`
- **Evidence:** On credential-already-in-use, the 'Backup & Sign In' button pops the dialog with no value (line 41), so showBackupMergeDialog completes with null at once. It then calls exportAsZip(), which writes InvTrack_Export_<ts>.zip to getTemporaryDirectory(), the OS-purgeable cache (export:218-224). It never calls exportAndShare. Next it calls authRepo.signInWithGoogle() (line 81). signInWithGoogle returns null when the user cancels the second account picker (repo:85-88), but the result is not checked: the code still logs …
- **Impact:** This hits a guest who already has a Google account and taps 'Sign in to link'. After 'Backup & Sign In' they land on the Google account's Overview with none of their guest data. The only copy is a ZIP in the app cache that Android may purge, and no UI ever tells them where it is. Even when the dialog does show, 'Import now' navigates to a non-existent route (GoRouter error …
- **Fix:** As proposed. Drive the flow from a provider rather than a widget context. Persist or share the backup in a user-visible place. Treat a null sign-in result as cancel. Auto-import with merge after sign-in using the in-memory bytes. Then delete the anon user's data.

### PLAT-04 · high · Account deletion wipes data and then often fails to delete the Firebase Auth account (Google Sign-In never initialized in the re-auth path)

- **Status:** Confirmed · effort S · action A06
- **Where:** `lib/features/settings/presentation/screens/data_management_screen.dart:529-585`; `lib/features/auth/data/repositories/firebase_auth_repository.dart:180-202`; `lib/features/auth/data/repositories/firebase_auth_repository.dart:280-287`
- **Evidence:** _handleDeleteAccount first calls _deleteAllUserData() (server wipe), then authRepo.deleteAccount(). Firebase throws requires-recent-login for any Google session older than about 5 minutes, which is the normal case for a returning user. The code then calls authRepo.reauthenticateWithGoogle() (repo 180-202), which calls _googleSignIn.authenticate(). GoogleSignIn.instance.initialize(serverClientId:…) only runs inside googleSignInInitializedProvider, and that provider is awaited only by sign_in_screen.dart:134 and …
- **Impact:** Most Google users who try 'Delete Account' end up with their data deleted but their Firebase Auth record (PII) still present, and the app reports 'cancelled'. That fails Google Play's account-deletion requirement and is a GDPR/DPDP erasure gap. Because data is deleted before re-auth, a user who really did cancel loses everything anyway.
- **Fix:** Await googleSignInInitializedProvider before re-auth. Re-authenticate before any destructive step when lastSignInTime is more than about 4 minutes old. Better: do the server-side deletion of data and the Auth user in one step (Cloud Function / Admin SDK, reusing the existing deletionRequests pipeline).

### PLAT-05 · high · App-lock (PIN/biometric) bypass: notification taps push investment screens over the /lock route, and the portfolio flashes before the lock at cold start

- **Status:** Confirmed · effort M · action A07
- **Where:** `lib/core/notifications/notification_navigator.dart:126-150`; `lib/core/notifications/notification_navigator.dart:186-206`; `lib/app/app.dart:86-99`
- **Evidence:** _navigateToInvestmentDetail calls context.go('/investments'), which the redirect sends to /lock while locked. It then runs rootNavigatorKey.currentState.push(MaterialPageRoute(InvestmentDetailScreen)) (146-150). That imperative route sits on the root navigator above the /lock page and bypasses GoRouter's redirect. _navigateToAddCashFlow does the same (202-206). Separately, SecurityState starts with isLocked=false (provider:39). The real hasPin/isLocked state only arrives after async secure-storage and biometric …
- **Impact:** Scenario: PIN set, app backgrounded longer than the auto-lock time, user taps a maturity or income notification. The app resumes, locks (router to /lock), then about 500 ms later the investment detail or add-cash-flow screen is pushed over the lock screen. Anyone holding the phone sees the full investment and can edit it. At cold start, Overview totals render briefly before …
- **Fix:** As proposed. Defer notification navigation while isLocked and replay it after unlock. Make detail and add-cash-flow GoRoutes so the redirect applies. Start SecurityState in an unknown/locked state until _init resolves (mirror has_pin in SharedPreferences).

### PLAT-07 · high · CSV import treats a missing or blank Currency as USD (the template says base currency), inflating INR portfolios about 88x

- **Status:** Confirmed · effort S · action A03
- **Where:** `lib/features/bulk_import/data/services/simple_csv_parser.dart:269-276`; `lib/features/bulk_import/presentation/screens/import_confirmation_screen.dart:96-101`; `lib/features/bulk_import/data/services/csv_template_service.dart:170`
- **Evidence:** Parser: `final currency = (currencyRaw == null || currencyRaw.isEmpty) ? 'USD' : currencyRaw.toUpperCase();` (simple_csv_parser 274-276). The template text says '# Currency Column Values (optional, defaults to base currency)' (csv_template_service 170). The confirmation screen and ZIP import also fall back to `row.currency ?? 'USD'`. Imported InvestmentEntity objects never set currency, so they get the constructor default 'USD' (investment_entity 335).
- **Impact:** An Indian user (default base currency INR) imports a sheet without a Currency column, or with blank cells: Date,Investment Name,Type,Amount / 2024-01-15,HDFC FD,INVEST,100000. Each row is stored as USD 100,000 and the portfolio shows about ₹88,00,000 (at ~88 INR/USD) instead of ₹1,00,000. Every total, XIRR weight and goal progress is inflated. The edit screen also preselects …
- **Fix:** As proposed. Pass the base currency into the parser as the default, validate codes, set investment currency from its cash flows, and show the assumed currency on the confirmation screen.

### PLAT-08 · high · CSV date parser turns 2-digit-year Indian dates into year 0005/0024, and one row can flip dd/MM to MM/dd for the rest of the file

- **Status:** Confirmed · effort M · action A25
- **Where:** `lib/features/bulk_import/data/services/simple_csv_parser.dart:82-98`; `lib/features/bulk_import/data/services/simple_csv_parser.dart:423-447`; `lib/features/bulk_import/data/services/simple_csv_parser.dart:481-488`
- **Evidence:** Patterns are tried with parseStrict in order 'yyyy-MM-dd','dd-MM-yyyy',…,'d-MMM-yyyy',… and the first success is memoized as _detectedDateFormat (433-438). I ran the parser logic in a scratch copy (intl 0.20.2, any_date 1.2.2) and got: '05-03-24' -> 0005-03-24 (matched yyyy-MM-dd); '5-Mar-24' -> 0024-03-05; '05/03/24' -> 0024-03-05. In a dd/MM file, one stray row like '01/13/2024' fails the memoized dd/MM, matches MM/dd/yyyy and resets _detectedDateFormat, so every later ambiguous row (e.g. '05/03/2024') is read …
- **Impact:** Indian bank, broker and P2P statements commonly use dd-MMM-yy or dd/MM/yy. Such rows import silently with dates 2,000 years in the past. XIRR, CAGR, holding period and FY reports come out absurd (XIRR near 0%, or a solver failure) with no warning. A single typo row can silently swap day and month for all following rows.
- **Fix:** As proposed. Detect the format per file from all date cells, add 2-digit-year patterns, require 4 digits for yyyy-first patterns, reject years before 1950 or far-future dates, and ask the user when day/month order is ambiguous.

### PLAT-09 · high · ZIP backup/restore is lossy and destructive: investment metadata is dropped, same-name investments merge, multi-line notes split rows, and Replace wipes data before validating

- **Status:** Confirmed · effort L · action A24
- **Where:** `lib/features/settings/data/services/data_export_service.dart:254-287`; `lib/features/settings/data/services/data_export_service.dart:359-387`; `lib/features/settings/data/services/data_import_service.dart:148-151`
- **Evidence:** Export writes only cash-flow rows (Date, Investment Name, Type, Amount, Currency, Notes, Investment Type, Investment Status), plus goals and documents. Import rebuilds each investment from name, type and status only (import 436-446). Lost on restore: maturityDate, startDate, expectedRate, tenureMonths, platform, incomeFrequency, interestPayoutMode, compoundingFrequency, autoRenewal, riskLevel, notes, closedAt and currency. Investments with no cash flows are dropped. expectedCashFlows (Income Guardian) and …
- **Impact:** A user who exports before changing phones and imports on the new one gets back investments with no maturity dates, rates or payout schedules. Maturity and income reminders, income projection, FIRE and health score inputs all silently disappear. Duplicate-named investments are merged, which corrupts XIRR. Choosing Replace with a corrupt or partial ZIP (for example a …
- **Fix:** As proposed. Add investments.json with full entities and IDs plus a schemaVersion, import by ID, and use a CSV decoder that handles quoted newlines. For Replace, validate everything in memory first and keep a pre-replace auto-backup. Add a round-trip test.

### PLAT-10 · high · Income reminders are pushed to 'now + N months' on every app open or investment change, so active users never get them

- **Status:** Confirmed · effort S · action A08
- **Where:** `lib/features/investment/presentation/widgets/notification_sync_initializer.dart:92-105`; `lib/core/notifications/handlers/investment_notification_handler.dart:333-339`; `lib/core/notifications/handlers/investment_notification_handler.dart:57-75`
- **Evidence:** InvestmentNotifier._scheduleIncomeReminder correctly passes lastIncomeDate (notifier 698-724). But NotificationSyncInitializer listens to allInvestmentsProvider and, 0.5-2 s after every emission, calls rescheduleAllNotifications. That method calls scheduleIncomeReminder WITHOUT lastIncomeDate (handler 333-339). The `else` branch then sets nextIncomeDate = _addMonthsSafely(now, monthsBetweenPayments, hour: 9) (line 74), replacing the correct schedule.
- **Impact:** For a monthly-payout P2P or FD investment, a user who opens the app on 2 Oct gets a reminder set for 2 Nov. Opening again on 20 Oct moves it to 20 Nov, and so on. Anyone who opens the app at least once per payout interval never receives an 'Income Expected' reminder, and when one does fire it isn't aligned with the real payout date. Income tracking, the app's main retention …
- **Fix:** As proposed. Compute lastIncomeDate per investment in rescheduleAll (or pass a map of investmentId to last INCOME date), anchor on startDate when there is no income yet, and skip rescheduling when nothing changed.

### PLAT-03 · medium · Sign-out and account deletion leave the previous user's scheduled notifications (investment names and values) on the device

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A08
- **Where:** `lib/features/settings/presentation/screens/settings_screen.dart:212-218`; `lib/features/settings/presentation/screens/data_management_screen.dart:433-441`; `lib/features/settings/presentation/screens/data_management_screen.dart:580-596`
- **Evidence:** NotificationService.cancelAll() (607-609) has no caller anywhere in lib/. Sign-out (settings_screen 212-218), guest deletion (data_management 433-441) and account deletion (580-596) never cancel notifications. rescheduleAllNotifications (handler 311-340) only adds or refreshes reminders for the current investment list. It never cancels IDs that are no longer present. When the list is empty, NotificationSyncInitializer (92-105) doesn't reschedule at all. Maturity reminder bodies embed the investment name and value, …
- **Impact:** On a shared or handed-down phone, the next person to sign in gets the previous user's 'HDFC FD matures tomorrow. Value: ₹5,12,000' notifications and income reminders. A user who deleted their account keeps getting reminders about deleted investments. Investments closed or deleted on another device keep firing reminders on this one.
- **Fix:** Add an auth listener: on a uid change or null, await cancelAll(), clear per-user notification prefs, then reschedule app-wide reminders. Call cancelAll() before signOut() in both deletion flows. In rescheduleAll, cancel pending investment-range IDs that are no longer expected (pendingNotificationRequests()).
- **Verifier:** The core claim holds. NotificationService.cancelAll() (notification_service.dart:607-609) has no caller in lib/. The sign-out and both deletion flows (settings_screen:212-218, data_management_screen:433-441 and 529-596) never cancel notifications. rescheduleAllNotifications (handler:311-341) never removes stale IDs …

### PLAT-06 · medium · GoRouter is rebuilt on every auth, lock or feature-flag change, resetting navigation to '/' and discarding open screens and forms

- **Status:** Confirmed · effort S · action A27
- **Where:** `lib/core/router/app_router.dart:33-44`; `lib/app/app.dart:23`; `lib/features/security/presentation/providers/security_provider.dart:180-188`
- **Evidence:** routerProvider is a Provider that ref.watch()es authStateProvider, securityProvider, onboardingCompleteProvider and isReportsTabEnabledProvider (app_router 34-38). Each time it returns a new GoRouter(initialLocation: '/'). Every state change (lockApp, _onSuccessfulUnlock, setPin, removePin, toggleBiometrics) therefore hands MaterialApp.router a new routerConfig with fresh navigation state. Imperatively pushed routes (all Settings sub-screens use Navigator.push) are lost. The old GoRouter is also never disposed.
- **Impact:** A common case: a user half-way through Add Investment switches to their bank app to copy an FD number. Auto-lock fires, and after unlocking they land on Overview with the form gone. Toggling 'biometrics' in Security settings throws the user back to Overview. Linking or signing in kills the in-flight merge dialogs (root cause of the dialog loss in PLAT-02).
- **Fix:** Create the GoRouter once with refreshListenable (ChangeNotifier fed by ref.listen) and ref.onDispose(router.dispose). Also, to preserve in-progress forms across auto-lock, either render the lock as an overlay above the Navigator (not a route), or store the pre-lock location and restore it after unlock instead of redirecting to '/'.

### PLAT-11 · medium · Notification deep links fail: taps from a killed app are dropped, weekly check-in tap does nothing, and summary taps hit the disabled Reports route

- **Status:** Confirmed · effort S · action A29
- **Where:** `lib/core/notifications/notification_service.dart:278-281`; `lib/core/notifications/notification_service.dart:418-439`; `lib/core/notifications/notification_payload.dart:176-180`
- **Evidence:** Taps are handled only via onDidReceiveNotificationResponse (service 278-281). There is no call to getNotificationAppLaunchDetails() anywhere in lib/, and the plugin does not deliver the launching tap through that callback when the app was terminated. 'weekly_check_in' parses to addCashFlow with no investmentId (payload 176-180), and _navigateToAddCashFlow returns false when investmentId == null (navigator 172), despite the body 'Tap to log it now'. weekly_summary, monthly_summary and fy_summary map to …
- **Impact:** Maturity, income and goal reminders mostly arrive while the app is killed. Tapping them just opens the app on Overview, so the deep-link value is lost. The weekly 'Tap to log it now' prompt, scheduled for every user by default each Sunday, does nothing when tapped. The weekly, monthly and FY summary notifications promise a report the user can never reach.
- **Fix:** In _doInitialize, call _plugin.getNotificationAppLaunchDetails() and, if didNotificationLaunchApp, queueNotificationNavigation(response.payload) after the first frame. For weekly_check_in, open an investment picker, or the investment list with a 'log income' sheet. Don't schedule report-linked summaries while the Reports flag is off, or point them at Overview with matching copy. For a missing entity, show a SnackBar ('This investment was deleted') and cancel its reminders.

### PLAT-12 · medium · Indian tax-deadline reminders are cancelled or pushed a year out depending on the day the app was last opened

- **Status:** Confirmed · effort S · action A29
- **Where:** `lib/core/notifications/handlers/scheduled_notification_handler.dart:149-209`; `lib/core/notifications/handlers/scheduled_notification_handler.dart:233-250`; `lib/main.dart:130-141`
- **Evidence:** scheduleTaxReminders runs on every app start (main.dart:135). It first cancels all six reminders, then recomputes them. Q4: DateTime(now.month >= 3 && now.day > 15 ? nextYear : currentYear, 3, 10). ITR: DateTime(now.month >= 7 && now.day > 25 ? nextYear : currentYear, 7, 25). Q1/Q2/Q3: `now.month >= 6 ? nextYear : currentYear` (likewise 9 and 12). Past dates are skipped (line 234). I simulated every day of 2026 in python: the Q4 (Mar-15) reminder is wrong on 141 days (every 1st-15th of Apr-Dec, plus 10-15 Mar) and …
- **Impact:** Every user who opens the app on days 1-15 of a month from April to December silently loses the March-15 advance-tax reminder and often the July ITR reminder. Opening the app on 5 June cancels the 10 June advance-tax reminder. For an India-first app these are among the most valuable reminders. The reminders are also sent to all users regardless of currency or country.
- **Fix:** For each (month, day) use: `var d = DateTime(now.year, m, day, 9); if (!d.isAfter(now)) d = DateTime(now.year + 1, m, day, 9);`. Don't cancel before rescheduling (zonedSchedule with the same ID replaces). Only schedule when the base currency is INR or the country is IN. Worked example: now = 2026-10-02 gives Q4 = 2027-03-10 and ITR = 2027-07-25 (currently both None).
- **Numeric check:** Python simulation (2026): wrong days are 80C=8, Q1=9, Q2=9, Q3=9, Q4=141, ITR=126. At 2026-10-02 the app gives {Q3: 2026-12-10, Q1: 2027-06-10, Q2: 2027-09-10, 80C: 2027-03-24, Q4: None, ITR: None}; correct values are Q4 2027-03-10 and ITR 2027-07-25.

### PLAT-13 · medium · After a successful guest-to-Google link the UI still shows 'Guest' (authStateChanges does not emit on link)

- **Status:** Confirmed · effort S · action A05
- **Where:** `lib/features/auth/presentation/providers/auth_provider.dart:78-81`; `lib/features/auth/data/repositories/firebase_auth_repository.dart:21-29`; `lib/features/auth/data/repositories/firebase_auth_repository.dart:395`
- **Evidence:** authStateProvider maps _firebaseAuth.authStateChanges() (repo 21-29). FlutterFire documents that authStateChanges fires only on sign-in and sign-out; provider link/unlink is reported only by userChanges(). linkWithCredential (repo 395) keeps the same UID, so the cached UserEntity keeps isAnonymous=true. user_profile_card shows the 'Guest' badge and the 'Sign in to link account' button from that value, and data_management_screen shows 'Delete guest data'. Analytics setUserId and Crashlytics setUserIdentifier are …
- **Impact:** The user sees 'Account linked successfully', but Settings still says Guest, and Data & Account still offers 'Delete guest data', until the app restarts. Tapping 'link' again silently returns (notAnonymous). This invites support tickets or a guest-style sign-out (PLAT-01).
- **Fix:** Use _firebaseAuth.userChanges() for authStateProvider, or call ref.invalidate(authStateProvider) and await user.reload() after linking. Set the analytics and Crashlytics identifiers in an auth listener rather than in screens.

### PLAT-14 · medium · Locale-based currency detection is never wired up: every new user starts in INR, and base currency is device-local, not per account

- **Status:** Confirmed · effort S · action A31
- **Where:** `lib/features/user_profile/presentation/widgets/profile_initializer.dart:12-78`; `lib/features/user_profile/data/services/profile_initialization_service.dart:21-117`; `lib/features/settings/presentation/providers/settings_provider.dart:55-56`
- **Evidence:** ProfileInitializer is never used anywhere in lib/ (grep finds only its own file), so ProfileInitializationService and LocaleDetectionService.getCurrencyForCountry never run, and no users/{uid}/profile document is ever written. Base currency comes from SharedPreferences: `prefs.getString('currency') ?? 'INR'` (settings_provider 55). Onboarding only sets onboarding_complete (onboarding_screen 70) and never asks for a currency.
- **Impact:** US, UK, UAE and other users start with ₹ formatting and INR conversion, and must find the setting themselves; with 40+ supported currencies that hurts activation outside India. When an existing user installs on a new phone, the base currency silently reverts to INR. On a shared device, the second account inherits the first account's currency.
- **Fix:** Mount ProfileInitializer under the authenticated shell, or move the logic into an auth listener. Persist preferredCurrency in users/{uid}/profile and hydrate settingsProvider from it on sign-in. Add a currency confirmation step to onboarding, pre-selected from LocaleDetectionService.

### PLAT-15 · medium · Bulk CSV import has no duplicate detection: re-importing after fixing errors doubles amounts, and template type 'p2p' maps to 'Other'

- **Status:** Confirmed · effort M · action A25
- **Where:** `lib/features/bulk_import/presentation/screens/import_confirmation_screen.dart:53-110`; `lib/features/bulk_import/data/services/csv_template_service.dart:32`; `lib/features/bulk_import/data/services/csv_template_service.dart:174`
- **Evidence:** _importAll creates a new uuid investment for every name group and new cash flows for every valid row. It never checks existing investments by name, or cash flows by (investment, date, type, amount). Invalid rows are dropped and valid rows imported, so the natural 'fix the 3 bad rows and import the file again' path re-creates every valid row. The template sample rows and docs use investment types 'p2p' and 'mutualFund' (template 32, 174). The enum values are p2pLending and mutualFunds (investment_entity 203-217), …
- **Impact:** Example: a user imports 50 rows, 3 fail, they fix the file and re-import it. They now have duplicate 'Bhive Investment' entries and double the invested and income totals; portfolio value and goal progress are 2x. Everyone who follows the template gets P2P holdings classified as 'Other', which skews allocation and the health score.
- **Fix:** On the confirmation screen, match names against existing investments (case-insensitive) and offer 'add to existing / create new / skip'. Flag rows identical to an existing cash flow on the same date, type and amount as duplicates, unchecked by default. Accept aliases in the parser (p2p to p2pLending, mutualfund/mf to mutualFunds, fd to fixedDeposit) via InvestmentType.fromString plus an alias map, and fix the template.

### PLAT-16 · medium · Feature flags are local-only and default to off: review prompt, Income Guardian, Reports and Health Score are dark for all production users, and any user can seed demo data via the 7-tap debug mode

- **Status:** Confirmed · effort S · action A35, A42
- **Where:** `lib/core/providers/feature_flags_provider.dart:46`; `lib/core/providers/feature_flags_provider.dart:72-73`; `lib/features/investment/presentation/screens/add_transaction_screen.dart:173-186`
- **Evidence:** `final defaultValue = flag == FeatureFlag.portfolioHealthScore ? false : false;` and the value is read from SharedPreferences only (flags 72-73); there is no Remote Config. The review prompt is gated on ref.read(isReviewPromptEnabledProvider) (add_transaction 173-177), so the Play review sheet never appears for real users. Debug mode is enabled by 7 taps on the version number in About (about_screen 46-68), and the FAQ documents it. It exposes 'Seed demo data' (debug 82-100), which writes demo investments into the …
- **Impact:** No in-app review prompts means fewer ratings on the live Play listing, a direct store-ranking and conversion cost. Finished features (Income Guardian, Reports, Portfolio Health) are invisible to users and can't be rolled out without shipping a build. Curious users who enable debug mode can pollute their real portfolio with demo data they can't easily remove.
- **Fix:** Back the flags with Firebase Remote Config (defaults set in code, server overrides, percentage rollout). Turn on reviewPrompt for 100% once the gating is verified. Hide 'Seed demo data' in release builds (if (!kReleaseMode)), or route it through SampleDataModeNotifier so the IDs are tracked and clearable.

### PLAT-17 · low · Notification IDs are hash mod small ranges: collisions between investments cancel or overwrite each other's reminders

- **Status:** Confirmed with corrections · effort S · action A29
- **Where:** `lib/core/notifications/notification_constants.dart:51-58`; `lib/core/notifications/notification_constants.dart:79-84`
- **Evidence:** maturityReminder7Days = (investmentId.hashCode.abs() % 25000) + 100000 and incomeReminder = (hashCode % 50000) + 50000. Goal milestone IDs = (hash % 20000) + 220000 + percent, which can reach 240,100 and overlap goalAtRisk (240000+). By the birthday bound, P(maturity collision) is 4.8% at 50 investments, 18% at 100 and 55% at 200. String.hashCode is also not guaranteed stable across Dart SDK versions, so after an app update compiled with a different SDK, cancel(id) may miss reminders scheduled by the previous …
- **Impact:** Power users with many FDs or bonds can lose a maturity reminder: one investment's reminder replaces another's, or deleting one investment cancels another's reminder.
- **Fix:** Keep a persistent Map<String, int> (SharedPreferences JSON) that assigns sequential IDs per (investmentId, kind). Alternatively, derive IDs from a stable FNV-1a hash of the ID and check for collisions against pendingNotificationRequests().
- **Numeric check:** Python: P(collision) with 25000 slots: n=50 0.048, n=100 0.18, n=200 0.55. Max goalMilestone ID = 220000+19999+100 = 240099 >= goalAtRisk base 240000.
- **Verifier:** The ID formulas are as quoted (notification_constants.dart:51-58, 79-84). goalMilestone can reach 220000+19999+100 = 240099, which overlaps goalAtRisk (240000+). My birthday-bound computation for 25,000 slots matches: 50->4.8%, 100->18%, 200->55%. These collisions only matter among investments that have maturity …

### PLAT-18 · low · Maturity notification uses '$' for every non-INR currency and has no digit grouping; 'last day of month' summary repeats on a fixed day number

- **Status:** Confirmed with corrections · effort S · action A18
- **Where:** `lib/core/notifications/handlers/investment_notification_handler.dart:294-296`; `lib/core/notifications/handlers/scheduled_notification_handler.dart:121-137`
- **Evidence:** `final currencySymbol = currency == 'INR' ? '₹' : '\$'; buffer.write(' Value: $currencySymbol${currentValue.toInt()}');`, so a EUR user sees '$51200' and an INR user sees '₹512000' rather than '₹5,12,000'. The monthly summary schedules DateTime(now.year, now.month + 1, 0, 18) with matchDateTimeComponents: dayOfMonthAndTime. The Android plugin (flutter_local_notifications 21.0.0, FlutterLocalNotificationsPlugin.java:1371-1374) advances day by day until dayOfMonth matches, so a schedule created on the 31st skips …
- **Impact:** Values in reminders are wrong or hard to read for non-INR users, and the monthly summary is missed in 30-day months and February for users who don't open the app that month.
- **Fix:** Drop the currency-formatting item, or treat it as dead code to fix only when currentValue is actually wired in. For the monthly summary, schedule a one-shot for the last day and reschedule on fire or app open, or move it to the 1st of the next month.
- **Verifier:** The currency-symbol part is unreachable. The '$' fallback at investment_notification_handler.dart:294-296 runs only when currentValue != null, but no caller passes currentValue: InvestmentNotifier._scheduleMaturityReminders (investment_notifier.dart:745-758) and rescheduleAllNotifications (handler:326-330) pass only …

## SEC · Security, privacy & compliance (incl. public-claim accuracy)

### SEC-01 · critical · Play Store listing says 'We don't store your financial data on our servers', but all data lives in Cloud Firestore

- **Status:** Confirmed · effort S · action A01
- **Where:** `android/fastlane/metadata/android/en-US/full_description.txt:62-63`; `android/fastlane/metadata/android/en-US/full_description.txt:59-60`; `release.yaml:27`
- **Evidence:** full_description.txt:62-63: "🔒 Your Data, Your Control / We don't store your financial data on our servers. It stays with you." Three lines earlier (59-60) the same listing says "Sign in with Google to backup your data. Access it from any device." The code writes every investment, cash flow, goal, FIRE setting, health score and document-metadata record to Firestore under users/{uid}/... (account_data_deletion_service.dart:53-66 lists 12 server collections). Guest users are stored in the cloud too …
- **Impact:** Every Play visitor is told their financial data is not on the developer's servers. That contradicts the Data Safety form (which must declare Financial info as collected and stored) and the in-app policy. This is a textbook breach of Google Play's Deceptive Behavior and User Data policies, the kind that gets apps suspended. It is also a misleading claim under India's Consumer …
- **Fix:** Replace lines 62-63 with a true statement (data stored in your account on Google Firebase, private to your account, never sold; attachments stay on the device; delete any time in Settings). Remove the stale 3.6.0 block. Run listing.yml with dry_run=false. Add a CI grep for phrases like "don't store" / "stays with you" in android/fastlane/**.

### SEC-02 · high · The web account-deletion path required by Play is missing, and the deletionRequests queue has no processor

- **Status:** Confirmed with corrections · effort M · action A02, A36
- **Where:** `firestore.rules:9-28`; `scripts/account-deletion/package.json:1-15`; `scripts/account-deletion/test/rules.test.mjs:49-177`
- **Evidence:** firestore.rules:12 says "Processing is done by the daily GitHub Actions job with the Admin SDK" and accepts requests with source in ['web','app']. But scripts/account-deletion holds only package.json and test/rules.test.mjs. There is no job script, and none of the 7 workflows has a schedule other than auto-release.yml (hourly release). No Dart code writes deletionRequests (grep finds no matches in lib/). .appforge/product.yaml:54: "a required web deletion link exists but per FINDINGS.md is not yet published".
- **Impact:** Google Play requires apps that allow account creation to provide BOTH an in-app path AND a working web link (entered in Play Console) where users can request deletion, including users who already uninstalled. Without it the app risks an enforcement or update rejection. If the planned web page goes live writing to deletionRequests as the rules allow, those requests are queued …
- **Fix:** This week, publish a static deletion page (in-app steps plus one monitored email, a list of what is deleted and what is retained, and a 30-day SLA), and set it in Play Console > Data safety. Do not ship any web form that writes deletionRequests until the scheduled processor exists (Admin SDK recursiveDelete of users/{uid}, auth deleteUser, audit entry) with emulator tests.
- **Verifier:** Confirmed: firestore.rules:12 refers to a "daily GitHub Actions job", but scripts/account-deletion contains only package.json and test/rules.test.mjs. The only scheduled workflow is auto-release.yml (cron '23 * * * *'). grep finds no deletionRequests writes in lib/. product.yaml:54 records that the web deletion link …

### SEC-03 · high · Guest users can sign out with a generic prompt and permanently lose their data, while the FAQ claims guest data is accessible across devices

- **Status:** Confirmed · effort S · action A05
- **Where:** `lib/features/settings/presentation/screens/settings_screen.dart:164-173`; `lib/features/settings/presentation/screens/settings_screen.dart:200-224`; `lib/l10n/app_en.arb:287`
- **Evidence:** The Sign Out tile is shown for every user (no isAnonymous check in settings_screen.dart). Its dialog says only "Are you sure you want to sign out?" (arb:287) and then calls authRepo.signOut(). An anonymous user's credential cannot be recovered after sign-out. arb:2501 FAQ: "Your data is stored in the cloud under an anonymous account, so you can access it across devices." That is false: an anonymous account exists only on the installing device, and arb:2451 itself warns that uninstalling may cause data loss. …
- **Impact:** A guest who taps Sign Out (or trusts the FAQ and switches phones) loses all investment history with no recovery path. That is direct data loss for a user group the app actively recruits. The orphaned data stays on the server indefinitely (see SEC-04), which is a retention problem under DPDP s.8(7).
- **Fix:** As the reviewer recommends: for anonymous users, replace Sign Out with 'Sign in with Google to keep your data' or a strong warning dialog whose primary action is Export. Correct the FAQ text at arb:2501. After a successful import in backup_merge_dialog, delete the old anonymous uid's data and its Auth user.

### SEC-14 · high · Privacy policy does not meet DPDP/GDPR notice requirements; policy URLs and support emails are inconsistent

- **Status:** Confirmed · effort M · action A02, A39
- **Where:** `lib/features/settings/presentation/screens/legal_content.dart:8-35`; `app-metadata.json:20`; `lib/l10n/app_en.arb:667`
- **Evidence:** The in-app policy (legal_content.dart) has 5 short sections. It has no grievance officer or DPO contact, no retention periods, no list of processors or recipients (Firebase/Google, api.frankfurter.dev and api.exchangerate-api.com, which receive the user's IP plus transaction dates via `$_primaryApiBaseUrl/$dateStr?base=$from&symbols=$to`), no cross-border transfer notice (Firebase US/EU regions), no consent-withdrawal method, and no right to complain to the Data Protection Board or nominate. Policy URLs differ: …
- **Impact:** If the live Play policy still describes SQLite plus Google Sheets, the policy registered with Play misstates collection, which is a direct User Data policy violation (I could not fetch either URL from this sandbox, so verify). DPDP Rules 2025 (notified 14 Nov 2025) make the notice, consent, grievance and erasure obligations enforceable from 13 May 2027, with penalties up to …
- **Fix:** First, publish the corrected policy at one canonical URL and register it in Play Console. Point legal_content.dart and app-metadata.json at it, and use one monitored support email everywhere. Then, before May 2027, extend the policy with the DPDP/GDPR items: processors, retention, rights and a grievance contact.

### SEC-04 · medium · The anonymous-user cleanup Cloud Function is never deployed, so abandoned guest data is kept forever

- **Status:** Confirmed · effort M · action A36
- **Where:** `functions/src/cleanupAnonymousUsers.ts:1-208`; `firebase.json:1-4`; `docs/ANONYMOUS_AUTH_GUEST_MODE.md:48`
- **Evidence:** `git ls-files functions` returns only functions/src/cleanupAnonymousUsers.ts. There is no package.json, tsconfig or index.ts, and firebase.json has no "functions" key, so `firebase deploy` cannot deploy it. The design doc lists "Orphaned anonymous users | ✅ Accepted | Cloud Function cleanup (30 days)" (line 48), but its checklist still shows "- [ ] Cloud Function deployed" (245). The function also never deletes the parent users/{uid} document and only deletes a hard-coded list of 12 subcollections.
- **Impact:** Every guest who uninstalls, clears data, signs out (SEC-03) or hits the link-conflict path leaves financial records and an Auth record in Firestore indefinitely. That conflicts with DPDP s.8(7) (erase once the purpose is no longer served), GDPR storage limitation, and the in-app policy's implied retention 'until you delete your account'. Storage and cost also grow without …
- **Fix:** As the reviewer recommends: either make the function deployable (package.json, index.ts, a firebase.json functions key, v2 onSchedule, recursiveDelete) or fold the logic into the deletion-job workflow. State the 30-day guest retention in the policy.

### SEC-05 · medium · Unprovable or false security claims in the README, in-app FAQ, privacy text and an activation notification

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A01
- **Where:** `README.md:59-62`; `README.md:72`; `README.md:169`
- **Evidence:** README:60 "Encrypted Storage - FlutterSecureStorage for sensitive data". Only the PIN hash is in secure storage. Financial data sits in an unlimited, unencrypted Firestore SQLite cache (database_module.dart:19-21) and plaintext ZIP exports (SEC-06). README:61 "No PII Logging" contradicts README:169 "tied to user ID, no opt-out yet" and SEC-09. README:62 "OWASP MASVS Compliant" and :72 "WCAG compliant" are self-asserted with no assessment in the repo. legal_content.dart:21 "Only you can read your records": the …
- **Impact:** These statements reach users through the README/GitHub, in-app policy, FAQ and push notifications. Unsubstantiated security and social-proof claims are a Google Play Deceptive Behavior risk and an India CCPA misleading-advertisement risk. They also expose the founder if there is ever an incident ('you said only I could read it').
- **Fix:** Change legal_content.dart:21 to 'Your records are private to your account; other users cannot access them. The developer can access stored data only for support and legal compliance.' Replace the Day-14 notification copy with a non-numeric claim. In the README, change 'Encrypted Storage' to 'PIN hash in Keystore-backed secure storage' and change MASVS/WCAG to 'designed with reference to; not certified'. Fix the AES claim in the design doc.
- **Verifier:** The claims exist as quoted. README.md:60-62 has 'Encrypted Storage', 'No PII Logging' and 'OWASP MASVS Compliant'; :72 has 'WCAG compliant'; :169 admits analytics is tied to the user ID with no opt-out. legal_content.dart:21 says 'Only you can read your records', which is false because the project owner and admin SA …

### SEC-06 · medium · The full-portfolio ZIP backup (including attached KYC/statement files) is unencrypted, shared through the share sheet, and left in the cache

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A33
- **Where:** `lib/features/settings/data/services/data_export_service.dart:122-234`; `lib/features/settings/data/services/data_export_service.dart:238-248`; `lib/features/auth/presentation/dialogs/backup_merge_dialog.dart:69`
- **Evidence:** _exportAsZipInternal builds cashflows.csv (investment name, amount, currency, notes), goals.csv, metadata.json, fire_settings.json and every attached document's raw bytes (lines 158-168). It encodes with ZipEncoder().encode(archive) with no password (line 213), writes to getTemporaryDirectory() (219-224), then hands it to SharePlus (241-247). The file is never deleted. The `encrypt: ^5.0.3` dependency (pubspec.yaml:77) is not imported anywhere in lib/. backup_merge_dialog.dart:69 also creates such a ZIP …
- **Impact:** Users are prompted to 'Keep this file safe for backup' and typically send it to WhatsApp, Gmail or Drive. Anyone who gets the file (chat history, shared Drive, a lost laptop) sees the user's full net worth, every FD/P2P/bond holding, notes, and attached documents such as PAN/Aadhaar copies, bond certificates and bank statements. That is the most sensitive artefact the app …
- **Fix:** Offer an optional password (strongly encouraged) for the full ZIP backup: PBKDF2-HMAC-SHA256 or Argon2id, AES-256-GCM with a random nonce, and a versioned header. Detect the header on import. Delete the temp ZIP after the share sheet returns and purge stale exports on startup. Drop the unused `encrypt` dependency.
- **Verifier:** The code matches the description. data_export_service.dart builds the CSVs, metadata and fire_settings, and adds every document's raw bytes (158-168). It calls ZipEncoder().encode with no password (213), writes InvTrack_Export_<ts>.zip to getTemporaryDirectory (219-224), and shares it through SharePlus (241-247). No …

### SEC-07 · medium · Analytics, Crashlytics and Performance are always on and linked to the user ID, and the Advertising ID is collected with no consent or opt-out

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A34
- **Where:** `android/app/src/main/AndroidManifest.xml:4-5`; `lib/features/auth/presentation/screens/sign_in_screen.dart:149-156`; `lib/core/performance/performance_service.dart:31`
- **Evidence:** The manifest declares com.google.android.gms.permission.AD_ID "for Firebase Analytics" and has no google_analytics_adid_collection_enabled=false meta-data. sign_in_screen.dart:149/156 set the Analytics user ID and Crashlytics identifier to the Firebase uid. performance_service.dart:31 setPerformanceCollectionEnabled(true). No call to setAnalyticsCollectionEnabled or setConsent exists anywhere in lib/. legal_content.dart:23: "it is always on (there is currently no opt-out)". The only 'consent' is arb:1767 "By …
- **Impact:** For EU/UK users, GDPR plus ePrivacy require opt-in before non-essential analytics and advertising-ID access, and Google's EU User Consent Policy applies. Under India's DPDP Act (notice and consent rules enforceable from 13 May 2027), consent bundled into ToS acceptance is not 'free, specific, informed, unconditional' (s.6). Every user's financial-app behaviour is tied to a …
- **Fix:** Add google_analytics_adid_collection_enabled=false. Remove AD_ID with tools:node="remove" (the Analytics SDK merges it in otherwise) once AdMob is removed. Add a Settings > Privacy toggle that drives Analytics, Crashlytics and Performance collection. Before DPDP enforcement in May 2027, or immediately if the app is distributed in the EEA/UK, make the toggle default-off for those locales and show a first-run notice.
- **Verifier:** Confirmed facts: the AndroidManifest.xml:4-5 AD_ID permission is declared 'for Firebase Analytics', and there is no google_analytics_adid_collection_enabled meta-data. sign_in_screen.dart:149/156 set the Analytics userId and Crashlytics identifier. performance_service.dart:31 enables Performance unconditionally. grep …

### SEC-09 · medium · Document names, file names and device paths are sent to Crashlytics; LoggerService forwards all warn/error metadata verbatim

- **Status:** Confirmed · effort S · action A30
- **Where:** `lib/features/settings/data/services/data_export_service.dart:171-180`; `lib/features/investment/data/services/document_storage_service.dart:94-97`; `lib/features/investment/data/services/document_storage_service.dart:118-121`
- **Evidence:** data_export_service.dart:171-180 calls LoggerService.warn('Document not found or inaccessible during export', metadata: {'documentId', 'documentName': doc.name, 'fileName': doc.fileName, 'localPath': doc.localPath, 'investmentId'}). logger_service.dart:150-162 builds `reason = '$message | Metadata: ${metadata...}'` and calls recordError in release builds for every warn/error. Lines 158-162 also mark every LoggerService.error as fatal: true. document_storage_service.dart:96/120 send {'path': localPath}, which …
- **Impact:** User-entered document titles such as 'Aadhaar - Ravi', 'HDFC FD receipt 5L' or 'PAN card' and on-device paths with uid end up in Crashlytics, retained 90 days and visible to anyone with console access. That contradicts README 'No PII Logging' and the policy, which says only diagnostic data is collected. Separately, non-fatal errors reported as fatal distort crash-free metrics.
- **Fix:** As the reviewer recommends: run logger metadata through an allowlist before it reaches Crashlytics, drop the name/fileName/path fields from these call sites, and use fatal: false for LoggerService.error.

### SEC-12 · medium · Firestore rules have no schema or size validation and there is no App Check while anonymous sign-up is open

- **Status:** Confirmed · effort M · action A32
- **Where:** `firestore.rules:5-7`; `pubspec.yaml:64-71`
- **Evidence:** firestore.rules:5-7: `match /users/{userId}/{document=**} { allow read, write: if request.auth != null && request.auth.uid == userId; }` with no field, type or size constraints. pubspec has no firebase_app_check, and grep for AppCheck in lib/ is empty. Guest mode means any client can obtain a uid via signInAnonymously with the public API key (google-services.json:39).
- **Impact:** A script can create unlimited anonymous accounts over REST and write up to 1 MiB per document into arbitrary subcollections at any depth. That runs up Firestore storage and write bills on a solo-founder budget, and cleanup is not deployed (SEC-04). It also lets a malformed client write documents (wrong types, huge strings) that crash other code paths after sync.
- **Fix:** As the reviewer recommends: enable App Check with Play Integrity (monitor, then enforce), allowlist the subcollection names in the rules with a size cap, and set a GCP budget alert.

### SEC-15 · medium · Account deletion can leave the Auth account (email/name) alive while telling the user data was deleted; analytics and crash data are not covered

- **Status:** Confirmed · effort S · action A06
- **Where:** `lib/features/settings/presentation/screens/data_management_screen.dart:528-579`; `lib/features/auth/data/repositories/firebase_auth_repository.dart:269-296`; `lib/features/settings/presentation/screens/data_management_screen.dart:584`
- **Evidence:** The flow deletes Firestore data first (530), then calls authRepo.deleteAccount(). On requires-recent-login, if Google re-auth is cancelled or fails, it shows 'Re-authentication failed. Your data has been deleted. Please sign out.' (566-567) and calls signOut(). The Firebase Auth user (email, display name, photo, provider link) is never deleted and there is no retry or queue. firebase_auth_repository.deleteAccount signs out of GoogleSignIn (281-283) before user.delete(), which forces a fresh account picker on …
- **Impact:** Users who cancel the re-auth prompt believe their account is gone, but their identity record stays in Firebase Auth indefinitely. That is an incomplete erasure under DPDP s.12 and GDPR Art.17, and it fails Play's requirement to delete the account and associated data. Their next sign-in silently recreates an empty account under the same uid.
- **Fix:** For non-anonymous users, re-authenticate before deleting any data, and abort with 'nothing was deleted' if cancelled. Then delete the data and the Auth user. If Auth deletion still fails, queue a deletion request and say 'scheduled'. Clear the Crashlytics identifier. Fix the misleading 'Account deletion cancelled' message.

### SEC-08 · low · Dormant AdMob ships Google's TEST App ID and a fake consent flow that always records 'obtained'

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A34
- **Where:** `android/app/src/main/AndroidManifest.xml:57-62`; `lib/core/ads/ad_service.dart:105-130`; `lib/core/ads/ad_service.dart:141-157`
- **Evidence:** The manifest sets APPLICATION_ID to "ca-app-pub-3940256099942544~3347511713" with the comment "Using Google's test app ID - replace with actual AdMob App ID in production". AdService.requestConsent(): "Placeholder: Always return obtained for MVP" -> _setConsentStatus(AdConsentStatus.obtained). _applyConsentConfiguration ignores the status. No UMP SDK is used. initialize() is never called outside lib/core/ads (grep), so ads are dormant, but google_mobile_ads ^8.0.0 is still linked into the release.
- **Impact:** Today: an extra SDK, the AD_ID permission and Data Safety ambiguity ('Contains ads' / advertising ID) with no revenue. If anyone wires AdService.initialize() as written, EEA/UK users would get ads with fabricated consent. That violates Google's EU User Consent Policy, which requires a Google-certified CMP since Jan 2024, as well as GDPR. Test IDs in production would serve test …
- **Fix:** Remove google_mobile_ads, lib/core/ads/** and the APPLICATION_ID meta-data until monetisation is decided. If ads come back, use UMP and gate initialize() on canRequestAds().
- **Verifier:** Confirmed: AndroidManifest.xml:57-62 uses Google's test App ID ca-app-pub-3940256099942544~3347511713. ad_service.dart:158-161 shows 'Placeholder: Always return obtained for MVP'. _applyConsentConfiguration ignores status. grep finds no reference to AdService or adServiceProvider outside lib/core/ads, so the SDK is …

### SEC-10 · low · The app-lock PIN lockout can be bypassed by changing the device clock; the 4-digit PIN gives a small keyspace

- **Status:** Confirmed with corrections (reviewer said medium) · effort M · action A37
- **Where:** `lib/features/security/data/services/security_service.dart:201-216`; `lib/features/security/data/services/security_service.dart:298-305`; `lib/features/security/presentation/screens/passcode_screen.dart:204-214`
- **Evidence:** getLockoutRemainingSeconds() computes `DateTime.now().difference(lockoutTime)` from wall-clock time. If the difference is ≥900s it calls _clearRateLimit(), which resets the failed-attempt counter to 0. Lockout is a fixed 15 minutes after 5 failures and never escalates. passcode_screen.dart:205-213 fixes the PIN at 4 digits (10,000 combinations).
- **Impact:** Someone holding an unlocked phone (a family member, a repair shop) can set the system clock forward 15 minutes after every 5 wrong guesses and immediately get 5 more. That allows exhausting all 10,000 PINs in roughly an hour instead of about 21 days (10,000/5 × 15 min ≈ 500 h without the trick). The lock is also purely local: Settings > Apps > Clear data, then Google sign-in …
- **Fix:** Store the lockout as a monotonic deadline (elapsedRealtime) and treat clock jumps as still locked. Escalate lockouts. Optionally allow 6-digit PINs. Describe app lock in the FAQ as preventing casual access on this device.
- **Numeric check:** python3: 10000/5=2000 rounds; no trick 2000×15min=500h=20.8 days (expected about 10.4 days); with clock trick at 20/40/60 s per round = 11.1/22.2/33.3 h. Reviewer's 'about 21 days' is right; 'roughly an hour' is wrong by about 10-30×.
- **Verifier:** Confirmed: security_service.dart:201-216 uses DateTime.now() wall-clock time against the stored lockout timestamp and calls _clearRateLimit() once difference >= 900s. Lockout is a fixed 15 minutes after 5 failures (_maxAttempts=5, _lockoutDurationSeconds=900), and passcode_screen.dart:205-213 fixes the PIN at 4 …

### SEC-11 · low · App-switcher snapshot protection relies on a Flutter overlay; FLAG_SECURE is only set on the passcode screen

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A37
- **Where:** `lib/features/security/presentation/widgets/privacy_protection_wrapper.dart:40-56`; `android/app/src/main/kotlin/com/invtracker/inv_tracker/MainActivity.kt:15-28`; `lib/features/security/presentation/screens/passcode_screen.dart:47-80`
- **Evidence:** PrivacyProtectionWrapper sets state on AppLifecycleState.inactive/paused and paints an overlay in the next frame. MainActivity says "Screenshot restriction disabled by default globally", and FLAG_SECURE is only toggled from passcode_screen (lines 62/80). No setRecentsScreenshotEnabled call exists.
- **Impact:** Android captures the Recents thumbnail when the activity pauses. A Flutter frame scheduled after `inactive` often lands after the snapshot is taken, especially on slower devices or when the app is killed from Recents. Portfolio totals can then show in the task switcher even for users who enabled app lock or privacy mode, the scenario the feature promises to cover.
- **Fix:** When app lock is enabled, call setRecentsScreenshotEnabled(false) on API 33+ (FLAG_SECURE fallback below 33) through the existing channel, and verify on a device.
- **Verifier:** Confirmed: MainActivity.kt sets FLAG_SECURE only through the setSecureMode channel, which is called only from passcode_screen (initState true, dispose false). PrivacyProtectionWrapper (app.dart:41 wraps the whole app) paints an overlay on inactive/paused. There is no setRecentsScreenshotEnabled call. The race between …

### SEC-13 · low · The production rules deploy can run from any branch with unpinned tooling holding admin credentials; other CI hygiene gaps

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A38
- **Where:** `.github/workflows/deploy-firestore-rules.yml:1-27`; `.github/workflows/release.yml:30-35`; `.github/workflows/ci.yml:50-58`
- **Evidence:** deploy-firestore-rules.yml says "Deploys firestore.rules from main", but `on: workflow_dispatch` has no ref guard, so actions/checkout checks out whatever branch was dispatched. It then authenticates as admin-bot@invtracker-b19d1.iam.gserviceaccount.com and runs `npx --yes firebase-tools@latest deploy` (unpinned npm package executing with production credentials). Actions are pinned to mutable tags (google-github-actions/auth@v3, actions/*@v4). release.yml uses a reusable workflow @v2 with `secrets: inherit` …
- **Impact:** Anyone with write access (or a compromised token or bot) can dispatch the deploy from a branch whose firestore.rules is `allow read, write: if true`, exposing every user's financial data in one click. A compromised firebase-tools release or moved tag would run with admin rights on the production project.
- **Fix:** Add `if: github.ref == 'refs/heads/main'` plus a 'production' environment. Pin firebase-tools to an exact version. Add `permissions: contents: read` at the top of ci.yml. Drop `-k` from curl. SHA-pin third-party actions using Dependabot.
- **Verifier:** Confirmed facts: deploy-firestore-rules.yml is workflow_dispatch with no ref guard despite the 'from main' comment. It authenticates as admin-bot@invtracker-b19d1 and runs `npx --yes firebase-tools@latest` (unpinned). Actions are pinned to tags (checkout@v4, auth@v3). ci.yml has no top-level permissions block, and the …

### SEC-16 · low · Sign-out leaves the unlimited Firestore offline cache, attachments and app-lock PIN on the device

- **Status:** Confirmed · effort S · action A37
- **Where:** `lib/features/auth/data/repositories/firebase_auth_repository.dart:168-171`; `lib/core/di/database_module.dart:19-22`; `lib/features/security/data/services/security_service.dart:17`
- **Evidence:** signOut() only calls _googleSignIn.signOut() and _firebaseAuth.signOut(). Firestore persistence is enabled with CACHE_SIZE_UNLIMITED (database_module.dart:20-21), and grep finds no clearPersistence()/terminate() call. Attachments stay under documents/{uid}, and the PIN in secure storage persists across accounts.
- **Impact:** On a shared or handed-down phone, the previous user's full portfolio stays in the app's SQLite cache and files (readable with root or forensic tools). The next person who signs in inherits the previous user's PIN lock.
- **Fix:** As the reviewer recommends: on explicit sign-out, terminate Firestore and clear its persistence, offer to remove downloaded attachments, and clear the PIN or key it to the uid.

### SEC-17 · low · Income Guardian notifications put exact amounts and investment names on the lock screen, ignoring privacy mode

- **Status:** Confirmed with corrections · effort S · action A29
- **Where:** `lib/core/notifications/handlers/income_guardian_notification_handler.dart:44-60`; `lib/core/notifications/handlers/income_guardian_notification_handler.dart:73`; `lib/core/notifications/handlers/income_guardian_notification_handler.dart:128`
- **Evidence:** Body text is `'$formattedAmount expected from $investmentName is $daysOverdue days late'` and `'Expecting $formattedAmount from $investmentName'`. Unlike the other handlers (investment_notification_handler.dart:85 etc. set visibility: NotificationVisibility.private), the AndroidNotificationDetails here sets no visibility and no publicVersion, and nothing checks privacy mode or app lock.
- **Impact:** A user who turned on Privacy Mode or app lock to hide amounts still gets '₹50,000 expected from LenDenClub is 3 days late' on the lock screen. Most Android devices default to 'show all notification content'.
- **Fix:** Add a 'Hide amounts in notifications' option, honouring privacy mode, across all notification handlers. Setting explicit visibility is cosmetic.
- **Verifier:** The body strings with amount and investment name exist (income_guardian_notification_handler.dart:73, :128), and the AndroidNotificationDetails there set no visibility. However, Android's default Notification.visibility is VISIBILITY_PRIVATE (0), so omitting it behaves the same as the other handlers' explicit …

### SEC-18 · low · Dead paywall code grants premium for free with a mock purchase and a hard-coded $4.99/mo price

- **Status:** Confirmed · effort S · action A57
- **Where:** `lib/features/premium/presentation/screens/paywall_screen.dart:56-66`; `lib/features/premium/data/services/premium_service.dart:1-14`; `lib/l10n/app_en.arb:1835`
- **Evidence:** onPressed: `// Mock Purchase  await ref.read(isPremiumProvider.notifier).setPremium(true);`. The entitlement is a SharedPreferences bool 'is_premium_user'. The button label is "Upgrade for $4.99/mo" (USD in an INR-first app). PaywallScreen is not referenced outside lib/features/premium (grep), so it is unreachable today.
- **Impact:** If someone wires this screen into the app (e.g. through a feature flag), users would 'buy' a subscription for free, and digital goods sold outside Google Play Billing violate Play's Payments policy. A client-side bool entitlement is trivially flippable on rooted devices.
- **Fix:** As the reviewer recommends: delete lib/features/premium, or keep it behind a compile-time flag until it uses Play Billing with server-verified entitlements.

### SEC-19 · low · Repo hygiene: stray OAuth client file from another GCP project, a global gitleaks allowlist for all Google API keys, and no Dart obfuscation

- **Status:** Confirmed · effort S · action A38
- **Where:** `android/app/client_secret_20057918856-av34pl2772k7pm908i6k783duchnv8k7.apps.googleusercontent.com.json:1`; `.gitleaks.toml:28-31`; `release.yaml:20`
- **Evidence:** A tracked OAuth 'installed' client JSON for project_id "invtracker-480115" (not the production invtracker-b19d1) sits in android/app (no client_secret value present). .gitleaks.toml allowlists the regex `AIza[0-9A-Za-z\-_]{35}` repo-wide, so ANY Google API key (Maps, Gemini, server keys) committed anywhere would be ignored. The release build command `flutter build appbundle --release ...` has no --obfuscate --split-debug-info, so Dart class and method names ship in clear.
- **Impact:** This is a low direct risk, but the blanket allowlist hides a future real key leak, and the stray client file confuses which GCP project handles auth. Unobfuscated Dart makes reverse-engineering the PIN, lockout and premium logic easier.
- **Fix:** As the reviewer recommends: delete the stray client JSON, narrow the gitleaks allowlist to google-services.json/firebase_options paths, and add --obfuscate --split-debug-info with symbol upload.

## ARCH · Architecture, state management, performance & cost

### ARCH-01 · critical · 'USD' is the silent default currency in 40+ places: CSV imports, legacy docs, merges and old backups store INR amounts as USD, so the Overview shows them about 83x too high

- **Status:** Confirmed · effort M · action A03, A04
- **Where:** `lib/features/bulk_import/data/services/simple_csv_parser.dart:269-276`; `lib/features/bulk_import/presentation/screens/import_confirmation_screen.dart:81-101`; `lib/features/settings/data/services/data_import_service.dart:437-463`
- **Evidence:** CSV parser: `// Default to 'USD' if column is missing or empty` then `currency = (currencyRaw == null || currencyRaw.isEmpty) ? 'USD' : ...` (simple_csv_parser.dart:270-276). The import confirmation builds `InvestmentEntity(...)` with no currency, so it falls back to the 'USD' constructor default, and `currency: row.currency ?? 'USD'` (import_confirmation_screen.dart:81-101). The same pattern is in the ZIP/CSV restore (data_import_service.dart:461-462), and goal CSVs from 'old exports without currency column' also …
- **Impact:** Take an Indian user whose base currency is INR and who imports a typical spreadsheet with Date, Name, Type and Amount columns (bulk import is offered on the empty Overview). Each ₹1,00,000 row is stored as USD 100,000. The Overview hero, FIRE progress and Goals convert it at the historical USD→INR rate, for example 2024-06-01 at about 83.4, and show about ₹83,40,000. The …
- **Fix:** As proposed. Also copy cf.currency, the investment's currency and its metadata in mergeInvestments. Note that the `bulkImport`/`_executeWrite` path should write `currency` explicitly. Prioritise the merge fix and the CSV default (use the base currency plus a confirmation-screen picker) before the backfill migration.
- **Numeric check:** python3: ₹1,00,000 stored as USD 100,000 × 83.4 (USD→INR on 2024-06-01) = ₹83,40,000 shown in the Overview hero, against ₹1,00,000 in the preview and on the card. That is inflated 83.4×. The app path is validCashFlows → batchConvert (cf.currency 'USD' ≠ 'INR') → calculateStats.

### ARCH-02 · high · Investment list cards, list sorting, the XIRR map and the Overview charts use unconverted raw amounts, while the detail screen and hero are converted, so the same investment shows different numbers on different screens

- **Status:** Confirmed · effort L · action A13
- **Where:** `lib/features/investment/presentation/widgets/investment_card.dart:49-62`; `lib/features/investment/presentation/widgets/investment_card.dart:419-433`; `lib/features/investment/presentation/providers/investment_stats_provider.dart:21-66`
- **Evidence:** The card watches `investmentBasicStatsProvider`/`investmentXirrProvider` (card:55-62). These are fed by `activeInvestmentBasicStatsMapProvider` and `_calculateAllXirrs`, which call `calculateStats(flows)` and `calculateXirrFromCashFlows` on raw `CashFlowEntity.amount` with no conversion (stats_provider:47-62, 69-81). The card renders `currencyFormat.formatCompact(stats.netCashFlow.abs())` with the base-currency symbol (card:422-433). The detail screen uses `multiCurrencyInvestmentStatsProvider` (detail:72), which …
- **Impact:** Users with any non-base-currency holding, such as NRIs, US stocks or the sample-data USD stock, see contradictory money numbers. Worked example: invest $1,000 on 2024-01-10 (≈₹83.0/$) and receive $1,100 on 2025-01-10 (≈₹85.6/$). The card shows '+₹100' and '10.0% IRR'. The detail screen shows +₹11,160 and 13.4% XIRR, because the INR flows are −83,000 and +94,160. The …
- **Fix:** As proposed. A pragmatic first step for a solo founder is to make activeInvestmentBasicStatsMapProvider and activeInvestmentXirrMapProvider convert, by passing all flows through batchConvert once before the isolate compute and grouping afterwards. Do the same in the four analytics providers. Then fold everything into a single snapshot provider.
- **Numeric check:** python3 XIRR. Raw USD flows (−1000 on 2024-01-10, +1100 on 2025-01-10) give 9.97% and net +100, which the card shows as '+₹100' and '10.0%'. Converted at 83.0 and 85.6: −83,000 and +94,160 give 13.41% XIRR and net +₹11,160 on the detail screen. With more realistic rates (83.15 and 85.86) it is 13.55% and +₹11,296. The …

### ARCH-03 · high · 'Total invested', 'returns', 'portfolio value' and 'goal progress' have 10+ divergent implementations: FIRE double-counts reinvested capital and goal corpus ignores invested capital

- **Status:** Confirmed · effort M · action A11
- **Where:** `lib/core/calculations/modules/financial_module.dart:73-86`; `lib/features/reports/data/services/fy_report_service.dart:66-91`; `lib/features/reports/data/services/weekly_summary_service.dart:67-76`
- **Evidence:** calculateStats treats `cf.signedAmount < 0`, i.e. INVEST+FEE, as invested and RETURN+INCOME as returned (financial_module:82-86). The FY report, weekly summary and report builder count only `CashFlowType.invest` as invested and keep income and fees separate (fy:69-87, weekly:70-75, builder:92-101). The milestone check treats invest+fee as invested and everything else as returned (notifier:790-794), using the unconverted `GoalProgressCalculator.calculate` (notifier:835), while the Goals UI uses the converted …
- **Impact:** Users see contradictory headline numbers. FIRE example: ₹10,00,000 FD (Apr-2023) matures for ₹10,70,000 (Apr-2024), which is reinvested in a new FD. FIRE treats totalInvested = ₹20,70,000 as the corpus, but the capital actually deployed is ₹10,70,000, overstated by 93%. Savings rate is inflated the same way (₹20.7L/12 ≈ ₹1.7L/month of 'savings'). Goal example: a ₹10L corpus …
- **Fix:** As proposed. Do FIRE first: corpus = Σ capitalAtRisk(open) (+ income, if the product decides), and savings = net external contributions. Then make the goal corpus definition explicit in the UI. Unreachable report services should be deleted (ARCH-09) rather than aligned.
- **Numeric check:** python3. FIRE corpus = 10,00,000 + 10,70,000 = ₹20,70,000, against net capital deployed of ₹10,70,000, overstated by 93.5%. Monthly 'savings' is 20.7L/12.2 (inDays/30 for 366 days) ≈ ₹1,69,672. The reviewer's ₹1.7L holds. Goal example: _calculateNetValue = ₹50,000 → 5% of ₹10L, matching the reviewer.

### ARCH-04 · high · One unsupported currency (14 of 43 offered, including AED and SAR) breaks the whole conversion batch: all foreign flows fall back to arbitrary 'last known' rates and unconvertible flows are summed raw

- **Status:** Confirmed with corrections · effort M · action A14
- **Where:** `lib/core/services/currency_conversion_service.dart:182-187`; `lib/core/services/currency_conversion_service.dart:390-460`; `lib/core/services/currency_conversion_service.dart:470-509`
- **Evidence:** Historical rates come only from Frankfurter v1 (ECB, 31 currencies), and the fallback is explicitly skipped for dated requests: `if (date != null) { throw CurrencyConversionException('Historical rates not available from fallback API') }` (service:797-803). The app's currency map (currency_utils.dart:132) offers 43 codes, 14 of which ECB does not publish: AED, ARS, BDT, CLP, COP, EGP, KES, LKR, NGN, PEN, PKR, SAR, TWD, VND (computed by script). In batchConvertHistorical, any missing rate throws for the whole batch: …
- **Impact:** Gulf NRIs (AED/SAR) are a core segment for an India-first alternative-investments app. An AED 10,000 deposit is summed as ₹10,000 instead of about ₹2,27,000 (USD/INR 83.4 ÷ AED peg 3.6725 ≈ 22.7). It is worse for a mixed portfolio: one AED flow forces all USD/EUR flows in the same batch onto a single arbitrary cached rate instead of their historical rates, which changes XIRR …
- **Fix:** Return a partial map from batchConvertHistorical and apply the fallback per flow. Derive AED and SAR from USD via their fixed pegs (3.6725 and 3.75). Restrict the CSV currency column to supported codes, or warn on others. Surface an 'unconverted' count in the UI. Pick the nearest-date cached rate rather than the first map entry, and add the exchangeRates index or drop that query.
- **Numeric check:** python3: AED 10,000 × (83.4 / 3.6725) = ₹2,27,093, against ₹10,000 shown when the flow is kept raw, an understatement of about 22.7×. The app path is getHistoricalRate(AED) → Frankfurter 404/422 → NetworkException → batch throw → lastKnown (null for AED) → raw 10,000 summed as INR.
- **Verifier:** The mechanism is confirmed. The API is Frankfurter v1 (ECB, 31 currencies; WebSearch confirms AED and SAR are not supported). The fallback is skipped for dated requests (currency_conversion_service.dart:797-803). batchConvertHistorical throws for the whole batch on any missing rate (452-456). BatchCurrencyConverter …

### ARCH-05 · medium · Overview shows the 'Add your first investment' empty state and ₹0 while data loads or after any error, and logs a bogus empty_state_viewed event

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A28
- **Where:** `lib/features/investment/presentation/providers/multi_currency_providers.dart:258-286`; `lib/features/investment/presentation/providers/multi_currency_providers.dart:296-351`; `lib/features/investment/presentation/providers/multi_currency_providers.dart:361-416`
- **Evidence:** multiCurrencyGlobalStats does `final cashFlows = await cashFlowsAsync.when(data: (data) async => data, loading: () async => <CashFlowEntity>[], error: (e, st) async => <CashFlowEntity>[]);` and returns `InvestmentStats.empty()` (multi_currency:262-270). Open and closed do the same. The Overview branches on `stats.hasData` (`cashFlowCount > 0`) and shows `_buildEmptyStateContent` both when data is empty and in the `error:` branch (overview:103-137). `_buildEmptyStateContent` schedules `logEvent(name: …
- **Impact:** On every cold start, until the first Firestore snapshot plus currency conversion completes (seconds on a fresh install or slow 3G), returning users see '₹0' and the onboarding empty state. On a Firestore or permission error they see 'no investments' instead of an error, which can make users think their data is lost and re-enter it, creating duplicates. The activation funnel …
- **Fix:** As proposed: `await ref.watch(...future)` semantics. Make validCashFlows a FutureProvider, or bridge it with a Completer that completes on data. Show OverviewErrorCard on error, and log empty_state_viewed once per session via ref.listen only when allInvestmentsProvider has data and it is empty.
- **Verifier:** The evidence is exact. multiCurrencyGlobalStats maps loading and error to <CashFlowEntity>[] and returns InvestmentStats.empty() (multi_currency_providers.dart:259-270). The Overview shows _buildEmptyStateContent both when hasData is false and in its error branch (overview_screen.dart:103-137). _buildEmptyStateContent …

### ARCH-06 · medium · Every 'Add transaction' fetches all goals, investments and cash flows from the server and blocks the save on it, then tears down every Firestore listener

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A26
- **Where:** `lib/features/investment/presentation/providers/investment_notifier.dart:418-466`; `lib/features/investment/presentation/providers/investment_notifier.dart:775-808`; `lib/features/investment/presentation/providers/investment_notifier.dart:815-860`
- **Evidence:** addCashFlow awaits `_checkMilestoneAfterCashFlow(investmentId)` (getInvestmentById + getCashFlowsByInvestment) for income and returns, then `await _checkGoalMilestonesAfterCashFlow();` (notifier:453-458). That method runs `watchActiveGoals().first`, `getAllInvestments()` and `getAllCashFlows()` (notifier:822-829). These are plain `.get()` calls with the default source (server when online), returning every document (repository:114-121, 401-408). All of this already lives in memory in allInvestmentsProvider and …
- **Impact:** For a user with 40 investments, 1,500 cash flows and 3 goals, each logged interest payment costs about 1 + k + 3 + 40 + 1,500 ≈ 1,550 billed reads, and the save spinner waits on that download. On Indian 3G or flaky networks that adds seconds, and offline it can stall up to the SDK's server timeout. Afterwards, every Firestore listener and every derived provider is rebuilt: …
- **Fix:** Run the milestone checks unawaited, computed from in-memory provider state (multiCurrencyAllGoalsProgress) and not from repository .get(). Drop _invalidateAll. To get save latency below 300 ms, also stop awaiting server acks in _executeWrite: fire the write and rely on the local cache plus the snapshot listener, surfacing sync errors separately.
- **Numeric check:** For 40 investments, 1,500 flows and 3 goals: 1 + k + 3 + 40 + 1,500 ≈ 1,545 billed reads per income or return transaction (the arithmetic holds). For other types it is 3 + 40 + 1,500 = 1,543.
- **Verifier:** Confirmed: addCashFlow awaits _checkMilestoneAfterCashFlow (getInvestmentById + getCashFlowsByInvestment) for income and returns. It then awaits _checkGoalMilestonesAfterCashFlow, which runs watchActiveGoals().first + getAllInvestments() + getAllCashFlows() as default-source .get() calls …

### ARCH-07 · medium · GoRouter is recreated whenever auth, security, onboarding or flag state changes: auto-lock wipes the navigation stack and unsaved forms, and setting a PIN bounces the user to Overview

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A27
- **Where:** `lib/core/router/app_router.dart:33-44`; `lib/core/router/app_router.dart:69-77`; `lib/features/security/presentation/providers/security_provider.dart:179-188`
- **Evidence:** `final routerProvider = Provider<GoRouter>((ref) { final authState = ref.watch(authStateProvider); final securityState = ref.watch(securityProvider); final onboardingComplete = ref.watch(onboardingCompleteProvider); ... final isReportsEnabled = ref.watch(isReportsTabEnabledProvider); return GoRouter(navigatorKey: rootNavigatorKey, initialLocation: '/', debugLogDiagnostics: true, ...` (app_router:33-44). SecurityNotifier mutates state on auto-lock (`lockApp(): state = state.copyWith(isLocked: true)`, 179-181), on …
- **Impact:** A user filling Add Investment who switches to their bank app to copy a number and returns after the auto-lock timeout loses the form. After unlocking they land on '/' (Overview), not where they were, and every tab's StatefulShell state is reset. Enabling a PIN or biometrics in Settings ejects the user to Overview. Each rebuild disposes all autoDispose providers, including the …
- **Fix:** Create the GoRouter once with refreshListenable plus ref.read inside redirect. Render the lock as an overlay (PrivacyProtectionWrapper) instead of a redirect, so the stack and forms survive. Use kDebugMode for debugLogDiagnostics as hygiene, and select themeMode in app.dart.
- **Verifier:** Confirmed: routerProvider ref.watches authState, securityProvider, onboarding, the analytics observer and the reports flag, and constructs a new GoRouter each time (app_router.dart:33-44). SecurityNotifier changes state on lockApp, unlock, setPin, removePin and toggleBiometrics (security_provider.dart:180-243). A new …

### ARCH-08 · medium · Feature flags default to OFF and live only in local SharedPreferences: Reports, Health Score, Income Guardian and the Play review prompt are invisible to production users, while Income Guardian's background jobs still run

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A42
- **Where:** `lib/core/providers/feature_flags_provider.dart:11-46`; `lib/core/providers/feature_flags_provider.dart:65-77`; `lib/features/home/presentation/screens/home_shell_screen.dart:33-55`
- **Evidence:** `final defaultValue = flag == FeatureFlag.portfolioHealthScore ? false : false; flags[flag] = prefs.getBool('$_prefPrefix${flag.key}') ?? defaultValue;` (feature_flags:72-73), so every flag is false unless toggled in Debug Settings. Debug Settings is shown only `if (isDebugEnabled)`, unlocked by tapping the version 7 times (`_requiredTaps = 7`, about_screen:37). Effects: the Reports tab is hidden (home_shell:50-55), the health card returns `SizedBox.shrink()` (dashboard_card:29-32), the Income Guardian card is …
- **Impact:** About 16.7k LOC (reports 8,068, portfolio_health 2,757, income_projection 5,887) are effectively shipped dark. Users never see FY reports, health score or income tracking, which are the differentiators marketing would promote. The in-app review prompt never fires, removing the cheapest rating-growth lever. Meanwhile every user pays the battery and Firestore cost of the hidden …
- **Fix:** Enable the review prompt now; it is already limited to success moments and once per install. Gate IncomeGuardianServiceInitializer on isIncomeGuardianEnabledProvider. Ship the Health Score once ARCH-13 is fixed. Keep Reports off until ReportBuilder sections are implemented. Add firebase_remote_config later, for staged rollouts.
- **Verifier:** Confirmed: every flag defaults to false (feature_flags_provider.dart:72), it is stored only in SharedPreferences, and there is no remote config in pubspec or lib. Debug Settings is unlocked by 7 taps (about_screen.dart:37) and gated in settings_screen.dart:149. The Reports tab, health card, Income Guardian card and …

### ARCH-09 · medium · Reports are hollow: 7 of 8 report types render an empty placeholder, the real FY, PDF and CSV services are unreachable, and 62 files (8,693 LOC) cannot be reached from main.dart

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A42
- **Where:** `lib/features/reports/data/services/report_builder_service.dart:27-54`; `lib/features/reports/data/services/report_builder_service.dart:57-71`; `lib/features/reports/data/services/report_builder_service.dart:146-229`
- **Evidence:** The UI uses only `dynamicReportProvider` → ReportBuilderService. Its `_buildMonthlyIncome`, `_buildFyReport`, `_buildPerformance`, `_buildGoalProgress`, `_buildMaturityCalendar`, `_buildActionRequired` and `_buildPortfolioHealth` all return `DynamicReportData(sections: [])` ('Placeholder implementations', builder:146-229), which the screen renders as 'No sections to display' (dynamic_report_screen:49-53). `_buildWeeklySummary` uses `_ref.read(validCashFlowsProvider)` and, while it is loading, returns …
- **Impact:** If the Reports flag is turned on, users get empty FY, performance and maturity reports and can get a permanent spinner. Marketing claims of FY reports and PDF/CSV export are not true for shipped code paths. The founder maintains, tests and AI-reviews about 8.7k LOC that never runs, and tests on dead code give false confidence while the live ReportBuilder paths are untested.
- **Fix:** Delete premium, ads, user_profile and the legacy report services and providers, along with their tests, or wire FYReportService into ReportBuilder before enabling the flag. Add a CI unused-files check.
- **Numeric check:** Reachability scan: 333 lib files, 271 reachable, 62 unreachable, 8,693 LOC unreachable.
- **Verifier:** Confirmed: ReportBuilderService has 7 placeholder builders returning `sections: []` (report_builder_service.dart:146-229), which render as 'No sections to display' (dynamic_report_screen.dart:49-53). _buildWeeklySummary uses _ref.read(validCashFlowsProvider) and returns a never-completing Completer while loading. …

### ARCH-10 · medium · Income Guardian sync runs one Firestore query per historical income transaction on every app start, unserialized, even though the feature is hidden

- **Status:** Confirmed · effort S · action A42
- **Where:** `lib/features/income_projection/data/services/income_guardian_sync_service.dart:41-66`; `lib/features/income_projection/data/services/income_guardian_sync_service.dart:78-127`; `lib/features/income_projection/data/services/income_guardian_monitor_service.dart:67-75`
- **Evidence:** startSync opens a second `_investmentRepository.watchAllCashFlows().listen(_handleNewCashFlows)` (sync:62-64), duplicating allCashFlowsStreamProvider. `_processedCashFlows` is in-memory only, so on the first emission of each session every INCOME flow is processed: `for (final cashFlow in incomeCashFlows) { await _attemptMatch(cashFlow); _processedCashFlows.add(cashFlow.id); }` (sync:97-100). `_attemptMatch` runs `watchExpectedCashFlowsByInvestment(cashFlow.investmentId).first` (sync:105-107), a new query per flow. …
- **Impact:** A P2P or bond investor with 1,200 monthly interest entries triggers about 1,200 sequential queries every app session. Each costs at least one billed read plus round-trip latency, competes with the UI for the Firestore channel, and drains battery. All of this is for a feature hidden behind a flag (ARCH-08). Concurrent emissions can double-match one payment to two expected flows.
- **Fix:** As proposed: gate on the flag, persist a watermark, load pending expected flows once and match in memory, serialise the handler, reuse allCashFlowsStreamProvider, and add onError to the listens.
- **Numeric check:** For 1,200 income flows: 1,200 sequential queries per session, each billed at least 1 read even when empty. That is about 1,200 reads per launch if the index exists.

### ARCH-11 · medium · Exchange-rate caching amplifies Firestore reads: 100-entry FIFO cache, no coalescing on the historical path, hourly cache wipe, per-user rate collections, and an analytics event on every cache hit

- **Status:** Confirmed with corrections · effort M · action A14
- **Where:** `lib/core/services/currency_conversion_service.dart:179-180`; `lib/core/services/currency_conversion_service.dart:265-277`; `lib/core/services/currency_conversion_service.dart:289-324`
- **Evidence:** `static const int _maxMemoryCacheSize = 100;` with eviction of `_memoryCache.keys.first` (FIFO, 179-180, 269-277). Request coalescing exists only in `getRate` (305-323). batchConvertHistorical calls `getHistoricalRate` directly (412-416), so the Overview's three concurrent providers (global, open, closed: overview:40-59) fetch overlapping rates in parallel. Each memory miss runs `_exchangeRatesRef.doc(memKey).get()`, which is a server read when online (577). Each hit calls …
- **Impact:** A user with 250 USD flows on distinct dates triggers about 500 rate lookups per Overview recompute (global + open + closed). With a 100-slot FIFO, that is roughly 400 Firestore document reads and about 500 Analytics events per recompute, and recomputes happen on every cash-flow stream emission and after every unlock (ARCH-07). The hero number waits on those round-trips. Every …
- **Fix:** As proposed, ordered by cost and benefit: (1) drop the cache-hit analytics; (2) make the memory cache unbounded for historical rates and never clear them; (3) route batch fetches through the in-flight map; (4) keepAlive the service. Shared fxRates documents are a later optimisation.
- **Numeric check:** For 250 distinct USD dates: global (250) + open + closed (≤250 combined) ≈ 500 lookups per recompute. The 100-slot FIFO thrashes, so roughly 400+ Firestore doc reads and about 500 analytics events per recompute, which is consistent with the reviewer.
- **Verifier:** Confirmed: a 100-entry FIFO memory cache (currency_conversion_service.dart:180, 269-277). Coalescing exists only in getRate (289-324), and batchConvertHistorical calls getHistoricalRate directly (412-416). Each memory miss runs a default-source doc.get() (577), and every hit or API fetch logs an analytics event …

### ARCH-12 · medium · firestore.indexes.json is missing 3 composite indexes that live queries need, and CI never deploys indexes

- **Status:** Confirmed · effort S · action A65
- **Where:** `firestore.indexes.json:1-61`; `lib/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart:41-108`; `lib/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart:126-170`
- **Evidence:** The file declares only investments(status, createdAt), cashflows(investmentId, date), archivedCashflows(investmentId, date) and goals(isArchived, createdAt). No code queries goals by isArchived, so that index is stale. These live queries need composite indexes that are absent. (1) expectedCashFlows `.where('investmentId', isEqualTo).orderBy('expectedDate')` (repo:44-46, 129-130), used by the detail screen and sync. (2) expectedCashFlows `.where('status', whereIn: [...]).where('expectedDate', …
- **Impact:** Either these indexes were created by hand in the console, in which case the repo cannot reproduce production and a `firebase deploy` from the file would offer to delete them, or they do not exist, in which case the Income Guardian monitor and per-investment expected-income section fail with FAILED_PRECONDITION and last-known-rate lookup always returns null (ARCH-04). The …
- **Fix:** As proposed. Diff against production with `firebase firestore:indexes` before deploying, so manually created indexes are not deleted.

### ARCH-14 · medium · Heavy work on the UI isolate: three portfolio-wide XIRR solves per Overview recompute, plus ZIP export (with document bytes) and PDF generation; export also issues 2N sequential queries

- **Status:** Confirmed · effort M · action A65
- **Where:** `lib/features/investment/presentation/providers/multi_currency_providers.dart:285`; `lib/features/investment/presentation/providers/multi_currency_providers.dart:350`; `lib/features/investment/presentation/providers/multi_currency_providers.dart:415`
- **Evidence:** The global, open and closed stats call `engine.financial.calculateStats(convertedCashFlows)` with includeXirr=true on the UI isolate (multi_currency:285, 350, 415). Only the per-investment raw map uses `compute` (investment_stats_provider:111). A standalone benchmark of the repo's XirrSolver (scratchpad ARCH/bench/bench.dart, JIT on a server CPU) measured 16 ms per solve at 200 flows, 38 ms at 1,000 and 76 ms at 3,000. The Overview runs three solves on overlapping sets per recompute. Export loops `for (final inv …
- **Impact:** On low-end Android phones, which are common in India and AOT-compiled but several times slower than the benchmark machine, users with 1,000+ flows get janky first Overview paint (about 100 ms+ of the 16 ms frame budget). Exporting with dozens of scanned PDFs or photos freezes the UI, risks ANR or OOM, and takes 2N sequential round-trips (about 200 for 100 investments).
- **Fix:** As proposed. The XIRR part of the fix is to wrap calculateStats in Isolate.run (or compute) inside the three multiCurrency providers. Export should use getAllCashFlows plus one documents query and ZipFileEncoder in an isolate.
- **Numeric check:** My own benchmark of the repo's XirrSolver (scratchpad ARCH-verify/bench, 40% invest and 60% inflow flows over 5 years) gave 3.9/14.4/29.3 ms per solve at 200/1,000/3,000 flows (AOT) and 7.9/16.6/38.3 ms (JIT) on a server CPU. The reviewer's JIT numbers (16/38/76) are about 2× mine but in the same range. A low-end …

### ARCH-15 · medium · LoggerService.error is reported to Crashlytics as a FATAL crash, including from widget build methods and offline timeouts

- **Status:** Confirmed · effort S · action A30
- **Where:** `lib/core/logging/logger_service.dart:134-166`; `lib/features/portfolio_health/presentation/widgets/portfolio_health_dashboard_card.dart:44-55`; `lib/features/portfolio_health/data/repositories/health_score_repository.dart:73-80`
- **Evidence:** `_crashlyticsService!.recordError(error ?? Exception(message), stackTrace, reason: reason, fatal: level == LogLevel.error);` (logger:159-164). Every `LoggerService.error(...)` call, for example 'Error initializing currency cache' (initializer:85) or the dashboard card's error branch inside `build()` (card:46-52), is recorded as a fatal event, and the build-method call repeats on every rebuild. Warnings are sent as non-fatals. Health-score save timeouts while offline are recorded as errors (repository:73-80).
- **Impact:** Crashlytics crash-free-user rates and the top-issues list are dominated by non-crashes such as network timeouts and offline cache refreshes. Real crashes get buried, and a solo founder triaging by 'fatal' count chases noise.
- **Fix:** Use fatal: false in LoggerService. Remove the second LoggerService.error in the PlatformDispatcher and zone handlers, or downgrade it to a debug log. Apply _isTransientError in the zone handler too. Never log from build().

### ARCH-17 · medium · Document picker decodes full-resolution photos for 48 px thumbnails and stores camera images at full size, risking OOM on low-end phones

- **Status:** Confirmed · effort S · action A65
- **Where:** `lib/features/investment/presentation/widgets/add_document_sheet.dart:207-211`; `lib/features/investment/presentation/widgets/add_document_sheet.dart:319-330`; `lib/features/investment/presentation/widgets/add_document_sheet.dart:474-483`
- **Evidence:** `Image.memory(_selectedBytes!, fit: BoxFit.cover)` has no cacheWidth (sheet:210). In multi-select, `Image.memory(file.bytes, width: 48, height: 48, ...)` has no cacheWidth or cacheHeight (sheet:476-482), so each thumbnail decodes the full bitmap. `picker.pickImage(source: ImageSource.camera, imageQuality: 85)` sets no maxWidth (sheet:319-323). The list widget already does this correctly with `cacheWidth: 150` (document_list_widget.dart:327).
- **Impact:** Selecting 10 phone photos of 12 MP each decodes about 10 × 48 MB ≈ 480 MB of RGBA for 48 px previews, which is a likely OOM crash on 3–4 GB devices. Stored images of about 3–5 MB each also bloat on-device storage and ZIP exports (ARCH-14).
- **Fix:** As proposed.
- **Numeric check:** A 12 MP image is 4000×3000×4 B = 48 MB RGBA. About 7-8 visible or cached thumbnails come to about 340-380 MB (the reviewer's 10 × 48 = 480 MB assumes every item is built). With cacheWidth 144 (48 × 3 dpr) each thumbnail is about 144×108×4 ≈ 62 KB.

### ARCH-19 · medium · Unused dependencies and a dormant ads SDK shipped with Google's test AdMob App ID

- **Status:** Confirmed · effort S · action A34
- **Where:** `pubspec.yaml:36-80`; `android/app/src/main/AndroidManifest.xml:57-62`; `lib/core/ads/ad_service.dart:100-115`
- **Evidence:** Import counts in lib/ and test/ are zero for `rxdart`, `dio`, `excel` and `encrypt` (grep `package:<name>/`), yet all are 'direct main' in pubspec.lock. `google_mobile_ads: ^8.0.0` is a dependency, but AdService, ad_provider and native_ad_widget are unreachable from main.dart (ARCH-09). The release manifest carries `com.google.android.gms.ads.APPLICATION_ID` = `ca-app-pub-3940256099942544~3347511713`, which is Google's sample/test App ID, with the comment 'replace with actual AdMob App ID in production'. …
- **Impact:** The Mobile Ads plugin adds native code (Play Services Ads and its WebView dependency) to every APK and its own init provider and permissions, even though the Dart side is dead. That increases download size, which matters for Indian Play users, and complicates Data Safety and 'Contains ads' declarations. Unused Dart packages are tree-shaken from the AOT binary, but they still …
- **Fix:** As proposed. Also remove `pdf` until a reachable exporter exists, and keep `archive` (used by ZIP export and import). Measure with --analyze-size.

### ARCH-20 · medium · Merge and delete are non-atomic and do not cascade: documents, expected cash flows, goal links and reminders of merged or deleted investments are orphaned

- **Status:** Confirmed · effort M · action A23
- **Where:** `lib/features/investment/presentation/providers/investment_notifier.dart:520-616`; `lib/features/investment/presentation/providers/investment_notifier.dart:337-371`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:249-257`
- **Evidence:** mergeInvestments writes the new investment via `repo.bulkImport(...)` (600), then deletes the old ones one by one: `for (final id in investmentIds) { await repo.deleteInvestment(id); }` (606-608). A failure midway leaves both the merged copy and the originals, double-counting money. It calls the repository directly, so `_cancelIncomeReminder` and `_cancelMaturityReminders` (345-346) never run for the old IDs. Repository deleteInvestment removes only cash flows and the investment doc (249-257). …
- **Impact:** After a merge, 'selected investments' goals lose their links and drop toward 0% progress. Reminders keep firing for investments that no longer exist. Documents the user believes are deleted remain as Firestore metadata and as files on the device, which is a privacy expectation issue. A partial failure double-counts totals.
- **Fix:** As proposed. Fix goal relinking and currency preservation in merge first, since those produce wrong numbers. The WriteBatch atomicity and document cleanup can follow.

### ARCH-V01 · medium · Every uncaught async error is recorded as two fatal Crashlytics events, and zone errors are recorded as fatal with no transient filtering

- **Status:** Added by verifier · effort S · action A30
- **Where:** `lib/core/analytics/crashlytics_service.dart:185-214`; `lib/main.dart:60-68`; `lib/core/logging/logger_service.dart:158-163`
- **Evidence:** In the PlatformDispatcher.onError handler the app first calls `_crashlytics.recordError(error, stack, reason: 'Uncaught async error from PlatformDispatcher', fatal: true)` and then `LoggerService.error('Uncaught async error reported to Crashlytics', ...)`. LoggerService.error records `fatal: level == LogLevel.error`, which is a second fatal event for the same error. The runZonedGuarded handler in main.dart:60-68 sends every escaped zone error to LoggerService.error, so each one is recorded as fatal. Unlike the …
- **Impact:** The crash-free-users metric and the issue counts are inflated, by at least 2× for real async crashes. Transient network or Firestore errors that escape through the zone, such as the un-handled `.listen` callbacks in Income Guardian (ARCH-10, ARCH-12), are counted as crashes. This hides real regressions from a solo founder triaging by fatal count.
- **Fix:** In both global handlers, record once (fatal: true only for non-transient errors) and replace the follow-up LoggerService.error with LoggerService.debug or info. Apply _isTransientError in the zone handler as well. Combine this with the ARCH-15 change (fatal: false in LoggerService).

### ARCH-V02 · medium · Every investment or cash-flow write blocks the UI on the server acknowledgement for up to 3 s, so offline saves always stall

- **Status:** Added by verifier · effort S · action A26
- **Where:** `lib/features/investment/data/repositories/firestore_investment_repository.dart:16`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:27-34`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:430-434`
- **Evidence:** `static const Duration _writeTimeout = Duration(seconds: 3);` and `_executeWrite` does `await writeOperation().timeout(_writeTimeout)`, catching the TimeoutException. A Firestore set(), update() or commit() future completes only when the backend acknowledges the write, so every addCashFlow, createInvestment, update or delete awaits a network round trip. When the device is offline, every save waits the full 3 s before the notifier continues. addCashFlow then also awaits the milestone reads in ARCH-06.
- **Impact:** The core 'log a transaction' flow shows a spinner for a full server round trip online, 3 s or more offline, and 3 s or more on flaky Indian mobile networks, even though the write is already in the local cache and the snapshot listener would update the UI immediately. This also caps the latency benefit claimed in ARCH-06.
- **Fix:** For single-document writes, do not await the server acknowledgement. Start the write, attach a catchError for permission or validation errors (log, then surface a sync-failed snackbar), and return immediately; the snapshot listener reflects the change from the local cache. Keep awaiting only where the result is needed, such as bulk import progress.

### ARCH-13 · low · Portfolio Health opens one cash-flow listener per investment and recomputes the score N times with partial data, logging an analytics event and pushing a score to auto-save on each pass

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A62
- **Where:** `lib/features/portfolio_health/presentation/providers/portfolio_health_provider.dart:48-107`; `lib/features/investment/presentation/providers/investment_providers.dart:72-83`; `lib/features/portfolio_health/data/services/health_score_auto_save_service.dart:27-79`
- **Evidence:** `for (final inv in investments) { final invStats = ref.watch(multiCurrencyInvestmentStatsProvider(inv.id)); if (invStats.hasValue ...) statsMap[inv.id] = invStats.value!; }` (provider:69-74). Each family instance watches `cashFlowsByInvestmentProvider(id)`, a separate `.where('investmentId'...).snapshots()` listener, on top of the global allCashFlows listener that the same build also watches (line 53). As each instance resolves, build reruns with a larger partial map, calls `engine.health.calculate`, constructs …
- **Impact:** Once the flag is on: for 40 investments, there are 40 extra listeners that re-read the same cash flows (about 2x cash-flow reads on cold start), 40 transient wrong scores and about 40 analytics events per app open, plus a score built from a subset of holdings that can be auto-saved as a history point. The health-score history chart can show dips that never happened.
- **Fix:** Before enabling the flag, compute from one converted snapshot, return loading until it is complete, log analytics once per tier change, and inject dependencies.
- **Verifier:** The code matches. PortfolioHealth.build watches multiCurrencyInvestmentStatsProvider(inv.id) per investment (portfolio_health_provider.dart:69-74). Each instance opens cashFlowsByInvestmentProvider, a separate listener. Every partial rebuild constructs AnalyticsService() directly and logs, then calls updateScore …

### ARCH-16 · low · Inconsistent async-state handling: loading becomes empty data, loading throws, never-completing futures, errors are swallowed, and ref.read is used inside FutureProviders

- **Status:** Confirmed with corrections (reviewer said medium) · effort M · action A28
- **Where:** `lib/features/reports/presentation/providers/smart_insights_provider.dart:36-52`; `lib/features/investment/presentation/providers/investment_stats_provider.dart:92-98`; `lib/features/reports/data/services/report_builder_service.dart:61-71`
- **Evidence:** At least five patterns coexist. (a) `loading: () async => <CashFlowEntity>[]` resolves the provider with empty data (goal_progress:581-591, 644-654; action_required:22-38). (b) `loading: () => throw StateError('Investments data is still loading')` (smart_insights:38), so a transient error state appears. (c) `return Completer<Map<String, double>>().future;` (stats:93) and the never-completing builder future (report_builder:66). (d) `error: (e, st) async => <...>[]` hides Firestore errors (action_required:25, …
- **Impact:** Screens flash empty or error states, reports omit items depending on timing, and real Firestore errors are invisible to users and to Crashlytics. Each new feature copies whichever pattern it sees, so the bug class keeps spreading (ARCH-05 is one instance).
- **Fix:** Fix the live sites (multiCurrency* overview and goal providers) with await ref.watch(x.future). Delete the dead reports providers instead of migrating them. riverpod_lint would help but is optional.
- **Verifier:** All five patterns exist: loading mapped to an empty list (goals goal_progress_provider.dart:573-591; action_required_provider.dart:22-38), loading throwing StateError (smart_insights_provider.dart:36-51), a never-completing Completer (investment_stats_provider.dart:93; report_builder_service.dart:66), errors swallowed …

### ARCH-18 · low · GlassCard applies BackdropFilter blur by default at 81 of 82 call sites over solid backgrounds, paying an offscreen pass for no visual effect

- **Status:** Confirmed (reviewer said medium) · effort S · action A65
- **Where:** `lib/core/widgets/glass_card.dart:28`; `lib/core/widgets/glass_card.dart:76-92`; `lib/features/investment/presentation/widgets/investment_card.dart:98-100`
- **Evidence:** `this.blur = 10` is the default (glass_card:28). When `widget.blur > 0` it wraps the card in `ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: widget.blur, ...)))` (76-92). `grep 'GlassCard('` finds 82 usages, and only investment_card passes `blur: 0`, with the comment 'Since the background is solid, blurring it has no visual effect but high cost' (investment_card:98-100). Overview, Goals, FIRE and Settings cards all sit on the same solid Scaffold background.
- **Impact:** Each blurred card forces a saveLayer and a blur pass every frame it repaints, for example during scroll or a shimmer animation. On the Overview (hero, quick stats, health, goals, FIRE and 4 chart cards) this costs measurable raster time on low-end GPUs with no visual gain.
- **Fix:** Change the default to blur = 0, opt in only where content sits over imagery, and verify in profile mode.

### ARCH-21 · low · Provider lifecycle leaks and stale caches: non-autoDispose per-entity families keep Firestore listeners alive for the whole session

- **Status:** Confirmed · effort S · action A62
- **Where:** `lib/features/investment/presentation/providers/investment_providers.dart:55-64`; `lib/features/investment/presentation/providers/investment_providers.dart:147-157`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:564-565`
- **Evidence:** `archivedCashFlowsByInvestmentProvider = StreamProvider.family` (not autoDispose) opens one listener per archived investment ever rendered (147-157). `multiCurrencyGoalProgressProvider = FutureProvider.family` (goal_progress:564-565) watches `watchGoalByIdProvider` (a non-autoDispose StreamProvider.family doc listener with an extra archived `get()` fallback, goals_provider:96-106) for each GoalCard, duplicating data already in activeGoalsProvider. `investmentByIdProvider` is a non-autoDispose FutureProvider.family …
- **Impact:** Listener count and memory grow with browsing during a session. Edited investments can show stale names in income calendar cells. The per-goal listeners are minor, since goal counts are small, but they add to Firestore listen targets.
- **Fix:** As proposed.

### ARCH-22 · low · Duplicated and dead code inside reachable files: four deprecated stats providers, two health-score algorithms, two live-cache refresh methods, a shadow analyticsServiceProvider, and 12 unused analytics methods including logSignUp

- **Status:** Confirmed with corrections · effort S · action A13
- **Where:** `lib/features/investment/presentation/providers/investment_stats_provider.dart:126-391`; `lib/features/reports/data/services/portfolio_health_service.dart:17-80`; `lib/core/calculations/modules/portfolio_health_module.dart:18-31`
- **Evidence:** `globalStatsProvider`, `closedInvestmentsStatsProvider`, `openInvestmentsStatsProvider` and `investmentStatsProvider` are @Deprecated and have 0 references outside their file. Portfolio health is implemented twice with different weights: PortfolioHealthCalculator (returns 30 / diversification 25 / liquidity 20 / goals 15 / actions 10) and PortfolioHealthService (diversification 0.3, performance 0.4, activity 0.3; service:56-60). `refreshLiveCacheOnAppStart` (pref key 'last_live_cache_refresh') duplicates …
- **Impact:** AI agents and the founder edit the wrong copy, and fixes land in one of two implementations, which is how ARCH-02 and ARCH-03 arose. Sign-up conversion cannot be measured, which blocks the user-adoption plan.
- **Fix:** Delete the deprecated providers, refreshLiveCacheOnAppStart and the unused analytics methods. Delete the unreachable PortfolioHealthService and reports_analytics_provider as part of ARCH-09. Call logSignUp when additionalUserInfo.isNewUser, as a low-cost improvement.
- **Numeric check:** Script count: 50 `Future<void> log*` methods, 12 with zero `.method(` call sites outside analytics_service.dart.
- **Verifier:** Confirmed: the four @Deprecated stats providers have 0 external references. refreshLiveCacheOnAppStart has 0 callers and duplicates refreshLiveCacheIfStale under a different prefs key. GoalProgressCalculator.calculate and calculateMultiCurrency are near-duplicates. analytics_service.dart has 1,439 lines and 50 log …

## UX · UX, accessibility & localisation

### UX-01 · high · Guest users who tap Sign Out lose all their data, and the warning is visible only to screen-reader users

- **Status:** Confirmed with corrections (reviewer said critical) · effort S · action A05
- **Where:** `lib/features/settings/presentation/screens/settings_screen.dart:164-175`; `lib/features/settings/presentation/screens/settings_screen.dart:200-225`; `lib/features/auth/data/repositories/firebase_auth_repository.dart:168-171`
- **Evidence:** Sign Out shows the same dialog for every user, including anonymous ones: signOutConfirmMessage = "Are you sure you want to sign out?" (arb:287). It then calls authRepositoryProvider.signOut(), which only runs _googleSignIn.signOut(); _firebaseAuth.signOut() (repo:168-171). Nothing checks isAnonymous, offers to link the account or makes a backup. After that, the anonymous UID can never be signed into again. The only data-loss warning (guestModeNotice, arb:2451: "...uninstalling the app may cause data loss") sits in …
- **Impact:** A guest who wants to 'switch to Google' will usually tap Settings > Sign Out and then Continue with Google. They land in an empty account, and their guest portfolio is orphaned in Firestore for good. Reinstalling or changing phone has the same result, and the FAQ tells them the opposite. This is unrecoverable loss of financial records, and users will blame the app for it in …
- **Fix:** In _handleSignOut, when user.isAnonymous: show a destructive-styled dialog ('Signing out of a guest account permanently removes access to your data') whose primary action reuses the existing GoogleSignInHandler linking flow from user_profile_card.dart, a secondary action for ZIP export, and the sign-out button styled as destructive. Fix whatIsGuestModeAnswer (arb:2501) and show guestModeNotice as visible text under the guest button. The typed-'GUEST' gate and the Overview banner are optional extras.
- **Verifier:** The evidence holds. settings_screen.dart:200-225 shows the same generic dialog to every user, with signOutConfirmMessage at arb:287, then calls authRepository.signOut(), which runs googleSignIn.signOut() and firebaseAuth.signOut() (firebase_auth_repository.dart:168-171). Nothing checks isAnonymous. Once signed out, an …

### UX-02 · high · First value takes about 22 taps: adding an investment captures no amount, and Overview still shows the empty state afterwards

- **Status:** Confirmed · effort M · action A40
- **Where:** `lib/features/investment/presentation/screens/add_investment_screen.dart:296-315`; `lib/features/investment/presentation/screens/add_investment_screen.dart:345-351`; `lib/features/investment/presentation/providers/investment_notifier.dart:36-53`
- **Evidence:** addInvestment() takes name/type/notes/maturity/rate/tenure but no amount or date (investment_notifier.dart:36-53). After saving, the screen only calls `context.pop(...)` (add_investment_screen.dart:350). Overview picks its branch with `stats.hasData ? _buildDataContent : _buildEmptyStateContent` (overview_screen.dart:104), and hasData is `cashFlowCount > 0` (investment_stats.dart:57). So a user who has just created an investment comes back to the same "See Your Real Returns / Get Started" screen as if nothing …
- **Impact:** Most new users stall after creating an investment because the dashboard does not change, and some add the same investment twice. This is the main activation leak for a solo-founder app that depends on organic retention.
- **Fix:** Priority order: (1) after saving a new investment, push InvestmentDetailScreen or AddTransactionScreen with INVEST preselected instead of popping; (2) add optional amount and date fields on Add Investment that create the first INVEST cash flow; (3) leave the Overview empty state based on investment count and show 'N investments awaiting cash flows'; (4) fix arb:527.

### UX-03 · high · An open investment with no payouts yet shows −100% in red, 0.0% XIRR and 0.00x on the hero card

- **Status:** Confirmed · effort M · action A09, A10
- **Where:** `lib/features/overview/presentation/widgets/hero_card.dart:95-110`; `lib/features/overview/presentation/widgets/hero_card.dart:243-264`; `lib/features/overview/presentation/widgets/hero_card.dart:306-307`
- **Evidence:** The hero shows `stats.netCashFlow` as the headline amount and the badge `'${stats.absoluteReturn >= 0 ? '+' : ''}${stats.absoluteReturn.toStringAsFixed(1)}%'` in redAccent (hero_card.dart:257-259). absoluteReturn = ((returned − invested)/invested)×100 (financial_calculator.dart:373). XIRR falls back with `?? 0.0` (financial_module.dart:105) and displays as '0.0%' (hero_card.dart:307; detail stats :36). Worked example: one cumulative FD of ₹1,00,000 at 7% for 3 years with nothing received yet gives hero −₹1L, badge …
- **Impact:** Cumulative FDs, bonds held to maturity, real estate and chit funds are the core of the India alternative-investment audience, and every one of them looks like a total loss until it pays out. Users read −100% as losing all their money or as an app bug, so trust drops at the very first data screen.
- **Fix:** When totalReturned == 0, or the investment is open with no inflows yet: replace the % badge with a neutral chip, "Awaiting first payout". Show XIRR as "—" with the hint "Add a payout or maturity to calculate". Rename the headline to "Net cash flow (so far)" and show a secondary "Projected at maturity: ₹1,23,144 (7.19% p.a.)" from InvestmentProjector using expectedRate and compounding (₹1,00,000 × 1.0175^12 = ₹1,23,144). Use −100% only for investments that are actually closed with zero inflow.
- **Numeric check:** Python: absoluteReturn = (0-100000)/100000*100 = -100.0%; MOIC = 0.0; XIRR (1 flow) = 0.0 per code. Projected maturity of a 7% quarterly-compounded FD over 3 years = 100000*(1.0175)^12 = 123,143.93; effective annual = 7.186%. The app displays -100.0% / 0.00x / 0.0% for the whole tenure.

### UX-04 · medium · Privacy mode does not hide the hero card's amount or return from TalkBack

- **Status:** Confirmed (reviewer said high) · effort S · action A49
- **Where:** `lib/features/overview/presentation/widgets/hero_card.dart:99-114`; `lib/features/overview/presentation/widgets/hero_card.dart:228-241`; `lib/core/utils/accessibility_utils.dart:142-149`
- **Evidence:** semanticLabel = AccessibilityUtils.statCardLabel(title: 'Net Position All Investments', value: formatCurrencyForScreenReader(netPosition, ...), subtitle: 'Return: ${formatPercentageForScreenReader(stats.absoluteReturn)}'). It is applied with `Semantics(label: semanticLabel, child: GlassHeroCard(...))` (99-114) and never checks privacyModeProvider. Compare investment_card.dart:81, which passes `shouldMask: isPrivacyMode`.
- **Impact:** With privacy mode on, TalkBack still reads the full net worth aloud, e.g. "Net Position All Investments: 12,34,567 rupees. Return: positive 14.2 percent". Anyone nearby can hear it. This is exactly the public-use case the FAQ advertises privacy mode for, and it hits visually-impaired users hardest.
- **Fix:** Watch privacyModeProvider in HeroCardContent.build and use 'Hidden amount' / 'Return hidden' when it is on. Add a semantics test with privacy mode on. Grep the other Semantics(label:) call sites that format amounts.

### UX-06 · medium · English only for an India-first app, with 400+ hard-coded UI strings that block translation

- **Status:** Confirmed with corrections (reviewer said high) · effort L · action A50
- **Where:** `l10n.yaml:20-21`; `lib/l10n/generated/app_localizations.dart:95`; `lib/features/onboarding/presentation/screens/onboarding_screen.dart:30-58`
- **Evidence:** `supportedLocales = <Locale>[Locale('en')]` (generated:95), and l10n.yaml lists only `- en`. app_en.arb has 948 keys, but a scan found 403 multi-word English literals in 62 presentation, notification and widget files, not counting single words like 'Amount', 'Date', 'Skip', 'OR', 'Required'. Top files: add_investment_screen 34, create_goal_screen 22, fire_setup_screen 20, data_management_screen 19, fire_dashboard_screen 17, add_document_sheet 17, investment_detail_screen 16, scheduled_notification_handler 16, …
- **Impact:** The app cannot reach the large non-English Indian audience. KPMG-Google found nearly 9 in 10 new Indian internet users are Indian-language users and about 70% trust local-language content more (https://qz.com/india/972844/indias-internet-users-have-more-faith-in-content-thats-not-in-english-study-says). Even after adding a hi ARB, about 40% of screens would stay in English.
- **Fix:** Phase 1 only for now: move the literals into the ARB opportunistically as screens are touched, with a CI lint to stop new ones, and replace the month array and formatRelative with intl. Defer Hindi and other locales until there is demand evidence, such as Play Console installs by device language or user requests.
- **Verifier:** The facts hold. l10n.yaml and the generated supportedLocales contain only 'en' (app_localizations.dart:95), and lib/l10n has only app_en.arb. Hard-coded literals are widespread: the onboarding pages (onboarding_screen.dart:30-58), formatRelative (date_utils.dart:30-45), the month array (overview_analytics.dart:61-74), …

### UX-08 · medium · TalkBack reads Western-grouped numbers, defaults to 'rupees' and labels net cash flow as 'current value'

- **Status:** Confirmed · effort S · action A18
- **Where:** `lib/core/utils/accessibility_utils.dart:21-52`; `lib/core/utils/accessibility_utils.dart:81-84`; `lib/core/widgets/compact_amount_text.dart:54`
- **Evidence:** formatCurrencyForScreenReader uses `NumberFormat.decimalPattern()` with Intl.defaultLocale, which is never set (it defaults to en_US). So '₹1.05Cr' on screen is read as "10,505,000 rupees" ("ten million…"), not 1.05 crore. Only ₹/$/€/£ map to names; 'AED' (symbol د.إ) or 'S$' are read as raw symbols. Positive values start with a stray space (`'$sign $formattedAmount'`). CompactAmountText defaults `currencySymbol = '₹'`, and 3 call sites omit it (overview_screen:509, overview_analytics:394, :535). A USD-base user …
- **Impact:** Visually-impaired Indian users hear amounts in an unfamiliar scale. Non-INR users get the wrong currency, and every open investment is announced as a negative current value.
- **Fix:** In formatCurrencyForScreenReader, take a locale (getCurrencyLocale(code)) and the ISO code, and say 'crore'/'lakh' for INR: 10505000 → "1.05 crore rupees" (and "1,05,05,000 rupees" on long-press). Map codes to spoken names with NumberFormat.simpleCurrency(name: code).currencyName or a small table covering the 40 codes. Make currencySymbol required on CompactAmountText. Rename the card label to 'Net cash flow' and add 'Awaiting payouts' for open investments with no inflows.

### UX-10 · medium · FIRE setup silently swaps empty or comma-formatted monthly expenses for ₹50,000

- **Status:** Confirmed · effort S · action A11
- **Where:** `lib/features/fire_number/presentation/screens/fire_setup_screen.dart:56-67`; `lib/features/fire_number/presentation/screens/fire_setup_screen.dart:80-91`; `lib/features/fire_number/presentation/screens/fire_setup_screen.dart:153-161`
- **Evidence:** _nextStep() moves to the next page without validating. The PageView (NeverScrollableScrollPhysics, no keep-alive) disposes step 2's TextFormField, so `_formKey.currentState!.validate()` on step 4 never runs its 'Required'/'Enter a valid number' validator. The value is then `double.tryParse(_monthlyExpensesController.text) ?? 50000` (:89-90). The field has keyboardType number and no input formatter, so '75,000' parses to null. FIRE settings edit does the same: `double.tryParse(controller.text) ?? …
- **Impact:** Worked example: the user enters ₹75,000 per month as '75,000'. The app saves ₹50,000, so the FIRE number (25× annual expenses, fire_stats_card:53) is 25×12×50,000 = ₹1.5 Cr instead of ₹2.25 Cr. That is ₹75 L (33%) understated with no warning, and the 'years to FIRE' is too optimistic.
- **Fix:** Validate the current step's fields in _nextStep before advancing (give each step its own GlobalKey<FormState>). Add an input formatter that strips grouping commas (FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')) plus parse after removing ','), and show live 'That's ₹75,000/month (₹9 L/yr)' feedback. Remove both `?? 50000` and `?? settings.monthlyExpenses` fallbacks and keep the sheet open with an error instead.
- **Numeric check:** Python: core corpus = monthly x 12 / 0.04 → 50,000 gives 1,50,00,000 (₹1.5 Cr) and 75,000 gives 2,25,00,000 (₹2.25 Cr). The understatement is ₹75 L (33.3%), and the other components scale linearly, so the ratio holds.

### UX-11 · medium · Core semantic colours fail WCAG AA, and ACCESSIBILITY.md publishes wrong contrast ratios

- **Status:** Confirmed · effort M · action A49
- **Where:** `lib/core/theme/app_colors.dart:18`; `lib/core/theme/app_colors.dart:22`; `lib/core/theme/app_colors.dart:26`
- **Evidence:** Ratios computed with python (WCAG 2.1 formula). Light mode: success #10B981 on white 2.54:1 (doc claims 3.2), danger #EF4444 3.76:1 (doc claims 4.1), warning #F59E0B 2.15:1, white on primary #5B4CDB 6.00:1 (doc claims 8.2). AppFeedback.showSuccess puts white text on #10B981 (2.54:1) for every 'saved/deleted' toast. The investment detail header computes `foregroundColor` for contrast (:81-86) but draws the name, type chip and app-bar title in Colors.white. White on Gold #FFD700 is 1.40:1, on FD #10B981 2.54:1, on …
- **Impact:** Gains, losses and the names of Gold, FD and Bond investments (the most common Indian alt-investment types) are hard to read outdoors and for low-vision or older users. The published 'WCAG AAA' claim is false, which is a credibility and compliance risk if quoted in store or marketing copy.
- **Fix:** As proposed, except: use #047857 (not #059669) for white-text success snackbars, and keep the bright hues for fills and icons only. Rewrite ACCESSIBILITY.md with measured values and an AA target.
- **Numeric check:** Python WCAG: 10B981/FFF 2.54; EF4444/FFF 3.76; F59E0B/FFF 2.15; FFF/5B4CDB 6.00; FFF/8B7CF6 3.33; 0A0A0A/8B7CF6 5.95; FFF/FFD700 1.40; 1C1917/FFD700 12.47; 047857/FFF 5.48; DC2626/FFF 4.83; B45309/FFF 5.02; 059669/FFF 3.77 (fails AA).

### UX-13 · medium · Settings base-currency picker shows only 14 of the 40+ supported currencies and cannot scroll

- **Status:** Confirmed · effort S · action A31
- **Where:** `lib/features/settings/presentation/screens/settings_screen.dart:342-405`; `lib/core/utils/currency_utils.dart:132-176`
- **Evidence:** _showCurrencyPicker builds `showModalBottomSheet(builder: Container(child: Column(mainAxisSize: min, children: [title, ...14 ListTiles])))` with no isScrollControlled and no scroll view. Flutter caps a non-scroll-controlled sheet at 9/16 of screen height (about 450dp on an 800dp phone), while 14 ListTiles need ≥784dp. The list is hard-coded to USD…ZAR, but currency_utils supports 40 codes, including AED, SAR, KWD-region neighbours, PKR, BDT and LKR, which are offered for individual investments through …
- **Impact:** Currencies after about the 6th entry (AUD, CHF, CNY, SGD, HKD, BRL, MXN, ZAR) are clipped and cannot be tapped. NRI users in the Gulf (a key Indian diaspora segment) cannot pick AED/SAR as their base currency at all.
- **Fix:** Reuse the searchable CurrencySelector sheet (40 codes, with search) for the base-currency setting, or use isScrollControlled: true + DraggableScrollableSheet + ListView. Pin INR, USD and AED at the top for the India/NRI audience.

### UX-14 · medium · Add Cash Flow defaults to the base currency, not the investment's, and always shows the base symbol

- **Status:** Confirmed · effort S · action A03
- **Where:** `lib/features/investment/presentation/screens/add_transaction_screen.dart:79-83`; `lib/features/investment/presentation/screens/add_transaction_screen.dart:209-210`; `lib/features/investment/presentation/screens/add_transaction_screen.dart:351`
- **Evidence:** For new cash flows: `_selectedCurrency = ref.read(currencyCodeProvider);` with the comment "We'll fetch this from the investment in the build method", but build() never reads the investment. The amount field uses `prefixText: currencySymbol` from currencySymbolProvider (base), and the preview uses currencyFormatPreciseProvider (base). Both ignore _selectedCurrency even after the user changes it. The detail screen passes only investmentId/initialType.
- **Impact:** Worked example: an INR-base user with a 'US Treasury' investment in USD types 1,000 meaning $1,000. The cash flow is saved as ₹1,000, which is roughly 1/88 of the real amount, so the investment's XIRR, MOIC and the portfolio totals are badly wrong. Even if the user notices and switches to USD, the field still shows '₹' and the preview '+₹1,000.00'.
- **Fix:** Pass the InvestmentEntity (or its currency) into AddTransactionScreen and initialise `_selectedCurrency = investment.currency`. Derive the prefix and preview formatter from `_selectedCurrency` (getCurrencySymbol/getCurrencyLocale). Show an inline note when the cash-flow currency differs from the investment's.

### UX-15 · medium · When Overview fails to load, it shows the new-user empty state and 'Try sample data', which writes into the real account

- **Status:** Confirmed · effort S · action A28
- **Where:** `lib/features/overview/presentation/screens/overview_screen.dart:130-137`; `lib/features/overview/presentation/screens/overview_screen.dart:314-344`; `lib/features/settings/presentation/providers/sample_data_provider.dart:96-118`
- **Evidence:** `error: (e, s) => _buildEmptyStateContent(...)` renders the error card inside the hero, followed by the full onboarding empty state (Get Started, Add Manually, Import CSV, Quick Templates, Try Sample Data). activateSampleData() calls service.createSampleData and stores the IDs in SharedPreferences. In the same error branch, an empty_state_viewed analytics event is also logged.
- **Impact:** An existing user hitting a Firestore permission, offline or timeout error is told, in effect, that they have no investments. They are invited to re-add data or load sample investments into their real portfolio, which creates duplicates or mixes sample data in. If prefs are later cleared, the sample rows cannot be told apart from real ones. Activation analytics are also …
- **Fix:** Give the error branch a dedicated state: "Couldn't load your portfolio. Your data is safe." with a [Retry] button that invalidates the stream providers, and an offline hint. Hide the add/sample CTAs and do not log empty_state_viewed. Tag sample documents with isSample: true in Firestore rather than relying on SharedPreferences.

### UX-17 · medium · In-app copy is inaccurate or stale: the XIRR demo math, FAQ instructions and a hard-coded 'FY 2023-24' label

- **Status:** Confirmed · effort S · action A44
- **Where:** `lib/features/overview/presentation/widgets/overview_empty_state.dart:66-72`; `lib/features/overview/presentation/widgets/overview_empty_state.dart:183-264`; `lib/features/reports/presentation/screens/reports_home_screen.dart:235`
- **Evidence:** The empty-state demo says 'Banks say 7%. What did you really earn?' and animates 'Your XIRR' from 7.0% to 6.2%, explained as 'Lock-ins and compounding affect your true return.' A 7% FD compounded quarterly gives 1,00,000 → 1,07,186 in a year, an XIRR of 7.19%: compounding raises the return. Even after 10% TDS it is 6.47%, not 6.2%. The Reports FY tile subtitle is `l10n.currentFY('2023', '24')`, so it shows 'FY 2023-24' on 2026-10-02, when the current FY is 2026-27. FAQ arb:527 tells users to enter 'amount, date' …
- **Impact:** Finance-literate users, the core audience for XIRR, will see the demo as wrong and doubt every other number. The stale FY label and wrong help text add confusion and support load.
- **Fix:** Change the demo to a correct story, e.g. "FD says 7%. After 10% TDS your real XIRR is 6.47%", or "P2P says 12%. After defaults and fees your XIRR is 9.8%". Better, compute it live from the template. Derive the FY label from DateTime.now() (April–March). Update the FAQ copy, and add a privacy-mode switch to Settings > Security & Privacy and the AppBar of Investments and Reports.
- **Numeric check:** Python: (1+0.07/4)^4-1 = 7.186% effective. With 10% TDS on interest ≈ 6.467%. App demo: 7.0% → 6.2%, attributed to 'lock-ins and compounding'.

### UX-18 · medium · XIRR, MOIC and 'Net Position' are never explained where they appear; the tooltip widget is unused

- **Status:** Confirmed · effort S · action A44
- **Where:** `lib/features/overview/presentation/widgets/hero_card.dart:146-152`; `lib/features/overview/presentation/widgets/hero_card.dart:298-313`; `lib/features/investment/presentation/widgets/investment_detail_stats_section.dart:47-70`
- **Evidence:** The hero shows the bare labels 'XIRR' and 'Net Position (All)', and the detail screen shows 'XIRR' and 'MOIC' mini cards, all with no info affordance. A MetricWithTooltip widget and l10n.xirrTooltip (arb:4053) exist, but MetricWithTooltip has 0 instantiations. The only XIRR explanation is in Settings > About > Help & FAQ (3 levels deep). After onboarding slide 2 there is no MOIC explanation anywhere.
- **Impact:** The headline differentiator (XIRR rather than the 'bank rate') means nothing to mainstream Indian investors used to FD rates and 'absolute return', which lowers perceived value and word-of-mouth.
- **Fix:** Add an (i) next to XIRR, MOIC and Net Position on the hero and detail cards. Tapping it opens a bottom sheet with plain-language copy and the user's own numbers, e.g. "XIRR 9.4% = your money grew at 9.4% a year, like an FD paying 9.4%, after accounting for when each rupee went in and came out." and "MOIC 1.25x = every ₹1 invested has returned ₹1.25 so far." Wire up the existing MetricWithTooltip.

### UX-V01 · medium · Overview briefly shows the new-user empty state to existing users on every cold start, and logs empty_state_viewed each time

- **Status:** Added by verifier · effort S · action A28
- **Where:** `lib/features/investment/presentation/providers/multi_currency_providers.dart:258-270`; `lib/features/overview/presentation/screens/overview_screen.dart:103-137`; `lib/features/overview/presentation/screens/overview_screen.dart:256-263`
- **Evidence:** multiCurrencyGlobalStats awaits `cashFlowsAsync.when(data: ..., loading: () async => <CashFlowEntity>[], error: (e, st) async => <CashFlowEntity>[])` and then returns InvestmentStats.empty() when the list is empty. While validCashFlowsProvider is still loading (cold start, before the Firestore stream emits), the provider resolves to AsyncData(empty) rather than loading. Overview then takes the `stats.hasData ? ... : _buildEmptyStateContent` branch, which renders the Get Started / Try Sample Data UI and fires the …
- **Impact:** Existing users can see a flash of 'See your real returns / Try sample data' on launch, which looks like data loss for a moment. empty_state_viewed is logged for users who already have data on most cold starts, which corrupts the activation funnel metrics the growth plan depends on. Stream errors are also turned into 'you have no data' (see UX-15). How visible the flash is …
- **Fix:** Propagate loading and error instead of converting them to empty lists. For example, if validCashFlowsProvider is loading, return `await ref.watch(validCashFlowsProvider.future)`-style waiting, or throw/rethrow so the FutureProvider stays in loading/error. Log empty_state_viewed only when allInvestmentsProvider has resolved to an empty list.

### UX-05 · low · Notifications and the recent-apps preview bypass privacy mode; notification amounts use Western grouping

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A29
- **Where:** `lib/core/notifications/notification_service.dart:612-625`; `lib/core/notifications/handlers/income_guardian_notification_handler.dart:52-60`; `lib/core/notifications/handlers/income_guardian_notification_handler.dart:71-73`
- **Evidence:** Notification bodies embed exact amounts and investment names regardless of privacy mode, for example 'Current: $formattedCurrent of $formattedTarget' and 'FY...: Income: $formattedIncome, TDS: $formattedTDS'. None of the handlers reads privacyModeProvider. _formatCurrency uses `NumberFormat.currency(symbol: symbol, decimalDigits: 2)` with no locale, so ₹1234567 renders as '₹1,234,567.00', while the app shows '₹12,34,567'. The Income Guardian AndroidNotificationDetails (52-60) omit `visibility: …
- **Impact:** Amounts show on the lock screen and in the notification shade on shared or visible phones even with privacy mode on. Western grouping in notifications confuses Indian users. On Android the recents thumbnail may be taken before the overlay frame is drawn, so the portfolio can show in the task switcher (not verified at runtime).
- **Fix:** Format notification amounts with formatCurrency(amount, symbol, getCurrencyLocale(code)) in NotificationService._formatCurrency. Optionally add a 'Hide amounts in notifications' setting, or tie it to privacy mode. Skip the visibility change (it is already the default). Consider setRecentsScreenshotEnabled(false) on API 33+ when app lock is enabled.
- **Verifier:** Mixed. CONFIRMED: no notification handler reads privacyModeProvider, and bodies include amounts and names. NotificationService._formatCurrency (notification_service.dart:612-625), used by the goal, scheduled and milestone handlers, calls NumberFormat.currency with no locale; a scratch Dart run with intl 0.20.2 prints …

### UX-07 · low · With only Locale('en') supported, Indian users get US date conventions in pickers, lists and charts

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A50
- **Where:** `lib/app/app.dart:36-37`; `lib/core/utils/date_utils.dart:49-58`; `lib/features/portfolio_health/presentation/widgets/health_score_trend_chart.dart:246-250`
- **Evidence:** MaterialApp has supportedLocales [en], so an en_IN device resolves to 'en' and the 4 showDatePicker calls (none pass `locale:`) use US MaterialLocalizations, with mm/dd/yyyy in keyboard-input mode. AppDateUtils.formatShort uses 'MMM d, y' ('Dec 19, 2025') and formatLong 'MMMM d, yyyy'. Other screens hard-code 'MMM dd, yyyy'. The health-score axis uses the literal pattern DateFormat('M/d', locale), so 5 April renders as '4/5'. formatForDisplay(DateFormatPattern.dmy) exists in date_utils.dart but has 0 call sites.
- **Impact:** Indian users typing 05/04/2025 in the date picker's input mode get 4 May instead of 5 April. Because XIRR is date-sensitive, the return is silently wrong. The chart axis '4/5' reads as 4 May to an Indian user. The overall impression is a foreign app.
- **Fix:** Set MaterialApp.supportedLocales to [Locale('en','IN'), Locale('en')]. AppLocalizations.isSupported matches on languageCode, so no new ARB is needed. Replace 'M/d' with DateFormat.Md(locale). Route list dates through formatForDisplay with the stored DateFormatPattern, or remove the dead setting.
- **Verifier:** Partly true. supportedLocales is [en], so en_IN devices resolve to 'en', and none of the 4 showDatePicker calls passes a locale. health_score_trend_chart.dart:250 uses the literal 'M/d' pattern, so 5 April shows as '4/5'. AppDateUtils.formatForDisplay and the user's DateFormatPattern (settings default dmy, …

### UX-09 · low · Every slider is announced as a meaningless percentage: a 4% safe withdrawal rate is read as "60%"

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A29
- **Where:** `lib/features/fire_number/presentation/screens/fire_setup_screen.dart:265-271`; `lib/features/fire_number/presentation/screens/fire_setup_screen.dart:317-323`; `lib/features/fire_number/presentation/screens/fire_setup_screen.dart:500-510`
- **Evidence:** There are 6 Slider widgets and 0 uses of semanticFormatterCallback in lib/. Flutter's default reads the value as a percentage of the slider's range. SWR is min 2.5, max 5.0, value 4.0, normalised to 0.6, so TalkBack says "60%". The current-age slider (18–70) at 30 reads "23%". The sliders have no `label`, and the visible caption Text is a separate node.
- **Impact:** Screen-reader users cannot set FIRE assumptions correctly. They may believe the withdrawal rate is 60% or their age is 23%, which gives a meaningless FIRE plan.
- **Fix:** Add semanticFormatterCallback ('4.0 percent', '30 years') and a Semantics label to each Slider. This is a quick fix.
- **Verifier:** The code holds. There are 6 Slider widgets (fire_setup_screen.dart:265, 317 and 590 via _buildSliderSetting, which also renders SWR at :500; fire_settings_screen.dart:418 and 639; income_guardian_settings_screen.dart:251) and 0 semanticFormatterCallback uses. Flutter's default announces round(normalized*100)%, so SWR …

### UX-12 · low · Fixed-height, non-scrolling layouts break at large font sizes or small screens, including the PIN lock screen

- **Status:** Confirmed with corrections (reviewer said medium) · effort M · action A49
- **Where:** `lib/features/security/presentation/screens/passcode_screen.dart:376-431`; `lib/features/security/presentation/screens/passcode_screen.dart:379`; `lib/features/auth/presentation/screens/sign_in_screen.dart:271-457`
- **Evidence:** PasscodeScreen is a non-scrollable Column: 60 + 48 icon + 24 + h3 text + 40 + 16 dots + Spacer + 4 keypad rows × (80 + 24 padding) + 40, about 673dp before font scaling. A 360×640dp phone has about 616dp inside SafeArea, so the bottom row (biometric/0/backspace) would be clipped. The sign-in screen and onboarding pages are also Spacer-based Columns with no scroll view. The hero amount uses `fontSize: 36, maxLines: 1, overflow: TextOverflow.ellipsis`, which truncates money (e.g. '₹12.3…') at 1.3–1.5× font scale. No …
- **Impact:** On compact phones or with large display/font size (common among older users), a user may not be able to reach '0' on the lock keypad and be locked out of the app. Sign-in buttons can be pushed off-screen. Truncating the headline amount hides the most important number. (Derived from layout arithmetic; not run on a device.)
- **Fix:** Make the passcode keypad size adapt via LayoutBuilder and theme it for dark mode. Wrap sign-in and onboarding in SingleChildScrollView + ConstrainedBox. Use FittedBox(scaleDown) for the hero amount. Add one 360x640 / 2.0x text-scale smoke test.
- **Verifier:** The layout facts are correct. passcode_screen.dart:376-431 is a non-scrolling Column (60+48+24+~28 h3+40+16+Spacer+4x(80+24)+40 ≈ 672dp). backgroundColor is hard-coded to backgroundLight. No textScaler reference exists in lib/. The sign-in and onboarding screens are Spacer Columns, and the hero amount uses maxLines:1 …

### UX-16 · low · The brand appears as InvTrack, InvTracker and 'Investment Tracker', and 'Return' vs 'Income' are used inconsistently

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A53
- **Where:** `android/app/src/main/AndroidManifest.xml:23`; `android/fastlane/metadata/android/en-US/title.txt:1`; `lib/l10n/app_en.arb:3`
- **Evidence:** Brand: the launcher label is android:label="InvTracker"; the Play title is "InvTrack - Investment Tracker"; appTitle is "InvTrack"; the sign-in wordmark is 'InvTracker'; the paywall says "InvTracker Premium"; the Overview AppBar says 'Investment Tracker'. Terminology: the cash-flow type labelled 'Return' means principal back on exit or maturity ('Money returned (exit/sale)'), but 'Returns' means profit elsewhere: sort options 'Total Returns (High)' and 'Return %', TalkBack 'Returns: positive x percent' (which is …
- **Impact:** Users searching Play for 'InvTrack' see 'InvTracker' on their home screen, which weakens recall and trust. Mixing up principal-back ('Return') with income (interest) leads to mis-categorised cash flows, which feeds wrong income reports and an FY interest total that excludes or double-counts amounts.
- **Fix:** Choose one brand, e.g. 'InvTrack', and apply it to the manifest label, sign-in wordmark, AppBar (use l10n.appTitle) and paywall. Rename the cash-flow types to 'Invest', 'Payout – principal/maturity' (or 'Exit'), 'Income – interest/dividend/rent' and 'Fee', with one-line helper text under each chip. Reserve 'Return' for profit metrics. Use a single colour map for cash-flow types (CashFlowTypeUI.color) in bulk import too.
- **Verifier:** Brand variants confirmed: AndroidManifest.xml:23 label 'InvTracker'; Play title 'InvTrack - Investment Tracker'; appTitle 'InvTrack'; the sign-in wordmark 'InvTracker' (sign_in_screen.dart:353); arb:1747 'InvTracker Premium'; the Overview AppBar 'Investment Tracker' (overview_screen.dart:93-96). Terminology confirmed: …

### UX-19 · low · Charts have no text alternative for screen readers and use hard-coded English month names

- **Status:** Confirmed · effort S · action A49
- **Where:** `lib/features/overview/presentation/widgets/overview_analytics.dart:44-150`; `lib/features/overview/presentation/widgets/overview_analytics.dart:186-280`; `lib/features/reports/presentation/widgets/daily_cashflow_chart.dart:61-73`
- **Evidence:** MonthlyCashFlowTrend draws bars from Containers with no Semantics. TalkBack hears only 'Jan Feb Mar…' (a hard-coded English array, :61-74), with red/green meaning conveyed only by colour and a legend. TypeDistributionChart's bar has no semantics either. DailyCashFlowChart's tooltip uses `NumberFormat.compactSimpleCurrency(locale: 'en')`, which renders '$' for Indian users. It is currently unreferenced, but would be wrong if wired up.
- **Impact:** Blind and low-vision users cannot get the monthly in/out trend or allocation. Colour-blind users depend on the legend.
- **Fix:** Wrap each month column in Semantics(label: 'March: out ₹50K, in ₹12K'), masked in privacy mode, and the distribution bar in a summary label ('FD 45%, P2P 30%, Gold 25%'). Use DateFormat.MMM(locale). Fix or delete DailyCashFlowChart (use currencyFormatCompactProvider).

### UX-20 · low · Several primary controls are smaller than 48dp, and no test enforces the tap-target guideline the docs claim

- **Status:** Confirmed · effort S · action A49
- **Where:** `lib/core/widgets/privacy_toggle_button.dart:139-173`; `lib/features/overview/presentation/widgets/hero_card.dart:175-211`; `lib/features/onboarding/presentation/screens/onboarding_screen.dart:239-265`
- **Evidence:** Privacy toggle: 18px icon + 8px padding each side + 1px border ≈ 34dp. The Realized/All toggle has vertical padding 5 around a 14px icon / 12sp text, about 26dp tall. Inactive onboarding dots are 8 + 2×4 = 16dp wide. Template chips have vertical padding 8 around 16sp, about 36dp. ACCESSIBILITY.md says buttonHeightSm = 40 and buttonHeightMd = 48, but app_sizes.dart:56-59 has 36 and 44. No test in test/ or integration_test/ uses androidTapTargetGuideline, labeledTapTargetGuideline or textContrastGuideline.
- **Impact:** The privacy toggle, the main privacy control, and the realised/all switch are easy to miss on the hero card, especially for users with motor impairments. The docs claim compliance the code does not have.
- **Fix:** Wrap these in a SizedBox or ConstrainedBox of at least 48×48 (the visual can stay small). Fix app_sizes or the doc. Add a11y guideline tests: `expect(tester, meetsGuideline(androidTapTargetGuideline))` for Overview, Investment list, Add cash flow and Lock screen.

### UX-21 · low · Account deletion wipes data before re-authenticating, then says 'Account deletion cancelled' if re-auth is cancelled

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A06
- **Where:** `lib/features/settings/presentation/screens/data_management_screen.dart:526-560`; `lib/features/settings/presentation/screens/data_management_screen.dart:561-576`; `lib/l10n/app_en.arb:1329`
- **Evidence:** `await _deleteAllUserData();` runs first (:530). Only then does deleteAccount() hit requires-recent-login and trigger reauthenticateWithGoogle(). If the user dismisses the Google sheet, the snackbar shows l10n.accountDeletionCancelled = "Account deletion cancelled" (arb:1329) and the user is signed out. Every investment, goal and document has already been deleted. Neither confirmation step offers 'Export a backup first'.
- **Impact:** The user is told the deletion was cancelled. When they sign in again they find an empty account, which reads as silent data loss even though they confirmed earlier.
- **Fix:** Re-authenticate first (if a recent login is required), then delete the data, then delete the account. Otherwise change the copy to 'Your data was deleted, but your sign-in account could not be removed. Sign in again and repeat to finish.' Offering an export in the first dialog is a nice-to-have.
- **Verifier:** The order is as described. data_management_screen.dart:526-530 runs _deleteAllUserData() before deleteAccount(). On requires-recent-login with a cancelled re-auth it shows accountDeletionCancelled ('Account deletion cancelled', arb:1329) and signs out (:546-559), leaving the Firebase Auth record behind. The message is …

### UX-22 · low · Notification permission is requested right after sign-in, before the user has created anything

- **Status:** Confirmed · effort S · action A45
- **Where:** `lib/features/auth/presentation/screens/sign_in_screen.dart:158-160`; `lib/features/auth/presentation/screens/sign_in_screen.dart:207-209`; `lib/features/auth/presentation/screens/sign_in_screen.dart:224-245`
- **Evidence:** Both sign-in paths call _requestNotificationPermissionsIfNeeded(), which fires the OS dialog straight away, once per install (`notification_permissions_requested`), with no rationale screen.
- **Impact:** On Android 13+ a cold ask with no context gets a lower grant rate. Maturity, income and weekly check-in reminders are the app's main re-engagement loop, and a denial is effectively permanent.
- **Fix:** Defer the request until the user saves an investment with a maturity date or income frequency. Show a pre-prompt first: "Want a reminder 7 days before 'HDFC FD' matures on 12 Mar? We never show amounts on your lock screen."

### UX-23 · low · No indicator while offline, and every load failure is described as a connection problem

- **Status:** Confirmed · effort S · action A28
- **Where:** `lib/core/widgets/connectivity_listener.dart:58-62`; `lib/core/widgets/connectivity_listener.dart:136-144`; `lib/features/investment/presentation/widgets/investment_list_states.dart:216-223`
- **Evidence:** ConnectivityListener only shows a 'Back online' toast (white on #10B981, 2.54:1) when connection returns, and nothing while offline. The list and detail error states always say 'Connection Error … check your connection', whatever the exception. Export and import errors show raw `state.error.toString()` / `e.toString()` to the user.
- **Impact:** Onboarding promises 'Works Offline, Syncs Online', but users get no reassurance that offline edits are queued, and they see technical exception text on export failures.
- **Fix:** Add a subtle persistent banner while offline: "Offline: changes are saved on this phone and will sync automatically." Map errors through ErrorHandler.mapException(...).userMessage instead of toString().

### UX-24 · low · Screen-reader gaps in key forms: the date field hides its value, and PIN progress and errors are not announced

- **Status:** Confirmed · effort S · action A49
- **Where:** `lib/features/investment/presentation/screens/add_transaction_screen.dart:285-291`; `lib/l10n/app_en.arb:2241`; `lib/features/security/presentation/screens/passcode_screen.dart:390-412`
- **Evidence:** The date selector is `Semantics(button: true, label: l10n.semanticSelectTransactionDate /* 'Select transaction date' */, excludeSemantics: true, ...)`, which excludes the child Texts showing the chosen date. The PIN dots are plain Containers with no semantics, and _message ('Incorrect PIN', 'Locked out. Try again in 30s') is not in a liveRegion and is not announced. The lockout seconds are static and do not count down.
- **Impact:** TalkBack users cannot confirm which date they are about to save, and XIRR depends on dates. On the lock screen they get no feedback on digits entered or failures.
- **Fix:** Label the date field 'Transaction date, ${formatDateForScreenReader(_selectedDate)}, double-tap to change'. Wrap the dots in Semantics(label: '${_input.length} of 4 digits entered'). Make the message Text liveRegion: true, and add a Timer to count the lockout down.

### UX-25 · low · Destructive actions are confirmed but have no undo, and the success toast shows before deletion finishes

- **Status:** Confirmed · effort M · action A26
- **Where:** `lib/core/widgets/swipe_actions.dart:189-198`; `lib/features/investment/presentation/screens/investment_detail_screen.dart:479-482`; `lib/features/investment/presentation/screens/investment_list_screen.dart:413-429`
- **Evidence:** SwipeActions calls `deleteConfig!.onDelete();` without awaiting it, then immediately calls AppFeedback.showSuccess(...) (:196-198). The list's onDelete fires deleteInvestment() without await. _deleteCashFlow likewise shows 'Transaction deleted' synchronously. A repo-wide grep finds SnackBarAction only for retry/ok, never undo.
- **Impact:** A mis-swipe after an accidental confirm loses an investment and its whole cash-flow history permanently. Async failures are hidden behind a success message.
- **Fix:** Await the delete and only then show success. For cash flows and investments, use a 5-second 'Deleted · UNDO' snackbar backed by soft-delete (archive first, purge after timeout), which reuses the existing archive path.

### UX-26 · low · The dormant paywall would grant premium without payment and shows a USD price to an India-first audience

- **Status:** Confirmed · effort M · action A57
- **Where:** `lib/features/premium/presentation/screens/paywall_screen.dart:39-69`; `lib/features/premium/presentation/widgets/premium_gate.dart:21-33`; `lib/l10n/app_en.arb:1747`
- **Evidence:** The CTA's onPressed is `// Mock Purchase await ref.read(isPremiumProvider.notifier).setPremium(true);`. The button text is upgradeForPrice = "Upgrade for $4.99/mo". The feature list sells 'CSV Export & Import' and 'Cloud Backup & Sync', which are already free in Data & Account, plus '(Coming Soon)' analytics. PremiumGate is currently never instantiated, so the paywall is not reachable today.
- **Impact:** If it is wired up as-is, it gives premium away for free and shows a hard-coded USD price that Play billing rules disallow. Paywalling features users already have would anger them.
- **Fix:** Before enabling, integrate Play Billing and use ProductDetails.price (₹ localised). Base the value proposition on genuinely new features (e.g. multi-portfolio, advanced FY tax pack, family sharing) and keep the free tier's backup and export.

### UX-V02 · low · Income Guardian notifications show the ISO code instead of the currency symbol (e.g. 'Expecting INR25K from …')

- **Status:** Added by verifier · effort S · action A18
- **Where:** `lib/features/income_projection/presentation/providers/income_guardian_service_providers.dart:37-41`; `lib/core/notifications/handlers/income_guardian_notification_handler.dart:45-49`; `lib/core/notifications/handlers/income_guardian_notification_handler.dart:101-105`
- **Evidence:** The handler calls _formatCurrency(expectedAmount, currency, locale), where currency is expectedCashFlow.currency (an ISO code). The provider wires that as `formatCompactCurrency(amount, symbol: symbol, locale: locale)`, so the ISO code becomes the symbol. A scratch Dart run with intl 0.20.2, NumberFormat.compactCurrency(locale: 'en_IN', symbol: 'INR', decimalDigits: 2), printed 'INR25K' for 25000 and 'INR2.5L' for 250000.
- **Impact:** Every overdue and upcoming payment notification, which drives the app's main re-engagement loop, reads 'INR25K' or 'USD1.5K' instead of '₹25K' or '$1.5K'. That looks unpolished in the notification shade.
- **Fix:** Map the code to a symbol in the provider: `formatCompactCurrency(amount, symbol: getCurrencySymbol(code), locale: locale)`.

## MON · Monetization & business model

### MON-01 · high · There is no way to earn money today: no billing SDK, and both the premium module and the AdMob code are dead code that nothing calls

- **Status:** Confirmed · effort L · action A57
- **Where:** `pubspec.yaml:33-86`; `lib/features/premium/presentation/widgets/premium_gate.dart:7-62`; `lib/features/premium/presentation/screens/paywall_screen.dart:8-97`
- **Evidence:** pubspec.yaml includes google_mobile_ads ^8.0.0 (line 83) but no in_app_purchase, purchases_flutter or any other Play Billing plugin. Searching lib/, test/ and integration_test/ for PremiumGate|isPremiumProvider|PaywallScreen|premiumServiceProvider finds nothing outside lib/features/premium/. The gate and the paywall are never mounted and no route leads to them. The same search for adServiceProvider|NativeAdWidget|loadNativeAd|AdPlacementStrategy|MobileAds finds nothing outside lib/core/ads and …
- **Impact:** The live Play app earns ₹0. Firebase and exchange-rate API costs still grow with every user. Every revenue number in the planning docs is unreachable, and Q1–Q3 2026 have already passed with no revenue. Users have never been told what is or will be paid, so adding prices later will feel more abrupt.
- **Fix:** Keep the decision to use Play subscriptions only and remove ads. Set the launch date only after the Premium feature set actually works from start to finish. The Reports detail screens are empty stubs today (MON-V02), so set a realistic target: a free Tax-Year report MVP for the Feb–Mar 2027 advance-tax and year-end window, then Premium gating with RevenueCat before the Jun–Jul 2027 ITR season. Remove the mock paywall now.

### MON-07 · high · The most sellable features (Reports and FY report, PDF export, Portfolio Health, Income Guardian) are hidden behind developer flags, so there is nothing new to charge for

- **Status:** Confirmed with corrections · effort L · action A58
- **Where:** `lib/core/providers/feature_flags_provider.dart:17-46`; `lib/core/providers/feature_flags_provider.dart:69-74`; `lib/features/home/presentation/screens/home_shell_screen.dart:33`
- **Evidence:** Every flag defaults to off: `final defaultValue = flag == FeatureFlag.portfolioHealthScore ? false : false;`. Release users therefore never see the Reports tab (`if (isReportsEnabled)` at home_shell_screen.dart:51), the Portfolio Health card, or Income Guardian (overview_screen.dart:179). ReportPdfExporter is implemented, but ReportExportButton is used by no screen; the only match is its own file. Flags are stored in SharedPreferences and toggled from DebugSettingsScreen. Any release user can open that screen by …
- **Impact:** Everything shipped today is free, so a paywall launched now could only work by taking features away, which risks review-bombing. Meanwhile the features people would plausibly pay for (a tax-season report, a PDF for their CA, a health score) sit unreleased. If the flag mechanism were reused for paid gating, anyone could bypass it.
- **Fix:** Re-plan around building one feature fully rather than flipping flags. Build the Tax-Year report end to end: real service, then screen sections, then PDF/CSV export using the real FYReport fields, with widget and export tests. Add Portfolio Health history next. Release them as free features first to measure engagement, then gate the deeper views with a server-backed entitlement. Do not use FeatureFlag or SharedPreferences for gating. Consider hiding the 7-tap debug unlock in release builds.
- **Verifier:** The flag facts hold:
- feature_flags_provider.dart:72 sets `defaultValue = ... ? false : false`.
- home_shell_screen.dart:51 adds the Reports destination only when the flag is on, and app_router.dart:83-86 redirects /reports to / when it is off.
- PortfolioHealthDashboardCard returns SizedBox.shrink when disabled, and …

### MON-04 · medium · The AdMob code cannot work as written, yet release builds still ship the Ads SDK, Google's test App ID and a fake consent flow

- **Status:** Confirmed · effort S · action A34
- **Where:** `android/app/src/main/AndroidManifest.xml:57-62`; `ios/Runner/Info.plist:76-86`; `lib/core/ads/ad_service.dart:147-162`
- **Evidence:** The main (release) manifest sets com.google.android.gms.ads.APPLICATION_ID to Google's sample ID 'ca-app-pub-3940256099942544~3347511713'. Info.plist does the same with '~1458002511'. Release ad unit IDs are literal placeholders such as 'ca-app-pub-YOUR_PUBLISHER_ID/INVESTMENT_LIST_AD_UNIT'. NativeAd uses factoryId 'investmentListNativeAd', but MainActivity registers no NativeAdFactory and no nativeTemplateStyle is passed, so a load would fail. nativeAdProvider always returns AsyncValue.loading(), and …
- **Impact:** The app ships extra APK size and SDK surface for zero revenue, and the Data Safety form must disclose an ads SDK. Wiring it up as-is would serve no ads (test App ID). With real IDs, it would serve ads in the EEA/UK/Switzerland without a Google-certified consent platform. AdMob has required one since 16 Jan 2024 (support.google.com/admob/answer/13554020); without it Google …
- **Fix:** Remove the ads stack completely: lib/core/ads/*, lib/core/widgets/native_ad_widget.dart, google_mobile_ads in pubspec, the APPLICATION_ID meta-data, and GADApplicationIdentifier/SKAdNetworkItems in Info.plist. Mark docs/AD_INTEGRATION_*.md and docs/FEATURE_PLAN_ADS_AND_NOTIFICATIONS.md as superseded. Set 'Contains ads: No' in Play Console and update Data Safety. If ads are ever reconsidered, that requires UMP, real IDs and native templates, but see MON-05 first.

### MON-09 · medium · Code and docs give four conflicting price points, and the roadmap's ₹799/month is about 3x what comparable Indian apps charge

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A58
- **Where:** `lib/l10n/app_en.arb:1835`; `docs/PRODUCT_ROADMAP.md:520`; `docs/PRODUCT_ROADMAP.md:537`
- **Evidence:** The four price points:
- Paywall string: '$4.99/mo'.
- Roadmap: Pro '₹799/month or ₹5,999/year', Family '₹1,499/month or ₹11,999/year', Advisor '₹3,999/month or ₹35,999/year'.
- MBA doc: '₹299/month or ₹2,999/year'.
- Ads plan: an ad-free 'Premium' tier at '₹99/month'.

2026 benchmarks (from search-result snippets; the live pages were blocked, so re-verify before publishing):
- Tickertape Pro: ₹249/month auto-renew, ₹2,399/year (tickertape.in/pricing).
- Value Research: about ₹5,841/year including taxes …
- **Impact:** ₹799/month (₹9,588/year) for a manual-entry tracker with no market data is more expensive than every Indian comparable, so conversion would be near zero. The ₹11,999 and ₹35,999 annual plans exceed the RBI e-mandate limit for debits without extra authentication (₹15,000) and Google Play's original under-₹5,000 cap on Indian auto-renewing subscriptions. Plans above that cap are …
- **Fix:** Keep a single PRICING.md as the source of truth, with Premium at ₹149/month and ₹999/year plus an optional ₹2,999 lifetime product. Keep every India auto-renew price under ₹5,000 until Play's current India rules are confirmed in Play Console. Use Play regional pricing elsewhere. Delete the conflicting tables in the roadmap, MBA, strategy and ads docs.
- **Numeric check:** ₹149 × 12 = ₹1,788, and ₹999 ÷ 1,788 means a 44.1% saving. ₹999 ÷ 12 = ₹83.25 a month. Net per annual subscriber = 999 ÷ 1.18 × 0.85 = ₹719.6. These match the reviewer. ₹11,999 < ₹15,000, which contradicts the reviewer's claim.
- **Verifier:** The four conflicting price points exist:
- app_en.arb:1835 '$4.99/mo'.
- Roadmap Pro ₹799/₹5,999, Family ₹1,499/₹11,999, Advisor ₹3,999/₹35,999.
- MBA doc ₹299/₹2,999 (line 631).
- FEATURE_PLAN:941 ad-free tier at ₹99/month.
WebSearch confirms Tickertape Pro at ₹249/month and ₹2,399/year (from 2023 pricing; current …

### MON-10 · medium · Split free and Premium around new value; the roadmap's free tier would take back features users already have

- **Status:** Confirmed (reviewer said high) · effort M · action A58
- **Where:** `docs/PRODUCT_ROADMAP.md:503-518`; `docs/research/MBA_LEVEL_INNOVATION_ANALYSIS.md:611-625`; `lib/features/settings/presentation/screens/data_management_screen.dart:56-121`
- **Evidence:** The roadmap's free tier sets 'Active Investments 5' and 'Data Retention 1 year', and marks 'CSV Import ❌', 'Export Reports ❌', 'Notifications ❌' and 'Multi-Currency ❌'. Apart from the two caps, all of these ship free today: CSV export/import and ZIP backup/restore are in DataManagementScreen, and notifications, multi-currency, goals and FIRE are unrestricted. There are no limit constants anywhere in lib/ (searching for maxInvestments or investmentLimit finds nothing). exportAsZip (data_export_service.dart:50) …
- **Impact:** Capping existing users at 5 investments, or deleting data older than a year, would break XIRR on multi-year FDs and bonds and trigger review-bombing. Gating notifications would remove the app's main retention hook.
- **Fix:** As the reviewer proposes, keep everything that is free today free forever, and build Premium only from new features. Scope it to features that will really exist by launch (the Tax-Year report with PDF export, then Health history), not the long H1/H2 list.

### MON-11 · medium · Billing plan: use RevenueCat (purchases_flutter) keyed to the Firebase UID, and keep entitlements out of the client-writable users/{uid} tree

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A59
- **Where:** `firestore.rules:5-7`; `firebase.json:1-5`; `functions/src/cleanupAnonymousUsers.ts:5-16`
- **Evidence:** Firestore rules contain `match /users/{userId}/{document=**} { allow read, write: if request.auth != null && request.auth.uid == userId; }`, so any entitlement stored there can be written by the user. firebase.json configures only Firestore; there is no Functions backend for verifying receipts on a server. Guest (anonymous) accounts are deleted by cleanupOldAnonymousUsers after 30 days of inactivity. Guest-to-Google linking already exists (linkWithCredential, line 395). After 31-Aug-2026, Play no longer accepts …
- **Impact:** A home-grown in_app_purchase integration would need Cloud Functions on the Blaze plan, Play Developer API verification and Pub/Sub handling of real-time notifications. That is roughly 2–3 extra weeks for a solo founder. Storing a premium flag in users/{uid} or SharedPreferences lets anyone give themselves Premium. Purchases made by guests would be orphaned when their account …
- **Fix:** Keep steps 1-7. Ground the guest-linking requirement on anonymous UIDs not surviving reinstall or sign-out, rather than on the cleanup function. Check whether the function is actually deployed and either delete the orphan source or add a proper functions setup. Use the RevenueCat Firebase extension or webhook with Firestore rules that deny client writes to /entitlements/{uid}.
- **Verifier:** Confirmed:
- firestore.rules:5-7 lets the owner write anything under users/{uid}.
- firebase.json configures only Firestore plus FlutterFire, with no functions block.
- linkWithCredential exists in firebase_auth_repository.dart (around line 395).
- WebSearch confirms the Play Billing Library 7 cutoff (31-Aug-2026, …

### MON-13 · medium · There is no monetization tracking or remote configuration, so gate thresholds and prices cannot be measured or tested

- **Status:** Confirmed · effort S · action A61
- **Where:** `lib/core/analytics/analytics_service.dart:387-399`; `pubspec.yaml:64-71`; `lib/core/providers/feature_flags_provider.dart:64-77`
- **Evidence:** AnalyticsService.setUserProperty exists but is never called outside analytics_service.dart. There are no paywall, trial or purchase events; the logging methods cover investments, goals, reports, health and Income Guardian only. pubspec has firebase_analytics, crashlytics and performance but no firebase_remote_config. Feature flags read only local SharedPreferences.
- **Impact:** The founder cannot answer questions like 'how many users have more than 10 investments, use multi-currency, or open reports', so every gate and price is a guess. There is also no way to A/B test paywall copy, or to turn off Premium enforcement in an emergency, without shipping a Play release.
- **Fix:** Add bucketed user properties: investment_count_bucket (1-4 / 5-9 / 10-24 / 25+), active_types_count, has_goal, auth_type (guest/google) and plan (free/trial/premium/lifetime). Add events: paywall_viewed{source}, paywall_dismissed, trial_started{plan}, purchase_completed{product}, purchase_failed{code}, restore_completed, and subscription_cancelled (fed from RevenueCat). Add firebase_remote_config to control paywall copy, which features are gated, whether the trial is on, and a premium_enforced kill switch. Ship the tracking 4–6 weeks before launch so thresholds rest on real data.

### MON-16 · medium · The store listing makes a false data-storage claim and says nothing about being ad-free or about pricing

- **Status:** Confirmed · effort S · action A01
- **Where:** `android/fastlane/metadata/android/en-US/full_description.txt:59-63`; `android/fastlane/metadata/android/en-US/full_description.txt:22`; `lib/features/settings/presentation/screens/legal_content.dart:21`
- **Evidence:** The listing says '☁️ Cloud Backup — Sign in with Google to backup your data' and '🔒 Your Data, Your Control — We don't store your financial data on our servers. It stays with you.' The privacy policy, however, says 'Your data is securely stored in your private cloud account (Google Firebase)', and product.yaml lists remote storage in Cloud Firestore under users/{uid}. The listing never mentions 'no ads' or pricing, and its 'NEW IN VERSION 3.6.0' header (line 22) is stale against 3.70.18.
- **Impact:** Once users are paying, a demonstrably false privacy claim exposes the app to Play's Misleading Claims enforcement and to consumer complaints. It also undercuts the trust story, which is the main reason anyone would pay a small indie app instead of using free INDmoney or Kuvera.
- **Fix:** Rewrite the trust bullets as: 'No ads. We never sell your data. Your records sync to your private, Google-Firebase-backed account; export everything to CSV/ZIP anytime.' At the Premium launch, add a short 'Free vs Premium' section (Play shows the 'In-app purchases' label automatically). Update the 'what's new' header with each release.

### MON-V02 · medium · Every Reports detail screen is an empty placeholder, and the FY PDF/CSV export targets fields that do not exist

- **Status:** Added by verifier · effort L · action A60
- **Where:** `lib/features/reports/data/services/report_builder_service.dart:27-220`; `lib/features/reports/presentation/screens/dynamic_report_screen.dart:48-53`; `lib/features/reports/presentation/screens/reports_home_screen.dart:234-236`
- **Evidence:** ReportBuilderService.buildReport sends all 8 ReportTypes to builders that return `DynamicReportData(..., sections: [])`. DynamicReportScreen then renders 'No sections to display'. Every tile on ReportsHomeScreen navigates to /reports/builder, which is DynamicReportScreen. fyReportProvider and currentFYReportProvider, the only consumers of FYReportService, are used by no widget. The FY tile subtitle is hard-coded as `l10n.currentFY('2023', '24')`. The FY PDF and CSV exporters read `report.fyYear`, …
- **Impact:** The 'sellable features hidden behind flags' (MON-07) are mostly unbuilt, so the monetization plan's January 2027 Premium launch rests on work that has not started. Release users who enable Reports with the 7-tap debug unlock (about_screen.dart) see empty reports and 'FY 2023-24'.
- **Fix:** Re-baseline the plan:
1. Build the Tax-Year report end to end first: FYReportService output feeding real DynamicReportData sections, the screen, and PDF/CSV exporters typed to FYReport rather than dynamic.
2. Derive the FY label from the date.
3. Add a widget test that the FY report renders non-empty sections, plus export tests.
4. Only then add the Premium gate and billing.
5. Hide the debug unlock in release builds, or exclude unfinished flags from it.

### MON-02 · low · Mock paywall grants Premium for free, shows a hard-coded USD price, and sells features that are already free

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A57
- **Where:** `lib/features/premium/presentation/screens/paywall_screen.dart:27-44`; `lib/features/premium/presentation/screens/paywall_screen.dart:56-65`; `lib/l10n/app_en.arb:1835`
- **Evidence:** The button's onPressed handler is `// Mock Purchase` followed by `await ref.read(isPremiumProvider.notifier).setPremium(true);`, then a 'Welcome to Premium!' snackbar. The button label l10n.upgradeForPrice reads "Upgrade for $4.99/mo", in USD, in an app built for INR users. The feature list shows 'CSV Export & Import', 'Advanced Analytics (Coming Soon)' and 'Cloud Backup & Sync'. CSV export, CSV import and ZIP backup are already free for everyone in DataManagementScreen (lines 59-120), and Google sign-in sync is …
- **Impact:** The paywall cannot be reached today (no references, see MON-01), so nothing is violating policy right now. But the obvious next step, wrapping a screen in PremiumGate, would ship a subscription price with no Play Billing transaction behind it (Play Payments policy). It would also sell already-free and not-yet-built features, which risks Play's Misleading Claims policy and the …
- **Fix:** Delete PaywallScreen, PremiumGate, PremiumService, premium_provider and the upgradeForPrice/welcomeToPremium strings now, rather than keeping them behind kDebugMode. Rebuild the paywall only together with real billing (MON-11), using store-localized prices, the required disclosures and Restore purchases.
- **Verifier:** The code matches the description. paywall_screen.dart:118-127 has '// Mock Purchase' followed by setPremium(true). app_en.arb:1835 is 'Upgrade for $4.99/mo', and it is the only arb file. The feature rows 'CSV Export & Import', 'Advanced Analytics (Coming Soon)' and 'Cloud Backup & Sync' are hard-coded English. CSV/ZIP …

### MON-03 · low · PremiumGate shows the real premium content at 30% opacity, so gated numbers leak and are still fully computed

- **Status:** Confirmed · effort S · action A57
- **Where:** `lib/features/premium/presentation/widgets/premium_gate.dart:28-60`
- **Evidence:** The locked state is `AbsorbPointer(child: lockedChild ?? Stack(children: [Opacity(opacity: 0.3, child: child), ... Icon(Icons.lock) ]))`. The real `child` is still built: its providers fire and its XIRR/FY computations run, and its values remain readable and screenshot-able at 30% opacity. Tapping the gate logs no analytics event. The paywall opens with Navigator.push(MaterialPageRoute) outside GoRouter, so no deep link can reach it.
- **Impact:** Once wired to something like the FY report, free users would still see the totals faintly, so the gate would be cosmetic, while the app still pays the CPU and Firestore cost. There would also be no way to tell which gate drives upgrades.
- **Fix:** Make `lockedChild` required and give it a static teaser: sample data, or a blurred image of placeholder numbers, never the user's real data. Log `paywall_viewed {source: <gate id>}` on tap. Route through GoRouter, e.g. '/premium?source=fy_report', so notifications and deep links can open the paywall.

### MON-05 · low · Ads are the wrong model for a private finance tracker: revenue is tiny, the trust cost is high, and they contradict the privacy policy

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A34
- **Where:** `lib/core/ads/ad_placement_strategy.dart:29-67`; `lib/core/ads/ad_placement_strategy.dart:122-129`; `docs/AD_INTEGRATION_SUMMARY.md:53-61`
- **Evidence:** The placement rules show a native ad only at list positions 10, 20 and so on, and only for users with at least 10 investments. Goals get an ad every 5th goal. The Portfolio Health ad sits on a screen that is behind a feature flag. The docs' own revenue target is '₹500+/month after 3 months' (AD_INTEGRATION_SUMMARY.md:128). Their design goals are 'Ads blend seamlessly' (line 55) and 'Ads should feel like premium content recommendations, not spam' (line 194). The in-app privacy policy says 'we do not sell your data, …
- **Impact:** Native ads mixed into a user's FD and P2P holdings would put loan, trading, crypto or P2P-platform promotions next to their portfolio, which reads as an endorsement. Ads designed to 'blend seamlessly' match the 'disguised advertisement' dark pattern in CCPA's 30-Nov-2023 guidelines. Reviewers of finance trackers punish ads. Ratings and word of mouth, the app's main acquisition …
- **Fix:** Record a 'no ads' decision and fold the execution into MON-04, which removes the SDK. Mark the ads docs as superseded. Run a 'No ads, no data selling' store-listing experiment as part of MON-16.
- **Verifier:** The cited facts hold:
- ad_placement_strategy.dart:29-66 places an ad every 10 investments and only when there are at least 10; goals get one every 5; shouldShowPortfolioHealthAd always returns true.
- AD_INTEGRATION_SUMMARY.md has 'Ads blend seamlessly' (around line 55), '₹500+/month after 3 months' (around line 127) …

### MON-06 · low · The app requests the Advertising ID, and Firebase Analytics collects it alongside financial amount buckets, even though there are no ads

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A34
- **Where:** `android/app/src/main/AndroidManifest.xml:4-5`; `lib/core/analytics/analytics_service.dart:482-489`; `.appforge/product.yaml:31-41`
- **Evidence:** The manifest has `<!-- AD_ID permission for Firebase Analytics --> <uses-permission android:name="com.google.android.gms.permission.AD_ID"/>`. Nothing under android/ sets google_analytics_adid_collection_enabled=false or google_analytics_default_allow_ad_personalization_signals=false. The logCashFlowAdded event sends `'amount_range': amountRange` (analytics_service.dart:488), and the user ID is set on the analytics instance. product.yaml lists 'advertising_id' as collected data. permissions.yaml justifies AD_ID …
- **Impact:** Users' investment-activity amount buckets can be linked to a resettable ad identifier inside Google. The Data Safety form must then declare 'Device or other IDs', which looks bad on a finance app's store page, undercuts the policy's 'not used for advertising' promise, and weakens a privacy-first pitch for Premium.
- **Fix:** Add `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>` and the two google_analytics_* meta-data flags set to false, and remove google_mobile_ads (MON-04). Then update the Play Console Advertising ID declaration to 'does not use', and update product.yaml and permissions.yaml. Data Safety will still list Device or other IDs because of the Firebase IDs.
- **Verifier:** Confirmed:
- AndroidManifest.xml:4-5 declares the AD_ID permission.
- No google_analytics_adid_collection_enabled or allow_ad_personalization_signals meta-data exists anywhere under android/.
- investment_notifier.dart:445-450 sends amount_range on every cash flow.
- sign_in_screen.dart:149 calls …

### MON-08 · low · The FY 'tax' report counts 10% of every RETURN cash flow as capital gain; this must be fixed before it can be sold

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A60
- **Where:** `lib/core/calculations/tax_and_basis_calculator.dart:78-103`; `lib/features/reports/data/services/fy_report_service.dart:224-235`
- **Evidence:** The calculator does `final gain = cf.amount * assumedGainPercentage;` with `double assumedGainPercentage = 0.10, // Default 10%`, and FYReportService explicitly passes `assumedGainPercentage: 0.10`. It then classifies every asset the same way, `if (holdingDays < 365) shortTermGains += gain; else longTermGains += gain;`, with holding days measured from the investment's start date.
- **Impact:** Users cannot see this today because the Reports flag is off, but it is the natural flagship of a paid tier. Example 1: a ₹1,00,000 FD from 1-Apr-2025 matures at ₹1,07,000 on 1-Apr-2026. The app shows an LTCG of ₹10,700. In reality there is ₹7,000 of interest, taxed at slab rate as 'Income from other sources', and no capital gain. Example 2: gold bought for ₹2,00,000 in …
- **Fix:** Remove the placeholder method now, or rename it with a clear 'estimate' marker, and update the test that locks it in, so it cannot leak into a future UI. When the Tax-Year report is actually built (MON-07), implement realized gain = proceeds − allocated basis per investment, route INCOME and interest to 'other sources', apply asset-type holding thresholds (12 months for listed equity, 24 months for others, slab rate for post-Apr-2023 debt MFs), label it 'Tax Year 2026-27', and add the two worked examples as golden tests.
- **Numeric check:** My python3 replica of the app logic:
- FD (₹1,00,000 on 2025-04-01, RETURN ₹1,07,000 on 2026-04-01): holding 365 days, so the app classes it LT with a gain of ₹10,700. Correct treatment: ₹7,000 interest under 'other sources' and ₹0 capital gain.
- Gold (₹2,00,000 in Jan-2024, sold for ₹2,60,000 in Mar-2026): holding …
- **Verifier:** The formula is wrong exactly as described. tax_and_basis_calculator.dart:81 defaults assumedGainPercentage to 0.10, line 92 computes gain = cf.amount × that percentage, lines 94-98 split at 365 days, and fy_report_service.dart:237 passes 0.10. test/core/calculations/tax_and_basis_calculator_test.dart:100-145 locks …

### MON-12 · low · Time the trial and paywall to India's tax calendar, with Play- and CCPA-compliant disclosures, and drop the dark-pattern tactics in the docs

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A39, A58
- **Where:** `docs/research/STRATEGIC_VISION_RETURNS_CALCULATOR.md:455-462`; `lib/features/settings/presentation/screens/legal_content.dart:37-56`; `lib/features/reports/data/services/action_required_service.dart:151-162`
- **Evidence:** The strategy doc proposes 'Anchoring | Show yearly price (₹7,999) before monthly (₹799)', 'Loss Framing | "You're losing ₹X insights without Pro"' and 'Social Proof | "10,000+ Pro users"', while there are zero paying users. The Terms of Service (legal_content.dart:37-56) have no subscription, auto-renewal, refund or cancellation clause. The app already knows the ITR deadline (`DateTime(currentFY + 1, 7, 31)` at action_required_service.dart:151). The paywall's existing 'Maybe Later' dismiss button is non-coercive …
- **Impact:** Fake social proof and loss-framing copy fall under the dark patterns listed in CCPA's Guidelines for Prevention and Regulation of Dark Patterns (30-Nov-2023), e.g. confirm-shaming and false urgency. Play's subscription policy requires clear disclosure of trial length, the price after the trial, when it converts and how to cancel …
- **Fix:** Remove the fake-social-proof, loss-framing and inflated-anchor ideas from the docs. Before launch, add ToS sections on auto-renewal, cancellation via Play, refunds and price changes, and use trial copy compliant with Play's subscription policy. Fix the ITR-deadline logic (MON-V01) before relying on it for any tax-season prompt. Show the paywall in context only.
- **Verifier:** The doc quotes exist: STRATEGIC_VISION_RETURNS_CALCULATOR.md:455-462 has 'Anchoring ₹7,999 before ₹799', 'Loss Framing' and 'Social Proof "10,000+ Pro users"'. The ToS (legal_content.dart:37-56) has no subscription, renewal or refund clauses. WebSearch confirms UPI Autopay for Play subscriptions (Google India blog, …

### MON-14 · low · Unit economics in the planning docs are mathematically wrong and overstate LTV:CAC by roughly 50–100x

- **Status:** Confirmed (reviewer said medium) · effort S · action A58
- **Where:** `docs/research/MBA_LEVEL_INNOVATION_ANALYSIS.md:679-693`; `docs/research/STRATEGIC_VISION_RETURNS_CALCULATOR.md:444-451`; `docs/PRODUCT_ROADMAP.md:563-593`
- **Evidence:** The MBA doc divides 'LTV: ₹9,000' (per paying user: ₹3,600/year × 2.5 years) by 'Blended CAC: ₹200/user' (per install) and reports 'LTV:CAC 45:1'. The strategy doc uses 'LTV ₹3,000 = ₹500 ARPU × 6 month average' and claims '30:1'. The roadmap's Q4-2026 MRR is '1.4M', but its own subscriber mix gives 1,200×799 + 225×1,499 + 75×3,999 = ₹15.96 lakh (computed in scratchpad MON/econ.py).
- **Impact:** These figures would mislead any decision on paid acquisition. At 3% conversion, the acquisition cost per paying user is ₹200 ÷ 0.03 ≈ ₹6,667. A realistic net LTV at ₹999/year is about ₹1,000: ₹999 nets ₹720 after GST and the 15% Play fee, and with ~27–28% of subscribers retained at 12 months (RevenueCat 2025), expected paid years ≈ 1 ÷ (1 − 0.28) ≈ 1.39. Buying installs at …
- **Fix:** Replace these with a bottom-up model. Net LTV = price ÷ 1.18 × 0.85 ÷ (1 − annual renewal rate). CAC per payer = CAC per install ÷ install-to-paid rate. Target LTV:CAC of at least 3. Until conversion and renewal are measured, growth has to be organic: ASO, the 'No ads' trust message, content on XIRR and FD tax, and a 'give a month, get a month' referral. Cap paid cost-per-install at LTV × conversion ÷ 3, which is about ₹10 at 3% conversion.
- **Numeric check:** My figures:
- Roadmap mix: 1,200 × 799 + 225 × 1,499 + 75 × 3,999 = ₹15,96,000 against the doc's 1.4M.
- CAC per payer at 3% conversion: ₹200 ÷ 0.03 = ₹6,667.
- Net LTV: ₹999 ÷ 1.18 × 0.85 = ₹719.6; ÷ (1 − 0.28) = ₹1,000.
- Loss per payer at ₹200 CPI: about ₹5,667.
- CPI cap at LTV:CAC = 3: 1,000 × 0.03 ÷ 3 = ₹10.
- …

### MON-15 · low · Planned lead-generation, data-insights and P2P-referral revenue conflicts with the privacy policy and Indian regulation

- **Status:** Confirmed (reviewer said medium) · effort S · action A58
- **Where:** `docs/PRODUCT_ROADMAP.md:468-486`; `docs/PRODUCT_ROADMAP.md:595-602`; `docs/research/STRATEGIC_VISION_RETURNS_CALCULATOR.md:463-468`
- **Evidence:** The plans include:
- Roadmap: 'Referral Commission | P2P platforms, FD providers | ₹500-2000 per lead', 'Data Insights | Anonymized market research | Enterprise contracts', and an Investment Marketplace with 'Referral commission / Lead generation'.
- Strategy doc: 'Lead Generation | Anonymized leads to investment platforms'.
- MBA doc: 'Move ₹1L from low-performing Gold to P2P (18% vs 2%)', paired with referral commissions.

The privacy policy promises 'we do not sell your data, and we do not use it for …
- **Impact:** Selling leads or insights derived from users' private holdings would break the published policy and the DPDP Act's purpose limitation (DPDP Rules notified 14-Nov-2025; most obligations apply from 13-May-2027). Recommending specific P2P or bond platforms with return claims, for a commission, looks like unregistered advice. Since 29-Aug-2024, SEBI-regulated entities may not …
- **Fix:** Remove 'data insights' and 'lead generation' from the plans. If affiliate revenue is ever added, restrict it to links clearly labelled 'Sponsored' pointing to RBI- or SEBI-regulated FD and bond platforms. Never personalise them from user holdings or XIRR rankings, make no return claims, and add them only after legal review. Keep subscriptions as the only model.

### MON-V01 · low · The ITR-deadline 'Action Required' reminder can never fire, and would name the wrong FY if it did

- **Status:** Added by verifier · effort S · action A60
- **Where:** `lib/features/reports/data/services/action_required_service.dart:149-163`
- **Evidence:** `final currentFY = now.month >= 4 ? now.year : now.year - 1; final taxDeadline = DateTime(currentFY + 1, 7, 31); ... if (daysUntilTax > 0 && daysUntilTax <= 90)`. From April to December the deadline is July 31 of the next year (more than 200 days away). From January to March it is July 31 of the current year, which is at least 122 days away. A python3 simulation over every day from 2026-01-01 to 2028-12-31 found 0 days on which the item is produced. The title 'ITR Filing Deadline - FY $currentFY-${currentFY+1}' …
- **Impact:** The one tax-calendar hook in the app is silently dead. Reports is flag-gated, so few users are affected today. But MON-12 cites this code as an existing asset for tax-season paywall timing, and any ITR-season engagement or upsell built on it would never fire.
- **Fix:** Compute the next due date as July 31 of now.year if now is on or before July 31, otherwise July 31 of now.year + 1. Set the FY label to (dueYear − 1)-(dueYear). Under the Income-tax Act 2025, label it 'Tax Year'. Make the due date configurable via Remote Config, since CBDT often extends it. Add unit tests for 15-May, 25-Jul, 1-Aug and 15-Mar.

## MKT · Marketing, positioning & ASO

### MKT-01 · critical · Live Play listing falsely says financial data is not stored on servers, contradicting the app's own privacy policy

- **Status:** Confirmed · effort S · action A01
- **Where:** `android/fastlane/metadata/android/en-US/full_description.txt:59-63`; `lib/features/settings/presentation/screens/legal_content.dart:20-23`; `README.md:59,67`
- **Evidence:** full_description.txt:62-63 says "🔒 Your Data, Your Control / We don't store your financial data on our servers. It stays with you." Lines 59-60 of the same listing say "Sign in with Google to backup your data". The in-app policy (legal_content.dart:21) says "Your data is securely stored in your private cloud account (Google Firebase)", and line 23 says analytics are "associated with your user ID and device identifiers... always on". Commits #710 and #719 (Sept 28-30, 2026) fixed this wording inside the app but did …
- **Impact:** Every listing visitor reads a false data-handling claim for a finance app. It contradicts the Data safety form, which must disclose collection of user-entered financial info, email, user ID and device IDs. This is exactly what Play's User Data / Deceptive Behavior enforcement and Data safety consistency checks target, and it risks a rejected update or removal. It also exposes …
- **Fix:** As the reviewer says: replace full_description.txt:59-63 in a PR, then run Actions → listing (dry_run=true, then live). Two adjustments. (1) Avoid absolute 'never used for ads / no ads' wording while google_mobile_ads (pubspec.yaml:83), the AdMob APPLICATION_ID (AndroidManifest.xml:61) and AD_ID stay in the build. Either remove them or say 'no ads are shown', matching product.yaml:75-77. (2) In the same pass, publish the corrected hosted privacy policy and make sure the Play Console privacy URL points to that one page.
- **Numeric check:** n/a (claims check): listing line 63 vs legal_content.dart:21,23 vs product.yaml remote storage list, a direct contradiction.

### MKT-03 · high · No working ratings or review engine: the review prompt is off for everyone, the trigger is too narrow, and there is no Rate/Share entry

- **Status:** Confirmed · effort S · action A42
- **Where:** `lib/core/providers/feature_flags_provider.dart:43-46,66-67`; `lib/features/investment/presentation/screens/add_transaction_screen.dart:33-36,173-186`; `lib/core/review/review_prompt_service.dart:68-98`
- **Evidence:** The comment on reviewPrompt reads "Disabled by default, enable via Debug Settings (POR-91/POR-99)", so no production user is ever prompted. Even when enabled, the success moment is `!isEditing && type == CashFlowType.returnFlow` only. INCOME (monthly interest payouts, the most common positive event for P2P and bond users) never triggers it, and an FD user may wait months for a RETURN. The About screen Support section has only Help, Contact and Check-for-updates, with no 'Rate InvTrack' or 'Share InvTrack'. The …
- **Impact:** Rating count and recency are core Play ranking and conversion signals. With no prompt, reviews come mostly from unhappy users who go looking for the store. Word of mouth, the cheapest channel for a solo founder, has no link to click.
- **Fix:** Flip the reviewPrompt default to true in code. ADR 0001 (commit 869baa9) explicitly rejected remote-config gating, and the app has no Remote Config dependency, so use the RELEASE_HOLD/rollout_fraction controls as the kill switch. Widen isReviewPromptSuccessMoment to INCOME as well as RETURN, keeping the one-shot gate. Add passive 'Rate InvTrack' (market:// with https fallback) and 'Share InvTrack' (UTM-tagged Play link) tiles to about_screen.dart Support. Reply to reviews.
- **Numeric check:** n/a

### MKT-V-03 · high · FIRE progress shows cumulative money ever invested as the current corpus, and the store screenshots display it

- **Status:** Added by verifier · effort M · action A11
- **Where:** `lib/features/fire_number/presentation/providers/fire_providers.dart:89-95,166`; `android/fastlane/metadata/android/en-US/images/phoneScreenshots/play_04_overview.png`
- **Evidence:** fire_providers.dart:92 sets `currentPortfolioValue = stats.totalInvested` from multiCurrencyGlobalStatsProvider, which covers all investments, including closed ones and money already returned. FIRE settings have no corpus-override field. Screenshot #4 shows a fully closed portfolio ('Closed 6', ₹27.2L out, ₹36.3L in) with a FIRE corpus of ₹27.2L (15.6% of ₹1.75Cr). That is the sum of all outflows, though none of that capital is still invested.
- **Impact:** Every user who has set up FIRE and rolls over FDs or P2P, or has closed positions, sees an inflated FIRE progress figure and an optimistic retirement date. The promotional screenshot advertises that number. The calculation dimension should own the fix; it is listed here because it appears in the store listing.
- **Fix:** Use capital still deployed (net invested in open positions, or a current-value field once one exists) plus an optional user-entered 'other savings' corpus. Add a unit test for an FD rollover. Regenerate screenshot #4 after the fix.

### MKT-02 · medium · The most marketable features (FY reports, Health Score, Income calendar, review prompt) are hidden behind a secret debug menu

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A42
- **Where:** `lib/core/providers/feature_flags_provider.dart:24,41,46,66-69`; `lib/features/home/presentation/screens/home_shell_screen.dart:33,52-57`; `lib/core/router/app_router.dart:83-86`
- **Evidence:** All flags default to false: `final defaultValue = flag == FeatureFlag.portfolioHealthScore ? false : false;` (feature_flags_provider.dart:66-67). The Reports tab, with FY report, PDF and CSV export, renders only `if (isReportsEnabled)` (home_shell_screen.dart:52), and the router redirects /reports to '/' when the flag is off (app_router.dart:83-86). The Health card returns `SizedBox.shrink()` when disabled. The Income calendar is reachable only through IncomeGuardianDashboardCard (overview_screen.dart:179), which …
- **Impact:** For India the strongest hooks are an FY (Apr-Mar) gains/income report for ITR filing and a monthly payout calendar for P2P and bond investors. Neither can appear in screenshots, the listing or tax-season content, because production users cannot see them. Users who read the FAQ hunt for a menu that doesn't exist, and the Health Score share loop is dead.
- **Fix:** Now: remove the Debug Settings and 'AI-powered' FAQ entries (help_faq_screen.dart:116-139; arb:682,3062) and hide the orphan Income Guardian settings tile. Next sprint, ship Reports/FY: fix the hard-coded FY label, wire onCalendarTap to '/income-calendar', flip the code default for reportsTab, and use release-platform's existing rollout_fraction (auto-release.yml) for a staged rollout instead of adding Remote Config. Do this before Apr 2027 and leave Health Score for later. Add features to the listing only once they are on by default.
- **Numeric check:** n/a
- **Verifier:** Core claim holds. Every flag defaults to false (feature_flags_provider.dart:72, not 66-67). The Reports tab appears only when the flag is on (home_shell_screen.dart:52-57), and /reports redirects to '/' (app_router.dart:83-86). The health card is flag-gated (portfolio_health_dashboard_card.dart:29). Debug mode is …

### MKT-04 · medium · Title and short description waste keyword space on generic or jargon terms and miss Indian search intent

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A51
- **Where:** `android/fastlane/metadata/android/en-US/title.txt:1`; `android/fastlane/metadata/android/en-US/short_description.txt:1`; `app-metadata.json:16-20`
- **Evidence:** Title: "InvTrack - Investment Tracker" (29/30 chars). The head term 'investment tracker' is dominated by INDmoney, broker apps and dozens of similarly named apps (InvestTrack, InvesTrackr). Short description: "Track investments with XIRR & MOIC. Goals, privacy mode & cloud sync." (69/80 chars, 11 unused). It never says FD, fixed deposit, P2P, bond, chit fund, gold or SGB, which are the long-tail intents this niche app can actually win, and it spends words on 'MOIC' (unfamiliar to Indian retail) and 'cloud sync'. …
- **Impact:** Low organic visibility for high-intent searches like 'fd tracker', 'p2p lending tracker', 'xirr calculator', 'chit fund app' and 'bond tracker'. If the live category really is Tools/Utilities, the app is also absent from Finance browse and charts, where tracker shoppers look.
- **Fix:** Check the live category in Play Console first and move to Finance only if it is not already there. Then test the title and short description through a Store Listing Experiment, using the reviewer's variants (lengths verified). Delete app-metadata.json or mark it as non-authoritative. The Financial features declaration is mandatory for all apps, so confirm it is filed as 'no financial features'.
- **Numeric check:** Lengths (python): live title 29, live short 69; proposed 'InvTrack: FD & P2P Tracker' 26, 'InvTrack: FD & P2P XIRR App' 27, 'InvTrack: Private Deal Tracker' 30; short A 79, B 79, global 80, all within the 30/80 limits.
- **Verifier:** Factual parts verified. title.txt is 'InvTrack - Investment Tracker' (29 chars). short_description.txt is 69 chars, with no FD, P2P, bond or chit-fund keywords, and uses MOIC. app-metadata.json:18-21 has title 'inv_tracker', a short description truncated mid-word ('calculatio') and category 'utilities'. However, …

### MKT-05 · medium · Full description is stale ('NEW IN VERSION 3.6.0'), self-contradictory and leaves out the strongest differentiators

- **Status:** Confirmed with corrections · effort S · action A51
- **Where:** `android/fastlane/metadata/android/en-US/full_description.txt:1,5,7,22-40,30-31,82-93`; `lib/features/investment/domain/entities/investment_entity.dart:203-217`
- **Evidence:** Line 22 says "🆕 NEW IN VERSION 3.6.0" while pubspec is 3.70.18+274. Line 5 says "No complicated charts. No stock tickers.", but the listing's first screenshot leads with "UTI Nifty 50 Index / Mutual Funds". Line 30-31 is a vague "Enhanced Analytics: Comprehensive tracking for your investment lifecycle". 8 divider lines of '━' spend 240 characters (about 7% of the 3,545-char text). Features that exist but are never mentioned: FIRE number calculator, lakh/crore formatting and Indian FY, 40+ currencies, CSV bulk …
- **Impact:** A visitor who expands the description sees an app that looks abandoned (version 3.6 vs 3.70) and is unsure whether stocks are in scope. Google indexes the full description for search, so missing terms (chit fund XIRR, invoice discounting, SGB, FIRE calculator, ITR) cost rankings.
- **Fix:** Rewrite as proposed, in the same PR as the MKT-01 fix. Drop the version section, restore FIRE, add CSV import, app lock, guest mode and multi-currency, and use CAPS headings instead of '━' dividers. Do not describe reminders as covering 'maturity and income' payouts in a way that implies the Income calendar, which is currently unreachable (see MKT-02).
- **Numeric check:** Example ₹1,00,000 on 2025-04-01 → ₹1,07,100 on 2026-04-01: 365 days, XIRR = 7.100% (own python bisection). Divider share: 240/3545 = 6.77%.
- **Verifier:** Verified: line 22 reads '🆕 NEW IN VERSION 3.6.0' while pubspec.yaml:21 is 3.70.18+274. Lines 30-31 are vague. There are 240 '━' characters in a 3,545-character text (6.8%). Not mentioned anywhere: FIRE (the reseed in 2f6509d actually removed the FIRE section), 40+ currencies (LocaleDetectionService feeds …

### MKT-06 · medium · Screenshots are uncaptioned raw UI, show an all-closed portfolio and a mutual fund hero, with overlapping FABs; only 5 of 8 slots are used

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A52
- **Where:** `android/fastlane/metadata/android/en-US/images/phoneScreenshots/play_01_investments_list.png`; `android/fastlane/metadata/android/en-US/images/phoneScreenshots/play_02_investment_detail.png`; `android/fastlane/metadata/android/en-US/images/phoneScreenshots/play_03_goals.png`
- **Evidence:** I viewed all 5 PNGs (1080x1920). None has a caption or headline. The app UI is only about 864px wide, padded with navy bars, so it shows at roughly 80% size. #1 (hero) is the Investments list where the chips read "All 6 / Open / Closed 6": every card says CLOSED, the Open tab is empty, the first card is "UTI Nifty 50 Index – Mutual Funds", and the 'Add Investment' FAB covers the LenDenClub card. #2's header renders in a flat grey that looks disabled. #4 and #5 are the same Overview screen (privacy off/on), and in …
- **Impact:** Screenshots drive most of the install decision, and most visitors never expand the text. The current set doesn't say what the app is for in the first 2 frames, shows the wrong asset class first, and implies users only track finished investments. In reality FD, bond and P2P users mostly hold OPEN positions, which today display as negative (a product issue for the calculation …
- **Fix:** Add captions to the existing generator output with a simple framing script, swap the hero to the Overview or an FD/P2P card, hide the FAB (scroll or a test flag), and add the already-captured FIRE dashboard shot. Use 6-8 frames. Add a feature graphic to images/. Leave the FY-report and Upcoming shots until those features are actually visible (MKT-02).
- **Numeric check:** Screenshot #4 arithmetic checked: 36.3L in − 27.2L out = 9.1L net; 9.1/27.2 = 33.5%; MOIC 36.3/27.2 = 1.33x, which matches the display. Note: the FIRE card shows ₹27.2L = total outflows of a fully closed portfolio (see MKT-V-03).
- **Verifier:** I viewed all five PNGs (each 1080x1920, with UI about 864 px wide and 108 px navy bars on each side). None has a caption. #1 shows 'Closed 6' with an empty Open tab, leads with 'UTI Nifty 50 Index / Mutual Funds', and the FAB covers the LenDenClub card. #2 has a grey 'closed' header. #4 and #5 are the same Overview …

### MKT-10 · medium · No web presence or SEO funnel: no landing page, no free calculators, mismatched privacy URLs, README without store link

- **Status:** Confirmed · effort M · action A55
- **Where:** `web/index.html:21,36,40-49`; `web/manifest.json:2-8`; `firebase.json:1-5`
- **Evidence:** web/ is the default Flutter web shell (title "InvTracker") still loading sql.js "for Drift web database support" (index.html:40-49), although drift is no longer in pubspec. It is not a marketing site. firebase.json configures no Hosting. README.md:135 says "Coming soon! Screenshots will be added after App Store submission.", has no Play badge or link, and points to a LICENSE file (line 259) that doesn't exist. Two different privacy-policy URLs exist: app-metadata.json:20 has …github.io/InvTrack/privacy.html, while …
- **Impact:** Searches like 'xirr calculator', 'fd maturity calculator', 'chit fund returns calculator' and 'p2p real return' are high-volume and dominated by content sites (e.g. freefincal's XIRR and chit fund calculators: https://freefincal.com/investment-calculators/xirr-returns-calculator/, https://freefincal.com/dealing-with-complex-cash-flows-i-chit-fund-returns-calculator/). InvTrack …
- **Fix:** Phase 1 (S): a single static landing page on GitHub Pages (already used for the privacy page) with a Play badge (utm_source=web), honest privacy copy, and one canonical privacy URL that Play, the app and the README all use. Also fix the README's screenshots, Play link and LICENSE. Phase 2 (M): one XIRR calculator page (dates + amounts) that ends with a CTA to the app. Add the FD, chit and P2P calculators only if the first one pulls traffic. Scale the success metric down (e.g. ≥500 organic sessions/month at 6 months).
- **Numeric check:** n/a

### MKT-13 · medium · No growth loops or partner hooks: no platform statement importers, referral link or install attribution

- **Status:** Confirmed with corrections · effort L · action A46
- **Where:** `lib/features/bulk_import/data/services/csv_template_service.dart:58-78`; `lib/features/settings/presentation/screens/about_screen.dart:377-402`; `lib/l10n/app_en.arb:3009`
- **Evidence:** Bulk import is a single generic CSV template whose example rows say 'P2P Lending - LenDenClub' (csv_template_service.dart:58-78). There is no parser for any platform's statement export. A grep for install_referrer, utm_, invite and referral in lib/ finds nothing. The only share text has no link (arb:3009). P2P Dash built its business on importing exports from 78 platforms (https://p2pdash.com/).
- **Impact:** Data entry is the main activation barrier for a manual ledger. Without importers, users with 50-500 P2P loans or a dozen bonds give up, and InvTrack has nothing concrete to offer platforms or creators ('import your X statement in one tap'). Channel ROI can't be measured.
- **Fix:** (1) Tag every outbound link with Play referrer UTMs now (zero code). (2) Add the share-app link (MKT-03). (3) Validate importer demand cheaply: log which investment types users create and ask in-app or on Reddit. Then build one importer for the most-used platform (likely LenDenClub) and expand only if adoption is proven.
- **Numeric check:** n/a
- **Verifier:** Verified: bulk import is a single generic template (csv_template_service.dart:55-80, with 'P2P Lending - LenDenClub' example rows) plus simple_csv_parser.dart. There are no platform-specific parsers. A grep of lib/ for install_referrer, utm_, invite, referral and referrer finds nothing. shareScoreText has no link. …

### MKT-16 · medium · ₹0-budget channel plan: communities, creators, platform partnerships and launch sites with compliance guardrails

- **Status:** Confirmed with corrections · effort M · action A56
- **Where:** `docs/PRODUCT_ROADMAP.md:711-770,1210-1250`
- **Evidence:** The current §8 plan relies on paid influencers (₹1L), ₹50K/month on X and a mega-creator list, and none of the GTM checkboxes (1212-1250) are ticked. Community facts: r/IndiaInvestments has about 913k members (https://gummysearch.com/r/IndiaInvestments). India's active FIRE sub is r/FIRE_Ind with about 55k members and self-promotion only in a designated thread; r/FIREIndia is inactive (https://gummysearch.com/r/FIRE_Ind). TradingQnA hosts indie tool launches such as WatchMyFolio and xirrledger …
- **Impact:** Without a realistic, measurable channel plan, ASO fixes alone will plateau. A careless creator or platform tie-up could also create regulatory or reputational trouble.
- **Fix:** Sequence it. Weeks 0-2: fix the listing truth, ratings and screenshots (MKT-01/03/06). Weeks 2-12: post data-led content fortnightly on r/IndiaInvestments and TradingQnA, linking a free calculator or post rather than the app; one weekly X thread; pitch 1-2 niche creators with #ad and no return claims. Keep platform partnerships neutral (no commissions). Postpone Product Hunt and HN until the en-US listing and landing page exist. Realistic targets: ≥300 attributable installs and ≥30 ratings in 90 days.
- **Numeric check:** n/a
- **Verifier:** Verified: roadmap §8 (PRODUCT_ROADMAP.md:711-770) relies on ₹50K/month on X, ₹1L for YouTube and mega-influencers. All 33 GTM checkboxes at 1205-1255 are unchecked and none are ticked. SEBI's 26 Aug 2024 rules on regulated entities associating with unregistered or return-claiming finfluencers, and the SEBI–Google …

### MKT-V-01 · medium · Default-on weekly, monthly and FY summary push notifications lead to the hidden Reports route and bounce to Overview

- **Status:** Added by verifier · effort S · action A29
- **Where:** `lib/core/notifications/notification_preferences.dart:20,44,105`; `lib/core/notifications/handlers/scheduled_notification_handler.dart:41,76-84`; `lib/core/notifications/handlers/investment_notification_handler.dart:319-320`
- **Evidence:** weeklySummaryEnabled, monthlySummaryEnabled and fySummaryEnabled all default to true (notification_preferences.dart:20,44,105). rescheduleAllNotifications re-schedules the weekly and monthly summaries on every launch (investment_notification_handler.dart:319-320), and main.dart:141 schedules the FY summary. The weekly one fires every Sunday at 10:00 with Importance.max, titled '📊 Weekly Investment Summary' (scheduled_notification_handler.dart:44-84). Its payload is NotificationPayloadType.dynamicReport …
- **Impact:** Every user with notifications on gets a max-priority weekly push promising a summary. Tapping it opens the Overview, not a report. That trains users to ignore or disable notifications and wastes the app's main re-engagement channel, including maturity and income reminders on the same permission.
- **Fix:** Until Reports ships, either skip scheduling the weekly, monthly and FY summaries when reportsTab is off, or route them to an Overview state that actually shows the week's activity. Lower the summary channel from Importance.max to default. When Reports ships (MKT-02), this becomes a real weekly retention loop. Add a test that every notification payload's target route is reachable with default flags.

### MKT-07 · low · Brand name is inconsistent across store, launcher, in-app, legal and web: InvTrack / InvTracker / 'Investment Tracker' / inv_tracker

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A53
- **Where:** `android/fastlane/metadata/android/en-US/title.txt:1`; `android/app/src/main/AndroidManifest.xml:23`; `lib/features/auth/presentation/screens/sign_in_screen.dart:353`
- **Evidence:** The Play title is "InvTrack - Investment Tracker", but the home-screen launcher label is `android:label="InvTracker"`. The sign-in hero shows 'InvTracker', the biometric prompt says 'Authenticate to unlock InvTracker', the legal text says 'InvTracker ("we")', the premium screen says "InvTracker Premium", the support email is support@invtracker.app, and web/manifest name is "InvTracker". The overview app bar is a hard-coded 'Investment Tracker' (visible in screenshots 4-5). appTitle and About use "InvTrack". …
- **Impact:** Users who search for the name they saw under the icon ('InvTracker') or heard about may not find the 'InvTrack' listing. Brand recall and word of mouth are diluted, and the app reads as less professional. Similarly named apps (InvestTrack, InvesTrackr) make confusion more likely.
- **Fix:** Standardise on 'InvTrack' in user-facing strings: the launcher label, sign-in hero (l10n.appTitle), biometric reason, legal text and the overview app bar. The Play listing may keep 'InvTracker' once in the description as an alias. Settle the domain and mailbox decision separately (DNS could not be verified from this sandbox).
- **Numeric check:** n/a
- **Verifier:** All quoted strings exist. AndroidManifest.xml:23 has label 'InvTracker'. sign_in_screen.dart:353 shows 'InvTracker'. overview_screen.dart:94 hard-codes 'Investment Tracker' (visible in screenshots #4 and #5). security_service.dart:352 says 'unlock InvTracker'. legal_content.dart uses 'InvTracker'. arb:3 and arb:1116 …

### MKT-08 · low · App icon carries a Gemini AI watermark and its glyph reads as the ♂ (male) symbol

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A53
- **Where:** `assets/icons/app_icon.png`; `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`; `android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png`
- **Evidence:** Viewing the files shows a 4-point sparkle (the Gemini image-generation watermark) in the bottom-right corner of the 1024px source and of every generated icon: the legacy 192px launcher icon, the adaptive foreground and the 512px web icon. pubspec.yaml:160-166 generates all launcher and web icons from this PNG. The mark is a ring with a diagonal arrow out of its upper right, which is visually the Mars/male gender symbol. A different, unused vector design (gradient square with a chart) sits in …
- **Impact:** The watermark shows on legacy-launcher devices, in the PWA/web icon and on any marketing asset or Play hi-res icon made from the same file (the Play icon is not in the repo and could not be checked). A gendered-looking icon is a poor fit for an app that also targets couples and families. The icon is the first thing every search impression sees, so it directly affects …
- **Fix:** Check the Play Console hi-res icon first; if the watermark is present there, re-upload a clean one immediately, which raises this to medium. Then commission a clean icon, regenerate it, commit the 512 px Play icon, and A/B test it via a store listing experiment when convenient.
- **Numeric check:** Adaptive geometry: sparkle at 0.94 of the foreground → 16% + 0.94×68% = 79.9% of the 108 dp canvas = 86.3 dp; offset from centre (54,54) = (32.3,32.3) dp → radial 45.7 dp > 36 dp mask radius (clipped on circle masks); squircle n=4 test 2×(32.3/36)^4 = 1.30 > 1 (clipped).
- **Verifier:** Viewed. The 1024 px source assets/icons/app_icon.png has a 4-point sparkle in the bottom-right corner (about 94% across and down) and a ring-with-arrow glyph that reads as ♂. The same mark is in mipmap-xxxhdpi/ic_launcher.png, drawable-xxxhdpi/ic_launcher_foreground.png and web/icons/Icon-512.png, all generated from …

### MKT-09 · low · Play 'What's new' notes are empty or commit-speak; the changelog tooling leaks CI/CD and refactor messages

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A54
- **Where:** `android/fastlane/metadata/android/en-US/changelogs/274.txt`; `android/fastlane/metadata/android/en-US/changelogs/249.txt`; `android/fastlane/metadata/android/en-US/changelogs/247.txt`
- **Evidence:** 58 of 233 files in changelogs/ are empty (e.g. 246.txt, and 90, 93, 95-98...). About 58 contain developer jargon. 274.txt: "Replace O(N log N) declining investments sorting with O(N) bounded insertion (#559)… Fix infinite loop - correct skip logic and enable cancel-in-progress". 249.txt: "Guard head_commit message retrieval in cd.yml check_skip step". 247.txt: "Pass and prioritize FIREBASE_TOKEN to resolve service account 404 bug". cliff-playstore.toml:56-58 routes every `^fix`/`^perf` commit, including fix(cd) …
- **Impact:** The 'What's new' text is one of the few listing elements that updates often. Engineering noise tells visitors and existing users nothing, weakens update adoption, and makes a finance app look careless. Very frequent tiny releases add update fatigue.
- **Fix:** Keep a short, hand-written user-facing notes file that release-platform reads (or a curated top section of CHANGELOG.md), and add skips for fix(ci|cd|deps|build) in the cliff config. Delete the orphaned root fastlane/ tree and fix PLAYSTORE_CHANGELOG_GUIDE.md. Consider raising min_interval_hours or batching promotions weekly. That is mainly a stability choice, not a marketing one.
- **Numeric check:** Counted with python: 233 files, 58 blank, 34 containing CI/workflow/O(N)/FIREBASE-type jargon; root tree 13/13 blank.
- **Verifier:** Verified: 233 files in changelogs/, 58 of them blank (whitespace only; e.g. 90, 93, 95-98, 246). 274.txt, 249.txt and 247.txt contain CI/CD and big-O jargon. cliff-playstore.toml:55-66 routes all ^fix and ^perf commits with no scope filter. release.yaml:23 sets release_notes: CHANGELOG.md, and CHANGELOG.md has …

### MKT-11 · low · Positioning rests on a false 'only app / no competitor' premise; the GTM plan is stale and contains errors

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A51
- **Where:** `docs/PRODUCT_ROADMAP.md:142,719,730,1256,1299,1303,1343`; `docs/research/MBA_LEVEL_INNOVATION_ANALYSIS.md:16,107`
- **Evidence:** The roadmap's competitor table ends with "| **Nothing** | For alternatives | — | The gap we fill |" (1299) and claims "Only app focused on alternative investments" (142, 1303). The MBA doc says "No direct competitor for alternative investment XIRR tracking" (107). The GTM plan budgets "₹50K/month" for X (719), lists a non-existent handle "@1financebyzerodha" (730), has a Q1 2026 'Production Launch: 5,000 users' milestone with no status (1256), and says 'Next Review Date: January 15, 2026' (1343). As of 2026 the …
- **Impact:** Messaging that says 'nothing else does this' won't hold up with r/IndiaInvestments readers, who know these tools. The plan's budgets and influencer targets don't fit a solo founder, so real GTM work never starts (every GTM checkbox at 1210-1250 is unchecked).
- **Fix:** Write a one-paragraph positioning statement ('cash-flow ledger for investments your broker app can't see') and a short competitor table (MProfit, INDmoney, spreadsheets) to guide listing copy. Archive or mark §8 of the roadmap as stale. No urgency beyond feeding MKT-04 and MKT-05.
- **Numeric check:** n/a
- **Verifier:** The quotes exist: PRODUCT_ROADMAP.md:142 ('Only app focused on alternative investments'), :719 ('₹50K/month'), :730 ('@1financebyzerodha'; a web search finds only Zerodha's 'Zero1' brand, so the handle looks wrong), :1256 (Q1 2026 launch milestone), :1299 ('Nothing … The gap we fill'), :1303, and :1343 ('Next Review …

### MKT-12 · low · No localized, India-specific or global listings; English-only app and listing despite an India-first, multi-currency product

- **Status:** Confirmed with corrections (reviewer said medium) · effort M · action A56
- **Where:** `android/fastlane/metadata/android/en-US/`; `lib/l10n/app_en.arb`; `l10n.yaml`
- **Evidence:** The only listing locale is en-US (android/fastlane/metadata/android/en-US), and the only ARB is app_en.arb. The single listing mixes India-only examples ("Invested ₹1 lakh…", line 50) with global claims, so the same text serves Indian and NRI/US/UK visitors.
- **Impact:** Indian users with Hindi or regional-language devices see English text with no local keywords. Global users (the roadmap targets UAE and Singapore NRIs) see ₹-centric copy. Chit funds are concentrated in Tamil Nadu, Andhra Pradesh, Telangana, Kerala and Karnataka, and those users search in regional languages.
- **Fix:** Defer. After MKT-01/04/05/06 land, optionally add an en-IN listing or an India custom store listing with ₹/FD/ITR keywords, and leave the default listing currency-neutral. Do not add regional-language listings until the UI is localized.
- **Numeric check:** n/a
- **Verifier:** Verified: android/fastlane/metadata/android contains only en-US, and lib/l10n contains only app_en.arb (l10n.yaml preferred-supported-locales: en). The listing mixes ₹ examples (line 50) with general copy. But Play shows the default en-US listing to Indian English users anyway. Translating the listing into hi, ta or …

### MKT-14 · low · README and FAQ overclaim (AI-powered, OWASP compliant, MIT licence with no LICENSE) and contradict the niche

- **Status:** Confirmed · effort S · action A01, A68
- **Where:** `README.md:38,62,217,244,259,282-301`; `lib/l10n/app_en.arb:537,602,682`; `lib/features/income_projection/data/services/smart_amount_predictor.dart:3`
- **Evidence:** README:38 "Smart Projections - AI-powered goal completion predictions". FAQ arb:682 calls Income Guardian "an AI-powered income monitoring system", but the predictor is a "Weighted Moving Average" (smart_amount_predictor.dart:3). README:62 says "OWASP MASVS Compliant" with no audit cited. README:259 cites an MIT LICENSE file that doesn't exist, and links TODO.md (217) and docs/CODERABBIT_FEATURES.md (244), which are missing. The roadmap section still lists 'Recurring income projections' as unchecked Q1 2026 work. …
- **Impact:** Overclaims ('AI', compliance badges) invite scrutiny under India's ASCI misleading-ads code and erode credibility with technical early adopters on GitHub, IndieHackers and HN. The FAQ undercuts the alternative-investment positioning.
- **Fix:** As proposed: reword the 'AI' claims, drop or substantiate the MASVS claim, add a LICENSE or remove the claim, fix the dead links, and rewrite arb:537 to lead with FDs, P2P, bonds and chit funds.
- **Numeric check:** n/a

### MKT-15 · low · Dormant paywall copy would mislead Indian users ($4.99, premium 'Cloud Backup' that is already free, mock purchase)

- **Status:** Confirmed with corrections · effort S · action A57
- **Where:** `lib/features/premium/presentation/screens/paywall_screen.dart:38-45,56-58`; `lib/l10n/app_en.arb:1835`; `docs/PRODUCT_ROADMAP.md:520`
- **Evidence:** The button reads "Upgrade for $4.99/mo" (arb:1835), a USD price in an INR-first app. The feature list sells "Cloud Backup & Sync" and "CSV Export & Import" as premium, though both are free today. onPressed calls `// Mock Purchase` → setPremium(true). The screen is not referenced anywhere outside lib/features/premium. The roadmap prices Pro at "₹799/month or ₹5,999/year" (520), well above the Kubera-like global anchor for an Indian retail tracker.
- **Impact:** There is no user impact today because the screen is unreachable. If it gets wired up by mistake, users would see a price in the wrong currency and be sold features they already have, which is a refund and review risk. 'Free' is currently a marketing asset the listing doesn't use.
- **Fix:** Delete the mock paywall or keep it hidden behind a debug flag. Use 'free' in listing copy, and say 'no ads' only after removing google_mobile_ads and AD_ID, or say 'no ads shown'. Before monetizing, use localized Play Billing prices and keep sync and basic import/export free.
- **Numeric check:** Kubera anchor ≈ $249 × ~₹88 = ~₹21,900/yr vs roadmap Pro ₹5,999/yr (0.27x) or ₹799×12 = ₹9,588/yr monthly-billed.
- **Verifier:** Verified: arb:1835 'Upgrade for $4.99/mo'. paywall_screen.dart:38-45 lists CSV Export & Import and Cloud Backup & Sync, both already free. :56-58 is a mock purchase that calls setPremium(true). PaywallScreen is not referenced outside lib/features/premium, so the screen is unreachable today. The reviewer correctly says …

### MKT-V-02 · low · FY report quick card is hard-coded to 'FY 2023-24' and opens the in-progress FY during ITR season

- **Status:** Added by verifier · effort S · action A44
- **Where:** `lib/features/reports/presentation/screens/reports_home_screen.dart:234-239`; `lib/features/reports/domain/entities/report_configuration.dart:89-101`; `lib/features/reports/presentation/providers/fy_report_provider.dart:18`
- **Evidence:** The card subtitle is `l10n.currentFY('2023', '24')`, a literal 2023-24 (reports_home_screen.dart:235). The report it opens uses `now.month >= 4 ? now.year : now.year - 1` (report_configuration.dart:96). From 1 April to 31 July (the ITR filing window) the quick card therefore opens the new, nearly empty FY, not the FY being filed. The previous FY is reachable only through HistoricalReportsList lower on the screen (reports_home_screen.dart:309).
- **Impact:** No impact today because Reports is flag-gated. But MKT-02's main recommendation is to ship and market the FY report for ITR season, and as built the first tap shows a three-year-old label and the wrong FY for tax filing.
- **Fix:** Compute the subtitle from the same FY logic. During Apr-Jul, default the quick card (or add a second one) to the just-closed FY, labelled 'FY 2026-27 (for ITR)'. Fix this before any tax-season push.

## ADOPT · User adoption, activation, retention & growth loops

### ADOPT-03 · high · The 'aha moment' shows wrong numbers: sample data shows about -97% XIRR, and the empty-state demo claims compounding lowers a 7% FD to 6.2%

- **Status:** Confirmed · effort S · action A20
- **Where:** `lib/features/settings/data/services/sample_data_service.dart:98-150`; `lib/features/settings/data/services/sample_data_service.dart:211-236`; `lib/features/overview/presentation/widgets/overview_empty_state.dart:66-72`
- **Evidence:** Sample FD 'Sample FD - HDFC Bank' is status open with INVEST 1,00,000 at now-365d and four INCOME 1,813 payments (now-275/-183/-91/-1d), with no RETURN. Its note says 'Notice how the real XIRR differs from the advertised 7.25% rate!' and a code comment says 'Real XIRR: ~6.2%'. I copied lib/core/calculations/xirr_solver.dart to a scratch directory and ran it with dart on these exact flows: FD = -0.9701 (shown '-97.0%' in red, because `xirrIsPositive ? graphCyan : errorLight`); SGB (-62,630 then +783) = -0.99984 …
- **Impact:** Every new user who taps 'Try Sample Data', the main way to explore the app before entering anything, sees a portfolio losing about 97% a year and a red FD. Finance-literate users, the core audience, will spot that the demo's math is wrong. Trust breaks at first impression and the app reads as broken.
- **Fix:** 1) Rebuild the samples so every one is closed or valued. Lead the 'advertised vs real' demo with the P2P example (12% advertised, 6.3% after fee and one default). Show the FD honestly: a gross payout FD gives about 7.45%; an after-tax view at slab rate (e.g. 30% slab gives about 5.2%) is the realistic way to show 'less than the bank says'. Do not use TDS on a Rs 1L FD. 2) Fix the empty-state caption, which wrongly blames compounding. 3) Add a unit test that keeps every sample XIRR in [0%, 20%] and portfolio MOIC >= 1.
- **Numeric check:** I ran the app's own XirrSolver in Dart and an independent Python bisection; both agree.
- Sample FD: app -0.97007 (shows -97.0% in red).
- SGB: app -0.99984 (shows -100.0%).
- Whole sample portfolio (USD 88, EUR 103): invested Rs 3,77,030, returned Rs 11,677, MOIC 0.031x. The hero card shows the app's -97.3%. That …

### ADOPT-05 · high · Play listing makes false or stale claims ('We don't store your financial data on our servers', 'NEW IN VERSION 3.6.0') and brand names are inconsistent

- **Status:** Confirmed · effort S · action A01
- **Where:** `android/fastlane/metadata/android/en-US/full_description.txt:22`; `android/fastlane/metadata/android/en-US/full_description.txt:56-57`; `android/fastlane/metadata/android/en-US/full_description.txt:60`
- **Evidence:** full_description.txt:63 says 'We don't store your financial data on our servers. It stays with you.' In fact all investments, cash flows and goals live in Cloud Firestore under users/{uid} (product.yaml data_collection.stored.remote; the repo's own notes say the live privacy policy 'understates data collection'). Line 22 says '🆕 NEW IN VERSION 3.6.0' while current_version is '3.70.18+274'. Lines 56-57 say 'Works Offline - Use the app without internet', but first launch needs network for Google or anonymous …
- **Impact:** A false data-handling claim that contradicts the Data Safety form and privacy policy is a Play policy risk (deceptive or misleading claims) and a trust breaker for a finance app. Stale 'new in 3.6.0' copy signals neglect. Inconsistent naming weakens brand recall and search. Unmentioned differentiators lower store conversion.
- **Fix:** As recommended: fix line 63 first, together with the pending privacy-policy correction; remove the version block; qualify the offline claim; unify the brand. Note that guest mode is a differentiator only once its FAQ is corrected (ADOPT-06).

### ADOPT-06 · high · Guest mode: FAQ wrongly promises cross-device access, the 30-day inactivity purge is undisclosed, and the upgrade path is buried in Settings and untracked

- **Status:** Confirmed · effort S · action A05, A43
- **Where:** `lib/l10n/app_en.arb:2451`; `lib/l10n/app_en.arb:2501`; `lib/l10n/app_en.arb:2521`
- **Evidence:** FAQ `whatIsGuestModeAnswer`: 'Your data is stored in the cloud under an anonymous account, so you can access it across devices.' Anonymous Firebase accounts can't be signed into on another device, so this is false. cleanupAnonymousUsers.ts deletes all Firestore data and the auth user for anonymous users whose `lastRefreshTime ?? lastSignInTime ?? creationTime` is older than 30 days, daily at 02:00 UTC. Neither guestModeNotice ('...uninstalling the app may cause data loss') nor the FAQ mentions this. The repo can't …
- **Impact:** If the purge is live, a guest who opens the app every quarter when FD interest arrives (normal for this audience) loses all data silently after 30 days. Guests who switch phones lose everything despite the FAQ's promise. Guest-to-Google conversion is unmeasured and is never encouraged at moments of high value.
- **Fix:** As recommended: fix the FAQ now; check in the Firebase console whether the purge is live, and if so raise the threshold or disclose it; add contextual link prompts after the 3rd investment or first goal; log account_link_success. Keep the 'account_link_failure{reason: google_account_exists}' event: it describes a link that did fail. Optionally add a separate backup_signin event.

### ADOPT-07 · high · First investment is a dead end: Add Investment takes no amount, then returns to an Overview that still shows the empty state; activation nudges stop anyway

- **Status:** Confirmed · effort M · action A40
- **Where:** `lib/features/investment/presentation/screens/add_investment_screen.dart:276-310`; `lib/features/investment/presentation/screens/add_investment_screen.dart:344-350`; `lib/features/investment/presentation/screens/add_investment_screen.dart:627-629`
- **Evidence:** `addInvestment(name:, type:, notes:, maturityDate:, incomeFrequency:, startDate:, expectedRate:, tenureMonths:, platform:, ...)` takes no amount, and the live projection uses `const illustrativePrincipal = 100000.0; // 100K for illustration`. After saving, `context.pop(widget.isEditing ? true : null)` returns to the caller, Overview. Overview renders `stats.hasData ? _buildDataContent : _buildEmptyStateContent`, with `bool get hasData => cashFlowCount > 0;`. So after creating an investment the user sees the same …
- **Impact:** Getting to the first XIRR takes about 10 taps across 3 screens (create investment, find it in the Investments tab, open detail, Add Transaction, type, amount, date). Users who stop after step 1 believe nothing happened, and their reminder nudges have already been cancelled. This is the largest likely leak between investment_created and cashflow_added.
- **Fix:** 1) Add 'Amount invested' plus a start date (default today) to the Add Investment form. On save, create the investment and its INVEST cash flow in one batch. 2) For FD/RD/Bond/P2P templates, offer 'Add past interest payouts' and 'Schedule expected payouts': generate INCOME rows (past) and expected cash flows (future) from principal, rate, payout mode and start date. Example: FD Rs 1,00,000 at 7.25% quarterly payout from 2026-01-01 creates 3 past INCOME rows of Rs 1,812.50 (Apr/Jul/Oct) and maturity on 2027-01-01. This gives 'Add an FD in 3 fields'. 3) After save, go to InvestmentDetailScreen (pushReplacement) …
- **Numeric check:** Quarterly payout on Rs 1,00,000 at 7.25% = 1,812.50 per quarter, matching the reviewer. From 2026-01-01, the past payout dates before 2026-10-02 are Apr 1, Jul 1 and Oct 1, which is 3 rows.

### ADOPT-08 · high · No current or expected value for open investments, so real users of FDs, P2P, SGB and real estate see 0.0% or about -99% XIRR and a red net position until exit

- **Status:** Confirmed · effort L · action A10, A47
- **Where:** `lib/features/investment/domain/entities/transaction_entity.dart:7-11`; `lib/core/calculations/financial_calculator.dart:87-99`; `lib/core/calculations/xirr_solver.dart:205-207`
- **Evidence:** CashFlowType has only `invest, returnFlow, income, fee`, with no valuation or current-value type. XIRR is computed purely from recorded flows (`XirrSolver.calculateXirr(dates, amounts) ?? 0.0`). If there are only outflows the solver returns null, which is shown as '0.0%'. Worked examples (python check): P2P with -50,000 on 2026-04-02 and 6 monthly +625 gives XIRR -99.93% in the app today. With principal valued at Rs 50,000 on 2026-10-02 it is +16.03%. A cumulative FD of Rs 1,00,000 at 7% quarterly, 6 months in, …
- **Impact:** The product's main promise ('know your real returns') doesn't hold for the main use case. Most alternative investments stay open for months or years, so a new user who honestly records their FD or P2P loan sees a loss-making portfolio and 0x MOIC. That kills the aha moment and the reason to come back. This overlaps with the CALC dimension; the activation impact is flagged here.
- **Fix:** 1) Add an optional 'current value' or 'valuation' entry, a non-cash mark kept separate from cash flows, that XIRR uses as a terminal inflow at its date when the investment is open. Formula: XIRR solves sum CF_i / (1+r)^((d_i-d_0)/365) + V_t / (1+r)^((t-d_0)/365) = 0. 2) For fixed-income types with rate and tenure (FD, RD, bonds, P2P), auto-derive V_t: cumulative FD V_t = P x (1+r/n)^(n x years_elapsed); payout types V_t = outstanding principal. Label it 'Expected XIRR (based on 7% p.a.)' until real cash comes back. 3) Show 'Realised XIRR' and 'Expected XIRR' side by side, with a tooltip. 4) For gold/SGB, take a …
- **Numeric check:** App XirrSolver (Dart) and independent Python agree:
- P2P: -50,000 on 2026-04-02 plus six monthly +625 gives -0.99926 (-99.9%). Adding a principal value of 50,000 on 2026-10-02 gives +0.16029 (16.03%), consistent with 1.0125^12-1 = 16.08% compounding.
- Cumulative FD: a single -1,00,000 flow gives 0.0 (shown 0.0%). …

### ADOPT-V1 · high · CSV import tags every row without a Currency column as USD while the preview shows it in rupees, so imported amounts come out about 85x too large

- **Status:** Added by verifier · effort S · action A03
- **Where:** `lib/features/bulk_import/data/services/simple_csv_parser.dart:268-275`; `lib/features/bulk_import/presentation/screens/import_confirmation_screen.dart:80-101`; `lib/features/bulk_import/presentation/screens/import_confirmation_screen.dart:241-270`
- **Evidence:** SimpleCsvParser: `final currency = (currencyRaw == null || currencyRaw.isEmpty) ? 'USD' : currencyRaw.toUpperCase();`, and the amount parser strips ₹/$ symbols (line 484), so '₹5,000' is also tagged USD. ImportConfirmationScreen creates InvestmentEntity without a currency, which defaults to 'USD' (investment_entity.dart:335), and creates cash flows with `row.currency ?? 'USD'`. The confirmation preview formats amounts with the user's base-currency currencyFormat (₹ by default, since settings default to INR) and …
- **Impact:** An INR user who follows the guide, or imports their own spreadsheet without a Currency column, sees ₹1,00,000 in the preview. After import the portfolio shows about ₹83-88 lakh per ₹1 lakh. These are wrong money numbers on the very path the Day-3 activation push promotes ('Import your investments from CSV in seconds'). Power users with many investments, the highest-value …
- **Fix:** 1) When the Currency cell or column is missing, default to the user's base currency (currencyCodeProvider) at import time, not 'USD'. Set InvestmentEntity.currency explicitly from the rows. 2) Show the resolved currency per investment in the confirmation screen and format amounts in that currency, with a picker to override. 3) Add the Currency column to BULK_IMPORT_GUIDE's sample. 4) Add a regression test: a CSV with no Currency column and base currency INR imports as INR. 5) Offer a one-time repair for already-imported investments: re-tag USD to INR where every flow came from an import with no currency column.

### ADOPT-01 · medium · Retention features ship turned off: Reports (FY/PDF), Portfolio Health and Income Guardian only reachable through a hidden 7-tap debug menu

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A42
- **Where:** `lib/core/providers/feature_flags_provider.dart:17-46`; `lib/core/providers/feature_flags_provider.dart:69-74`; `lib/features/home/presentation/screens/home_shell_screen.dart:52-57`
- **Evidence:** FeatureFlagsNotifier.build(): `final defaultValue = flag == FeatureFlag.portfolioHealthScore ? false : false;` so every flag defaults to false. Flags are only stored in SharedPreferences, with no Remote Config (pubspec has no firebase_remote_config). They can only be toggled from DebugSettingsScreen. That screen appears in Settings only when `isDebugEnabled`, which is turned on by tapping the version 7 times inside 3 s (about_screen.dart `_requiredTaps = 7`). Effects: HomeShell adds the Reports tab only `if …
- **Impact:** Every Play user loses the features that bring people back and set the app apart: FY reports and PDF/CSV export (relevant at tax time), the Portfolio Health score and the income calendar. Weekly, monthly and FY summary notifications send users to an Overview with no summary (see ADOPT-09). The founder can't learn whether these features help retention because no real user has …
- **Fix:** 1) Now: stop scheduling the weekly, monthly and FY summary pushes while reportsTab is off, or point them at a working destination. 2) QA Reports and Health with portfolios that are mostly open investments (after the ADOPT-08 fix, or with XIRR hidden for open positions), then turn reportsTab on by changing the code default in a release. Remote Config is optional for a solo founder; per-cohort A/B can come later. 3) Decide whether Income Guardian is launched or hidden. Today its settings and background service are live while its dashboard card is not; make it consistent.
- **Verifier:** Most of the evidence holds. Every flag defaults to false (feature_flags_provider.dart:72, `flag == FeatureFlag.portfolioHealthScore ? false : false`). pubspec has no firebase_remote_config, so flags can only be set from SharedPreferences. The debug screen appears only after 7 taps within 3 s (about_screen.dart:37,61; …

### ADOPT-02 · medium · Play in-app review prompt is built but disabled for all users, and its trigger (first RETURN only) rarely fires for long-tenure investments

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A42
- **Where:** `lib/core/providers/feature_flags_provider.dart:43-46`; `lib/core/providers/feature_flags_provider.dart:182-188`; `lib/features/investment/presentation/screens/add_transaction_screen.dart:33-36`
- **Evidence:** The flag is defined as `reviewPrompt('review_prompt', 'Play Review Prompt')` with the comment 'Disabled by default, enable via Debug Settings (POR-91/POR-99)'. add_transaction_screen.dart only calls the service when `isReviewPromptSuccessMoment(...) && ref.read(isReviewPromptEnabledProvider)`, and `isReviewPromptSuccessMoment` is `!isEditing && type == CashFlowType.returnFlow`. The service itself is well built: one-shot (`review_prompt_v1_requested_at`), checks whether an update is pending and is Android-only. …
- **Impact:** In production the review sheet is never shown, so ratings volume and recency, which drive Play ranking and store conversion, depend entirely on users who go to the store by themselves. Even with the flag on, users of cumulative FDs, SGBs (8-year tenure) or real estate may not record a RETURN for months or years, so most satisfied users would never see the prompt.
- **Fix:** Turn the flag on in a release (no Remote Config needed). Broaden the trigger to the first RETURN, the 3rd INCOME, or the 2nd day viewing a positive XIRR, with a minimum tenure of 7 days or 5 sessions. Add a 'Rate InvTrack' row in About that opens market://details?id=<package> (fallback to the https Play URL). Log review_prompt_eligible.
- **Verifier:** Confirmed: reviewPrompt defaults to false (feature_flags_provider.dart:46,72). add_transaction_screen.dart:173-186 calls the service only for `!isEditing && type == returnFlow` and only when the flag is on. The service is one-shot and Android-only (review_prompt_service.dart:60-87). There is no Rate/Play-store row in …

### ADOPT-04 · medium · Activation funnel can't be measured: key steps not instrumented, most screens send no screen_view, no user properties, 13 dead event methods

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A41
- **Where:** `lib/core/analytics/analytics_service.dart:125-204`; `lib/core/analytics/analytics_service.dart:387-399`; `lib/core/analytics/analytics_service.dart:429-431`
- **Evidence:** Funnel map from grep of call sites. (1) Install: first_open is automatic. MEASURABLE. (2) Onboarding: only a screen_view '/onboarding' (root GoRoute, page name = path). `_completeOnboarding` logs nothing, so completed vs. skipped is unknown. (3) Sign-in: `analytics.logSignIn(method: 'google')` fires on every Google sign-in. logSignUp has 0 callers and `additionalUserInfo`/`isNewUser` is never read, so new and returning users can't be told apart. Guest: 'guest_mode_started' is measurable. (4) Guest upgrade: …
- **Impact:** The founder can't compute activation rate, time-to-value or the drop-off between sign-in, investment, cash flow and seeing XIRR. No onboarding, sample-data or notification change can be evaluated. Retention can't be compared with finance-app norms: D30 is about 4-5% (https://www.plotline.so/blog/retention-rates-mobile-apps-by-industry, …
- **Fix:** Build a GA4 funnel now from the existing events. Then add the few events that matter: onboarding_completed, sign_up (from isNewUser), account_link_success, notification_opened, xirr_viewed and notification_permission_result. Set 2-3 user properties (auth_type, activation_state). Give the investment-detail, add-investment and add-transaction routes RouteSettings names. Move empty_state_viewed out of build(). Delete the 12 unused methods rather than wiring them all.
- **Verifier:** Mostly accurate.
- logSignUp, logErrorOccurred, logGoalMilestoneReached, logProjectionViewed, logReportMetricTooltipViewed, logHealthComponentExpanded and setUserProperty have 0 callers.
- 24 MaterialPageRoute pushes, none with `settings:`. The observer is attached only to the root GoRouter navigator …

### ADOPT-09 · medium · Re-engagement notifications misroute or do nothing on tap, are generic, fire at max importance and ignore user context

- **Status:** Confirmed · effort S · action A29
- **Where:** `lib/core/notifications/notification_payload.dart:176-180`; `lib/core/notifications/notification_navigator.dart:168-172`; `lib/core/notifications/notification_payload.dart:319-327`
- **Evidence:** (a) The weekly check-in ('Did you receive any investment income this week? Tap to log it now.') parses to `addCashFlow` with no investmentId, and `_navigateToAddCashFlow` begins `if (investmentId == null) return false;`, so tapping does nothing. (b) Weekly summary, monthly summary and FY summary payloads push '/reports/builder?...', which the router redirects to '/' while reportsTab is off (ADOPT-01). (c) Activation pushes 'Add your first investment now!' and 'Import your investments from CSV' both route to …
- **Impact:** Weekly pushes that open nothing useful teach users to ignore or disable InvTrack notifications. That also mutes the valuable maturity and income reminders and raises uninstall risk. Non-Indian users get irrelevant tax pushes. Effectiveness can't be measured.
- **Fix:** As recommended. Fix the year logic for all tax reminders together: next occurrence = DateTime(y, m, d), and if it is not after now, use y+1. Note that gating tax reminders on 'base currency INR' does not currently separate anyone, because every user defaults to INR (see ADOPT-V2). Use the device country, or an explicit opt-in.

### ADOPT-10 · medium · No growth loops: no share-returns card, invite or referral, 'Share app' or 'Rate us'; the only share is health-score text copied to the clipboard with no link, behind a disabled flag

- **Status:** Confirmed with corrections (reviewer said high) · effort M · action A46
- **Where:** `lib/features/portfolio_health/presentation/screens/portfolio_health_details_screen.dart:489-516`; `lib/l10n/app_en.arb:3009`; `lib/features/investment/presentation/widgets/investment_detail_stats_section.dart:47-70`
- **Evidence:** share_plus is only used to share files (CSV template, ZIP or CSV export, report export, document viewer). `_shareScore` logs `shareMethod: 'clipboard'` and calls `Clipboard.setData(...)` with a TODO: '(@ravitejakamalapuram, 2026-04-06, #322): Generate score card image and share'. The shareScoreText ends with 'Track your investments with InvTrack!' and has no store link or referrer. The Health screen is itself behind the disabled portfolioHealthScore flag. The investment detail XIRR/MOIC section has no share …
- **Impact:** All growth depends on store search and the founder's own marketing; existing users have nothing to share and no reason to invite anyone. Indian alternative-investment communities (P2P/bond Telegram groups, Reddit r/IndiaInvestments, Twitter) readily share XIRR screenshots, but InvTrack doesn't produce one.
- **Fix:** Start cheap: add 'Share InvTrack' and 'Rate InvTrack' rows (S effort), and a 'Made with InvTrack' footer with a UTM Play link on exported PDFs once Reports ships. Then build a privacy-safe XIRR share card (percentages only, no amounts, opt-in) on closed investments, measured by share_card_shared and install-referrer UTM. Defer advisor and family links.
- **Verifier:** The facts hold. share_plus is used only for files (csv_template_service.dart:213, data_export_service.dart:241, export_service.dart:90, report_export_providers.dart:171, document_viewer_screen.dart:368). _shareScore copies text to the clipboard, has the TODO #322, and logs shareMethod 'clipboard' …

### ADOPT-11 · medium · Overview shows the empty state (and offers 'Try Sample Data') to existing users while cash flows load or on error, and logs empty_state_viewed

- **Status:** Confirmed · effort S · action A28
- **Where:** `lib/features/investment/presentation/providers/multi_currency_providers.dart:258-270`; `lib/features/overview/presentation/screens/overview_screen.dart:103-137`; `lib/features/overview/presentation/screens/overview_screen.dart:258-265`
- **Evidence:** multiCurrencyGlobalStats does `cashFlowsAsync.when(data: ..., loading: () async => <CashFlowEntity>[], error: (e, st) async => <CashFlowEntity>[])`, then `if (cashFlows.isEmpty) return InvestmentStats.empty();`, and also returns empty if `!engine.currency.isAvailable`. Overview's `globalStats.when(data: (stats) => stats.hasData ? ... : _buildEmptyStateContent(...), error: (e, s) => _buildEmptyStateContent(...))` renders the onboarding empty state, including the 'Try Sample Data' CTA, whenever that happens. …
- **Impact:** Returning users can briefly see 'See Your Real Returns / Get Started' on cold start, or see it permanently on a load or currency error. That reads as data loss and can lead them to load sample data on top of real data. empty_state_viewed counts users who already have data, which corrupts the activation funnel.
- **Fix:** 1) Pass loading and error through from the provider (await the stream's first value, or return AsyncLoading/AsyncError) instead of mapping them to an empty list. 2) In Overview, show skeletons on loading and OverviewErrorCard with a Retry button on error. 3) Show the empty state only when allInvestmentsProvider has loaded and is empty. When investments exist but there are no cash flows, show a 'Finish setup: add amounts' card instead (ties to ADOPT-07). 4) Log empty_state_viewed once per session from initState.

### ADOPT-14 · medium · Import friction: CSV-only with a generic schema, no parsers for popular Indian platform statements or AIS, and a stale template in docs

- **Status:** Confirmed · effort L · action A48
- **Where:** `lib/features/bulk_import/presentation/screens/bulk_import_screen.dart:50-54`; `lib/features/bulk_import/data/services/csv_template_service.dart:9-18`; `docs/invtracker_template.csv:1`
- **Evidence:** The file picker allows `type: FileType.custom, allowedExtensions: ['csv']`, so no XLSX or PDF. The in-app template has the columns Date, Investment Name, Type, Amount, Currency, Notes, Investment Type, Investment Status. docs/invtracker_template.csv has a different, internal schema (`id,user_id,investment_id,...,sync_status,meta`) that contradicts BULK_IMPORT_GUIDE.md. bulk_import has no platform-specific mapping for any lender or bond platform; the only mention is a sample row named 'P2P Lending - LenDenClub'. …
- **Impact:** Users with 10+ alternative investments face hours of manual entry or spreadsheet reshaping. Platforms usually export XLSX or PDF statements with their own columns, so 'import in seconds' is untrue for them and power users, the highest-LTV segment, drop off.
- **Fix:** First fix the USD currency default (ADOPT-V1) and the stale docs template; both are S effort. Then add a column-mapping step and accept XLSX. Gate platform presets and AIS import on measured demand (import_platform_requested).

### ADOPT-V2 · medium · First-run locale and currency detection is dead code: ProfileInitializer is never mounted, so every user worldwide starts in INR with en_IN formatting and no profile document

- **Status:** Added by verifier · effort S · action A31
- **Where:** `lib/features/user_profile/presentation/widgets/profile_initializer.dart:15-60`; `lib/features/user_profile/data/services/profile_initialization_service.dart:45-125`; `lib/features/settings/presentation/providers/settings_provider.dart:54-56`
- **Evidence:** `grep -rn ProfileInitializer lib` finds only its own file, and ProfileInitializationService has no instantiation anywhere. These are the only code paths that call LocaleDetectionService and write the detected currency or locale into settings (profile_initializer.dart:55-57; profile_initialization_service.dart:123-124). SettingsNotifier therefore falls back to `prefs.getString('currency') ?? 'INR'` and `'locale' ?? 'en_IN'` for every new install. initializeProfileForNewUser is never called, so no user profile is …
- **Impact:** Non-Indian users, whom the listing and multi-currency samples court, see ₹ and lakh/crore formatting from the first screen with no prompt to change it. Analyses or recommendations that assume a locale-detected currency (ADOPT-13, and gating tax pushes by base currency in ADOPT-09) rest on a false premise. Any future ad monetisation is silently off for all users.
- **Fix:** Decide on one path. Either (a) mount ProfileInitializer in app.dart only for installs with no stored 'currency' pref, and pair it with a one-tap 'Confirm your currency' sheet on first run (pre-selected from the device country, INR first). Or (b) delete the unused profile-initialisation code and add the confirmation sheet directly. Add a widget test asserting that a fresh install with device locale en_GB gets GBP proposed. Use the device country, not base currency, for India-only content such as tax reminders.

### ADOPT-13 · low · Onboarding is 4 static English slides with no personalisation; currency is guessed silently from device locale; notification permission is asked cold right after sign-in

- **Status:** Confirmed with corrections (reviewer said medium) · effort M · action A40
- **Where:** `lib/features/onboarding/presentation/screens/onboarding_screen.dart:30-59`; `lib/features/onboarding/presentation/screens/onboarding_screen.dart:67-72`; `lib/features/auth/presentation/screens/sign_in_screen.dart:158-160`
- **Evidence:** The onboarding pages are hard-coded education ('Track Money In & Out', 'Know Your Real Returns', ...) with no question or action. Page 4 claims 'Use the app without internet'. Currency comes from `LocaleDetectionService.getCurrencyForCountry(countryCode)`, falling back to `?? 'USD'` with no confirmation UI (isFirstLogin is only ever set to false). New investments default to `currency: currency ?? 'USD'`. The currency switch provider only fetches rates and does not rewrite stored currencies. …
- **Impact:** Indian users whose phone locale is en_US (common) get USD and '$' amounts. If they enter rupee amounts and later switch base currency to INR, each amount is converted about 88x (Rs 1,00,000 entered under USD shows as about Rs 88 lakh). A cold permission prompt with no context lowers opt-in, and maturity and income reminders, the best retention hook, need that permission. The …
- **Fix:** Move the notification permission request to after the first investment that has a maturity or income date, behind a primer sheet. Trim onboarding to 1-2 slides plus an optional 'what do you track' chip screen. Add a one-tap currency confirmation on first run, pre-selected from the device country and defaulting to INR (see ADOPT-V2). Externalise the strings.
- **Verifier:** Confirmed:
- Onboarding is 4 hard-coded slides that ask nothing, including the 'Use the app without internet' claim (onboarding_screen.dart:29-59).
- The OS notification permission is requested immediately after Google or guest sign-in (sign_in_screen.dart:158-160, 206-208, 224-253).

Refuted, which is the main impact …

### ADOPT-15 · low · Android-only reach: ios/ is configured but App Store blockers (Sign in with Apple) are unaddressed, and web/ is unused as an acquisition channel

- **Status:** Confirmed with corrections (reviewer said medium) · effort L · action A68
- **Where:** `.appforge/product.yaml:9`; `ios/Runner/Info.plist:49-63`; `ios/Runner.xcodeproj/project.pbxproj:502`
- **Evidence:** product.yaml has `platform: [android]`. The iOS project has bundle id com.invtracker.invTracker, GoogleService-Info.plist, Face ID and camera usage strings and URL schemes, but auth offers only Google and anonymous login. Apple Guideline 4.8 requires an equivalent privacy-focused login option (e.g. Sign in with Apple) when a third-party social login authenticates the primary account (https://developer.apple.com/forums/thread/765145). The review prompt and in-app update are Android-only by design. firebase_options …
- **Impact:** Affluent Indian alternative-investment users who use iPhones can't install the app. The free organic search channel for 'XIRR calculator', 'FD return calculator' and 'P2P lending return calculator' is unused.
- **Fix:** Keep iOS gated on Android activation and retention targets. If you try the web channel, start with a static XIRR or 'real return' calculator page reusing XirrSolver logic, with a UTM-tagged Play CTA. Treat it as a marketing experiment rather than a product track.
- **Verifier:** The facts hold:
- product.yaml:9 has `platform: [android]`.
- An iOS project exists (bundle com.invtracker.invTracker, project.pbxproj:502).
- pubspec has no sign_in_with_apple, and auth offers only Google and anonymous sign-in.
- Apple Guideline 4.8 does require an equivalent privacy-focused login (e.g. Sign in with …

### ADOPT-16 · low · English-only, with many user-facing strings hard-coded outside ARB in the activation path

- **Status:** Confirmed · effort M · action A50
- **Where:** `l10n.yaml:20-21`; `lib/features/onboarding/presentation/screens/onboarding_screen.dart:31-58`; `lib/features/onboarding/presentation/screens/onboarding_screen.dart:105`
- **Evidence:** l10n.yaml has `preferred-supported-locales: - en`, and lib/l10n contains only app_en.arb. Hard-coded strings include onboarding titles and subtitles and 'Skip', the empty-state 'See Your Real Returns', 'Banks say 7%. What did you really earn?', 'Advertised', 'Your XIRR', 'Quick Templates', the Overview title 'Investment Tracker', and the 'Investment created successfully' snackbar. Notification copy in notification_service.dart and scheduled_notification_handler.dart is also hard-coded.
- **Impact:** Adding Hindi or other Indian languages would still leave the first-run screens in English. This limits reach beyond English-first users, a smaller but real segment for FD and chit-fund users.
- **Fix:** 1) Move all onboarding, empty-state, snackbar and notification strings into app_en.arb, enforced with a lint or CI grep for string literals in presentation/ widgets. 2) Set a user property for device language. If >=10% of Indian users have hi/ta/te devices, translate only the activation path (onboarding, empty state, add investment, notifications) into Hindi first.

## QA · Tests, CI/CD, dependencies, repo hygiene & docs accuracy

### QA-02 · high · Play listing in the repo (now auto-synced to Play) says the financial data is not stored on servers, and its 'what's new' section is 3.6.0

- **Status:** Confirmed · effort S · action A01
- **Where:** `android/fastlane/metadata/android/en-US/full_description.txt:22`; `android/fastlane/metadata/android/en-US/full_description.txt:59-63`; `release.yaml:24-27`
- **Evidence:** full_description.txt:62-63 says '🔒 Your Data, Your Control / We don't store your financial data on our servers. It stays with you.' Three lines earlier (59-60) the same file says 'Sign in with Google to backup your data'. All investments and cash flows are written to Cloud Firestore under users/{uid} in the developer's Firebase project (firestore.rules:5; README.md:59 'shared project'; the in-app policy legal_content.dart:20 'securely stored in ... Google Firebase'). Line 22 says '🆕 NEW IN VERSION 3.6.0'. The …
- **Impact:** Google Play's deceptive-behaviour and Data safety rules require store claims to match the declared data handling. The Data safety form must declare cloud storage of financial info, so this listing contradicts it, and the next listing sync republishes the false claim. Users who pick the app for 'data stays with you' are misled. The '3.6.0' heading also makes a maintained app …
- **Fix:** As proposed: rewrite lines 22-40 without a version number, and replace lines 62-63 with an accurate claim that matches the Data safety form and the in-app policy. Avoid 'your private cloud account' wording, because it is the developer's Firebase project. Run listing.yml with dry_run and then live. Add the CI grep for false-privacy phrases.

### QA-03 · high · Missing 'currency' field defaults to USD in an INR-first app, and a test locks that behaviour in

- **Status:** Confirmed · effort M · action A03, A04
- **Where:** `lib/features/investment/data/repositories/firestore_investment_repository.dart:661`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:688`; `lib/features/goals/data/models/goal_model.dart:54`
- **Evidence:** Every Firestore mapper and the ZIP/CSV import use `data['currency'] as String? ?? 'USD'` or `row.currency ?? 'USD'`. The app's default base currency is INR (settings_provider.dart:55 `prefs.getString('currency') ?? 'INR'`). ADR-002 (MULTI_CURRENCY_ARCHITECTURAL_REVIEW.md:403-408) says 'Existing data in production may not have currency field' and still picks USD. The test 'handles missing currency column (backward compatibility)' imports a v1.0 backup with '2024-01-15,Legacy Investment,INVEST,100000' and asserts …
- **Impact:** An Indian user with pre-multi-currency data or an old backup sees ₹1,00,000 converted as $1,00,000, which is about ₹85,00,000 at 85 INR/USD. Invested, value, goal progress and FIRE progress are all inflated by about 85x. XIRR is unaffected if every flow defaults the same way, but mixed old and new flows give nonsense.
- **Fix:** Fall back to the user's base currency (passed in) in SimpleCsvParser, both import services, the notifier and the mappers. If the base is unknown at parse time, keep currency null in ParsedCashFlowRow and resolve it at confirmation. Show the resolved currency on the import confirmation screen. Update simple_csv_parser_test.dart:392-401 and multi_currency_export_import_test.dart:314-316 to assert the base currency. Then count production docs that have no currency field and backfill them with the user's base currency.
- **Numeric check:** Legacy or imported flow: amount 100,000, no currency, base INR. Correct display is ₹1,00,000. The app stores and treats it as 100,000 USD, so it shows 100,000 × USD/INR (about 85-88) ≈ ₹85-88 lakh. XIRR on a single-currency investment is unchanged because the scale factor cancels, but totals, goals and FIRE progress …

### QA-01 · medium · FY report and weekly summary count boundary-day cash flows in two periods (regression from a bot 'optimisation', untested)

- **Status:** Confirmed with corrections (reviewer said high) · effort S · action A19
- **Where:** `lib/features/reports/data/services/fy_report_service.dart:42-43`; `lib/features/reports/data/services/fy_report_service.dart:61-67`; `lib/features/reports/data/services/fy_report_service.dart:180-209`
- **Evidence:** fy_report_service.dart:43 sets fyEnd = DateTime(fyYear + 1, 3, 31, 23, 59, 59). Lines 61-67 (comment '⚡ Bolt: Single pass loop replacing .where().toList()') then use startLimit = fyStart - 1 day, endLimit = fyEnd + 1 day and `cf.date.isAfter(startLimit) && cf.date.isBefore(endLimit)`. Because fyEnd is already 23:59:59, endLimit becomes 1 April 23:59:59 of the next year. I copied the filter into a standalone Dart script and got: 2024-04-01 00:00 -> FY2023-24=true, FY2024-25=true; 2024-03-31 10:00 -> FY2023-24=true, …
- **Impact:** Indian users get wrong tax-year numbers. Example: ₹5,00,000 invested on 1 Apr 2024 shows in 'Total Invested' for both FY 2023-24 and FY 2024-25. The FY 2023-24 headline is ₹5,00,000 too high, the 12 monthly rows add up to ₹5,00,000 less than the headline, and the FY XIRR includes a cash flow from outside the year. 1 April (start of the FY) is a common date for new FDs, …
- **Fix:** Same fix: use half-open intervals [DateTime(fyYear,4,1), DateTime(fyYear+1,4,1)), [weekStart, weekStart+7d) and [DateTime(y,m,1), DateTime(y,m+1,1)), and add boundary tests plus a test that the monthly rows add up to the headline. Treat it as a blocker before enabling the reportsTab flag, not a hotfix for live users. Remove the 'regression from Bolt' framing, because the bug predates that PR.
- **Numeric check:** I ran a standalone Dart copy of the filter. 2024-03-31 00:00 is in FY23 only. 2024-03-31 10:00 is in FY23 and FY24. 2024-04-01 00:00 is in FY23 and FY24. 2024-04-01 12:00 is in FY23 and FY24. For the worked example {31 Mar 2024: 100,000 invest; 1 Apr 2024: 500,000 invest}, the correct values are FY23-24 = 100,000 and …
- **Verifier:** The boundary bug is real. fy_report_service.dart:42-43 sets fyEnd to 31 Mar 23:59:59, and lines 61-67 then use isAfter(fyStart-1d) && isBefore(fyEnd+1d), so 1 Apr of the next year (any time up to 23:59:59) falls inside the FY. With a time component, 31 Mar of the start year is also inside the next FY. This matters …

### QA-07 · medium · 45% of lib code is in files no test imports, and the gaps include repositories, model mappers, the router's auth/app-lock redirect and notification deep links

- **Status:** Confirmed · effort L · action A64
- **Where:** `lib/features/goals/data/repositories/firestore_goal_repository.dart:1`; `lib/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart:1`; `lib/features/fire_number/data/repositories/firestore_fire_settings_repository.dart:1`
- **Evidence:** I mapped every `import 'package:inv_tracker/...'` in test/ and integration_test/ to lib/. 167 of 325 lib files (35,589 of 78,654 LOC) are imported by no test. By layer: presentation 62.5% untested-direct, data 32.1%, domain 22.1%. Data and core files with zero tests include firestore_goal_repository.dart (204 LOC), firestore_expected_cash_flow_repository.dart (377), firestore_fire_settings_repository.dart (77), firestore_user_profile_repository.dart (77), goal_model.dart, fire_settings_model.dart, …
- **Impact:** Firestore mapping errors (wrong field name, Timestamp cast, default value) and router-guard regressions would ship silently. An app-lock redirect bug would expose amounts on a shared device. The data layer is where wrong-money and data-loss bugs start.
- **Fix:** Priority order: (1) table-driven redirect tests for app_router covering signed out, onboarding incomplete, locked and unlocked, and the reports flag. (2) toFirestore/fromFirestore round-trip tests for each model, including docs with missing optional fields. (3) Repository tests with fake_cloud_firestore (add as dev dependency) for goals, expected cash flows, fire settings and profile. (4) notification_navigator payload-to-route tests. Delete the tests of fakes. Add `flutter test --coverage` to release.yaml's test command, publish lcov, and add a ratchet so coverage never drops (start at the current baseline).

### QA-08 · medium · Golden and integration tests never run, and auto-release sends every feat/fix to 100% of production

- **Status:** Confirmed · effort M · action A63
- **Where:** `release.yaml:8`; `test/golden/widgets/glass_card_golden_test.dart:2`; `test/golden/theme/theme_showcase_golden_test.dart:2`
- **Evidence:** release.yaml:8 runs `flutter test --exclude-tags=golden`, and all 6 golden files are tagged @Tags(['golden']) (884 LOC, 24 PNG baselines). The CI log has 0 lines from test/golden. 16 integration_test files (2,781 LOC: robots, 13 flows, performance, store screenshots) are not run by any workflow, because `flutter test` with no path only runs test/. build.gradle.kts:37 configures PatrolJUnitRunner, but no patrol tests or patrol pubspec config exist; only patrol_finders is imported. auto-release.yml:33 sets …
- **Impact:** UI regressions, end-to-end breakage (add investment, then cash flow, then XIRR; ZIP import; app lock) and crash-on-start bugs reach all users within hours, gated only by widget and unit tests. The ~3.6k LOC of golden and integration tests is unmaintained and decaying.
- **Fix:** (a) Run goldens on ubuntu in CI with `flutter test --tags golden` (fonts are already bundled), or delete them. (b) Add a nightly and pre-release job that runs 3 critical integration flows on an Android emulator (reactivecircus/android-emulator-runner) and blocks auto-release on failure. (c) Set rollout_fraction to 0.2, then complete via promote after 48h if Crashlytics crash-free users ≥99.5%. (d) Remove the patrol dependency and the PatrolJUnitRunner config, or actually write patrol tests.

### QA-10 · medium · CSV import can switch date format mid-file; tests only count rows

- **Status:** Confirmed with corrections · effort M · action A25
- **Where:** `lib/features/bulk_import/data/services/simple_csv_parser.dart:142`; `lib/features/bulk_import/data/services/simple_csv_parser.dart:424-439`; `test/features/bulk_import/data/services/simple_csv_parser_test.dart:57-69`
- **Evidence:** _CsvParserSession stores `_detectedDateFormat` (line 142). Each row tries the stored format first, and if that fails it loops through the pattern list ('dd-MM-yyyy' before 'MM-dd-yyyy', 'dd/MM/yyyy' before 'MM/dd/yyyy') and replaces the stored format with the first one that parses (437). For a file with rows '01/02/2024', '12/25/2024', '03/04/2024': row 1 parses dd/MM to 1 Feb, row 2 fails dd/MM and switches to MM/dd (25 Dec), and row 3 becomes 4 Mar. The file is read with two conventions and no warning. The only …
- **Impact:** Users importing years of history (the main onboarding path for this app) can get cash flows silently shifted by months, which changes XIRR, FY attribution and maturity reminders. Indian bank exports are dd/MM and US exports are MM/dd.
- **Fix:** Detect the format in two passes: choose one pattern that parses every row, prefer day-first for en_IN, and prompt the user when the file is ambiguous or no single pattern fits. Assert exact DateTime values per row, including a US-format file whose first rows have day ≤12.
- **Verifier:** I reproduced it with the real intl 0.20.2 DateFormat.parseStrict and the parser's pattern order (simple_csv_parser.dart:82-100, 424-439). '01/02/2024', '12/25/2024', '03/04/2024' parse to 2024-02-01 (dd/MM), 2024-12-25 (switches to MM/dd) and 2024-03-04. A worse case the reviewer missed: in a consistently US-format …

### QA-16 · medium · Guest-account cleanup function cannot be deployed, and the account-deletion job the rules describe does not exist

- **Status:** Confirmed with corrections · effort M · action A02, A36
- **Where:** `functions/src/cleanupAnonymousUsers.ts:1-30`; `firebase.json:1-5`; `docs/ANONYMOUS_AUTH_GUEST_MODE.md:48`
- **Evidence:** functions/ contains a single TS file (208 lines, 'Runs daily at 2 AM UTC. Deletes anonymous users inactive for 30+ days') with no package.json, no tsconfig and no `functions` entry in firebase.json, so `firebase deploy` cannot ship it. The guest-mode doc marks 'Orphaned anonymous users | ✅ Accepted | Cloud Function cleanup (30 days)' (48) while its own checklist leaves '[ ] Cloud Function deployed' unticked (245). firestore.rules:12 says deletion requests are processed 'by the daily GitHub Actions job with the …
- **Impact:** Guest users who uninstall leave financial data in Firestore indefinitely, which conflicts with any 'deleted after inactivity' wording. If the planned web deletion link (needed for Play's account-deletion requirement) goes live before the job exists, requests will sit unprocessed.
- **Fix:** Finish APP-331 as one scheduled Admin-SDK GitHub Actions job (WIF) that processes deletionRequests and purges anonymous users inactive for more than N days across AccountDataDeletionService.userCollections. Add emulator tests, delete functions/ (or make it a real Functions package), and state the guest-data retention period in the privacy policy.
- **Verifier:** functions/src/cleanupAnonymousUsers.ts (208 lines) is the only file under functions/. There is no package.json or tsconfig, and firebase.json has no `functions` key, so it cannot be deployed from this repo. ANONYMOUS_AUTH_GUEST_MODE.md:48 marks cleanup as 'Accepted', while its checklist at :245 is unticked. Guest mode …

### QA-04 · low · The last two Play releases shipped stale July developer notes as 'What's new'

- **Status:** Confirmed (reviewer said medium) · effort S · action A54
- **Where:** `release.yaml:23`; `CHANGELOG.md:3-13`; `android/fastlane/metadata/android/en-US/changelogs/274.txt:1-6`
- **Evidence:** release.yaml:23 `release_notes: CHANGELOG.md`. No workflow updates CHANGELOG.md any more: its '[Unreleased]' block (lines 3-13) still lists July items. I downloaded the GitHub release assets invtrack-3.72.0-...whatsnew.txt and the v3.71.0 equivalent. Both read verbatim: '⚡ Performance - Replace O(N log N) sort with O(N) bounded list scan in FY report (#556) 🐛 Bug Fixes - Resolve merge conflict artifacts and localization issues - auth: Correct exception throwing in Google SignIn handler (#546) - Skip transient …
- **Impact:** Every Play user sees the same meaningless engineering text on each update. This is wasted space for retention and ratings, and it hides the privacy and deletion fixes that build trust. Release notes will stay wrong until someone remembers to edit CHANGELOG.md.
- **Fix:** Keep a user-facing `release-notes/en-US.txt` (≤500 chars, plain language) and point release_notes to it. Make the PR template require an entry for user-visible feat/fix, and add a CI check that fails when feat/fix commits since the last tag exist but the notes file did not change. Alternatively, restore git-cliff with cliff-playstore.toml in the release job. Delete docs/CHANGELOG.md, and remove cliff*.toml if unused. Remove the root CHANGELOG.md '[Unreleased]' block once it is no longer the Play source.

### QA-05 · low · bulkDelete still leaves cash flows orphaned when offline; archive, unarchive, bulkDelete and bulkImport have no tests

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A23
- **Where:** `lib/features/investment/data/repositories/firestore_investment_repository.dart:527-579`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:249-293`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:179-245`
- **Evidence:** deleteInvestment (249-293) was fixed to throw NetworkException rather than orphan cash flows ('Deleting the investment without knowing which cash flows to remove would silently orphan them forever - a real data-deletion bug'). bulkDelete (527-579) still does `} on TimeoutException { // Continue without cash flows - they'll be orphaned but filtered out` (552-553) and then deletes the investments. bulkDelete is called from the multi-select delete (investment_notifier.dart:406) and sample_data_service.dart:476. The …
- **Impact:** A user who multi-selects investments and deletes them on a bad connection gets 'deleted' feedback, while their cash flows (financial PII) stay in Firestore until account deletion. This is the same class of bug the team already treated as critical for single delete. Archive and unarchive regressions, such as losing a cash-flow field or leaving half-moved data, would not be …
- **Fix:** Make bulkDelete reuse _getCashFlowDocsForDeletion and fail before deleting anything, which takes a few lines. Add mocktail tests for bulkDelete and archive/unarchive that mirror the deleteInvestment group. Treat this as hardening, not an urgent data-loss fix.
- **Verifier:** The code smell is real. bulkDelete (firestore_investment_repository.dart:527-579) catches TimeoutException with a comment that cash flows will be orphaned, and then deletes the investments anyway. deleteInvestment instead throws NetworkException (249-293). The repository test file has groups only for deleteInvestment …

### QA-06 · low · Report CSV/PDF export is unreachable dead code, typed `dynamic`, and reads fields that do not exist

- **Status:** Confirmed with corrections (reviewer said medium) · effort M · action A60, A66
- **Where:** `lib/features/reports/presentation/widgets/report_export_button.dart:17`; `lib/features/reports/presentation/providers/report_export_providers.dart:61-140`; `lib/features/reports/data/services/report_csv_exporter.dart:23`
- **Evidence:** `ReportExportButton` is declared (report_export_button.dart:17) but no other file in lib/ instantiates it, and reportExportProvider, csvExporterProvider and pdfExporterProvider are not referenced outside their own files. The exporters take `dynamic report`. I compared the accessed names against the entity classes. WeeklySummary is missing weekStart, totalReturned, dailyCashflows and topPerformers (the entity has periodStart, totalReturns, dailyCashFlows, topPerformer). FYReport is missing fyYear, totalReturned and …
- **Impact:** About 1,000 LOC and the pdf dependency ship in the APK with no user value. The README and marketing describe 'PDF/CSV export' of reports. Wiring the button up as is would throw NoSuchMethodError for 6 of 8 report types, which shows up as a generic error snackbar.
- **Fix:** Delete the exporters, providers, button, report_export_service and the pdf dependency, or rebuild them later with typed per-report methods and a CSV snapshot test for each ReportType. Enable avoid_dynamic_calls at least for lib/features/reports.
- **Verifier:** The dead code is confirmed. No file outside their own references ReportExportButton, reportExportProvider, csvExporterProvider or pdfExporterProvider. package:pdf is imported only by report_pdf_exporter.dart. The exporters use dynamic access to names that do not exist on the entities: report.weekStart, …

### QA-09 · low · XIRR tests accept ±1-2 percentage points or bare ranges, and nothing checks the solver's silent non-root fallbacks

- **Status:** Confirmed (reviewer said medium) · effort S · action A19
- **Where:** `test/core/calculations/xirr_solver_test.dart:20`; `test/core/calculations/xirr_solver_test.dart:116-117`; `test/core/calculations/xirr_solver_test.dart:227-228`
- **Evidence:** Typical assertions are `closeTo(0.10, 0.01)`, `closeTo(0.10, 0.02)`, `greaterThan(0)` with `lessThan(0.5)` for a 12-month SIP, and `greaterThan(0.05)` with `lessThan(0.10)` for the 'Recurring Deposit ... 7% annual return' case. That case's exact XIRR is 6.4979% (computed independently, and the solver returns 0.06497938). financial_calculator_test.dart:22 says 'Let's rely on the solver's consistency' and comments 'approx 13.06%' while asserting 0.1343, so the expected value was copied from the solver. I ran the …
- **Impact:** A day-count or solver regression of up to 100-200 bp would pass CI. Users with unusual flows (an early large payout, total loss) see a CAGR-style approximation or 0.0% labelled 'XIRR' with no warning.
- **Fix:** Tighten the expected values to the exact figures above with a tolerance of 1e-6. Add an NPV-residual property test. Make the solver return null, or a flagged approximate result, instead of 0.0 or a CAGR approximation when no root is found. Make the Newton acceptance test relative to Σ|CF|.
- **Numeric check:** Independent Python bisection with days/365: RD (12×-10,000 monthly from 2023-01-01, +124,200 on 2024-01-01) = 0.0649794, and the shipped solver gives 0.06497938. SIP with +130,000 = 0.1566984, and the solver gives 0.15669835. The 3-flow case -1000, -1000, +2200 = 0.1343767, and the test asserts 0.1343 ±0.001, which …

### QA-11 · low · Automated agent PRs ('⚡ Bolt', '🛡️ Sentinel', '🎨 Palette') change financial code and get merged without verification

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A19
- **Where:** `lib/features/reports/data/services/fy_report_service.dart:61`; `.jules/bolt.md:1-20`; `lib/features/security/presentation/providers/security_provider.dart:13-19`
- **Evidence:** There are 10 'Bolt' annotations in lib/, and one of them (fy_report_service.dart:61) introduced QA-01. Commit d8d81a7 '🛡️ Sentinel: [CRITICAL] Fix encryptedSharedPreferences for Android (#693)' added `encryptedSharedPreferences: true`. The analyzer now reports it as deprecated and says it 'will be ignored' (security_provider.dart:16), so the 'critical fix' does nothing. Commit 373c909 'No PR created. Relevant fixes are already covered by existing remote branches. (#681)' was merged. CHANGELOG.md repeats entries …
- **Impact:** Micro-optimisations with no measured benefit change money logic without boundary tests, and noisy 'CRITICAL' labels make real security work hard to see. Release notes are generated from this stream (see QA-04).
- **Fix:** Revert the no-op encryptedSharedPreferences flag. Require bot PRs that touch lib/core/calculations or */data to add a test that fails before the change, or restrict bots from those paths. Filter bot and chore commits out of release notes (see QA-04). CODEOWNERS is optional for a single maintainer.
- **Verifier:** The process facts hold. There are 10 'Bolt' annotations in lib/. d8d81a7 '🛡️ Sentinel: [CRITICAL] Fix encryptedSharedPreferences' re-added `encryptedSharedPreferences: true`, reverting an earlier removal. flutter_secure_storage 10.2.0's AndroidOptions marks that parameter @Deprecated with the note 'Remove this …

### QA-12 · low · Dependencies: 6 unused packages, a beta file_picker with an outdated justification, a deprecated secure-storage option, and Flutter 9 minors behind

- **Status:** Confirmed (reviewer said medium) · effort M · action A66
- **Where:** `pubspec.yaml:41`; `pubspec.yaml:48`; `pubspec.yaml:56`
- **Evidence:** Packages imported nowhere in lib/ or test/: dio (lib=0; only http is used, in 1 file), rxdart, encrypt (last published 2023-09), excel (last published 2024-08; it pins archive ^3.6.1 and blocks archive 4.3.0), cupertino_icons (0 CupertinoIcons uses) and patrol (only patrol_finders is used). file_picker is locked at 12.0.0-beta.2 with the comment 'Beta required due to win32 ^6.0.1 dependency conflict'. pub.dev shows file_picker 13.1.0 (2026-09-15) has no win32 dependency and needs Flutter ≥3.38.0, which CI already …
- **Impact:** Shipping a pre-release file picker in a finance app, larger APK and attack surface, and a growing upgrade cliff (Flutter, Firebase and Riverpod majors) for a solo maintainer. A future Play target-API bump will force a rushed jump of several versions.
- **Fix:** Remove dio, rxdart, encrypt, excel, cupertino_icons and patrol, plus google_mobile_ads until monetisation is real. Move to file_picker ^13.1.0 and delete the comment. Remove the deprecated AndroidOptions flag. Set `flutter: '>=3.38.0'`. Then do one major upgrade per PR: Flutter 3.47, flutter_secure_storage 11, go_router 18, flutter_local_notifications 22, Riverpod 4. Add a monthly `flutter pub outdated` report job (Dependabot does not support pub well, so use a scheduled workflow).

### QA-13 · low · CI supply chain: production rules deploy runs `firebase-tools@latest` with the admin service account; also `curl -k`, unpinned reusable workflows and no lockfile

- **Status:** Confirmed with corrections (reviewer said medium) · effort S · action A38
- **Where:** `.github/workflows/deploy-firestore-rules.yml:21-27`; `.github/workflows/ci.yml:160`; `.github/workflows/release.yml:30-35`
- **Evidence:** deploy-firestore-rules.yml:27 runs `npx --yes firebase-tools@latest deploy --only firestore:rules --project invtracker-b19d1` after authenticating as admin-bot@invtracker-b19d1 through WIF (lines 21-25). It has no `needs:` on the rules tests and no environment protection. ci.yml:160 calls `curl -k` to post to Slack, which turns off the TLS verification the same file forbids for app code (lines 66-72). release.yml and auto-release.yml call `ravitejakamalapuram/release-platform/...@v2`, a mutable tag, with `secrets: …
- **Impact:** A compromised or broken firebase-tools release runs with production admin rights. A broken rules file can be deployed from main without the emulator tests passing, which could lock every user out or open data. Test results are not reproducible.
- **Fix:** Pin firebase-tools to an exact version that supports WIF (e.g. 14.x.y), add a `production` environment with a required reviewer to the rules deploy, commit scripts/account-deletion/package-lock.json and use `npm ci`, and drop `-k`. Pinning reusable workflows to a SHA is optional, since you own that repo.
- **Verifier:** The facts hold. deploy-firestore-rules.yml:27 runs `npx --yes firebase-tools@latest` after WIF auth as admin-bot@invtracker-b19d1, with no `needs:` and no environment protection. ci.yml:160 uses `curl -k`. release.yml and auto-release.yml call release-platform@v2 with `secrets: inherit`. deletion-job-tests.yml:45 runs …

### QA-14 · low · docs/ is 97 mostly AI-generated status files (1.4 MB), and CodeRabbit's knowledge base is fed a spec for an architecture that does not exist

- **Status:** Confirmed (reviewer said medium) · effort M · action A68
- **Where:** `docs/InvTracker_TechSpec.md:3-8`; `docs/InvTracker_PRD.md:14`; `docs/InvTracker_PRD.md:339`
- **Evidence:** InvTracker_TechSpec.md describes 'SQLite local DB / Google Sheets + Google Drive API'. The PRD says 'Privacy-first: Your data stays in your own Firebase account' (line 14) and 'Local DB (Drift) → Sync Queue → Google Sheets API' (339). Both are listed in .coderabbit.yaml knowledge_base (lines 378-379), so the AI reviewer is given the wrong architecture. TEST_COVERAGE_SUMMARY.md documents 23 tests under test/features/app_update/**, which do not exist. PLAYSTORE_AUTOMATION_KT.md, VERSION_UPDATE_TROUBLESHOOTING.md and …
- **Impact:** Contributors and AI reviewers make decisions from false architecture and stale status. The real living docs (bulk import, localization, store listing) are hard to find. The public repo shows outdated privacy claims.
- **Fix:** Delete the status, PR and sprint reports: CODERABBIT_FIXES_2026_04_09, CODERABBIT_RE_REVIEW_REQUEST, CODERABBIT_TEST_CHECKLIST, CODE_REVIEW_PORTFOLIO_HEALTH, COMPREHENSIVE_REVIEW_2026_04_09, ENGINEERING_REVIEW_REPORT, EXECUTIVE_SUMMARY, EXHAUSTIVE_REVIEW_CHECKLIST, FINAL_DELIVERY_SUMMARY, FINAL_EXHAUSTIVE_REVIEW_100PCT, IMPLEMENTATION_COMPLETE, INNOVATION_SUMMARY, MIGRATION_ANALYSIS, MIGRATION_PR_SUMMARY, MULTI_CURRENCY_{AUDIT_REPORT,FINAL_PR_SUMMARY,IMPLEMENTATION_SUMMARY,UI_UPDATE_SUMMARY,STATS_FIX_PLAN}, OPTIMIZATION_SUMMARY, PR_342_CRITICAL_ISSUES_SUMMARY, PR_BODY_PORTFOLIO_HEALTH, PR_FIXES_SUMMARY, …

### QA-15 · low · README for a public repo claims an MIT licence with no LICENSE file, and has broken links and outdated facts

- **Status:** Confirmed (reviewer said medium) · effort S · action A68
- **Where:** `README.md:7`; `README.md:9`; `README.md:38`
- **Evidence:** The repo is public (GitHub API: visibility 'public', license null), yet README.md:9 and :259 link to a LICENSE file that does not exist. Broken links: TODO.md (217) and docs/CODERABBIT_FEATURES.md (244). Prerequisites say 'Flutter 3.32 or higher / Dart 3.0 or higher' (80-81), but pubspec requires Dart ^3.10.1, i.e. Flutter ≥3.38, and CI uses 3.38.4. The rules snippet (107-120) includes an `appConfig` read rule that is not in firestore.rules and that no lib code uses, and it omits deletionRequests. '868+ unit …
- **Impact:** Legal ambiguity: anyone can fork the code but nobody can tell what terms apply. Contributors who follow the README setup fail at `pub get`. Marketing claims ('AI-powered', 'OWASP MASVS Compliant', 'WCAG compliant') have no backing.
- **Fix:** Decide on a licence. Either add a LICENSE file (MIT as claimed, or a source-available or proprietary notice if the founder does not want commercial forks) or remove the badge. Replace the rules snippet with a link to firestore.rules. Set prerequisites to Flutter 3.38+. Embed the 5 Play screenshots and a Play badge. Change 'AI-powered' to 'trend-based'. Remove unverified compliance claims or link to evidence. Drop the hard-coded test count or generate it in CI.

### QA-17 · low · Version numbers disagree across pubspec, product.yaml, tags and the listing

- **Status:** Confirmed · effort S · action A68
- **Where:** `pubspec.yaml:21`; `pubspec.yaml:25`; `.appforge/product.yaml:56`
- **Evidence:** pubspec.yaml:21 says `version: 3.70.18+274` and product.yaml says `current_version: "3.70.18+274"`, while GitHub tags show v3.71.0 (2026-09-30) and v3.72.0 (2026-10-01). release-platform computes the version from tags and passes --build-name/--build-number (release.yaml:17-20), so pubspec is only cosmetic. The listing says 3.6.0. The last pubspec bump commit is '5b05168 chore(release): v3.70.18 [skip-release]' from 2026-07-12.
- **Impact:** Local and debug builds report an older versionCode than Play, so sideloaded upgrade tests fail. Support conversations ('which version are you on?') and analytics get confusing.
- **Fix:** Either have the release job commit the bumped pubspec version, or set pubspec to a placeholder (`0.0.0+1`) with a comment that tags are the source of truth. Remove current_version from product.yaml or have the release update it. See QA-02 for the listing.

### QA-18 · low · Repo clutter: two fastlane trees, folders for unsupported platforms, orphaned scripts and stale config files

- **Status:** Confirmed · effort S · action A68
- **Where:** `fastlane/metadata/android/en-US/changelogs/251.txt`; `android/fastlane/Fastfile:1-60`; `.appforge/product.yaml:8`
- **Evidence:** Root fastlane/ holds only changelogs 251-268, while android/fastlane holds 1-249, 272 and 274, and release.yaml uses only android/fastlane. android/fastlane/Fastfile has legacy supply lanes that nothing calls. product.yaml says `platform: [android]`, yet linux/, macos/, windows/ and web/ (about 2.4 MB, 124 files) plus web, macos and windows FirebaseOptions and launcher-icon generation remain. The 6 .github/scripts/* Jules crash-fix scripts are referenced by no workflow, and scripts/setup-*runner*.sh configures …
- **Impact:** Maintenance drag and confusion about which files are live. Each Flutter upgrade has to migrate 4 unused platform runners, and the duplicated fakes drift apart.
- **Fix:** Delete root fastlane/, the Fastfile (or note that it is legacy), linux/, macos/, windows/ and web/ (keep ios/ only if iOS is on the roadmap), the web, macos and windows entries in firebase_options.dart and flutter_launcher_icons, .github/scripts/*, scripts/setup-*runner*.sh, app-metadata.json, cliff*.toml and the legacy client_secret JSON. Move the shared fakes to test/support/ and import them from integration_test.

### QA-19 · low · Skipped, trivial and self-referential tests: active/archived separation tests are skipped and some tests assert nothing useful

- **Status:** Confirmed · effort S · action A64
- **Where:** `test/features/investment/presentation/providers/investment_stats_provider_test.dart:353-433`; `test/features/settings/presentation/providers/currency_switch_provider_test.dart:161`; `test/core/analytics/analytics_service_test.dart:5-19`
- **Evidence:** 4 tests are skipped in the run. 3 of them ('should use correct collection for each provider type', 'multiCurrencyInvestmentStatsProvider should not find archived cash flows', 'archivedInvestmentStatsProvider should not find active cash flows') carry `skip: 'TODO: Fix async stream-to-future timing issue'`, and 1 has `skip: 'Timer-based tests are flaky'`. analytics_service_test only compares string constants. crashlytics_service_test asserts `expect(CrashlyticsService, isNotNull)` and imports mockito, which is only …
- **Impact:** The skipped tests guard against archived cash flows leaking into active stats, which would be wrong totals, and they have been switched off. Test names promise behaviour that is not checked, giving false confidence.
- **Fix:** Fix the skips by overriding cashFlowsByInvestmentProvider directly or using `container.listen` plus `await container.read(p.future)`, and use fakeAsync for the debounce. Make the timezone tests assert the resolved tz.local.name. Delete the constant-only and isNotNull tests. Switch crashlytics_service_test to mocktail. Move benchmarks to a `benchmark` tag that is excluded from CI.

### QA-20 · low · Lint configuration is lenient: base flutter_lints only, no strict type modes, avoid_dynamic_calls off, infos not fatal

- **Status:** Confirmed · effort M · action A67
- **Where:** `analysis_options.yaml:10`; `analysis_options.yaml:12-27`; `analysis_options.yaml:34-65`
- **Evidence:** The analyzer passes with 2 issues: 0 errors, 0 warnings and 2 infos (deprecated_member_use at lib/features/security/presentation/providers/security_provider.dart:16:7 and depend_on_referenced_packages at test/core/crashlytics/crashlytics_service_test.dart:8:8). The config only adds 12 rules to flutter_lints. `avoid_dynamic_calls`, the prefer_const_* rules and always_use_package_imports are commented out ('would require significant refactoring'). There is no `strict-casts`, `strict-inference` or `strict-raw-types`, …
- **Impact:** Whole classes of runtime bugs pass analysis, such as the dynamic field access in QA-06, unchecked `as` casts in Firestore mappers, and dropped Futures in notifiers.
- **Fix:** Enable `analyzer: language: {strict-casts: true, strict-inference: true, strict-raw-types: true}` and the rules avoid_dynamic_calls, unawaited_futures, discarded_futures (lib only), cancel_subscriptions (already on) and always_use_package_imports. Start with a baseline: fix data-layer and reports files first and use `// ignore_for_file` temporarily elsewhere. Make deprecated_member_use fatal in CI.

### QA-21 · low · Public product.yaml admits privacy-policy and deletion gaps, and is now partly out of date

- **Status:** Confirmed · effort S · action A02, A68
- **Where:** `.appforge/product.yaml:24-30`; `.appforge/product.yaml:58-75`; `lib/features/settings/data/services/account_data_deletion_service.dart:54-65`
- **Evidence:** In the public repo, product.yaml notes say 'The LIVE Play Store privacy policy currently understates data collection (says local SQLite + Sheets sync...)' and 'Account deletion is incomplete: expectedCashFlows and document metadata are not deleted'. AccountDataDeletionService.userCollections (54-65) now includes 'expectedCashFlows' and 'documents', so the second statement is stale. The file also references a private path '~/git-personal/.claude/invtrack-privacy/FINDINGS.md' and 'Three inconsistent support emails'.
- **Impact:** Anyone, including Play reviewers, can read the developer's own record of compliance gaps, some of which are already fixed, which adds unnecessary regulatory and reputational exposure.
- **Fix:** Update the notes to the current state (deletion fixed by #710/#720), track remaining gaps as private issues, and keep internal compliance notes out of the public repo, or make the repo private if open-sourcing is not intended (see QA-15).

## GAP1 · Archive semantics: archived investments vanish from all money totals, goals, FIRE and FY/tax report

### GAP1-01 · high · Archiving removes an investment's whole history from every lifetime total (Overview 'Net Position (All)', Realized P&L, YoY, FIRE, Health, reports), but the dialog says it only hides it

- **Status:** Not independently verified · effort M · action A17
- **Where:** `lib/features/investment/data/repositories/firestore_investment_repository.dart:179-211`; `lib/features/investment/presentation/providers/investment_providers.dart:119-126`; `lib/features/investment/presentation/providers/investment_providers.dart:159-194`
- **Evidence:** Archive moves the investment and all of its cash flows into users/{uid}/archivedInvestments and archivedCashflows (repo:179-211). Every aggregate reads only the active collections. validCashFlowsProvider is documented as 'IMPORTANT: Only includes cash flows from NON-ARCHIVED investments' (investment_providers.dart:161). It feeds: multiCurrencyGlobal/Open/ClosedStats (multi_currency_providers.dart:259, 297-298, 362-363); the YoY, 6-month trend, type-distribution and recently-closed providers …
- **Impact:** Worked example. All numbers use the code's own formulas; I checked the arithmetic with python in scratch. An FD is the user's only investment: INVEST ₹1,00,000 on 2024-04-01; INCOME ₹7,000 on 2025-04-01 and on 2026-04-01; RETURN ₹1,00,000 on 2026-04-01. Today is 2026-10-02.

(a) Open:
- Hero: Net Position (All) +₹14,000, +14.0%, out ₹1L / in ₹1.14L, XIRR 7.0%, MOIC 1.14x over …
- **Fix:** Make archive a visibility flag only: it hides the item from lists and reminders, and history still counts.
1. Repository: add `watchAllArchivedCashFlows()` on _archivedCashFlowsRef.
2. Providers: add `lifetimeInvestmentsProvider` = allInvestmentsProvider ∪ archivedInvestmentsProvider, and `lifetimeCashFlowsProvider` = allCashFlowsStreamProvider ∪ allArchivedCashFlowsStreamProvider. Both must propagate loading and error, not substitute [].
3. Switch the historical aggregates to the lifetime providers: global stats, closed stats (classify archived items by their status), YoY, trend, recently closed, FY, …

### GAP1-02 · high · Archiving a linked investment silently drops goal progress, often to 0% / 'Not Started', with no warning or cleanup

- **Status:** Not independently verified · effort M · action A17
- **Where:** `lib/features/goals/presentation/providers/goal_progress_provider.dart:96-112`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:208-210`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:357-366`
- **Evidence:** - All four goal-progress providers read activeInvestmentsProvider and validCashFlowsProvider on purpose: '// Use activeInvestmentsProvider to exclude archived investments' (:363-366, 401-404, 568-571, 633-636). Portfolio Health's goal alignment uses the same exclusion.
- `_getLinkedInvestments` filters the active list by linkedInvestmentIds (:107-110), so an archived linked FD simply disappears. The same filtering applies in 'all' and 'byType' modes (:101-106).
- `_determineStatus` returns notStarted whenever …
- **Impact:** Example: goal 'House', corpus target ₹1,50,000, 'selected' mode, linked to the FD from GAP1-01.
- (a) Open and (b) Closed: card '₹1.14L of ₹1.5L', ring 76%, milestone '75% Complete', status On Track, message 'On track for Jul 2027'. The projection comes from velocity 1,14,000 / 31 months = ₹3,677/mo; 36,000 / 3,677 = 9.8 months, giving 2027-07-23.
- (c) Archived: '₹0 of …
- **Fix:** 1. Goals should measure history. Use lifetimeInvestmentsProvider and lifetimeCashFlowsProvider (GAP1-01) in goalProgressProvider, allGoalsProgressProvider, both multiCurrency providers, and in _checkGoalMilestonesAfterCashFlow (which should also read the archived collections).
2. Before archive or delete, find the affected goals: call `getGoalsForInvestment(id)`, plus 'all' goals and 'byType' goals that include the investment's type. If any are found, show: 'Linked to goal "House". Its returns will keep counting toward this goal.'
3. Show 'Linked investments (n)' on goal details, with an Archived chip on …

### GAP1-03 · high · Archived investment detail and archived list cards show native USD/AED amounts under the base-currency symbol

- **Status:** Not independently verified · effort S · action A13
- **Where:** `lib/features/investment/presentation/providers/investment_stats_provider.dart:160-177`; `lib/features/investment/presentation/providers/investment_stats_provider.dart:193-211`; `lib/features/investment/presentation/screens/investment_detail_screen.dart:68-75`
- **Evidence:** - `archivedInvestmentStatsProvider` returns `calculateStats(cashFlows)` on the raw archived cash flows (:172), with no conversion. Compare multiCurrencyInvestmentStatsProvider, which calls batchConvert first (multi_currency_providers.dart:237-244).
- The detail screen says so in a comment: '// Archived investments still use old provider (no currency conversion needed for historical data)' (:69).
- The stats section is formatted with `currencyFormatProvider`, the base-currency symbol (detail screen :75; stats …
- **Impact:** - A US ETF with INVEST $10,000 and RETURN $11,500, base INR at ₹83.5/$, shows Net Position +₹1,25,250 and out ₹8.35L while active.
- After archiving it shows Net Position '₹1,500', out '₹10K', in '₹11.5K': understated 83.5x.
- An AED 50,000 deposit (about ₹22.7/AED) shows '₹50K' instead of about ₹11.35L.
- Sorting the Archived tab by 'Total Invested (High)' puts the $10,000 …
- **Fix:** Convert archived stats the same way active ones are converted:
```dart
final archivedInvestmentStatsProvider = FutureProvider.family<InvestmentStats, String>((ref, id) async {
  final cfs = await ref.watch(archivedCashFlowsByInvestmentProvider(id).future);
  if (cfs.isEmpty) return InvestmentStats.empty();
  final engine = ref.watch(calculationEngineProvider);
  if (!engine.currency.isAvailable) return InvestmentStats.empty();
  final converted = await engine.currency.batchConvert(
      cashFlows: cfs,
      baseCurrency: ref.watch(currencyCodeProvider),
      fallbackStrategy: …

### GAP1-04 · medium · Archive is the only lasting way to declutter closed items and is one swipe away, so users are steered into the GAP1-01 and GAP1-02 data loss

- **Status:** Not independently verified · effort S · action A17
- **Where:** `lib/core/widgets/swipe_actions.dart:60-61`; `lib/core/widgets/swipe_actions.dart:203-219`; `lib/features/investment/presentation/screens/investment_list_screen.dart:430-451`
- **Evidence:** - Every card in the active list supports swipe-right to Archive ('Swipe right to archive/unarchive', swipe_actions.dart:61; list screen :430-451).
- The confirm dialog is non-destructive and only says the item 'will be hidden'.
- The swipe handler fires `onArchive()` without awaiting it and shows the 'Investment archived' success message regardless of the outcome (:212-216).
- Closed items stay in the default tab: `filter = InvestmentFilter.all` (:22), and `build() => const InvestmentListState()` (:56) is not …
- **Impact:** Indian FD and P2P investors pile up matured FDs and repaid loans every year, and the natural tidy-up gesture silently removes their realized interest from Overview, goals, FIRE and reports. Example: 12 matured ₹1L FDs at 7% for 2 years means ₹1,68,000 of realized interest leaves 'Net Position (All)', and the user watches goals regress. That breaks the core lifetime XIRR/MOIC …
- **Fix:** Separate 'closed' from 'hidden':
1. Save the list filter in SharedPreferences, or add a 'Hide closed' toggle.
2. Rename Archive to 'Hide from list' and adopt the GAP1-01 semantics.
3. If the exclusion is kept, take swipe-to-archive off closed rows and show the quantified impact before confirming.
4. Add a `status` parameter to logInvestmentArchived so the founder can measure whether archives are mostly of closed items.

### GAP1-05 · medium · When every investment is archived, Overview shows the first-run empty state and logs empty_state_viewed

- **Status:** Not independently verified · effort S · action A17
- **Where:** `lib/features/overview/presentation/screens/overview_screen.dart:103-122`; `lib/features/overview/presentation/screens/overview_screen.dart:257-265`; `lib/features/investment/presentation/screens/investment_list_screen.dart:357-373`
- **Evidence:** - Overview picks its content from `stats.hasData` of the active-only multiCurrencyGlobalStatsProvider (:104). With no data it builds `_buildEmptyStateContent`, which shows OverviewEmptyState ('add first investment', 'import CSV', 'try sample data') and logs 'empty_state_viewed' (:258-264).
- The Investments list handles this correctly with `hasAnyInvestments = counts.all > 0 || counts.archived > 0` (:359).
- **Impact:** A user who archived every matured FD, for example between FD ladders, sees ₹0, 'XIRR 0.0%' and onboarding CTAs, including 'Try sample data', on Home. Meanwhile the Investments tab shows N archived items. Analytics count this user as an empty-state user, which pollutes the activation funnel.
- **Fix:** Gate the empty state on investmentCountsProvider (all plus archived), as the list screen does. With GAP1-01 in place the hero would show lifetime totals. Otherwise show a card: 'All your investments are archived; totals exclude archived items' with a link to the Archived tab.

Widget test: seed only archived investments and expect no OverviewEmptyState.

### GAP1-06 · medium · GoalEntity == ignores linkedInvestmentIds and linkedTypes, so goal details and Goals-tab cards keep stale progress after the user edits the links

- **Status:** Not independently verified · effort S · action A12
- **Where:** `lib/features/goals/domain/entities/goal_entity.dart:217-247`; `lib/features/goals/presentation/providers/goals_provider.dart:96-107`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:564-571`
- **Evidence:** - GoalEntity's `operator ==` compares id, name, type, targetAmount, targetMonthlyIncome, targetDate, trackingMode, icon, colorValue, isArchived and currency. It omits linkedInvestmentIds and linkedTypes (:218-231).
- The app uses flutter_riverpod 3.0.3. Its elements skip notifying listeners when `previous != next` is false (pub-cache riverpod-3.0.3 lib/src/core/element.dart:350-352, 481-482, 809), and AsyncData equality compares the wrapped value (async_value.dart:24-33, 601-607).
- …
- **Impact:** A user edits 'House' to add a second FD with ₹1,14,000 of returns. The Overview carousel shows 100% / Completed, while the goal details ring and the Goals-tab card stay at 76% until some investment or cash flow changes or the app restarts. The same happens when removing an archived or deleted link, or when changing types in byType mode.
- **Fix:** Include the lists in equality: `listEquals(other.linkedInvestmentIds, linkedInvestmentIds) && listEquals(other.linkedTypes, linkedTypes)`, and use `Object.hashAll` in hashCode.

Tests:
- `expect(g.copyWith(linkedInvestmentIds: ['a']) == g, isFalse)`.
- A provider test where updating the links in the fake repo changes the output of multiCurrencyGoalProgressProvider.

### GAP1-07 · medium · Goal investment selector hides archived and deleted links but still counts them; they cannot be seen or unlinked

- **Status:** Not independently verified · effort S · action A12
- **Where:** `lib/features/goals/presentation/screens/create_goal_screen.dart:70`; `lib/features/goals/presentation/screens/create_goal_screen.dart:499-525`; `lib/features/goals/presentation/screens/create_goal_screen.dart:541-552`
- **Evidence:** - The edit screen preloads `_linkedInvestmentIds = goal?.linkedInvestmentIds` (:70) and shows `'$linkedCount selected'`, where `linkedCount = _linkedInvestmentIds.length` (:500-502, :525).
- The sheet lists only `allInvestmentsProvider`, i.e. active open and closed investments (:131). Archived IDs (and deleted ones, INV-07) are never drawn and cannot be unticked.
- Those IDs are passed back unchanged on Done (`_selectedIds = List.from(widget.selectedInvestmentIds)` :41; :107).
- Closed investments can be selected, …
- **Impact:** A goal linked to FD-A (archived) and FD-B shows '2 selected', but only FD-B is ticked in the sheet. The user cannot see or remove FD-A. If FD-A is later unarchived, its ₹1,14,000 silently re-enters the goal and the progress jumps.
- **Fix:** 1. In the sheet, also watch archivedInvestmentsProvider and render linked archived items under 'Archived (still counted)' with a chip.
2. Compute linkedCount only from IDs that resolve.
3. On save, drop IDs that no longer resolve and show 'Removed 1 deleted investment from this goal'.
4. Show a 'Closed' chip on closed items.

Widget test: the selected count equals the number of visible ticks.

### GAP1-08 · medium · Goal progress providers turn loading and errors into empty data, so users see 0% / 'Not Started' / 'Set your first goal'

- **Status:** Not independently verified · effort S · action A28
- **Where:** `lib/features/goals/presentation/providers/goal_progress_provider.dart:573-591`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:638-654`; `lib/features/goals/presentation/widgets/goal_card.dart:106`
- **Evidence:** - multiCurrencyGoalProgressProvider maps `loading: () async => <InvestmentEntity>[]` and `error: (e, s) async => <InvestmentEntity>[]` for investments, and does the same for cash flows (:581-591).
- The all-goals variant also maps goals in loading or error state to [] (:638-654).
- The result is AsyncData with currentAmount 0 and status notStarted.
- GoalCard falls back to `progress?.status ?? GoalStatus.notStarted` (:275) and a ring value of `?? 0` (:106).
- The dashboard renders 'Set your first goal' when the …
- **Impact:** - Every cold start: users with goals briefly see '₹0 of ₹1.5L, 0%, Not Started, Start investing to make progress', and Overview shows 'Set your first goal' before the real values arrive.
- Any Firestore error (offline with no cache, or a permission error): 0% stays on screen with no error or retry.
- The empty_state_viewed analytics event is logged for users with data.
- **Fix:** Propagate the real states:
- In the FutureProviders, use `if (x.isLoading) return Completer<T>().future; if (x.hasError) throw x.error!;`. This pattern is already used at investment_stats_provider.dart:92-98.
- Or await the stream providers' `.future`.
- In GoalCard, show a skeleton when progress is null instead of 'Not Started'.

Tests:
- With validCashFlowsProvider overridden to AsyncLoading, multiCurrencyGoalProgressProvider isLoading.
- With AsyncError, it hasError.

### GAP1-09 · medium · Goal 'X of Y' text and the Target row show the raw goal-currency target under the base-currency symbol

- **Status:** Not independently verified · effort S · action A12
- **Where:** `lib/features/goals/domain/entities/goal_progress.dart:97`; `lib/features/goals/domain/entities/goal_progress.dart:133-142`; `lib/features/goals/presentation/providers/goal_progress_provider.dart:290-306`
- **Evidence:** - The progress percent uses the target converted to base currency (goal_progress_provider.dart:296-306).
- But `double get targetAmount => goal.targetAmount;` (goal_progress.dart:97) is the raw goal-currency value.
- getProgressMessage prints `'$symbol${current} of $symbol${targetAmount}'` with the base symbol (:141); income goals print the raw targetMonthlyIncome (:138-139).
- The Target row on goal details prints goal.targetAmount with the base symbol (goal_details_screen.dart:341-348).
- The create form has an …
- **Impact:** - Goal 'US college': $20,000 in USD, base INR, linked returns ₹8,35,000. The ring correctly shows 50%, but the text says '₹8.35L of ₹20K' and the Target row says '₹20K'.
- An INR goal of ₹1,50,000, after the user switches base currency to USD: ring 76%, text '$1.4K of $150K'.
- PDF and CSV goal reports repeat the error.
- If PLAN-09/10/11 already cover this, merge it with them.
- **Fix:** 1. Carry the converted target in GoalProgress (e.g. `targetAmountBase`) and use it in getProgressMessage and remainingAmount.
2. On goal details show 'Target $20,000 (≈ ₹16.7L)'.
3. Make the amount-field prefix follow `getCurrencySymbol(_selectedCurrency)`.

Test: goal USD 20,000, base INR, rate 83.5, current ₹8,35,000 must give '₹8.35L of ₹16.7L'.

### GAP1-13 · medium · No test pins what archive does to totals, goals or FIRE; the archived-stats tests pass vacuously

- **Status:** Not independently verified · effort M · action A17
- **Where:** `integration_test/flows/archive_flow_test.dart:20-153`; `test/features/investment/presentation/providers/investment_stats_provider_test.dart:251-272`; `test/features/goals/presentation/providers/goal_progress_multi_currency_test.dart:63`
- **Evidence:** - The archive integration flow only checks list visibility (verifyInvestmentNotDisplayed / Displayed). Its seeds have no cash flows and no goals.
- The archivedInvestmentStatsProvider tests use `loading: () {}`, so they pass without ever asserting data, and they have no currency case. That is how GAP1-03 shipped past a test named 'should calculate stats correctly for archived investment'.
- The separation tests are skipped (QA-19, :392, :413, :430).
- The goal-progress tests seed only `InvestmentStatus.open` …
- **Impact:** The behaviour in GAP1-01, 02, 03 and 06 is unpinned. A refactor could flip it either way without any test failing.
- **Fix:** Add test/features/investment/archive_semantics_test.dart using the FD example (expected values below assume the GAP1-01/02 'archive hides only' fix), checking each value both before and after archive:
- global net 14000, moic 1.14, xirr ≈ 0.07
- closed net 14000
- FIRE corpus 100000
- YoY 107000 / 7000
- 'House' progress 76%
- Health goal-alignment 100

Also add:
- an archived-USD conversion test (net 125250 at 83.5)
- the GoalEntity link-inequality test
- a test that the selector count matches visible ticks
- a test that unarchiving a closed item schedules no reminders

Replace `loading: () {}` with `await …

### GAP1-10 · low · Goal percent rounding differs: the Overview carousel can show '100%' while the Goals tab shows '99%' and the goal is not achieved

- **Status:** Not independently verified · effort S · action A12
- **Where:** `lib/features/goals/presentation/widgets/goal_carousel_card.dart:97-148`; `lib/features/goals/presentation/widgets/goal_progress_ring.dart:57`; `lib/features/goals/presentation/widgets/goal_progress_ring.dart:116`
- **Evidence:** - The carousel badge uses `'${progress.progressPercent.toStringAsFixed(0)}%'` (:140), which rounds half-up.
- The ring uses `value.clamp(0.0, 100.0).toInt()` (:116), which truncates.
- The 'Completed' badge appears only when status == achieved (:97).
- **Impact:** At ₹1,49,400 of ₹1,50,000 (99.6%), the Overview carousel shows '100%' with no Completed badge, while the Goals tab and details ring show '99%'. At 0.6%, the ring shows 0% and the carousel 1%.
- **Fix:** Use one shared formatter, `p >= 100 ? '100%' : '${p.floor()}%'`, everywhere.

Unit test: 99.6 gives '99%'.

### GAP1-11 · low · Unarchiving a closed investment re-schedules income and maturity reminders

- **Status:** Not independently verified · effort S · action A17
- **Where:** `lib/features/investment/presentation/providers/investment_notifier.dart:305-334`; `lib/features/investment/presentation/providers/investment_notifier.dart:217-244`; `lib/core/notifications/handlers/investment_notification_handler.dart:323`
- **Evidence:** - unarchiveInvestment schedules income and maturity reminders whenever incomeFrequency or maturityDate is non-null (:314-321), without checking status.
- closeInvestment cancels both (:227-229).
- rescheduleAllNotifications skips anything not open (`if (!investment.isOpen) continue;`, handler :323). It does not cancel stale reminders either, so a wrongly scheduled one survives the next launch.
- **Impact:** A closed annual-interest FD that is archived and later unarchived gets a new 'income due' reminder about 12 months after its last INCOME (around 2027-04-01 in the example), for money that will never arrive.
- **Fix:** Wrap the scheduling in `if (investment.status == InvestmentStatus.open) { ... }`.

Test: with a mock notification service, unarchiving a closed investment never calls scheduleIncomeReminder.

### GAP1-12 · low · 'Recently Closed' is sorted by updatedAt, so an unarchived or edited old item jumps to the top

- **Status:** Not independently verified · effort S · action A17
- **Where:** `lib/features/investment/presentation/providers/investment_analytics_provider.dart:36-56`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:157-165`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:186-187`
- **Evidence:** - The ranking uses `i.updatedAt.isAfter(recentClosed[j].updatedAt)` (:41).
- closedAt exists and is set when an investment is closed (repo :161).
- Archive and unarchive bump updatedAt (:187, :222), and so does any edit.
- **Impact:** An FD closed in 2024 that is archived and unarchived, or merely renamed, is shown above one closed last week.
- **Fix:** Sort by `closedAt ?? updatedAt`.

Unit test: two closed items with an unarchive in between keep their order.

## GAP2 · Money stored without a currency (FIRE settings et al.) and the base-currency switch end to end

### GAP2-01 · high · FIRE settings store money with no currency; a base-currency switch, a restore or a second device reads Rs 50,000/month as $50,000/month

- **Status:** Not independently verified · effort M · action A11
- **Where:** `lib/features/fire_number/data/models/fire_settings_model.dart:8`; `lib/features/fire_number/data/models/fire_settings_model.dart:11-30`; `lib/features/fire_number/data/models/fire_settings_model.dart:34-63`
- **Evidence:** fire_settings_model.dart:11-30 writes 'monthlyExpenses', 'monthlyPassiveIncome' and 'expectedPension' with schemaVersion 1 and no currency key. fromFirestore (:34-63) never reads schemaVersion, so there is no migration hook. The entity has no currency field, and its toJson (:296-316) has none either. The default is `monthlyExpenses: 50000, // ₹50K default for India` (:199). fire_providers.dart:70-72 takes the portfolio from multiCurrencyGlobalStatsProvider, which batch-converts every cash flow to …
- **Impact:** Python replica of calculate(), scratchpad GAP2/fire.py. Assumptions: FX 88 INR/USD; setup defaults of age 30 to 45, SWR 4%, inflation 6%, return 12% (real 5.6604%), healthcare 20%, emergency 6 months, Regular; portfolio = converted totalInvested; cash flows span 60 months. (a) INR user switches to USD (Rs 50,000/month, portfolio Rs 60,00,000, savings Rs 1,00,000/month). …
- **Fix:** 1) Add `final String currency` to FireSettingsEntity, toFirestore, fromFirestore, toJson and the import path, and bump currentSchemaVersion to 2. On every write, stamp currency = the value already on the entity, or else ref.read(currencyCodeProvider) at write time; never fall back to 'USD'. Legacy documents with no currency: interpret them as the device base currency (today's behaviour), do not auto-persist, and show a one-time chip on the FIRE dashboard ('Your monthly expenses Rs 50,000: is this in INR?'); stamp the currency on confirm or on the next save. Read schemaVersion in fromFirestore. 2) Convert on read …

### GAP2-02 · high · Backup ZIP carries no base currency and no FIRE or investment currency; a restore reinterprets FIRE, resets investment currency to USD and drops investment metadata

- **Status:** Not independently verified · effort M · action A24
- **Where:** `lib/features/settings/data/services/data_export_service.dart:194-210`; `lib/features/settings/data/services/data_export_service.dart:358-386`; `lib/features/settings/data/services/data_export_service.dart:258-283`
- **Evidence:** Export: fire_settings.json is `jsonEncode(fireSettings.toJson())` (:194-210), and toJson has no currency. metadata.json (:368-386) holds only version, exportedAt, files and documents, with no baseCurrency. cashflows.csv carries only 'Investment Type' and 'Investment Status' about the investment (:258-283). Import: FireSettingsEntity is rebuilt with `monthlyExpenses: (fireSettingsJson['monthlyExpenses'] as num).toDouble()` (:269-272) and saved with saveSettings (:312) in BOTH merge and replace mode. The doc comment …
- **Impact:** A USD-base user (FIRE $4,000/month, $100,000 invested, 3 FDs with maturity dates) moves phones as a guest and imports the ZIP with Replace. Cash flows convert correctly because each row has a Currency, but the FIRE dashboard jumps from 6.83% to 601% 'FIRE Achieved!' (GAP2-01 case b). Every restored investment is labelled USD; an INR FD shows USD preselected in its edit screen …
- **Fix:** 1) metadata.json: add 'schemaVersion': 2 and 'baseCurrency': <currencyCodeProvider>. fire_settings.json: add 'currency'. 2) Import: resolve the FIRE currency in this order: fire_settings.json currency, then metadata baseCurrency, then ask the user (default = device base); never 'USD'. If the backup's baseCurrency differs from the device base, prompt 'This backup was made in USD. Switch base currency to USD?'. 3) Export an investments.json (or investments.csv) with every InvestmentEntity field, including currency and maturityDate, and restore from it so the backup is lossless; the CSV columns stay for spreadsheet …

### GAP2-03 · medium · Milestone notifications show amounts in INR whatever the currency, and use unconverted cross-currency sums

- **Status:** Not independently verified · effort S · action A18
- **Where:** `lib/features/investment/presentation/providers/investment_notifier.dart:775-806`; `lib/features/investment/presentation/providers/investment_notifier.dart:835-862`; `lib/core/notifications/notification_service.dart:612-624`
- **Evidence:** _checkMilestoneAfterCashFlow sums raw `cf.amount` into totalInvested/totalReturned whatever cf.currency is (:785-794). It calls checkAndShowMilestone with no currency (:800-806), so the wrapper default `String currency = 'INR'` applies (notification_service.dart:789). The body is 'You've earned $formattedProfit profit' (investment_notification_handler.dart:467-474). Goal milestones use the NON-converted GoalProgressCalculator.calculate (investment_notifier.dart:835; goal_progress_provider.dart:14-49 sums raw …
- **Impact:** USD-base user, single-currency investment: $10,000 invested, $15,000 returned. The notification reads '1.5x Returns Achieved! ... You've earned ₹5,000.00 profit.' Mixed-currency investment ($10,000 invested, ₹8,80,000 repatriated at 88): raw MOIC = 880000/10000 = 88, which fires '10.0x Returns Achieved! You've earned ₹870,000.00 profit'; the true MOIC is 1.0x. Goal in USD, …
- **Fix:** Compute both checks on base-converted data: use multiCurrencyInvestmentStatsProvider(investmentId) for MOIC and profit, and GoalProgressCalculator.calculateMultiCurrency (already used by the UI, goal_progress_provider.dart:254-300) for goals. Pass `currency: ref.read(currencyCodeProvider)`. For income goals, pass targetMonthlyIncome converted to the base currency. Replace _formatCurrency with getCurrencySymbol(code) plus a NumberFormat built with getCurrencyLocale(code), or reuse formatCompactCurrency. Tests: (i) base USD with $10k invested and $15k returned gives a body containing '$5,000'; (ii) a USD goal …

### GAP2-04 · medium · Currency switch is one tap with no disclosure of what converts and what does not; FAQ implies relabelling only

- **Status:** Not independently verified · effort S · action A31
- **Where:** `lib/features/settings/presentation/screens/settings_screen.dart:342-399`; `lib/features/settings/presentation/screens/settings_screen.dart:245-256`; `lib/features/settings/presentation/providers/currency_switch_provider.dart:203-205`
- **Evidence:** A picker ListTile onTap closes the sheet and immediately calls `switchCurrencyDebounced(code)` (settings_screen.dart:394-399), with no confirmation sheet. The provider applies the switch optimistically, before anything else (currency_switch_provider.dart:203-205). On success the only feedback is the snackbar 'Currency switched to {currency}' (settings_screen.dart:253; app_en.arb:2531). The FAQ says 'select from 40+ supported currencies. The app will format all amounts according to your selected currency and …
- **Impact:** An INR user taps USD 'to see my dollar view'. The home FIRE card drops from 32.79% to 0.37% of '$18.3M' with no explanation. Nothing tells the user that FIRE expenses were not converted, that goals keep their own currency, that Add Cash Flow now defaults to USD (CALC-V01), that a second device keeps its own base (PLAT-14), or that CSV exports keep the original per-row …
- **Fix:** Before switching, show a bottom sheet: 'Totals, XIRR, charts and goal progress will be shown in USD using historical rates. Your transactions stay in their original currency. FIRE expenses: Rs 50,000/month [x] convert to $568.18 (1 USD = Rs 88.00). This device only.' Then confirm. After the switch, show a snackbar with 'Undo'. Rewrite the FAQ: '14 base currencies; amounts are converted at historical exchange rates; each transaction keeps its own currency.' Test: a widget test that tapping USD opens the confirmation and that cancelling leaves settings.currency unchanged.

### GAP2-05 · medium · Income Guardian is inert (nothing creates expected cash flows), and its matching and alerts ignore currency

- **Status:** Not independently verified · effort L · action A42
- **Where:** `lib/features/income_projection/domain/repositories/expected_cash_flow_repository.dart:53`; `lib/features/income_projection/domain/repositories/expected_cash_flow_repository.dart:81`; `lib/features/income_projection/data/services/income_guardian_sync_service.dart:186-205`
- **Evidence:** grep for createExpectedCashFlow or bulkCreateExpectedCashFlows across lib/, test/, integration_test/ and functions/src finds only the declarations and the Firestore implementation; there are no callers. ExpectedCashFlowEntity( is constructed only in the repository's fromFirestore and in copyWith, so users/{uid}/expectedCashFlows is never populated. The feature is enabled by default (`this.enabled = true`, settings :19, :68), and the monitor and sync services start anyway. Matching compares raw numbers: …
- **Impact:** Today users who rely on 'smart notifications' for missed interest payments get none, and the Income Guardian card and calendar show only empty states. Once a producer is added, a currency mismatch produces false alarms. Example: expected Rs 10,000, and a USD P2P payout of $115 (= Rs 10,120) is logged on the due date. dateScore 1.0*0.6 = 0.6; amountPercentDiff = …
- **Fix:** Implement the producer. For each open investment with incomeFrequency, generate the next N expected flows (amount = last INCOME amount, or principal*expectedRate/periods) and stamp currency = the last income cash flow's currency, or else the investment's currency. In _calculateMatchScore, convert cashFlow.amount to expectedCashFlow.currency (via BatchCurrencyConverter at cf.date) before comparing, or exclude candidates in a different currency. In alerts, use getCurrencySymbol(currency) and getCurrencyLocale(currency). Until it ships, hide the Income Guardian toggle and card or label them 'coming soon'. Tests: a …

### GAP2-06 · medium · Analytics amount buckets are computed on native transaction amounts with lakh labels and no currency dimension; the FIRE expense bucket never fires

- **Status:** Not independently verified · effort S · action A34
- **Where:** `lib/core/utils/analytics_utils.dart:52-60`; `lib/features/investment/presentation/providers/investment_notifier.dart:417-450`; `lib/core/analytics/analytics_service.dart:482-489`
- **Evidence:** getAmountRange uses INR thresholds with labels '50k_1L', '1L_5L', '5L_10L' and 'over_10L' (analytics_utils.dart:52-60). Its only live caller is addCashFlow: `amountRange: getAmountRange(amount)`, where amount is in the cash flow's own currency (investment_notifier.dart:449). logCashFlowAdded sends only flow_type and amount_range (analytics_service.dart:482-489), with no currency parameter. No setUserProperty call exists outside analytics_service.dart, so base currency is not a user property. The other caller, …
- **Impact:** Buckets mix currencies 88 to 1. A $5,000 entry logs '1k_10k' although it is Rs 4,40,000 (should be '1L_5L'); ¥500,000 logs '5L_10L' although it is Rs 2,95,000 at 0.59 INR/JPY ('1L_5L'); a $600 SIP logs 'under_1k' although it is Rs 52,800 ('50k_1L'). The switch does not rewrite past events, but because Add Cash Flow defaults to the new base (CALC-V01), a user who switches INR …
- **Fix:** Bucket on an INR-equivalent: getAmountRange(amount * rate(cf.currency to INR)) using the cached live rate, and also send 'currency': cf.currency. Set the user property 'base_currency' at startup and on currency_switch_completed. Log fire_setup_completed from the setup screen (call notifier.completeSetup, or log it in saveSettings when isSetupComplete flips to true), bucketing expenses on the INR-equivalent of the FIRE settings currency (GAP2-01). Tests: analytics test that a $5,000 cash flow logs amount_range '1L_5L' with currency 'USD'; setup-screen test that fire_setup_completed is logged once.

### GAP2-07 · low · Goal form prefixes the target with the base-currency symbol, not the goal's currency, so edits after a switch invite an 88x mis-entry

- **Status:** Not independently verified · effort S · action A03
- **Where:** `lib/features/goals/presentation/screens/create_goal_screen.dart:75`; `lib/features/goals/presentation/screens/create_goal_screen.dart:83`; `lib/features/goals/presentation/screens/create_goal_screen.dart:219`
- **Evidence:** `final currencySymbol = ref.watch(currencySymbolProvider);` (:219) is used as prefixText for both Target Amount (:251) and Target Monthly Income (:286). The goal's own currency comes from `goal?.currency` or `ref.read(currencyCodeProvider)` (:75, :83) and is shown in a separate CurrencySelector labelled 'Goal Currency' (:262-275).
- **Impact:** After switching base INR to USD, editing an INR goal of Rs 50,00,000 shows '$ 5000000' next to 'Goal Currency: INR'. A user who corrects the number to 56,818 (thinking it is dollars) saves Rs 56,818, an 88x target cut, and the goal immediately shows as achieved. Stored goal data is otherwise switch-safe; this form is the weak point.
- **Fix:** Use getCurrencySymbol(_selectedCurrency) for both prefixes and rebuild the prefix when the selector changes. Show '≈ $56,818 at today's rate' under the field when _selectedCurrency differs from the base. Widget test: base USD with an INR goal being edited shows a '₹' prefix.

### GAP2-08 · low · Nothing reschedules notifications on a currency switch, and the maturity-reminder body has a latent INR-or-$ symbol rule

- **Status:** Not independently verified · effort S · action A29
- **Where:** `lib/features/investment/presentation/widgets/notification_sync_initializer.dart:92-107`; `lib/core/notifications/handlers/investment_notification_handler.dart:134-142`; `lib/core/notifications/handlers/investment_notification_handler.dart:293-301`
- **Evidence:** NotificationSyncInitializer reschedules only on `ref.listen(allInvestmentsProvider, ...)` (:92-107); nothing listens to currencyCodeProvider, and currency_switch_provider.dart has no notification call. Today no scheduled body contains money. The income reminder is 'Income from $investmentName may be due today' (:98-99). Neither maturity caller passes currentValue or currency (investment_notifier.dart:751-755; rescheduleAll :326-330), so the body is name and date only. Weekly, monthly, tax, check-in and FY bodies …
- **Impact:** No user is affected today: already-scheduled reminders carry no stale amounts after a switch. If someone wires currentValue (the doc comment at :129-133 invites it), an EUR, GBP or AED investment would show '$', amounts would be ungrouped ('Value: ₹1050000'), and a reminder scheduled before an INR to USD switch would still say '₹' up to 7 days later, because nothing …
- **Fix:** Either delete the unused investedAmount, currentValue and currency parameters, or format with getCurrencySymbol(currency) plus a locale-aware NumberFormat in the investment's own currency. Add ref.listen(currencyCodeProvider) in NotificationSyncInitializer to call rescheduleAllNotifications. Add a regression test asserting that scheduled bodies contain no currency symbol, so amounts are only ever rendered at show time.

## GAP3 · Notification opt-out integrity and the unreviewed settings screens (consent, trust, in-app update, prod debug tools)

### GAP3-01 · high · Turning off Income or Maturity reminders leaves alarms already registered with Android in place, and nothing ever cancels them later

- **Status:** Not independently verified · effort M · action A08
- **Where:** `lib/core/notifications/notification_preferences.dart:29-31`; `lib/core/notifications/notification_preferences.dart:36-41`; `lib/core/notifications/notification_service.dart:505-558`
- **Evidence:** setIncomeRemindersEnabled and setMaturityRemindersEnabled only call prefs.setBool. NotificationService overrides five setters with a schedule-or-cancel side effect (weekly summary, monthly summary, tax, weekly check-in, FY summary, lines 505-558); income and maturity are not among them. In scheduleIncomeReminder, `if (!incomeRemindersEnabled) return;` (line 53) comes before `await _plugin.cancel(id: NotificationIds.incomeReminder(investmentId))` (line 55). In scheduleMaturityReminders, `if …
- **Impact:** A user with 10 FDs switches 'Maturity reminders' off. The 20 pending 7-day and 1-day alarms, which can be scheduled years ahead, still fire with Importance.max sound and vibration. Each investment with a payout frequency also keeps one pending 'Income Expected' alarm. With two devices, closing or deleting an investment on phone A leaves phone B showing 'Investment Maturing …
- **Fix:** (1) In both handlers, cancel first and then check the preference: `await cancel...(id); if (!enabled) return;`. (2) Add setIncomeRemindersEnabled and setMaturityRemindersEnabled overrides in NotificationService. On disable, call `_plugin.pendingNotificationRequests()` and cancel every request whose id is in the income range (50000-99999) or the maturity ranges (100000-149999), or whose payload starts with the income or maturity prefix. On enable, run rescheduleAllNotifications with the current investment list through an injected callback. (3) Turn rescheduleAllNotifications into a reconcile step: build the …

### GAP3-02 · high · Sign-out and 'Delete Account' leave every scheduled notification and the per-investment notification state on the device

- **Status:** Not independently verified · effort S · action A08
- **Where:** `lib/features/settings/presentation/screens/settings_screen.dart:213-219`; `lib/features/auth/data/repositories/firebase_auth_repository.dart:168-171`; `lib/features/settings/data/services/account_data_deletion_service.dart:68-92`
- **Evidence:** The sign-out button clears the analytics and Crashlytics ids and then calls authRepository.signOut(), which is just `_googleSignIn.signOut(); _firebaseAuth.signOut();`. deleteEverything removes only the userPreferenceKeys (sample-data and cache keys); the comment at line 69 says 'notification toggles are not user financial data and are left alone'. NotificationService.cancelAll() (lines 606-609) has no callers anywhere in lib/. Per-entity keys stay behind: milestone_shown_<investmentId>_*, goal_milestone_shown_*, …
- **Impact:** After 'Delete Account' (copy: 'Permanently delete all data', app_en.arb:4906), the phone keeps showing 'Income from <investment name> may be due today' and maturity reminders for months or years, plus weekly and monthly summaries for an account that no longer exists. On a shared or family phone, the next person who signs in receives the previous user's investment names, which …
- **Fix:** Add NotificationService.resetForAccountChange(). It should call `await _plugin.cancelAll()` and remove the keys matching milestone_shown_*, goal_milestone_shown_*, idle_alert_last_shown_*, goal_at_risk_last_shown_*, goal_stale_last_shown_*, user_signup_date and activation_day_*_sent. Call it from the sign-out handler, from deleteEverything (before the Auth account is deleted), and from an authStateProvider listener whenever the uid changes. Invalidate the Income Guardian providers on sign-out. Schedule tax, check-in and FY reminders again only after the next sign-in.

### GAP3-03 · high · Seven notification types are on by default with no in-app off switch, and three of them are scheduled on every launch, even before sign-in and for non-Indian users

- **Status:** Not independently verified · effort M · action A29
- **Where:** `lib/features/settings/presentation/screens/notifications_settings_screen.dart:33-119`; `lib/core/notifications/notification_settings_provider.dart:15-27`; `lib/core/notifications/notification_preferences.dart:50-133`
- **Evidence:** The settings screen shows five toggles; the NotificationSettingType enum has eleven. Tax reminders, weekly check-in, FY summary, investment MOIC milestones, risk alerts and idle alerts all have preferences that default to true (`?? true`) and no UI. goalAtRisk, goalStale and the activation sequence are not even in the enum, and setActivationNotificationsEnabled (line 868) has no callers. main.dart `_scheduleRecurringNotifications` runs on every cold start, with no auth or currency check, and schedules tax …
- **Impact:** With no opt-outs, the scheduled baseline is 52 check-ins, 52 weekly summaries, 12 monthly summaries, 6 tax reminders and 1 FY summary, about 123 pushes a year, before any per-investment reminders, goal alerts or activation nudges. On Android 12 and below there is no runtime permission, so these show to users who never consented, including people who installed the app and never …
- **Fix:** Add in-app toggles for every type, grouped as Reminders, Summaries, Tax (India), Goal milestones, Goal alerts, Investment milestones, and Tips and onboarding, plus a master 'Pause all'. Default the engagement types (weekly check-in, activation after Day 0) to OFF or opt-in. Gate tax and FY reminders on an INR base currency or Indian locale, and offer them in context, for example on the FY report screen. Move tax, check-in and FY scheduling out of main.dart into the auth-gated NotificationSyncInitializer, and schedule only when the user is authenticated and permission is granted. Schedule the activation sequence …

### GAP3-05 · high · Income Guardian settings, shown to every user, control a feature that never receives data, and changes to them do not take effect

- **Status:** Not independently verified · effort S · action A42
- **Where:** `lib/features/settings/presentation/screens/settings_screen.dart:105-118`; `lib/features/income_projection/presentation/screens/income_guardian_settings_screen.dart:33-150`; `lib/features/income_projection/presentation/providers/income_guardian_settings_provider.dart:18-25`
- **Evidence:** createExpectedCashFlow and bulkCreateExpectedCashFlows have no callers in lib/ or functions/src (only the anonymous-user cleanup references the collection), so users/{uid}/expectedCashFlows is always empty. overdueDaysAfter is read once, for a log line (monitor line 62); the overdue query filters only on `status in [gracePeriod, overdue]` and `expectedDate < now`. The Settings tile is hard-coded English and shown unconditionally, while FeatureFlag.incomeGuardian defaults to false and only gates the overview card. …
- **Impact:** Every user sees 'Income Guardian: Automated income tracking and payment alerts', with the subtitle 'Monitoring your expected payments'. In reality no overdue or upcoming alert can ever fire. Every investment's 'Expected income' tab says 'This investment has no predicted income payments', even for an FD with quarterly payouts. P2P and invoice-discounting users, the audience …
- **Fix:** Short term (S): hide the Settings tile and the Expected Income tab behind the existing incomeGuardian flag until there is a data generator. Long term (L): when an investment with incomeFrequency is created or updated, bulk-create its next 12 expected cash flows. Add daily status transitions (upcoming → dueSoon → gracePeriod → overdue) and apply overdueDaysAfter in the query (`expectedDate < now - overdueDaysAfter`). Replace the one-off ref.read with ref.listen or ref.watch so the services rebuild when settings or auth change. Add onError handlers and the composite indexes, and persist the ids of alerts already …

### GAP3-04 · medium · Goal at-risk and stale alerts ignore the 'Goal Milestones' toggle, share its Android channel, and the stale alert falsely claims 60 days of inactivity

- **Status:** Not independently verified · effort S · action A29
- **Where:** `lib/core/notifications/handlers/goal_notification_handler.dart:126-141`; `lib/core/notifications/handlers/goal_notification_handler.dart:153-163`; `lib/core/notifications/handlers/goal_notification_handler.dart:191-233`
- **Evidence:** At-risk alerts are gated by goalAtRiskEnabled and stale alerts by goalStaleEnabled; neither has UI. Both post on `NotificationChannels.goalMilestones` with the channel name 'Goal Alerts'. On Android, a channel's name and importance are fixed by whichever post creates it first. getLastActivityDate returns null when a goal has no linked investments. The stale handler then skips its threshold test and writes `daysSinceActivity = goalStaleDays` (60): '"X" has had no activity for 60 days. Add investments to make …
- **Impact:** A user turns off 'Goal Milestones' (subtitle 'Celebrate at 25%, 50%, 75%, 100%') and still gets '⚠️ Goal At Risk ... Consider increasing contributions' weekly and '💤 Goal Needs Attention' monthly. A goal created today with nothing linked triggers 'no activity for 60 days' the moment the user logs income on some other investment, which is false. A buy-and-hold goal funded by …
- **Fix:** Add a 'Goal alerts' toggle covering at-risk and stale. Post these alerts on a new channel id 'goal_alerts'; a new id is needed because channel importance cannot be changed after creation. Compute staleness from max(lastActivityDate, goal.createdAt). Skip the stale alert when the goal status is onTrack or ahead, or when the goal has no linked investments. Do not run the stale check from inside the add-cash-flow path, because the user is visibly active at that moment.

### GAP3-06 · medium · The notifications screen shows every toggle as ON when Android has blocked notifications, and routine nudges use maximum importance

- **Status:** Not independently verified · effort S · action A29
- **Where:** `lib/features/settings/presentation/screens/notifications_settings_screen.dart:20-119`; `lib/core/notifications/notification_settings_provider.dart:154-160`; `lib/core/notifications/notification_service.dart:377-404`
- **Evidence:** setSetting awaits requestPermissions() but ignores the boolean it returns, then flips the state to true. The screen never calls arePermissionsGranted(). On Android 13+, once permission has been denied twice, requestNotificationsPermission returns false without showing a dialog. _ensurePermissionsForShow logs LoggerService.warn on every blocked post, and warn is sent to Crashlytics as a non-fatal. The weekly summary ('Check your investment activity for this week'), monthly summary, milestones, tax and FY channels …
- **Impact:** A user who denied the one-time sign-in prompt sees all five toggles ON and assumes maturity reminders are active, but nothing is delivered. Every cash-flow add for such a user produces several Crashlytics non-fatals. Full-screen heads-up banners for generic 'check your activity' nudges push users to block the channel or the whole app. Android does not let the app lower a …
- **Fix:** Re-check the permission on screen open and on resume. When it is missing, show a banner, 'Notifications are turned off for InvTrack in Android settings', with a button that opens Settings.ACTION_APP_NOTIFICATION_SETTINGS. When requestPermissions() returns false, revert the toggle and show a snackbar. Re-tier importance: maturity 1-day and income-due as HIGH; summaries, check-in and milestones as DEFAULT or LOW. Use new channel ids (for example weekly_summary_v2) so the new importance applies. Downgrade the 'permissions not granted' log to info.

### GAP3-07 · medium · Goal and MOIC milestone notifications run backwards after a jump, ignore multi-currency and always show ₹

- **Status:** Not independently verified · effort S · action A12
- **Where:** `lib/core/notifications/handlers/goal_notification_handler.dart:53-64`; `lib/core/notifications/handlers/investment_notification_handler.dart:455-465`; `lib/features/investment/presentation/providers/investment_notifier.dart:798-805`
- **Evidence:** Both selectors pick the highest milestone that is at or below the current value and not yet shown, then mark only that one as shown. Once a goal is at 98% or more, `_shouldCheckGoalMilestone` returns true on every cash flow, and progressPercent is clamped to 100. A simulation of the handler logic (scratchpad GAP3/milestones.py) shows goal notifications of 100, 75, 50, 25 on consecutive cash flows, and MOIC notifications of 3.0x, then 2.0x, then 1.5x. The notifier computes goal progress with …
- **Impact:** A user links existing FDs worth ₹4.9L to a new ₹5L goal (98%). On each of the next three cash flows they get '🎯 75% Progress!', then 50%, then 25%. After 'Goal Achieved!' they read 'You're 75% of the way'. An investment that jumps from 0.2x to 3.2x MOIC announces '3.0x Returns Achieved', then '2.0x', then '1.5x'. A USD investment's milestone says 'You've earned ₹5,000.00 …
- **Fix:** When milestone m fires, mark every milestone at or below m as shown. The first time a goal or investment is observed (no stored state), silently mark all milestones already passed. Pass investment.currency, or the base currency for goals, into checkAndShowMilestone and checkAndShowGoalMilestone. Use calculateMultiCurrency in the notifier so notification percentages match the UI.

### GAP3-08 · medium · In-app updates can trap users in an immediate-update loop, nag on every launch and every resume, and ignore staleness

- **Status:** Not independently verified · effort S · action A29
- **Where:** `lib/core/widgets/in_app_update_initializer.dart:28-30`; `lib/core/widgets/in_app_update_initializer.dart:48-54`; `lib/core/widgets/in_app_update_initializer.dart:90-101`
- **Evidence:** An immediate (blocking) update runs when `isHighPriority` (updatePriority >= 4) and immediateUpdateAllowed are both true; otherwise a flexible dialog appears if flexibleUpdateAllowed is true and `_hasDeferredUpdate` is false. didChangeAppLifecycleState(resumed) calls `_checkForUpdates(isResume: true)`, which skips the once-per-session guard. When the user cancels Play's immediate screen, the app resumes and immediately re-launches the flow; there is no explanatory dialog and no per-session cap. …
- **Impact:** If a priority 4-5 release ships, anyone who backs out of Play's update screen, for example on limited mobile data, is locked out of the app until they update, with no explanation. At priority 0 users get an 'Update available' dialog on almost every launch, and again after every app switch if they dismissed it by tapping outside. Offline users are not blocked, because …
- **Fix:** Persist {availableVersionCode, lastPromptAt}. Prompt for a flexible update only when clientVersionStalenessDays >= 3 and at least 72 hours have passed since the last prompt. On resume, only resume a DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS immediate update or show the install dialog for a downloaded one. Never start a fresh immediate flow more than once per session. On userDeniedUpdate, show a one-time explanation and do not set an error. Make dismissing the dialog count as 'Later'. Set inAppUpdatePriority deliberately in the release pipeline and document it in release.yaml.

### GAP3-09 · medium · The production debug menu offers a real fatal-crash button, a Crashlytics 'disable' toggle that does nothing in release, and user-flippable feature flags

- **Status:** Not independently verified · effort S · action A35
- **Where:** `lib/features/settings/presentation/widgets/crashlytics_settings_section.dart:39-66`; `lib/features/settings/presentation/widgets/crashlytics_settings_section.dart:205-208`; `lib/core/analytics/crashlytics_service.dart:56-57`
- **Evidence:** After the 7-tap unlock (PLAT-16), any release user can open Debug Settings. 'Test Fatal Crash' calls `_crashlytics.crash()`, guarded only by `if (kDebugMode && !_debugMode)`, so in release it always crashes. 'Test Non-Fatal' sends a fake error. The toggle computes `shouldEnable = !kDebugMode || enabled`, which is always true in release, yet the snackbar says 'Crashlytics disabled in debug mode'. The feature-flag toggles for Reports tab, Portfolio Health Score, Income Guardian and the Play review prompt are all …
- **Impact:** Every 'Crash now' tap is a genuine native crash. It counts in Android vitals' user-perceived crash rate (bad-behaviour thresholds: 1.09% of daily active users overall, 8% per device model) and in Crashlytics crash-free users. For a niche app with about 300 DAU, 4 curious users on one day is 1.3%, enough to cross the threshold and reduce Play discoverability. A user who wants …
- **Fix:** Exclude CrashlyticsSettingsSection and the feature-flag section from release builds (`if (!kReleaseMode)`), or gate debug mode behind a server-side allowlist of developer UIDs in Remote Config. If a user-facing crash-reporting opt-out is wanted, add a real Settings → Privacy toggle that calls setCrashlyticsCollectionEnabled(false) in release and persists the choice.

### GAP3-10 · medium · Notification opt-outs, Income Guardian settings and privacy mode live only on the device and reset on reinstall or a new phone

- **Status:** Not independently verified · effort M · action A29
- **Where:** `lib/core/notifications/notification_constants.dart:112-128`; `lib/core/notifications/notification_preferences.dart:19-133`; `lib/core/providers/privacy_mode_provider.dart:8-16`
- **Evidence:** Every preference is a SharedPreferences key: notifications_*, privacy_mode_enabled, income_guardian_*. The manifest sets android:allowBackup="false" and fullBackupContent="false", and nothing mirrors these keys to the user's Firestore profile. Every default is true, except privacy mode, which defaults to false.
- **Impact:** A user who switched off weekly summaries and tax reminders on an old phone gets them all back on a new phone or after reinstalling. A privacy-mode user signing in on a new device in public sees full amounts. The user's withdrawal of consent does not stick, even though their investment data syncs across devices.
- **Fix:** Store notification preferences and privacy mode in users/{uid}/profile (or a settings document), load them on sign-in, and keep SharedPreferences as an offline cache. Write the choice to both places when a toggle changes.

### GAP3-11 · low · Dead risk and idle alerts are on by default; if wired as written, the idle alert would nag buy-and-hold users, and the risk-alert copy has no guardrails

- **Status:** Not independently verified · effort S · action A29
- **Where:** `lib/core/notifications/handlers/alert_notification_handler.dart:33-71`; `lib/core/notifications/handlers/alert_notification_handler.dart:79-143`; `lib/core/notifications/notification_constants.dart:183-194`
- **Evidence:** showRiskAlert and checkIdleInvestments are called only by notification_service.dart:847-859, so nothing triggers them. The idle check uses a 90-day threshold and a 30-day per-investment rate limit. IdleInvestmentInfo has no type, maturity or payout fields. The idle copy is '... has had no activity for N days. Review this investment?' or '... Consider adding cash flows.' showRiskAlert accepts free-text title and body at Importance.high. Both preferences default to true. A simulation (scratchpad GAP3/idle.py), run …
- **Impact:** Wired as written, every FD, bond and SGB holder would get a monthly 'Review this investment?' for each holding until maturity. 'Consider adding cash flows' invites users to invent entries, which corrupts XIRR. Unconstrained risk-alert text (for example 'reduce exposure to X') could read as personalised investment advice, an area governed by SEBI's Investment Advisers …
- **Fix:** Delete the dead code, or rewrite the idle alert as a 'matured but still open' alert (maturityDate < now and status open: 'Your HDFC FD matured on 12 Sep. Record the payout or close it?'). The case of an expected payout not arriving belongs to Income Guardian. Never run the idle alert on cumulative FDs, SGBs or bonds before maturity. Restrict risk alerts to factual templates (for example 'One platform holds 48% of your portfolio'), add 'Not investment advice', and make them opt-in. Set both defaults to false until the features ship.

### GAP3-12 · low · Activation nudges cannot be turned off, run for signed-out installs at high importance, and make an unverified 'thousands of investors' claim

- **Status:** Not independently verified · effort S · action A29
- **Where:** `lib/core/notifications/notification_service.dart:945-952`; `lib/core/notifications/notification_service.dart:1029-1031`; `lib/core/notifications/notification_service.dart:1053-1056`
- **Evidence:** The Day 14 notification reads '📈 Join Smart Investors' / 'Thousands of investors track their real returns with InvTrack. Add your first investment and join them!'. Day 7 says real returns are 'often different from advertised rates'. The channel is Importance.high and the strings are hard-coded English. setActivationNotificationsEnabled has no callers. The 'signup date' is recorded on the first empty investment list, which also happens when the user is signed out.
- **Impact:** If Play installs are not actually in the thousands, the social-proof claim is misleading, a credibility and consumer-protection risk. Users who installed but have not signed in get five nudges with no way to stop them short of the OS channel settings.
- **Fix:** Use verifiable copy such as 'Track FD, P2P and bond returns in one place'. Keep Day 0, 1 and 7 only, behind a 'Tips & onboarding' toggle. Schedule them only after sign-in and permission grant. Localise the strings through the ARB files.

### GAP3-13 · low · Privacy mode is off by default, can only be toggled from the Overview card, and does not apply to notifications

- **Status:** Not independently verified · effort S · action A29
- **Where:** `lib/core/providers/privacy_mode_provider.dart:14-17`; `lib/features/overview/presentation/widgets/hero_card.dart:155`; `lib/core/notifications/handlers/investment_notification_handler.dart:294-299`
- **Evidence:** `prefs.getBool(_privacyModeKey) ?? false`. The only toggle is PrivacyToggleButton on the hero card; there is no Settings entry. No file under lib/core/notifications or the Income Guardian services reads privacy mode, and the notification bodies include amounts ('Value: ₹...', 'You've earned ₹... profit', 'Current: ₹X of ₹Y'). The Play listing promises 'Hide all amounts with one tap'.
- **Impact:** With privacy mode on, heads-up banners on an unlocked screen, during screen sharing or when the phone is handed over, still show maturity values and profit. This is separate from the lock-screen issue in SEC-17. Users who never notice the eye icon never find the feature at all.
- **Fix:** When privacy mode is on, build notification bodies without amounts (for example 'HDFC FD matures in 7 days'). Add Privacy mode, plus a 'Hide amounts in notifications' option defaulting to ON, under Settings → Security & Privacy. Offer privacy mode once during onboarding.

### GAP3-14 · low · The 'summary' notifications contain no summary, and the data-rich FY summary is never shown

- **Status:** Not independently verified · effort M · action A10
- **Where:** `lib/core/notifications/handlers/scheduled_notification_handler.dart:77-78`; `lib/core/notifications/handlers/scheduled_notification_handler.dart:131-132`; `lib/core/notifications/handlers/scheduled_notification_handler.dart:355-356`
- **Evidence:** The toggle subtitles promise 'Get a summary every Sunday' and 'End of month income recap'. The notifications actually say 'Check your investment activity for this week', 'Review your investment income for this month' and 'Your financial year summary is ready!'. showFYSummary, which formats real income, TDS and top performer, has no callers outside NotificationService.
- **Impact:** Users enable 'summaries' expecting numbers and get generic re-engagement pings at maximum importance, which trains them to ignore the app. The routing of these notifications to the hidden Reports tab is MKT-V-01; this finding is about the content not matching the toggle.
- **Fix:** Generate content when the notification fires: compute the week's or month's income and number of cash flows and post them via show() (an on-device job using WorkManager, or computed at app open for the coming period). If no real data can be included, rename the toggles to 'Weekly reminder to review' and set them to default importance.

## GAP4 · Unit economics: Firebase/FX cost per active user and at scale vs proposed pricing

### GAP4-01 · high · Before fixes, infrastructure eats 38-82% of projected Premium revenue at 2% conversion. One active day costs about 1,750 Firestore reads.

- **Status:** Not independently verified · effort M · action A62
- **Where:** `lib/features/investment/presentation/providers/investment_providers.dart:23-32`; `lib/features/investment/presentation/providers/investment_providers.dart:88-96`; `lib/features/portfolio_health/presentation/providers/portfolio_health_provider.dart:69-70`
- **Evidence:** Cold start lands on Overview (app_router.dart:92-102, kept alive in an IndexedStack). The model lives in GAP4/cost_model.py. For a typical user (25 investments / 300 cash flows / 3 goals / FIRE / 2 currencies), one cold start or a resume more than 30 minutes after the last session bills about 994 reads:
- allInvestments listener: 25
- allCashFlows listener: 300
- 25 per-investment cashFlowsByInvestment listeners opened by PortfolioHealthDashboardCard via portfolio_health_provider.dart:69-70: 300 more
- goals + …
- **Impact:** Premium at ₹999/yr nets ₹719.6/yr after 18% GST and the 15% Play fee (MON/econ.py net()), which is $8.18/yr at ₹88/$.

Net revenue per MAU-month:
- 2% conversion: $0.0136
- 5% conversion: $0.0339

Free-user infrastructure as a share of net revenue at 30% DAU/MAU:
- 2% conversion: 49% (asia-south1) or 79% (nam5)
- 5% conversion: 20% or 32%
- After the four fixes: 15-25% at 2%, …
- **Fix:** 1) Ship the four existing fixes (ARCH-06/10/11/13). They cut reads per active day from 1,753 to about 549 (-69%).
2) Adopt a guardrail metric: Firestore reads per DAU-day of 700 or fewer. That keeps infrastructure at or below 20% of net revenue at 2% conversion and 30% DAU/MAU, since ₹0.24/MAU-month equals ₹0.80/DAU-month, or about 727 reads/day at $0.035/100k plus egress.
3) Track it weekly by dividing Cloud Monitoring `firestore.googleapis.com/document/read_ops_count` by Analytics DAU.
4) Set GCP budget alerts at $10, $50 and $200 per month now.
5) Keep cost-heavy live features, such as the per-investment …

### GAP4-02 · high · No App Check and permissive rules: one scripted anonymous account can run up a bill of hundreds of dollars a day

- **Status:** Not independently verified · effort M · action A32
- **Where:** `pubspec.yaml:64-71`; `firestore.rules:5-6`; `lib/features/auth/data/repositories/firebase_auth_repository.dart:299-303`
- **Evidence:** - pubspec.yaml:64-71 lists firebase_core, cloud_firestore, firebase_auth, analytics, crashlytics and performance. There is no firebase_app_check, so Firestore accepts any client holding a valid ID token.
- firestore.rules:5-6 is `match /users/{userId}/{document=**} { allow read, write: if request.auth != null && request.auth.uid == userId; }`. There is no allow-list of subcollection names, no field or size constraints, and no write-rate checks.
- Guest mode calls `_firebaseAuth.signInAnonymously()` …
- **Impact:** Results of the model's ABUSE SCENARIO with a looping client, using 600 B per read and 1 KiB writes:

At 1,000 ops/s:
- Reads: $30/day (asia-south1) or $52/day (nam5), plus $5.8/day egress
- Writes at the same rate: $90/day (asia-south1) or $156/day (nam5), plus about 206 GiB/day of new storage including index overhead

At 10,000 ops/s:
- Reads: $302/day or $518/day, plus …
- **Fix:** 1) Add firebase_app_check with the Play Integrity provider. Run it in monitor mode for 1-2 weeks, then enforce it on Firestore.
2) Before about 3-5k DAU, request an increase to the Play Integrity quota. The default is 10,000 requests/day per Cloud project, and approval can take up to a week.
3) Tighten the rules:
   - allow-list subcollections: investments, cashflows, archived*, goals, expectedCashFlows, documents, fireSettings, profile, healthScores, exchangeRates
   - validate types
   - cap string lengths, e.g. `request.resource.data.notes.size() < 2000`
   - cap key counts
4) Create GCP budget alerts at …

### GAP4-03 · medium · Per-session cost grows with each user's full history, so long-tenured users cost several times more while their revenue stays flat

- **Status:** Not independently verified · effort L · action A62
- **Where:** `lib/core/di/database_module.dart:19-22`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:342-351`; `lib/features/investment/data/repositories/firestore_investment_repository.dart:665-676`
- **Evidence:** - Persistence is on (database_module.dart:19-22). Per the Firestore pricing page, a listener disconnected for more than 30 minutes is billed "as if you had issued a brand-new query".
- `watchAllCashFlows()` (repo :342-351) listens to the entire cashflows collection with no window. Every session more than 30 minutes after the last one therefore re-bills every cash flow the user has ever entered, plus the 12-week healthScores history (about 1 doc per active day, health_score_repository.dart:155-164; auto-save writes …
- **Impact:** Model output, Firestore reads per active day:

| Profile | Now | After the four ARCH fixes |
|---|---|---|
| Typical (300 cash flows) | 1,753 ($0.022/DAU-month) | 549 ($0.0069) |
| 3-year user (60 investments, 1,000 cash flows, 3 currencies) | 7,658 ($0.097, nam5 $0.155) | 1,735 ($0.022) |

A monthly-interest user adds about 250 cash flows a year, so the floor cost per DAU …
- **Fix:** Make cold start cache-first with delta sync:
1) Add `updatedAt: serverTimestamp()` to cash flows, investments and goals. Turn deletes into soft deletes with `deletedAt`, purged after 30 days.
2) On start, render from `get(GetOptions(source: Source.cache))`.
3) Listen only to `where('updatedAt', isGreaterThan: lastSyncAt)` and persist lastSyncAt locally.
4) Keep a weekly full resync as a safety net.
5) Limit healthScores to 1 snapshot per day, keyed by the yyyy-mm-dd doc id, and stop listening to history: get it once per day.

Worked example: for the 1,000-cash-flow user, two sessions a day drop from 2 x (60 + …

### GAP4-04 · medium · A base-currency switch wipes every cached FX rate and re-fetches them all: about 1,100 reads, 1,080 writes and 1,080 Frankfurter calls in one tap

- **Status:** Not independently verified · effort S · action A14
- **Where:** `lib/features/settings/presentation/providers/settings_provider.dart:122`; `lib/core/services/currency_conversion_service.dart:226-251`; `lib/core/services/currency_conversion_service.dart:269-277`
- **Evidence:** - `setCurrency` calls `clearCache()` (settings_provider.dart:122). That runs `_exchangeRatesRef.get()` over all of the user's rate docs and batch-deletes every one (currency_conversion_service.dart:232-249). The deleted docs are immutable historical rates keyed by `historical_{date}_{FROM}_{TO}`, so they stay valid after a base switch.
- Every base-currency cash flow then becomes foreign, and all consumers recompute at once:
  - global, open and closed stats
  - 3 goals in parallel …
- **Impact:** Typical user (300 cash flows, 240 in INR) switching INR to USD, per the model: about 1,142 reads, 1,080 writes, 62 deletes and about 1,080 HTTP calls to api.frankfurter.dev from one device within seconds.

That is 65% of a typical day's reads and about 90 days of normal writes. 19 switches in one day exhaust the 20k free daily writes.

While thrashing, each later recompute in …
- **Fix:** Delete `clearCache()` from setCurrency, since cached rates stay valid under any base. Coalesce through `getRate()`'s `_inflightRequests` inside `batchConvertHistorical`. Raise the memory cache to 2,000 entries and evict only when inserting a new key. Alternatively, fetch a whole date range in one Frankfurter call (`/v1/2024-01-01..2024-12-31?base=INR&symbols=USD`) and store it.

Worked example: a 240-date switch then costs 1 HTTP call and 0 Firestore operations instead of about 1,080 / 1,080 / 1,142.

### GAP4-05 · medium · FX depends on Frankfurter v1 (no SLA, fair use only), failures are never cached, and the last-known-rate fallback needs an index the repo does not declare

- **Status:** Not independently verified · effort M · action A14
- **Where:** `lib/core/services/currency_conversion_service.dart:182-187`; `lib/core/services/currency_conversion_service.dart:767-784`; `lib/core/services/currency_conversion_service.dart:488-496`
- **Evidence:** Dependency facts:
- The primary API is `https://api.frankfurter.dev/v1` (:183). Code comments say "free, unlimited" and "NO rate limits!" (:182, :767).
- Frankfurter publishes no SLA and expects fair use. Search snippets describe v1 as frozen, with v2 current.
- v1 serves only the ECB basket of about 31 currencies (lineofflight/frankfurter#144). AED is the most-requested missing currency, and SAR/QAR/KWD are also absent. These are the NRI Gulf corridor.
- The fallback, exchangerate-api.com v4 (:186-187), serves …
- **Impact:** Cost:
- Steady state is 1.64 HTTP calls per active day. At 100k MAU and 30% DAU/MAU that is about 49k calls/day to an unpaid volunteer service, plus about 1,080-call bursts per currency switch from a single IP.
- An AED user with 60 AED cash flows pays about 60 doc reads, about 60 failing HTTP calls (until the circuit breaker opens for 1 minute), and up to 60 sequential …
- **Fix:** 1) Move FX server-side once a day. A scheduled job (a Cloud Function, or a free GitHub Action calling the Firestore REST API) writes `/fxRates/{yyyy-mm-dd}` with all pairs against EUR. Clients cross-compute any pair and cache dates locally. Total: about 1 HTTP call/day for the whole user base and 1 shared read per date per device.
2) Alternatively, self-host the MIT Frankfurter Docker image (`docker run lineofflight/frankfurter`) on Cloud Run, which scales to zero.
3) Plan the move to v2 for non-ECB currencies such as AED.
4) Negative-cache failures for 24 hours.
5) Add the composite index `exchangeRates(from …

### GAP4-06 · medium · Income Guardian background services run for every user, yet the feature is flagged off, nothing creates its data and its queries lack indexes

- **Status:** Not independently verified · effort S · action A42
- **Where:** `lib/features/income_projection/presentation/providers/income_guardian_settings_provider.dart:19`; `lib/features/income_projection/presentation/providers/income_guardian_settings_provider.dart:68`; `lib/core/providers/feature_flags_provider.dart:173-176`
- **Evidence:** - The UI flag defaults off: `flags[FeatureFlag.incomeGuardian] ?? false` (feature_flags_provider.dart:176).
- The service settings default on: `enabled = true` and `prefs.getBool(_keyEnabled) ?? true` (income_guardian_settings_provider.dart:19, 68).
- `IncomeGuardianServiceInitializer` wraps the whole app (app.dart:26) and starts both services for every signed-in user (income_guardian_service_providers.dart:91-95).
- Nothing in lib/ calls `createExpectedCashFlow` or `bulkCreateExpectedCashFlows`; a grep finds only …
- **Impact:** For the typical user (150 INCOME cash flows): about 152 billed reads per cold start (minimum one read per empty query) with a sequential round-trip chain. That is 9% of all reads per active day, or about $84/mo (asia-south1) / $135/mo (nam5) at 100k MAU and 30% DAU/MAU.

If the indexes were never created in the console, the queries error instead. Billing is then about 0, but …
- **Fix:** 1) Start the services only when `isIncomeGuardianEnabledProvider` is true AND at least one expected cash flow exists (a single `limit(1)` get), or simply default settings.enabled to false. About 0.25 days of work.
2) When the feature ships, replace the per-cash-flow loop with one listener on pending expected flows, matched in memory.
3) Add both composite indexes to firestore.indexes.json.

### GAP4-07 · medium · Ranked cost-reduction backlog: the best-value fixes are ARCH-06, ARCH-10 and ARCH-13, then ARCH-11 and delta-sync

- **Status:** Not independently verified · effort M · action A62
- **Where:** `lib/features/investment/presentation/providers/investment_notifier.dart:815-829`; `lib/features/investment/presentation/providers/investment_notifier.dart:651-656`; `lib/features/income_projection/data/services/income_guardian_sync_service.dart:96-107`
- **Evidence:** Model FIX RANKING at 100k MAU, 30% DAU/MAU. Savings are $/mo in asia-south1 (nam5 in brackets), including read egress.

| Rank | Fix | Effort | Saving | $/mo per eng-day |
|---|---|---|---|---|
| 1 | ARCH-06: compute milestones from in-memory providers and drop `_invalidateAll` | 0.5 d | $88 ($141) | 176 |
| 2 | ARCH-10: gate Income Guardian (see GAP4-06) | 0.25-0.5 d | $84 ($135) | 169-338 |
| 3 | ARCH-13: group allCashFlows by investmentId instead of 25 listeners | 1 d | $169 ($270) | 169 |
| 4 | ARCH-11: …
- **Impact:** Fixes 1-4 together cut the 100k-MAU bill from $696 to $234/mo (asia-south1) or from $1,120 to $379 (nam5), -66%. At today's likely scale (1k MAU or less) the whole bill is $2-9/mo.

The near-term payoff is fewer sequential round trips on cold start and add-transaction, which means faster screens and less battery and data use, plus bending the cost curve before growth. The …
- **Fix:** Do fixes 1-3 in one 2-day sprint (combined effort about 2 days, -54% reads). Do fix 4 in the next sprint. Schedule delta-sync together with the `updatedAt` schema change before any marketing push past about 10k MAU.

Add a debug-only Firestore read counter (wrap repositories) and a CI integration test asserting cold start at 400 reads or fewer for the seeded 25/300 fixture.

### GAP4-08 · low · Analytics floods with an event per FX lookup and per Health rebuild, which would pause a GA4 BigQuery export at about 1.3-2.2k DAU

- **Status:** Not independently verified · effort S · action A34
- **Where:** `lib/core/services/currency_conversion_service.dart:567-573`; `lib/core/services/currency_conversion_service.dart:579-586`; `lib/core/services/currency_conversion_service.dart:661-667`
- **Evidence:** - `getHistoricalRate` and `getLiveRate` call `_analytics?.logExchangeRateCacheHit(...)` on every lookup, including memory-cache hits (currency_conversion_service.dart:569-572, 583-586, 663-666). There is no sampling (analytics_service.dart:837-845 calls logEvent directly).
- `PortfolioHealth.build` constructs `AnalyticsService()` and logs `health_score_calculated` on every rebuild (portfolio_health_provider.dart:88-93). It rebuilds once per per-investment stats provider that resolves, about 25 times per cold …
- **Impact:** Firebase Analytics is no-cost, but GA4 standard properties cap daily BigQuery export at 1M events and pause the export when exceeded. At about 450-750 events per DAU-day, the cap is hit at about 1.3-2.2k DAU.

The flood also crowds out funnel events and adds client upload traffic. Low severity because BigQuery export status could not be verified.
- **Fix:** Remove `logExchangeRateCacheHit` for memory hits. Aggregate the rest into one `fx_session_summary` event using ConversionMetrics.toJson(). Log health_score_calculated only when the score tier changes, through the injected analyticsServiceProvider.

### GAP4-09 · low · The Firestore location is not declared anywhere; if it is nam5, every number in this model is 1.71x higher and Indian users get US round-trip latency

- **Status:** Not independently verified · effort S · action A62
- **Where:** `firebase.json:2-5`; `android/app/google-services.json:4-5`
- **Evidence:** - firebase.json:2-5 declares only rules and indexes, with no location.
- google-services.json gives only `project_id: invtracker-b19d1` and the storage bucket.
- No doc in the repo names the region.
- Database location is permanent once created.
- Standard-edition prices: nam5 reads/writes/storage are $0.06/$0.18/$0.18 against asia-south1's $0.035/$0.104/$0.104, a 1.71x ratio.
- **Impact:** 100k MAU at 30% DAU/MAU: $1,120/mo (nam5) against $696 (asia-south1) now, or $379 against $234 after the fixes. Every un-cached get on cold start (ARCH-06/10/11 chains) also pays roughly 200-250 ms of India-to-US RTT, compared with about 20-40 ms to Mumbai.
- **Fix:** Check Firestore > Database > Location in the console. If it is nam5/us-*, do not migrate now: the free tier applies only to the (default) database. Once paid usage exceeds about $100/mo, evaluate a new asia-south1 database with export/import and a dual-write window, and record the decision in docs.

### GAP4-10 · low · Storage grows without bound: healthScores has no TTL, FX rates are stored per user, and the anonymous-user cleanup function is not deployable

- **Status:** Not independently verified · effort S · action A36
- **Where:** `lib/features/portfolio_health/data/repositories/health_score_repository.dart:57-72`; `lib/core/services/currency_conversion_service.dart:264-266`; `lib/core/services/currency_conversion_service.dart:609-621`
- **Evidence:** - Health snapshots are appended with `_collection.add(...)` (health_score_repository.dart:63-65) and never pruned.
- Every user stores private copies of identical ECB rates under `users/{uid}/exchangeRates` (:264-266, writes at :610-620).
- The cleanup job for guest data (functions/src/cleanupAnonymousUsers.ts) cannot be deployed: functions/ contains only src/, with no package.json or index.ts, and firebase.json has no "functions" entry. Inactive guest subtrees therefore never disappear.
- Model estimate: about …
- **Impact:** With 3x MAU registered (no deletion), 100k MAU is about 286 GiB, or about $29/mo (asia-south1) / $51/mo (nam5). Small next to reads, but monotonic. Guest data retained indefinitely also contradicts the 30-day cleanup the function's comments promise.
- **Fix:** Store one healthScore doc per day (doc id = date) and set a Firestore TTL policy on `calculatedAt` (e.g. 400 days). Move FX rates to a shared or local store (GAP4-05). Finish and deploy the cleanup function with a package.json and index.ts exporting cleanupOldAnonymousUsers, registered in firebase.json, and alert on errors.

## Refuted

### ADOPT-12 · In-app update only runs when the user taps 'Check for Updates' in About; there is no startup check

- **Why refuted:** The reviewer missed lib/core/widgets/in_app_update_initializer.dart. It is mounted for the whole app in MaterialApp.router's builder (lib/app/app.dart:38-39). It calls checkForUpdate after the first frame (lines 33-40) and again on every AppLifecycleState.resumed (lines 49-53). It starts an immediate update for …
