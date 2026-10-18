# Reports and digest engine: PLAN, awaiting confirmation

> **Status: plan only, 2026-10-18. Nothing is deleted or built from this until Raviteja confirms.**

Grounded in current `main` (`950190c`) and `docs/review-2026-10/ACTION_PLAN.md`.

## Recommendation

Yes to replacing the reports code, no to a general "any requirement" report engine.

- **Replace the report data layer, don't evolve it.** It is mostly unreachable, and 11 of its 12 services break money rules 2 and 3 (details below). Patching that is more work than a small correct core. The recent fixes (#1043, #1044, #1057) touched FY and performance output and are not worth preserving as structure; their tests are, as acceptance tests for the new core.
- **Don't delete first.** Build the new core behind a flag, move each notification onto it, then delete the old services in the same PR that replaces them. This is what A66 (#813) already plans, so it stays on the plan.
- **Build a narrow "digest engine", not a DIY report builder.** A handful of composable blocks (money in, coming up, movers, goals, to-do) rendered four ways: report screen, notification text, share card, and later PDF/CSV. The DIY builder, report cache and the 8-card Reports tab go.
- **First thing to ship is the monthly digest** (A47, #790), because it is the one report with a retention hypothesis and a success metric already in the plan.

## Why summary taps land on the home screen

The Reports tab flag defaults to off (`lib/core/providers/feature_flags_provider.dart:27-28`). The router sends any `/reports` route to `/` while it is off (`lib/core/router/app_router.dart:101-107`). Summary payloads open `/reports/builder?...` (`lib/core/notifications/notification_navigator.dart:377-407`), so every weekly and monthly tap is redirected home. A29 (#780) already names this.

The notifications themselves are also weak: fixed text with no facts ("Check your investment activity for this week"), maximum importance, weekly, monthly and check-in all on by default, and the "monthly summary" fires at 18:00 on the last day of the month and opens the income report (`lib/core/notifications/handlers/scheduled_notification_handler.dart:76-137`, `notification_preferences.dart:19-81`).

## What exists

- `lib/features/reports`: about 8,900 lines, 13 services, 8 report types, a DIY builder, a cache, PDF and CSV exporters. Reachable only through the debug flag.
- Only `fy_report_service.dart` converts to base currency. The other services sum native amounts and re-derive invested, returned and XIRR outside `lib/core/calculations` (grep of `batchConvert` and `core/calculations` per service).
- Reusable pieces outside reports: `convertedCashFlowsSnapshotProvider` (A13, one converted snapshot), `CurrentValueCalculator`, `XirrSolver`, `ReturnDisplay`, goal progress, `share_plus`.
- No background execution (no WorkManager, no FCM). Local notifications carry fixed text set at scheduling time.

## Product thinking: what brings people back

Alternative investments change rarely, so a weekly "summary" is mostly empty and trains users to ignore us. People open a money app at **money moments**. Ranked by expected pull:

1. **Payout and maturity heads-up** (forward-looking, exact): "Your FD matures Thursday. It earned 7.4% a year. Reinvest or move it?" Opens to a one-screen report with the decision and a one-tap add-cash-flow. A decision moment, not a summary.
2. **Monthly money-in digest** (A47): received vs expected this month, what is due next month, values that need updating. Sent only when there is something to say.
3. **Update-values nudge** (A47): one tap per stale manual valuation, because XIRR is only as good as the current value (rule 4).
4. **FY wrap in March, "your year in returns"** (A47) plus a percentages-only share card (A46 growth loop).
5. **Tax-Year report** (A60, #800): the Premium report, built on the same engine. Digests stay free (A58).

Rules for every message: skip it when there is nothing new, at most one digest a week, default importance, no amounts on the lock screen and none at all in privacy mode (rule 8).

**Key technical point.** Forward-looking facts (payout due, maturity date, stale value) are known in advance, so their text can be composed when the app is open and the alarm rescheduled on every open and every data change. Backward-looking facts ("you received ₹X") go stale for exactly the users we want back, so the notification says only what is certain ("3 payouts landed in October") and the report computes amounts live on tap. No server push and no background job are needed.

## Engine shape

- `ReportSpec`: period (week, month, FY, custom, half-open date ranges per rule 5), scope (portfolio, one investment, one goal), list of block ids.
- `ReportInputs`: one read of the existing converted snapshot, investments, valuations, goals, base currency. No new Firestore listeners (A62).
- Blocks are pure Dart functions `Block(inputs, spec) -> BlockResult` that call `lib/core/calculations` only. Starting set: `moneyIn`, `comingUp`, `movers`, `goals`, `toDo`.
- Renderers: `ReportScreen` (one route, `/report/:spec`, outside the Reports tab and behind its own flag), `NotificationComposer`, `ShareCard` (percent only), exporter (with A60).
- Deep links carry only the spec id and period, never names or amounts (rule 7). Analytics: `report_opened{source}`, `digest_sent{type}`, so A47's D30 comparison can be measured.

## Phases

| Phase | What ships | Deletes | Size |
|---|---|---|---|
| 0 | A29 slice: summary notifications get default importance and stop pointing at a hidden route (open Overview or don't schedule) | nothing | S |
| 1 | Engine core, three blocks, monthly digest screen and notification behind a flag; mock in `design/system` first; golden tests to the paisa | weekly and monthly summary services, DIY builder, report cache | M |
| 2 | Maturity and payout heads-up, update-values nudge, on the same engine | action-required, maturity-calendar services | M |
| 3 | FY wrap and percent-only share card (A46, A47) | smart-insights duplicates | S |
| 4 | Tax-Year report and PDF/CSV (A60, Premium) | the rest of the old reports feature, Reports tab flag (A66) | L |

Each phase is its own PR, ships by flipping its flag default in a release PR, and is measured before the next starts.

## Risks

- **Wrong numbers.** Money rules 1 to 9 apply to every block. Mitigation: blocks only call `lib/core/calculations`, golden tests to the paisa, CodeRabbit review (calculations and notifications are risky paths).
- **Notification fatigue.** Over-sending causes uninstalls. Mitigation: send only when there is news, weekly cap, per-type toggles (A29), measure opt-outs.
- **Lock-screen privacy.** Mitigation: no amounts in notification text by default; privacy mode removes them everywhere.
- **Stale scheduled text.** Mitigation: forward-looking facts only, reschedule on open and on data change.
- **Overlap with open work.** A29 (#780), A47 (#790), A60 (#800), A66 (#813) cover parts of this. This plan sequences them; it should not run in parallel threads on the same files.

## Not doing

A configurable report builder, a fifth tab, server-side push, or AI-written summaries. None of them has a retention hypothesis, and each adds privacy or cost risk.
