# Reporting engine

Status: design, 2026-10-21. One engine builds every report (weekly, monthly, yearly/FY, tax, future custom ones). It lives in `lib/core/reporting/` as plain Dart with no Flutter imports, so it is unit-testable and the same result feeds the screen, CSV and PDF.

## What exists today, and what we do with it

| Existing | Verdict |
|---|---|
| `lib/core/utils/financial_year.dart` (`FinancialYear`) | Reuse. The period abstraction calls it for the Apr-Mar start and the half-open check. |
| `lib/core/calculations` (`FinancialCalculatorModule.calculateStats`, `TrackingPeriodCalculator`, `CurrentValueCalculator`, `CurrencyConverterModule.batchConvertToBase`) | Reuse as the only source of numbers. The metrics layer is a thin caller. |
| `FYReportService` + `FYReport` | Keep unchanged for now. It has its own tests and an FY screen and CSV/PDF export (#800) are being built on `FYReport` by other PRs. It moves onto the engine in a later ticket, once the engine reproduces its tested outputs (see "FY migration"). |
| `WeeklySummaryService`, `ReportBuilderService._buildWeeklySummary` | Replace. They sum unconverted amounts, step days with `add(Duration(days: 1))` (wrong across DST), use `isAfter/isBefore` windows with a one-day pad, and format money with `toStringAsFixed`. The weekly and monthly report screens are served by the engine. `WeeklySummaryService` and `WeeklySummary` stay for now because notifications and smart insights still read them; they are removed in a follow-up once those move to `ReportResult`. The report-builder weekly branch is left for the same follow-up. |
| `ReportSection`/`KpiData` (`dynamic_report_data.dart`) | Do not extend. `KpiData.value` is a pre-formatted `String`, which loses unknown-vs-zero and cannot be privacy-masked or exported. The engine returns typed values; renderers format. `DynamicReportData` stays for the other report types until they move. |
| `report_builder_screen`, `dynamic_report_screen`, `base_report_screen`, `historical_reports_list`, `report_stat_card` | Reuse the widgets (`BaseReportScreen` shell, `ReportStatCard`, `PrivacyMask`). The new screen is a renderer over `ReportResult`, not a new framework. |
| `ReportCacheService` | Reuse, but its current key is only report type + period bounds, which is not enough: two currencies, definitions or portfolios would collide. Before the engine uses it, the key becomes definition id + period bounds + base currency + scope (identity/portfolio), applied identically on read and write; the cache is also cleared when the scope changes. The same scope fix applies to `weeklySummaryServiceProvider` while `WeeklySummaryService` remains. A cache-key test covers USD vs EUR, two definitions, and two scopes. |

No second parallel system for the screens: after slice 3 the Weekly and Monthly tiles use the engine. The remaining old path is notification/insight data, tracked as the follow-up above.

## Period

`ReportPeriod` is an immutable value: `kind` (week, month, quarter, fy, custom), `start`, `endExclusive`, both date-only local `DateTime(y, m, d)`.

- Half-open `[start, endExclusive)`. `contains(date)` normalises to the calendar day first (money rule 5). Nothing uses `isAfter/isBefore` on raw instants and no `Duration(days:)` arithmetic: next/previous use `DateTime(y, m, d + n)`, which is DST-safe. Day counts go through `DateTime.utc`.
- Factories: `week(anchor, weekStart)`, `month(y, m)`, `quarter(y, q)`, `fy(startYear)` (1 Apr to next 1 Apr), `custom(start, endInclusive)`, and `containing(kind, day)`.
- `weekStart` is a `DateTime.monday..sunday` argument, default Monday (matches the old report); a setting can feed it later. YAGNI: no setting UI in this work.
- `previous()` gives the same-kind period before (for comparison). Month of 31 days vs 28/29 is handled by constructing from year/month, never by subtracting days. Leap day: 29 Feb is inside the month and FY periods like any other day. For `custom(start, endInclusive)`, `previous()` is the equal-length window immediately before: with `n` = day count of `[start, endExclusive)`, it is `[start - n days, start)` built with `DateTime(y, m, d - n)` (DST-safe). A test covers it, including across a month and year boundary.
- `months()` lists the calendar months a period touches (for the by-month breakdown).
- Quarter is calendar-year based here; an FY quarter (Apr-Jun) is `custom` until a ticket needs it.

## Metrics

`ReportMetric` is an enum, one value per metric: `invested`, `returned`, `income`, `fees`, `netCashFlow`, `periodXirr`, `periodMoic`, `portfolioValueStart`, `portfolioValueEnd`. Each maps to exactly one function in `MetricsCalculator`, which only calls `lib/core/calculations`:

- Flow totals and net: `FinancialCalculatorModule.calculateStats(periodFlows, includeXirr: false)`.
- XIRR and MOIC for the period: `TrackingPeriodCalculator.build` then `.stats`, with opening and closing values. If either value is missing the metric is unknown. It is never derived from the cash flows alone and never re-implemented.
- Current value: `CurrentValueCalculator`.

`MetricValue` is a sealed result: `Known(double)` or `Unknown(UnknownReason)` (`awaitingValue`, `noRate`, `noElapsedTime`, `notApplicable`). Unknown is never 0 and never -100%. Renderers show an em dash (and the existing "Awaiting current value" wording where the screen has room).

## Report definition and result

```text
ReportDefinition { id, titleKey(l10n key), metrics: List<ReportMetric>,
                   breakdowns: List<Breakdown>, comparePrevious: bool }
Breakdown = byInvestmentType | byCurrency | byMonth
ReportResult { definitionId, period, baseCurrency, generatedAt,
               totals: Map<ReportMetric, MetricValue>,
               previous: Map<ReportMetric, MetricValue>?,   // same metrics, previous period
               breakdowns: Map<Breakdown, List<BreakdownRow>>,
               notes: List<ReportNote> }                    // e.g. excludedFlows, archivedExcluded
BreakdownRow { key, labelKey/raw label, values: Map<ReportMetric, MetricValue> }
```

All are immutable (`const` constructors, unmodifiable collections). Weekly, monthly and yearly are three `ReportDefinition` constants, nothing more. The engine function is `ReportEngine.run(definition, period, inputs) -> ReportResult`, where `inputs` is `{investments, cashFlows, baseCurrency, valuations}` read from existing providers; the engine itself reads no providers, so tests need no Riverpod.

Rules the engine enforces once:

1. Archived investments (and their flows) are dropped first; a note records that, and the screen says so (money rule 9).
2. Flows are converted with `batchConvertToBase`. A flow with no rate is dropped from the totals and counted in an `excludedFlows` note so the screen can say "N entries left out: no exchange rate". Native amounts are never summed under the base symbol. A missing currency is never defaulted to USD (rule 1).
3. Flows are windowed with `period.contains`.
4. Comparison: the same metrics are computed for `period.previous()`. `delta(metric)` is `Known` only when both values are known; percentage change is `Unknown(notApplicable)` when the previous value is 0, so there is no divide-by-zero and no "+inf%". If the current or previous value is `Unknown`, the delta and percentage change are `Unknown` with the same reason as the unknown operand (the previous operand's reason when both are unknown). Comparison tests cover unknown current, unknown previous, both unknown, and zero previous.
5. Breakdown rows come from running the same metric functions on the subset (by investment type, by currency of the original flow, by calendar month), so for additive metrics (money totals, flow counts) the rows sum to the total (a test asserts this). Non-additive metrics (`periodXirr`, `periodMoic`) are recomputed on each subset and are never summed; no sum-equals-total assertion applies to them.

## Rendering contract

Adapters take a `ReportResult` and nothing else, so exports are written once:

- `ReportFormatter` is the single place that turns `MetricValue` into display text: money via the existing currency formatter, percent, em dash for unknown. It takes `privacyMode`; when on, money text is the mask and semantics labels are masked too (rule 8). Exports follow the same switch: CSV/PDF are only produced after the user confirms in privacy mode off, or are masked.
- Screen renderer: a widget over `ReportResult` built from `BaseReportScreen`, `ReportStatCard`, and `PrivacyMask`, 48dp targets, no fixed heights, checked at 1.8x text scale and 320dp.
- CSV and PDF adapters implement `ReportExporter { Uint8List/String export(ReportResult, ReportFormatter) }`. Their implementation belongs to the #800 work and the Tax-Year CSV PR (#1138); this design only fixes the input type. They are not part of this work and are not edited.
- CSV cells go through `csv_utils` (formula-injection guard exists there).

## FY migration

`FYReportService` produces `FYReport` including top performers by return and XIRR, income categorised by note text, and a realised-profit split. The engine covers the totals, monthly breakdown, and period XIRR, but not those extras. Moving the FY screen/exports onto `ReportResult` would change the data type that #800 PRs are building on, so it is out of scope now. Plan: after #800 merges, add a golden-values test that runs `FYReportService` and the engine on the same fixture and asserts equal totals, monthly rows and XIRR; only if they match does the service become a thin adapter. Until then FY keeps its service.

## Slices

1. `lib/core/reporting/report_period.dart` + tests (DST, leap year, FY boundaries 31 Mar/1 Apr, week start variants, month lengths, year boundaries).
2. `metric_value.dart`, `metrics_calculator.dart`, `report_definition.dart`, `report_result.dart`, `report_engine.dart` + tests with exact paisa/1e-6 values (multi-currency, unknown rate, archived, unknown XIRR, comparison with zero previous, breakdown sums).
3. Weekly, monthly, yearly definitions, provider, formatter, one `ReportScreen`, routes, strings appended to the end of `app_en.arb`, widget tests (privacy mask, 1.8x/320dp, em dash). Yearly period XIRR and opening/closing values are not wired (they need `valuationsAtFYEdges`, which belongs to the FY migration); the engine already accepts them through `ReportInputs`.

Non-goals: custom report builder UI, scheduling, new data sources, FY quarters, week-start setting UI.
