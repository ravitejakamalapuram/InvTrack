# InvTrack review and action plan (October 2026)

This plan comes from a full review of the InvTrack codebase, store listing and docs as of `f08e452` (v3.70.18). It covers the questions asked: issues, improvements, formula corrections, marketing, user adoption, and a plan of action items.

**At a glance:** 280 verified findings (8 critical, 54 high, 121 medium, 97 low) are grouped into **68 action items** across 8 phases. The full evidence (file:line, worked numbers, verifier notes) for every finding is in [FINDINGS.md](FINDINGS.md).

**The short version.** The engineering foundations are good: the analyzer is clean, all 1,477 tests pass, and the XIRR solver itself is correct. But the numbers users see are wrong for the app's core use case. Open investments have no current value, so healthy FDs show −95% returns. A silent USD default inflates INR data about 88×. FIRE and goal progress use the wrong inputs. Meanwhile the live store listing makes a false privacy claim, guest and deletion flows can lose data or leave PII behind, and the features that would retain and monetise users ship switched off. Fix trust and correctness first (P0–P1, about 5 weeks), then relaunch the listing and activation flow, then launch Premium before the 2027 tax season.

## The ten things that matter most

| # | Severity | Issue | What is happening | Findings |
|---|---|---|---|---|
| 1 | critical | **Healthy open investments look like losses** | No investment has a current value, so XIRR, MOIC and return % count only the cash that has come back. A ₹10L FD earning 7% shows about −95% return and −98% XIRR on the home screen. This hits every open FD, bond, P2P loan and chit fund, which is most of what users track. | CALC-01, ANLY-01, ADOPT-08, UX-03 |
| 2 | critical | **The Play listing makes a false privacy claim** | The live listing says “We don't store your financial data on our servers.” All data is stored in Cloud Firestore. The listing workflow re-publishes this file on every sync. This is a Google Play User Data / Deceptive Behaviour policy risk. | SEC-01, MKT-01, QA-02 |
| 3 | critical | **A missing currency silently defaults to USD** | A missing currency becomes 'USD' in 15+ places: CSV import, ZIP restore, Firestore reads and merge. ₹1,00,000 is stored as $1,00,000 and shown as ₹83–88 lakh on Overview, FIRE and Goals. Merging two INR investments permanently re-tags every flow as USD. | ARCH-01, INV-01, PLAT-07, QA-03 |
| 4 | critical | **FIRE progress counts every rupee ever invested** | The FIRE corpus is lifetime gross INVEST + FEE. One ₹10L FD rolled over yearly since 2020 shows ₹71.5L, 39% progress and “On Track, age 36”. The real figures are ₹14.0L, 7.7% and “Behind”. | PLAN-01, CALC-03, PLAN-02 |
| 5 | critical | **Goal progress counts only money received back** | A ₹10L corpus goal funded by a ₹10L FD shows 13.1% and “On track for Sep 2038” because only interest received is counted. Income goals inflate an annual coupon 12× and can show “Goal Achieved” wrongly. | PLAN-08, PLAN-09 |
| 6 | high | **Guest data and account deletion** | A guest who taps Sign Out loses everything behind a generic prompt, and the FAQ wrongly promises cross-device access. ‘Delete account’ wipes data, then usually fails to delete the Auth record. The web deletion link Play requires does not exist. | PLAT-01, PLAT-04, SEC-02, SEC-03 |
| 7 | high | **App lock can be bypassed** | Tapping a notification pushes investment screens above the PIN lock, and the portfolio flashes on screen before the lock appears at cold start. | PLAT-05 |
| 8 | high | **Reminders that never fire, or never stop** | Income reminders reset to “now + N months” on every launch, so engaged users never get them. Turning a reminder type off does not cancel alarms already scheduled. After sign-out, the previous user's notifications stay on the device. | INV-06, PLAT-10, GAP3-01, GAP3-02 |
| 9 | high | **First-run activation dead ends** | Add Investment asks for no amount, then drops the user back on the same empty state. Reaching the first real number takes about 22 taps. ‘Try Sample Data’ shows a −97% XIRR, and the demo claims compounding lowers a 7% FD to 6.2%. | UX-02, ADOPT-07, ADOPT-03 |
| 10 | high | **No revenue, and the best features are hidden** | There is no billing SDK and the paywall is a mock that grants Premium free. Reports, Health Score, Income Guardian and the Play review prompt default to OFF and are reachable only through a 7-tap debug menu. | MON-01, MON-07, PLAT-16, MKT-03 |

## Critical path

| When | Action items |
|---|---|
| Week 1 | A01 listing · A02 policy and deletion page · A03 USD default · A05 guest sign-out · A06 delete account · A08 reminders · A09 bridge display fix |
| Week 2 | A04 USD repair prompt · A07 app-lock bypass · A22 edit-clears-fields · A42 review prompt on · A51 listing copy |
| Weeks 2–5 | A10 current value (the big one) → A11 FIRE · A12 goals · A13 one converted snapshot · A19 golden tests |
| Weeks 4–8 | A14 FX · A17 archive · A23–A28 integrity · A32 App Check · A34 remove ads/AD_ID · A40 first-investment flow · A41 funnel |
| Weeks 6–12 | A20 honest samples · A52 screenshots · A55 landing page · A56 channel plan · A42 Health Score on · A46 growth loops |
| Dec – Feb | A58 pricing · A59 billing · A60 Tax-Year report → Premium launch before the 15-Mar advance-tax date |
| By May 2027 | A39 DPDP-complete notice · A36 deletion pipeline · A50 localisation groundwork |

## Formula corrections

Each row was checked by porting the Dart code to Python and comparing it with an independent reference implementation.

| Metric | What the app does | Correct approach | Example | App shows | Correct | Findings |
|---|---|---|---|---|---|---|
| Per-investment XIRR / MOIC / return (open) | Recorded cash only; no terminal value for open positions | Add a dated current value V as a terminal inflow: Σ CFᵢ/(1+r)^(tᵢ) + V/(1+r)^(t) = 0 | ₹1L FD, 7.5% quarterly payouts, 2 yrs | −75.7% · 0.15× | +7.71% · 1.15× | CALC-01 |
| Portfolio (hero) XIRR / return % | Same; plus an unlabelled ‘approximate’ fallback | Merged flows + terminal values of open investments; label approximations | ₹10L FD @7%, 3 quarterly payouts | −99.3% XIRR · −94.8% | +7.18% | ANLY-01, CALC-06 |
| FIRE current corpus | stats.totalInvested (lifetime INVEST+FEE, closed included) | Σ current value of open investments (fallback Σ max(0, invested − principal returned)) | ₹10L FD rolled over yearly since 2020 | ₹71.5L · 39.1% · ‘On Track’ | ₹14.0L · 7.7% · ‘Behind’ | PLAN-01, CALC-03 |
| FIRE monthly savings | totalInvested ÷ ((last flow − first flow)/30 days) | Trailing-12-month net new money, or user-declared SIP | Two ₹5L investments 10 days apart | ₹30,00,000 / month | Declared SIP or ‘not enough history’ | PLAN-02 |
| Projected FIRE age (no new savings) | Hard-coded 100; date = ceil(years) | n = ln(FV/PV) / ln(1 + r/12); date = today + n months | ₹50L corpus, ₹1.83Cr target, 5.66% real | Age 100 | Age 53 | PLAN-03 |
| FIRE status & advice | Fixed progress thresholds; ‘Invest \|gap\| more’ even when gap < 0 | Projected age vs target age; advice only when gap > 0 | Age 28, saving ₹60k vs ₹10.8k needed | ‘Behind · invest ₹49.2K more’ | ‘Ahead · FIRE at 40’ | PLAN-04 |
| FIRE number multiple | core/SWR + 6 months + 20% healthcare, labelled ‘25×’ | Show the breakdown and the real multiple (or drop hidden buffers) | ₹50k/month expenses | ₹1.83Cr labelled 25× | 30.5× shown honestly | PLAN-06 |
| Corpus goal progress | Σ RETURN + INCOME (money back only) | Current value of linked open investments (+ realised) | ₹10L goal funded by a ₹10L payout FD | 13.1% · ‘Sep 2038’ | 100% | PLAN-08 |
| Income goal monthly income | Σ INCOME ÷ months between first and last payout | Trailing-12-month INCOME ÷ 12 (open investments only) | ₹75,000 annual coupon | ₹75,000 / month · ‘Achieved’ | ₹6,250 / month | PLAN-09 |
| Goal required contribution | Not computed (FAQ promises it) | PMT = (FV − PV·(1+r)ⁿ)·r / ((1+r)ⁿ − 1) | ₹10L in 36 months at 8% with ₹2L saved | — | ₹18,402 / month | PLAN-08 |
| MOIC / absolute return with rollovers | Σ outflows vs Σ inflows (recycled capital double-counted) | Paid-in = peak cumulative net outflow; MOIC = (distributions + value) ÷ paid-in | ₹10L FD rolled over once, 2 yrs | 1.075× · 7.5% | 1.156× · 15.6% | CALC-07 |
| FD maturity (no compounding chosen) | Annual compounding default | Quarterly default for bank FDs; full quarters + simple interest on residual days | ₹1L, 7%, 5 years | ₹1,40,255 | ₹1,41,478 | CALC-08 |
| RD maturity | Lump-sum formula | M = Σₖ I·(1+r/4)^((n−k)/3) | ₹1L over 12 months, 6.5% | Interest ₹6,660 | Interest ₹3,572 | CALC-08 |
| FY capital gains | 10% of every RETURN, one 365-day rule | Gain only on assets sold above cost; interest at slab; post-Jul-2024 holding periods & rates | ₹5L FD maturing at ₹5.4L | ₹54,000 capital gain | ₹0 CG + ₹40,000 interest | CALC-09 |
| FY window | (31-Mar 00:00, 1-Apr 23:59) — overlapping | Half-open [1 Apr, 1 Apr) on local dates | Flow on 1 Apr 2025 00:00 | Counted in two FYs | Counted once (FY25-26) | CALC-10, QA-01 |
| FY XIRR | In-year flows only | Opening value as outflow at FY start, closing value as inflow at FY end | Income-only year | Null → 0 | Period money-weighted return | CALC-10 |
| Health ‘returns’ component | Invested-weighted average of per-investment XIRRs | One merged-flow portfolio XIRR (with valuations) | ₹10L @8% 1 yr + ₹10k +3% in 30 days | 8.35% (simple avg 25.6%) | 8.02% | CALC-02 |
| Short-holding annualisation | Annualised regardless of period; >1000% shown as ‘0.0%’ | Absolute return primary under 90 days; ‘>1000%’; ‘approx.’ label | 3-day 2% invoice discount | ‘0.0%’ | ‘+2.0% in 3 days’ | CALC-06 |
| XIRR day count | Floors ms differences of non-normalised local times | Date-only UTC days ÷ 365 (Excel parity) | 21:30 invest → +8% exactly a year later | 8.0228% | 8.0000% | CALC-11 |
| Year-over-year card | Calendar YTD net vs full previous year net | Same-period comparison, FY-aligned; colour by income, not net cash | Invested more this year | ‘−53% vs last year’ in red | Like-for-like income growth | ANLY-09 |
| Currency default | Missing currency → 'USD' | Missing currency → user's base currency | ₹1,00,000 CSV row, no currency column | ≈ ₹88,00,000 | ₹1,00,000 | ARCH-01, PLAT-07 |
| FX fallback | Whole batch falls back; unconverted amounts summed raw | Per-flow fallback; never sum unconverted; flag approximate | USD 10,000 when one rate fails | ₹10,000 | ≈ ₹8,80,000 | ANLY-02 |
| Indian compact format | intl compact, 3 sig. digits | Custom L/Cr formatter with promotion at 100 L | 9,994,999 · 99,999 | ‘₹0.999Cr’ · ‘₹1L’ | ‘₹99.95 L’ · ‘₹99,999’ | ANLY-11 |
| Sample-data / demo claim | Open sample FD with no value; demo says compounding lowers 7% to 6.2% | Valued samples; compounding raises effective yield | 7% quarterly FD | −97% XIRR · ‘6.2%’ | 7.19% effective | ADOPT-03 |

## Action plan

Effort: **S** ≤ 1 day, **M** 2–5 days, **L** 1–3 weeks (solo developer).

### P0 · Stop trust and data damage (This week · 2–9 Oct 2026)

_Goal: Nothing false on the store, and no flow that silently destroys or inflates money data._

#### A01 · Correct the Play listing and guard it in CI · effort S

**Why:** Lines 59–63 of full_description.txt contradict each other and the Data safety form. Line 22 still says “NEW IN VERSION 3.6.0”, and the offline claim is overstated.

**Do:**
- Replace the privacy paragraph with a true statement, e.g. “Your data is stored in your InvTrack account on Google Firebase, visible only to you, never sold, no ads. Attached documents stay on your phone. Delete everything any time from Settings.”
- Delete the version-specific block. Qualify offline: “works offline after first sign-in”.
- Run the listing workflow as a dry run, then live.
- Add a CI grep that fails on phrases like “don't store”, “stays with you”, “OWASP compliant”, “WCAG compliant” in android/fastlane/** and README.

**Done when:** The live listing matches the Data safety form, and a CI check blocks the phrases.

**Findings:** SEC-01, MKT-01, QA-02, ADOPT-05, SEC-05, MKT-14, MON-16

#### A02 · One privacy policy, one support email, and a web deletion page · effort S

**Why:** There are two policy URLs and two support emails, and the founder's own notes say the live policy still describes SQLite + Sheets. Play requires a web account-deletion link, and the deletionRequests queue has no processor.

**Do:**
- Publish the corrected policy at one GitHub Pages URL and point the app, app-metadata.json and Play Console at it.
- Pick one monitored support address and use it everywhere.
- Publish a static “Delete your InvTrack account” page (in-app steps, the email address, what is deleted and what is kept, a 30-day SLA) and enter it in Play Console → Data safety.
- Do not ship a web form that writes deletionRequests until the processor job exists (A36).

**Done when:** Play Console, app and README all show the same policy URL and support email, and the deletion URL is registered.

**Findings:** SEC-14, SEC-02, QA-16, QA-21

#### A03 · Remove the silent “USD” default · effort M

**Why:** For an INR-first app, a missing currency becomes USD in the CSV parser (the template says base currency), the import screen, the ZIP restore, the Firestore mappers, the notifier and merge. Amounts then show about 88× too high.

**Do:**
- Default every missing or blank currency to the user's base currency (pass currencyCodeProvider in at parse/import time).
- In mergeInvestments, copy cf.currency on every flow and copy the investment currency plus metadata (maturity, rate, frequency, startDate).
- Add Cash Flow: default to the investment's currency, and bind the prefix and preview symbol to the selected currency.
- Set InvestmentEntity.currency on import and show the resolved currency per row in the import preview.
- Flip the tests that pin USD (simple_csv_parser_test, multi_currency_export_import_test) and add regressions: CSV with no Currency column + INR base → INR; merging two INR investments keeps the sum and currency.

**Done when:** No user-money code path falls back to 'USD', and the regression tests pass.

**Findings:** ARCH-01, CALC-05, INV-01, INV-02, INV-17, INV-V1, PLAT-07, QA-03, PLAN-V1, ADOPT-V1, CALC-V01, UX-14, GAP2-07

#### A04 · Offer a one-tap repair for data already tagged USD · effort M

**Why:** Users who imported, merged or restored before A03 already see inflated totals, and the bad tags are stored in Firestore.

**Do:**
- On launch, find investments whose notes start with “Merged from:”, imported investments whose flows are all USD while the base currency is INR, and documents with no currency field.
- Ask: “We found 3 investments recorded in US dollars. Were these in ₹?” → Fix / Keep. Never rewrite silently.
- Log a repair event to measure how many users were affected.

**Done when:** Every affected user sees the prompt once, and the repair is reversible from the backup taken before it.

**Findings:** ARCH-01, INV-01, QA-03, INV-17

#### A05 · Protect guest data on sign-out and account linking · effort M

**Why:** Anonymous users get a generic “Are you sure?” and lose all data permanently. The FAQ wrongly promises cross-device access. The ‘Backup & Sign In’ path leaves the only backup in a purgeable cache file and opens a route that does not exist.

**Do:**
- For isAnonymous users, show a destructive dialog: primary “Link Google account”, secondary “Export backup”, then “Sign out and lose data”.
- Show the guest data-loss notice as visible text on the sign-in screen, not only as a screen-reader hint, and fix the FAQ (arb:2501).
- Drive backup-and-merge from a provider rather than a widget context. Save the backup somewhere the user can see. Treat a null sign-in as cancel. Auto-import after sign-in, then delete the anonymous user's data.
- Make the UI refresh after a successful link (authStateChanges does not emit on link).

**Done when:** A widget test shows a guest cannot reach sign-out without seeing the link and export options, and the merge flow imports the data.

**Findings:** PLAT-01, PLAT-02, SEC-03, UX-01, ADOPT-06, PLAT-13

#### A06 · Make ‘Delete account’ delete the account · effort S

**Why:** Data is wiped first. Re-authentication then fails because Google Sign-In is never initialised on this path, so the Auth record (email, name, photo) survives and the app says “cancelled”.

**Do:**
- Await googleSignInInitializedProvider before re-authenticating.
- Re-authenticate before any destructive step, then delete the data, then delete the Auth user.
- Show accurate success and failure messages.
- Later: move deletion server-side (Admin SDK recursiveDelete + deleteUser) through the deletionRequests job.

**Done when:** An integration test with a stale session deletes both the data and the Auth user.

**Findings:** PLAT-04, SEC-15, UX-21

#### A07 · Close the app-lock bypass · effort M

**Why:** Notification taps push InvestmentDetail and AddCashFlow imperatively above /lock, and SecurityState starts unlocked, so the portfolio renders before the lock.

**Do:**
- Start SecurityState as unknown/locked until secure storage resolves, mirroring a has_pin flag in SharedPreferences.
- Queue notification navigation while locked and replay it after unlock.
- Make investment detail and add-cash-flow GoRoutes so the redirect guard applies.

**Done when:** A router test confirms a notification tap while locked lands on /lock, and the target opens after unlock.

**Findings:** PLAT-05

#### A08 · Fix reminders that never fire or never stop · effort M

**Why:** rescheduleAllNotifications runs on every launch and drops lastIncomeDate, so income reminders always move to “now + N months”. Opt-out toggles only write prefs. Sign-out leaves the previous user's alarms, which include investment names and amounts.

**Do:**
- Pass the last INCOME date per investment into rescheduleAll (anchor on startDate if none), and skip investments whose schedule inputs have not changed.
- Reschedule after an INCOME flow is added, edited or deleted.
- Cancel scheduled notifications by type when a toggle is turned off. Call cancelAll on sign-out and on account deletion.
- Make the income-reminder tap pre-select INCOME, not INVEST.

**Done when:** A unit test shows two launches a week apart do not move the next reminder date, and toggling off removes pending alarms.

**Findings:** INV-06, PLAT-10, GAP3-01, GAP3-02, PLAT-03, INV-12

#### A09 · Stop showing −100% for healthy open investments (bridge fix) · effort S

**Why:** Until A10 lands, every open FD, bond or P2P loan shows a red −100% or −98% XIRR and 0.00x MOIC. This is the first number new users see.

**Do:**
- When an open investment has no inflows, or no terminal value, show “Awaiting first payout” instead of a % badge, and show XIRR as “—” with the hint “Add a payout or current value to calculate”.
- Rename the hero headline to “Net cash flow so far”, and when a rate is known show “Projected at maturity ₹1,23,144 (7.19% p.a.)” from InvestmentProjector.
- Return a result type from the XIRR solver (exact / approximate / undefined): label approximate results “approx.”, show “>1000%” instead of “0.0%”, and show absolute return as the primary figure for holdings under 90 days.

**Done when:** No open investment shows a negative XIRR purely because it has not paid out yet.

**Findings:** UX-03, ANLY-01, CALC-06, CALC-15

### P1 · Make every number right (Weeks 2–5 · 9 Oct – 6 Nov)

_Goal: Every figure on every screen comes from one correct, converted, tested calculation._

#### A10 · Give open investments a current value · effort L

**Why:** The PRD planned a ‘Current Value’ type, but the code has none. Without it XIRR, MOIC, return %, portfolio XIRR and the health score are wrong for the app's core use case.

**Do:**
- Add a dated valuation entry per investment, kept separate from cash flows.
- Estimate it automatically: cumulative FD/RD = P × (1 + r/n)^(n·t); payout FD, bond or P2P = outstanding principal. Let users override it, and ask for a manual value for gold, SGB, property and private deals.
- Use it as the terminal inflow at its date: XIRR solves Σ CFᵢ/(1+r)^((dᵢ−d₀)/365) + V/(1+r)^((t−d₀)/365) = 0. Apply it to MOIC, absolute return, portfolio XIRR and the health score.
- Show “Expected XIRR (based on 7% p.a.)” until the valuation is user-confirmed, and show “Realised” and “Expected” side by side.

**Done when:** Golden tests from CALC-01 pass: S1 7.19%, S2 7.71%, S3 12.67% and S4 8.73% (±0.01pp).

**Findings:** CALC-01, ANLY-01, ADOPT-08, UX-03, GAP3-14

#### A11 · Rebuild the FIRE inputs and status · effort M

**Why:** The corpus is lifetime gross invested and savings is totalInvested ÷ (span ÷ 30 days). Age is frozen at setup. The status ignores the timeline. The UI says 25× while the formula is 30.5×. FIRE money has no currency.

**Do:**
- Corpus = Σ current value of open investments (A10), with fallback Σ max(0, invested − principal returned) per open investment, plus an optional ‘other assets’ field.
- Monthly savings = trailing-12-month net new money, or a user-declared SIP. Show “not enough history” under 3 months.
- When savings = 0, solve n = ln(FV/PV) / ln(1 + r/12) instead of returning age 100. Build the date by adding months, not by rounding up years.
- Status = projected age vs target age. Render “Invest X more” only when the gap is positive.
- Store birth year instead of current age. Show the corpus breakdown and the real multiple, or drop the hidden buffers. Remove dead inputs and Coast/Barista types or implement them. Store the currency on FIRE settings and convert it on a currency switch.

**Done when:** The PLAN-01..04 scenarios give the correct values in tests, e.g. the rollover user shows 7.7% and “Behind”.

**Findings:** PLAN-01, PLAN-02, PLAN-03, PLAN-04, PLAN-05, PLAN-06, PLAN-07, CALC-03, ARCH-03, MKT-V-03, GAP2-01, UX-10

#### A12 · Rebuild goal progress · effort M

**Why:** Corpus goals count only RETURN + INCOME, and income goals divide by the span between the first and last payout. Projections are linear and mix units. Goals mix currencies, and one investment counts fully in every goal it matches.

**Do:**
- Corpus goal = current value of linked open investments (A10), or deployed capital plus accrual.
- Income goal = trailing-12-month INCOME ÷ 12, from open investments only.
- Add “required per month”: PMT = (FV − PV·(1+r)ⁿ)·r / ((1+r)ⁿ − 1), and project with compounding.
- Convert every goal path, including notifications and reports. Pass targetMonthlyIncome to income-goal milestones.
- Show an “also counted in N other goals” chip. Fix GoalEntity equality so goal edits refresh. Show linked investments, including archived ones, on goal details.
- Use one rounding rule for goal % everywhere.

**Done when:** The G1–G5 scenarios in PLAN-08/09 pass, and a goal funded by a ₹10L FD shows 100%.

**Findings:** PLAN-08, PLAN-09, PLAN-10, PLAN-11, INV-V2, GAP1-06, GAP1-07, GAP1-09, GAP1-10, GAP3-07

#### A13 · One converted stats snapshot for every screen · effort M

**Why:** List cards, sorting, ‘recently closed’, Overview charts, archived screens and cash-flow rows use raw native amounts under the base-currency symbol. A $1,000 → $1,100 investment shows +₹100 on the card and +₹13,000 on the detail screen.

**Do:**
- Convert validCashFlows once per snapshot with the existing batchConvert and feed the result to the basic-stats map, the XIRR map, the analytics providers, recently-closed and archived stats.
- Delete the deprecated raw providers so nothing can fall back to them.
- Print each cash-flow row in its own currency, and show the converted base value next to it.

**Done when:** A test with a USD investment shows identical net and XIRR on the card, the detail screen, the archived view and in sort order.

**Findings:** CALC-04, INV-03, ARCH-02, ANLY-04, GAP1-03, INV-16, ANLY-12, ARCH-22

#### A14 · Harden the FX pipeline · effort M

**Why:** One missing rate makes the whole batch fall back to an arbitrary cached rate or to raw foreign amounts (an implicit 1.0 rate). AED and SAR, the main NRI currencies, have no historical source. A currency switch costs about 1,100 reads.

**Do:**
- Return partial results plus a failures list from batchConvertHistorical, and fall back only for the failed keys: nearest-date cached rate, then live rate.
- Never sum an unconverted amount. Exclude it, set isApproximate, and show a banner.
- Derive AED (3.6725) and SAR (3.75) from USD crosses, or move to Frankfurter v2. Restrict the selectable base currencies to supported ones.
- Coalesce historical lookups, keep the latest rate per pair, add the exchangeRates (from, to, fetchedAt) index, parse with (x as num).toDouble(), and stop wiping the cache on a switch.

**Done when:** A test with an AED flow among INR and USD flows converts every flow at its own date's rate.

**Findings:** ANLY-02, ANLY-03, ARCH-04, ANLY-V1, ARCH-11, ANLY-10, GAP4-04, GAP4-05

#### A15 · Fix paid-in capital, fee disclosure, date normalisation and rounding · effort S

**Why:** A rolled-over FD doubles ‘invested’, so MOIC reads 1.075× instead of 1.156×. Time-of-day dates make the XIRR day count 364 instead of 365. Float sums can flip the sign of a break-even position.

**Do:**
- Paid-in capital = peak cumulative net outflow (or net same-day RETURN/INVEST pairs). MOIC = (distributions + current value) ÷ paid-in.
- Say in the UI that fees are part of invested.
- Normalise every cash-flow date to a date-only UTC value on save and in the solver.
- Round money to paisa when comparing and displaying.

**Done when:** The rollover golden test gives MOIC 1.156× and the date-only XIRR matches Excel to 1e-6.

**Findings:** CALC-07, CALC-11, CALC-13, CALC-12

#### A16 · Correct the FD and RD projector · effort S

**Why:** The projector defaults to annual compounding when none is chosen and uses the lump-sum formula for RDs (overstated 1.86×). Tenure is months only, and month arithmetic overflows (Jan 31 + 1 month = Mar 3).

**Do:**
- Default FD compounding to quarterly.
- Use the RD formula M = Σₖ I·(1 + r/4)^((n−k)/3).
- Compound full quarters and pay simple interest on the remaining days. Accept tenure in days (e.g. 444).
- Clamp month-end dates.

**Done when:** Tests pass: 5-year 7% FD = ₹1,41,478 per lakh; 12-month 6.5% RD interest = ₹3,572.

**Findings:** CALC-08, PLAN-15

#### A17 · Make archive hide, not erase history · effort M

**Why:** Archived investments vanish from lifetime totals, realised P&L, YoY, goals (often down to 0% / ‘Not Started’), FIRE, Health and the FY/tax report, but the dialog says it only hides them.

**Do:**
- Add lifetime providers (active ∪ archived) for historical aggregates. Keep current-holdings views on active-open data.
- Warn before archiving an investment that is linked to a goal.
- Change the dialog copy to: “Archive hides this investment from your lists and reminders. Its history still counts in totals, goals and reports.”
- Do not re-schedule reminders when a closed investment is unarchived, and sort ‘Recently closed’ by closedAt.

**Done when:** A test shows totals, goal % and the FY report are unchanged before and after archiving.

**Findings:** GAP1-01, GAP1-02, GAP1-04, GAP1-05, GAP1-11, GAP1-12, GAP1-13

#### A18 · Fix number formatting · effort S

**Why:** Some locale mappings print Bengali or Arabic digits in an English UI, and the en_IN compact format gives ‘₹0.999Cr’, ‘₹1KCr’ and 99,999 → ‘₹1L’. TalkBack reads Western grouping.

**Do:**
- Use Latin-digit number locales for every currency, with the symbol supplied separately.
- Write a custom Indian compact formatter (L/Cr, 2 decimals, promote 100.00 L to 1.00 Cr) with boundary golden tests.
- Use the same formatter for semantics labels and notifications.

**Done when:** Boundary tests pass for 99,999 / 9,994,999 / 1e10 and in every supported locale.

**Findings:** ANLY-11, UX-08, PLAT-18, GAP2-03, UX-V02

#### A19 · Add golden-number tests and gate bot PRs on them · effort M

**Why:** Tests use loose ranges (±1–2pp) and in places lock in wrong behaviour. A bot ‘optimisation’ PR introduced the FY boundary double-count, and agent PRs touch financial code without new tests.

**Do:**
- Add Excel-parity XIRR tests pinned to 1e-6, plus every scenario quoted in this plan (open FD, rollover, FIRE, goals, FY windows, RD).
- Require an added or updated test for any PR touching lib/core/calculations, goals, FIRE or reports. Do not auto-merge agent PRs (Bolt/Sentinel/Palette) on those paths.

**Done when:** CI fails if a calculation file changes without a test change. The golden suite covers every formula in the table below.

**Findings:** CALC-14, PLAN-16, QA-09, QA-11, QA-01

#### A20 · Make the sample data and the demo honest · effort S

**Why:** ‘Try Sample Data’ shows a −97% XIRR FD and a −100% SGB. The empty-state demo says compounding lowers a 7% FD to 6.2%, but compounding raises it to 7.19%.

**Do:**
- Rebuild the samples so each one is either closed or valued (A10).
- Lead the ‘advertised vs real’ demo with P2P (12% advertised, about 6.3% after fees and one default), or use an after-tax FD.
- Fix the caption, and add a test that keeps every sample XIRR between 0% and 20%.

**Done when:** The sample portfolio shows a positive, believable XIRR, and the test enforces it.

**Findings:** ADOPT-03

#### A21 · Fix the Health score and Year-over-Year card · effort S

**Why:** Returns are an invested-weighted average of per-investment XIRRs (and negative because of CALC-01). An empty portfolio gets free points. The YoY card compares year-to-date with the whole previous year and shows investing more as a red decline. The score shows ‘80’ next to the ‘Good’ tier.

**Do:**
- Use merged-flow portfolio XIRR with valuations for the returns component.
- Return ‘not enough data’ for empty or partial portfolios, and don't save partial scores.
- Compare like-for-like periods (FY-to-date vs the same span last FY) and show invested, income and net separately.
- Use one rounding rule for the score and its tier.

**Done when:** A single-FD portfolio scores sensibly, and the YoY card shows same-period figures.

**Findings:** CALC-02, ANLY-07, ANLY-09, ANLY-16, ANLY-08, PLAN-14

### P2 · Data integrity and reliability (Weeks 3–8 · Oct – Nov)

_Goal: No edit, import, merge, archive or restore can lose or corrupt data, and the app behaves offline._

#### A22 · Let edits clear optional fields · effort S

**Why:** copyWith uses `x ?? this.x`, so clearing the maturity date, notes, rate or frequency silently keeps the old value, and the reminders come back on the next launch.

**Do:**
- Build the updated entity explicitly from the form, or add clear flags to copyWith.
- Add a regression test: editing with maturityDate = null persists null.

**Done when:** A cleared field stays cleared after a restart.

**Findings:** INV-05

#### A23 · Make delete, merge and archive cascade safely · effort M

**Why:** Delete, bulk-delete and merge orphan documents, reminders and goal links. Archive commits more than 500 operations in one batch. An archived investment's screen writes to the active collection, and after unarchive a stale entity lets Delete silently do nothing.

**Do:**
- Chunk batches to 500 operations.
- Cascade to documents, expected cash flows, goal links and notifications.
- Make the archived detail screen read-only, and pop or refresh it after unarchive.
- Add tests for archive, unarchive, bulkDelete and bulkImport.

**Done when:** An emulator test with 300 flows archives, unarchives and deletes with no orphans.

**Findings:** INV-04, INV-07, INV-09, INV-10, ARCH-20, QA-05, INV-14

#### A24 · Make backup and restore lossless and safe · effort M

**Why:** The ZIP drops investment metadata and currencies, merges same-name investments, splits multi-line notes, and ‘Replace’ deletes everything before validating. It also carries no base currency or FIRE currency.

**Do:**
- Add investments.json with full entities and IDs, plus a schemaVersion, base currency and FIRE currency.
- Import by ID, and use a CSV decoder that handles quoted newlines.
- For Replace, validate everything in memory first and take an automatic backup before replacing.

**Done when:** A round-trip test (export → wipe → import) reproduces every field.

**Findings:** PLAT-09, GAP2-02

#### A25 · Make CSV import robust · effort M

**Why:** 2-digit years import as year 0005 or 0024. One row can flip dd/MM to MM/dd for the rest of the file. ‘1.234,56’ parses as 1.23. There is no duplicate detection, and ‘p2p’ maps to Other.

**Do:**
- Detect the date format once per file from every cell, add 2-digit-year patterns, reject years before 1950 or far in the future, and ask when day/month is ambiguous.
- Handle decimal commas and fix the type mapping.
- Warn on likely duplicates (same date, amount and name).
- Make the tests check parsed values, not row counts.

**Done when:** The PLAT-08 fixtures parse correctly, and re-importing the same file warns about duplicates.

**Findings:** PLAT-08, PLAT-15, QA-10

#### A26 · Make saves offline-first and non-blocking · effort M

**Why:** Every write waits up to 3 s for server acknowledgement. Each cash-flow save pulls all goals, investments and flows from the server. Swipe actions fire and forget and show success regardless.

**Do:**
- Treat a local write as success and surface sync errors asynchronously.
- Check goal milestones from cached providers after the save.
- Await swipe actions, and show success or failure accurately.

**Done when:** Adding a cash flow in airplane mode is instant, and nothing reports success before the operation finishes.

**Findings:** ARCH-V02, ARCH-06, INV-11, INV-08, UX-25

#### A27 · Stop rebuilding the router · effort M

**Why:** GoRouter is recreated on every auth, lock, onboarding or flag change, which resets navigation to ‘/’ and discards open forms. Auto-lock wipes unsaved input.

**Do:**
- Create one GoRouter with refreshListenable, and move state into the redirect.

**Done when:** Locking and unlocking keeps the navigation stack and form state.

**Findings:** PLAT-06, ARCH-07

#### A28 · Separate loading and error from empty · effort S

**Why:** Overview shows the first-run empty state, and offers ‘Try Sample Data’ that writes into the real account, while data loads or after an error. Goals show 0% / ‘Not Started’ on error, and empty_state_viewed is logged falsely.

**Do:**
- Propagate AsyncValue loading and error states instead of substituting [].
- Show skeletons while loading and a retry message on error. Never offer sample data to an account that has data.

**Done when:** A cold start with a slow network shows skeletons, never the empty state.

**Findings:** ARCH-05, UX-15, UX-V01, ADOPT-11, GAP1-08, ARCH-16, UX-23

#### A29 · Clean up the notification system · effort M

**Why:** Taps from a killed app are dropped. Summary taps go to the hidden Reports route. Tax reminders move depending on the day the app was opened. IDs collide. Seven types are on by default with no opt-out. Nudges use maximum importance. Amounts appear on the lock screen. In-app updates nag on every resume.

**Do:**
- Handle getNotificationAppLaunchDetails, and don't schedule summaries for routes that are disabled.
- Give every type a toggle (store prefs per account), use deterministic non-colliding IDs, use default importance for nudges, and respect privacy mode in notification text.
- Use flexible in-app updates with staleness thresholds.
- Delete the dead risk and idle alerts, and remove the unverified ‘thousands of investors’ claim.

**Done when:** Each notification type has an off switch that works, and every tap lands on a real screen.

**Findings:** PLAT-11, PLAT-12, PLAT-17, GAP3-03, GAP3-04, GAP3-06, GAP3-08, GAP3-10, GAP3-11, GAP3-12, GAP3-13, ADOPT-09, SEC-17, UX-05, MKT-V-01, GAP2-08, UX-09

#### A30 · Make Crashlytics signal honest · effort S

**Why:** LoggerService.error records FATAL crashes, including offline timeouts. Uncaught async errors are recorded twice. Document names and device paths are sent to Crashlytics.

**Do:**
- Record logged errors as non-fatal and deduplicate the zone and platform handlers.
- Strip names, paths and amounts from logs and custom keys.

**Done when:** The crash-free rate reflects real crashes, and a PII grep over Crashlytics keys is clean.

**Findings:** ARCH-15, ARCH-V01, SEC-09

#### A31 · Wire up currency detection and per-account settings · effort S

**Why:** ProfileInitializer is never mounted, so every user worldwide starts in INR. Base currency, notification opt-outs and privacy mode are device-local and reset on a new phone.

**Do:**
- Mount locale detection on first run, with a confirm step.
- Store base currency and preferences in the user's profile document.
- Show a picker with every supported currency, scrollable.

**Done when:** A US-locale first run proposes USD, and settings survive a reinstall.

**Findings:** PLAT-14, ADOPT-V2, UX-13, GAP2-04

### P3 · Security and privacy hardening (Weeks 4–10 · DPDP deadline 13 May 2027)

_Goal: The app is safe to scale. It meets Play's User Data rules now and India's DPDP Rules before enforcement._

#### A32 · Add App Check, rule validation and budget alerts · effort M

**Why:** There is no App Check, and anonymous sign-up is open. Rules allow any write under users/{uid}, with no allow-list, type checks or size limits. One scripted account could run up a large bill.

**Do:**
- Add firebase_app_check with Play Integrity: monitor for 1–2 weeks, then enforce.
- Allow-list subcollections, validate types and cap string lengths in the rules, with emulator tests.
- Set GCP budget alerts at $10, $50 and $200.

**Done when:** Over 99% verified requests in App Check, rules tests reject unknown collections, and an alert fires in a test.

**Findings:** SEC-12, GAP4-02

#### A33 · Encrypt backups · effort M

**Why:** The full-portfolio ZIP, including attached KYC and statement files, is written unencrypted, shared, and left in the cache.

**Do:**
- Add an optional password: AES-GCM with a PBKDF2 or Argon2 key and a random salt and nonce.
- Delete the temp file after sharing, and warn when exporting without a password.

**Done when:** An encrypted backup round-trips, and the cache is empty after sharing.

**Findings:** SEC-06

#### A34 · Remove the ads SDK and Advertising ID, and add consent · effort S

**Why:** google_mobile_ads ships with Google's test App ID and a fake consent flow. AD_ID is collected with no ads. Analytics, Crashlytics and Performance are always on and tied to the user ID.

**Do:**
- Remove google_mobile_ads, the AdMob manifest entry and AD_ID, and update the Data safety form.
- Add Settings toggles for analytics and crash reporting, and honour them at startup.

**Done when:** The release manifest has no AD_ID, and analytics stops when the toggle is off.

**Findings:** SEC-07, SEC-08, MON-04, MON-05, MON-06, ARCH-19, GAP2-06, GAP4-08

#### A35 · Remove debug tools from production · effort S

**Why:** Seven taps on the version number unlock a menu with a real fatal-crash button, demo-data seeding into the real account, and feature-flag toggles.

**Do:**
- Compile the debug menu out of release builds (kReleaseMode), or limit it to an allow-listed UID.

**Done when:** A release build has no reachable debug screen.

**Findings:** GAP3-09, PLAT-16

#### A36 · Finish the deletion and guest-cleanup pipelines · effort M

**Why:** The anonymous-cleanup function cannot be deployed (no package.json or index.ts, no functions block), and its 30-day purge is undisclosed. The deletionRequests processor described in the rules does not exist.

**Do:**
- Either set up functions/ properly and disclose the retention period (consider 180 days), or delete the dead source.
- Build the scheduled deletion job (recursiveDelete users/{uid}, deleteUser, audit entry) with emulator tests.

**Done when:** A queued deletion request is processed end to end in the emulator.

**Findings:** SEC-04, QA-16, SEC-02, GAP4-10

#### A37 · Lock down the device on sign-out and lock · effort S

**Why:** Sign-out leaves the Firestore offline cache, attachments and the PIN on the device. FLAG_SECURE is set only on the passcode screen. The PIN lockout can be bypassed by changing the clock, and a 4-digit PIN is a small keyspace.

**Do:**
- clearPersistence on sign-out, and delete the user's documents directory and PIN.
- Offer FLAG_SECURE app-wide when app lock is on.
- Use monotonic time for the lockout, and allow 6-digit PINs.

**Done when:** After sign-out, nothing from the previous user remains on disk.

**Findings:** SEC-16, SEC-10, SEC-11

#### A38 · Harden CI and the supply chain · effort S

**Why:** The production rules deploy runs firebase-tools@latest with admin credentials from any branch, and there is a curl -k, unpinned reusable workflows, a stray OAuth client file and a global gitleaks allow-list.

**Do:**
- Pin tool versions, restrict deploys to main with environment protection, and remove curl -k.
- Delete the stray client file and narrow the gitleaks allow-list.
- Turn on Dart obfuscation for release builds.

**Done when:** Deploy workflows are pinned and branch-protected.

**Findings:** SEC-13, QA-13, SEC-19

#### A39 · Write a DPDP- and GDPR-complete privacy notice · effort M

**Why:** The in-app policy has five short sections, with no processors (Firebase, frankfurter.dev, exchangerate-api.com), retention periods, grievance contact, rights or cross-border notice. The DPDP Rules are enforceable from 13 May 2027.

**Do:**
- Add processors, purposes, retention, rights, a grievance officer, a consent-withdrawal path and cross-border transfer information.
- Add ToS sections for subscriptions before any paid launch.

**Done when:** The policy covers every DPDP Rule 3 notice item, and the ToS covers auto-renewal and refunds.

**Findings:** SEC-14, MON-12

### P4 · Activation and adoption (Weeks 4–12 · Oct – Dec)

_Goal: A new user reaches a correct, positive real-return number within about two minutes and has a reason to come back every month._

#### A40 · Rebuild the first-investment flow · effort M

**Why:** Add Investment takes no amount, saving drops the user back on the same empty state, activation nudges are cancelled anyway, and reaching the first XIRR takes about 22 taps.

**Do:**
- Add ‘Amount invested’ and a start date (default today) to Add Investment, and create the INVEST flow in the same batch.
- For FD, RD, bond and P2P templates, generate past interest payouts and expected future ones from principal, rate and payout mode. Example: ₹1L at 7.25% quarterly from 1 Jan 2026 creates three ₹1,812.50 rows.
- After saving, open the investment's detail screen with its XIRR or projection card.
- Leave the empty state based on investment count, not cash-flow count.
- Cancel activation nudges only after the first cash flow, and nudge ‘finish setup’ 24 h later if there is still no amount.
- Add Chit Fund and Invoice Discounting templates.

**Done when:** An FD can be added in 3 fields, and the funnel shows first_cashflow within 24 h for the target share of new users (A41).

**Findings:** UX-02, ADOPT-07, ADOPT-13

#### A41 · Instrument the activation funnel · effort S

**Why:** Key steps are not logged, most screens send no screen_view, there are no user properties, and 13 event methods are never called. Activation and retention cannot be measured.

**Do:**
- Log first_open → auth_method → investment_created{has_amount} → first_cashflow → xirr_viewed → goal_created → valuation_updated → account_linked.
- Set user properties: investment_count_bucket, has_goal, is_guest, base_currency.
- Add a screen_view for every route, and delete the dead event methods.

**Done when:** A Firebase funnel report shows every step, with a 2-week baseline before targets are set.

**Findings:** ADOPT-04

#### A42 · Ship the hidden features deliberately · effort M

**Why:** Reports, Health Score, Income Guardian and the Play review prompt all default to OFF. Seven of eight report cards open an empty screen, Income Guardian has no data generator, and summary notifications point at the disabled route.

**Do:**
- Review prompt: turn it on now and widen the trigger to INCOME as well as RETURN, keeping the one-shot gate.
- Health Score: turn it on after A10 and A21.
- Reports: ship only the FY report (A62) and remove the 7 placeholder cards. Delete orphaned report services.
- Income Guardian: hide it, including its settings screen, until something generates expected cash flows. Don't run its background services.
- Use code defaults per release (Remote Config later), never SharedPreferences, for anything gated.

**Done when:** Every visible feature works end to end, and review_prompt_requested appears in production analytics.

**Findings:** PLAT-16, ADOPT-01, ADOPT-02, MKT-02, MKT-03, ARCH-08, ARCH-09, ANLY-05, PLAN-12, PLAN-13, GAP2-05, GAP3-05, GAP4-06, ARCH-10, ANLY-15, PLAN-17

#### A43 · Convert guests at moments of value · effort S

**Why:** The only upgrade path is a button inside Settings, it is untracked, and guests are not told their data lives only on this device.

**Do:**
- After the 3rd investment or the first goal, show “Back up your portfolio: link Google (10 s)”.
- Show a quiet Overview banner for guests, and log account_link_success.

**Done when:** Share of guests linked within 14 days is measured and rising.

**Findings:** ADOPT-06

#### A44 · Explain the jargon where it appears · effort S

**Why:** XIRR, MOIC and ‘Net Position’ are never explained, the tooltip widget is unused, and some in-app copy is wrong (FAQ says the add form asks for an amount, FY label hard-coded to 2023-24).

**Do:**
- Add a one-line ⓘ explanation with an example on each metric.
- Fix the FAQ and the FY label to compute the current FY.

**Done when:** Every metric has an explainer, and the FY label is computed.

**Findings:** UX-18, UX-17, MKT-V-02

#### A45 · Ask for notification permission at the right time · effort S

**Why:** Permission is requested right after sign-in, before the user has anything worth being reminded about.

**Do:**
- Ask after the first investment that has a maturity or payout date: “Get a reminder when this FD pays out?”

**Done when:** The notification opt-in rate is measured and higher than the cold-ask baseline.

**Findings:** UX-22

#### A46 · Build the growth loops · effort M

**Why:** There is no Rate or Share entry, no referral or UTM links, and the only share text (health score) has no link.

**Do:**
- Add ‘Rate InvTrack’ and ‘Share InvTrack’ tiles with UTM-tagged Play links.
- Add a privacy-safe ‘my real XIRR’ card that shows percentages only, never amounts.
- Tag every outbound link with Play referrer UTMs and report first_open by source.

**Done when:** Every channel has attributable installs in Firebase.

**Findings:** ADOPT-10, MKT-13

#### A47 · Create a monthly habit · effort S

**Why:** Alternative investments change rarely, so without a ritual users have no reason to open the app between payouts.

**Do:**
- After A10, send a monthly “Update values” nudge for manually valued assets and a monthly digest of income received vs expected.
- Add an FY-end (March) ‘your year in returns’ push.

**Done when:** D30 retention of users who receive the digest is measured against those who don't.

**Findings:** ADOPT-08

#### A48 · Validate, then build one statement importer · effort L

**Why:** Typing history in is the biggest barrier, and there are no parsers for Indian platforms' statements. Competitors such as P2P Dash built their business on statement imports.

**Do:**
- Use A41 data plus a short in-app or Reddit poll to find the most common platform.
- Build one importer (likely LenDenClub or a bond OBPP) with a matching SEO page, and expand only if adoption is proven.

**Done when:** At least 30% of users who see the importer use it in week 1.

**Findings:** ADOPT-14

#### A49 · Accessibility pass · effort M

**Why:** Core semantic colours fail WCAG AA. TalkBack reads the hero amount even in privacy mode. Sliders announce meaningless percentages. Fixed layouts break at large font sizes, some tap targets are under 48dp, and charts have no text alternative.

**Do:**
- Fix the colour tokens and publish correct ratios.
- Mask semantics labels in privacy mode, and give sliders semantic values.
- Make fixed layouts scrollable, enforce 48dp targets with a test, and add chart summaries.

**Done when:** A WCAG AA audit of the five core screens passes.

**Findings:** UX-04, UX-11, UX-12, UX-19, UX-20, UX-24, ANLY-13

#### A50 · Prepare for localisation · effort M

**Why:** The app supports only English, with 403 hard-coded strings (onboarding, add-cash-flow, every notification), US date conventions and a hard-coded month array.

**Do:**
- Move literals into ARB files as screens are touched, and add a CI lint against new ones.
- Use intl for dates and months, and support en_IN date order.
- Add Hindi once Play Console data shows demand.

**Done when:** Zero new hard-coded strings in CI, and en_IN date formatting throughout.

**Findings:** UX-06, UX-07, ADOPT-16

### P5 · Marketing and store relaunch (Truth fixes week 1 · relaunch from week 6)

_Goal: Store visitors understand in five seconds what InvTrack tracks, and the listing converts._

#### A51 · Rewrite the title, short and full description · effort S

**Why:** ‘InvTrack - Investment Tracker’ competes on a head term dominated by INDmoney and broker apps. The short description never mentions FD, P2P, bonds or chit funds. The full description is stale and leaves out FIRE, CSV import, app lock, guest mode and multi-currency.

**Do:**
- Title (India): “InvTrack: FD & P2P Tracker” (26 chars). Test it against “InvTrack: FD & P2P XIRR App”.
- Short A: “Track FDs, P2P lending, bonds, chit funds & gold in one app. True XIRR returns.” (79). Short B: “Track FDs, P2P lending, bonds & chit funds. See real XIRR, get maturity alerts.” (79)
- Full description outline: hook (170 chars) → what you can track → real returns, with a worked example → never miss a payout → goals & FIRE in today's rupees → made for India, works globally → data in/out → privacy & security (true wording) → what InvTrack is not (not a broker or adviser, no bank or SMS access) → start in 10 seconds (guest mode).
- Run Play store listing experiments on the title and short description. Move the app to the Finance category if it isn't there already.

**Done when:** Store listing conversion is up at least 20% over the 28-day baseline.

**Findings:** MKT-04, MKT-05, MKT-11

#### A52 · Replace the screenshots · effort M

**Why:** The five uncaptioned shots show an all-closed portfolio led by a mutual fund, two of them are the same screen, and the FAB covers content.

**Do:**
- Make 8 captioned frames: “Real returns on FDs, P2P & bonds” · “XIRR that counts every date” · “Never miss a maturity or payout” · “Every alternative investment, one ledger” · “₹1 crore goal? Track it automatically” · “Your FIRE number in today's rupees” · “FY report ready for ITR” (once shipped) · “Hide amounts. Lock with fingerprint.”
- Hide the FAB in the generator, show open positions once A10 exists, and add a 1024×500 feature graphic to the repo.

**Done when:** All 8 slots are filled, and a listing experiment shows the lift.

**Findings:** MKT-06

#### A53 · Fix the icon and the brand name · effort S

**Why:** The source icon carries a Gemini sparkle watermark and its glyph reads as ♂. The brand appears as InvTrack, InvTracker, ‘Investment Tracker’ and inv_tracker.

**Do:**
- Check the Play hi-res icon now, and re-upload a clean one if the watermark is there.
- Commission a ‘money out → money back’ icon.
- Use “InvTrack” everywhere: launcher label, sign-in, app bar, web title, legal text.

**Done when:** No watermark in any shipped icon, and one name everywhere.

**Findings:** MKT-08, MKT-07, UX-16

#### A54 · Write release notes for users · effort S

**Why:** The last two releases shipped stale July developer notes as ‘What's new’, and the changelog tooling leaks CI and refactor commits.

**Do:**
- Filter changelog generation to feat/fix with user-facing scopes, and write a two-line human summary per release.

**Done when:** Every release has a user-language ‘What's new’.

**Findings:** MKT-09, QA-04

#### A55 · Build a web presence: landing page, then one calculator · effort M

**Why:** There is no landing page, the README has no Play link, and the web/ folder is a stale shell. Free calculators are the cheapest SEO funnel for this niche.

**Do:**
- Phase 1: a one-page GitHub Pages site with a Play badge (utm_source=web), honest privacy copy and the canonical privacy URL.
- Phase 2: an XIRR calculator page (paste dates and amounts) ending in “Track this automatically in InvTrack →”.
- Add FD, chit-fund and P2P calculators only if the first one pulls traffic.

**Done when:** At least 500 organic sessions a month by month 6.

**Findings:** MKT-10

#### A56 · Run a ₹0-budget channel plan · effort M

**Why:** The existing GTM plan relies on paid influencers and ₹50K a month of X spend, and every checkbox in it is unticked.

**Do:**
- Fortnightly, post data-led pieces on r/IndiaInvestments (about 913k members) and TradingQnA, e.g. “Platform-reported 12% vs my real 9.4% XIRR on 3 years of P2P”, linking the calculator rather than the app.
- Use only the self-promo thread on r/FIRE_Ind.
- Post one weekly ‘XIRR explained’ thread on X.
- Pitch 1–2 niche creators (e.g. freefincal-style calculator authors). Require #ad and no return claims.
- Offer bond OBPPs and P2P NBFCs a neutral ‘import to InvTrack’ format, with no commissions (stay clear of SEBI finfluencer rules).
- Launch on Product Hunt / Show HN only after an en-US listing exists, and target NRIs (r/nri, UAE/SG groups) via multi-currency.

**Done when:** At least 300 attributable installs and 30 new ratings in 90 days.

**Findings:** MKT-16, MKT-12

### P6 · Monetization and cost (Decide Nov · build Dec–Jan · launch Jan–Feb 2027)

_Goal: A paid tier built on new value, launched before the March advance-tax and Jun–Jul ITR windows, on infrastructure whose cost is known._

#### A57 · Remove the dead monetization code · effort S

**Why:** The mock paywall grants Premium for free, shows a hard-coded $4.99, and sells features that are already free. PremiumGate renders the gated content at 30% opacity. The AdMob code can't work, but its SDK ships.

**Do:**
- Delete the mock purchase and the ads module (A34). Keep the non-coercive ‘Maybe later’ pattern for the real paywall.

**Done when:** No code path grants an entitlement without a verified purchase.

**Findings:** MON-01, MON-02, MON-03, SEC-18, UX-26, MKT-15

#### A58 · Settle pricing and packaging · effort S

**Why:** Code and docs quote four conflicting prices ($4.99, ₹799, ₹299, ₹99), and the roadmap's free tier would take back features users already have.

**Do:**
- Keep everything that is free today free forever: unlimited investments, XIRR, goals, basic FIRE, notifications, multi-currency, CSV/ZIP.
- InvTrack Premium: Tax-Year report with PDF/CSV for a CA, Health history, Income Guardian (once real), advanced FIRE scenarios.
- Prices: ₹149/month, ₹999/year (shown as ₹83/month), ₹2,999 lifetime launch offer. Benchmarks: Tickertape Pro ₹249/mo, MProfit ₹2,500/yr.
- Keep one PRICING.md, and delete the conflicting tables and the dark-pattern ideas in the docs.
- Drop the planned lead-generation, data-insights and P2P-referral revenue ideas: they conflict with the privacy policy and SEBI/RBI rules.

**Done when:** One pricing source of truth, with no free feature removed.

**Findings:** MON-09, MON-10, MON-12, MON-14, MON-07, MON-15

#### A59 · Integrate billing properly · effort M

**Why:** There is no billing library. Entitlements stored under users/{uid} would be client-writable. New updates need Play Billing Library 8+.

**Do:**
- Use RevenueCat (purchases_flutter with PBL 8+) keyed to the Firebase UID, and require guests to link before purchasing.
- Mirror entitlements into /entitlements/{uid} with rules that deny client writes.
- Add Restore and Manage-subscription links, and test with Play license testers.

**Done when:** Entitlement is active within 5 s of purchase, and a rules test denies client writes.

**Findings:** MON-11

#### A60 · Build the Tax-Year report for real · effort L

**Why:** The FY service invents capital gains as 10% of every RETURN (a ₹5L FD maturing at ₹5.4L reports ₹54,000 of gains instead of ₹40,000 of interest). It double-counts 31-Mar and 1-Apr. FY XIRR ignores opening and closing values. The PDF reads fields that do not exist, and the ITR reminder can never fire.

**Do:**
- Classify flows by tax head: interest/income at slab rates; capital gains only for assets sold at a gain, using post-23-Jul-2024 rules (12/24-month holding, 12.5% LTCG without indexation, 20% STCG on listed equity).
- Use half-open FY windows [1 Apr, 1 Apr) on local dates, and XIRR with opening value as an outflow and closing value as an inflow.
- Add an interest schedule per payer to reconcile with AIS/26AS, export PDF/CSV for a CA, and fix the ITR reminder.

**Done when:** Golden FY tests pass, and a CA reviews one real export.

**Findings:** CALC-09, CALC-10, ANLY-06, MON-08, MON-V01, MON-V02, ANLY-14, QA-06

#### A61 · Track monetization and allow remote tuning · effort S

**Why:** There are no paywall, trial or purchase events, and no way to tune prices or gates without a release.

**Do:**
- Log paywall_viewed{trigger}, trial_started, purchase, renewal and cancel, and add Remote Config for gate thresholds.

**Done when:** A paywall funnel report exists before launch.

**Findings:** MON-13

#### A62 · Cut Firestore cost per user · effort M

**Why:** A typical active day costs about 1,750 reads: 25 per-investment listeners, one query per INCOME flow on every start, FIFO FX cache churn and full-history reads. Cost grows with each user's history while revenue stays flat.

**Do:**
- Ship ARCH-06/10/11/13 first (about −69% reads), then delta-sync on cash flows.
- Guardrail: Firestore reads per DAU-day ≤ 700, tracked weekly as read_ops_count ÷ DAU.
- Confirm the Firestore location, and add a TTL on healthScores.

**Done when:** Reads per DAU-day stay at or under 700, with budget alerts live.

**Findings:** GAP4-01, GAP4-03, GAP4-07, GAP4-09, ARCH-13, ARCH-21

### P7 · Engineering health (Continuous)

_Goal: Releases stay safe as the codebase changes, and the repo tells the truth about itself._

#### A63 · Make releases safe · effort S

**Why:** Auto-release sends every feat/fix to 100% of production, and golden and integration tests never run in CI.

**Do:**
- Use a staged rollout (5% → 20% → 100%) with a Crashlytics gate.
- Run golden and integration tests nightly.

**Done when:** No release reaches 100% without 48 h at a partial rollout.

**Findings:** QA-08

#### A64 · Test the risky layers · effort M

**Why:** 45% of lib/ code is in files no test imports, including repositories, model mappers, the router's lock redirect and notification deep links. Some tests are skipped or assert nothing useful.

**Do:**
- Add tests for mappers (schema evolution), repositories (emulator), the router lock redirect and the notification navigator.
- Un-skip the active/archived separation tests.

**Done when:** Every repository and mapper has a test, and the lock redirect is covered.

**Findings:** QA-07, QA-19

#### A65 · Move heavy work off the UI isolate and fix image memory · effort M

**Why:** Three portfolio-wide XIRR solves run on each Overview recompute, and ZIP export and PDF generation run on the UI isolate. Full-resolution photos are decoded for 48px thumbnails, and files are fully loaded before the 10 MB check. GlassCard pays for a blur at 81 call sites.

**Do:**
- Use compute() for XIRR batches, ZIP and PDF.
- Use cacheWidth for thumbnails and check file size before reading bytes.
- Make the GlassCard blur opt-in, and add the 3 missing composite indexes.

**Done when:** No frame over 16 ms on Overview with 50 investments on a mid-range device.

**Findings:** ARCH-14, ARCH-17, ARCH-18, INV-15, ARCH-12, INV-13, INV-18

#### A66 · Delete dead code and unused dependencies · effort M

**Why:** 62 report files (8,693 LOC) cannot be reached. There are 6 unused packages, a beta file_picker, a deprecated secure-storage option, and duplicate stats and health algorithms.

**Do:**
- Remove the unreachable report code that A60 doesn't reuse, the unused packages and the deprecated providers.
- Upgrade file_picker to stable and remove encryptedSharedPreferences.

**Done when:** Analyzer is clean, every dependency is imported somewhere, and APK size is measured before and after.

**Findings:** QA-12, QA-06

#### A67 · Tighten the lint configuration · effort S

**Why:** Only the base flutter_lints rules are on, with no strict type modes, avoid_dynamic_calls off, and infos not fatal.

**Do:**
- Enable strict-casts, strict-inference and strict-raw-types, avoid_dynamic_calls, and unawaited_futures; fix the fallout gradually.

**Done when:** Strict modes are on, with a baseline that shrinks every week.

**Findings:** QA-20

#### A68 · Make the repo tell the truth · effort S

**Why:** docs/ holds about 97 mostly AI-generated status files (1.4 MB) that contradict each other, and CodeRabbit is fed a spec for an architecture that doesn't exist. The README claims an MIT licence with no LICENSE file and says ‘screenshots coming soon’. Versions disagree, there are two fastlane trees, and the repo has folders for unsupported platforms.

**Do:**
- Move the status reports into docs/archive and keep ~8 living docs (README, ARCHITECTURE, PRICING, this plan, runbooks).
- Add LICENSE (or drop the badge), a Play link and screenshots to the README.
- Use one version source of truth, delete the duplicate fastlane tree, and remove the unused platform folders.
- Decide on iOS explicitly: defer it until Android activation and retention targets are met (an App Store release also needs Sign in with Apple next to Google).

**Done when:** docs/ has fewer than 15 top-level files, and the README is accurate.

**Findings:** QA-14, QA-15, QA-17, QA-18, QA-21, MKT-14, ADOPT-15

## User adoption plan

Each funnel stage, what breaks there today, and the action items that fix it. Instrument first (A41) so every change can be measured against a two-week baseline.

| Stage | What breaks today | Actions | Measure |
|---|---|---|---|
| Store visit → install | Title, short description and screenshots don't say FD/P2P/bonds; false privacy claim; watermarked icon | A01, A51, A52, A53 | Store conversion |
| Install → first screen | Guest mode exists (no forced sign-up), but the guest data-loss notice is invisible | A05, A43 | auth_method split |
| First screen → first investment with an amount | Add Investment takes no amount; save returns to the same empty state | A40, A45 | Activation |
| First investment → first correct number | Open positions show −100% / −98% XIRR; samples show −97% | A09, A10, A20, A44 | Time to first real number |
| First number → habit | Income reminders never fire for active users; there is no monthly reason to return | A08, A47, A29 | D30 retention |
| Habit → advocacy | Review prompt off; no Rate or Share; no shareable card | A42, A46 | Ratings, referral installs |
| Advocacy → revenue | No billing; the best features are hidden | A57–A61 | Paywall → purchase |

**Positioning line:** “The cash-flow ledger for investments your broker app can't see.” Proof points: any irregular-cash-flow asset (chit funds, invoice discounting, private and rental deals); date-accurate XIRR/MOIC; Indian FY and lakh/crore with 40+ currencies; privacy mode and app lock; free, with no bank or SMS access. The copy and channel details are in A51–A56.

## Success metrics

| Metric | Definition | Source | Target |
|---|---|---|---|
| Money correctness | Golden formula suite passes at 1e-6; zero user-money paths default to USD | CI | 100% from week 5 |
| Valuation coverage | Share of open investments with a valuation ≤ 35 days old (auto or manual) | Firestore / analytics | ≥ 80% |
| Activation | New users with ≥ 1 investment and ≥ 1 cash flow within 24 h of first_open | Firebase funnel (A41) | Baseline 2 weeks, then +15 pp |
| Time to first real number | Median seconds from first_open to first xirr_viewed with a valuation | Firebase | ≤ 120 s |
| D30 retention | Cohort retention at day 30 | Firebase | Baseline, then +5 pp |
| Guest conversion | Guests linked to Google within 14 days | account_link_success | ≥ 35% |
| Ratings | New Play ratings per 90 days and average | Play Console | ≥ 30 new, ≥ 4.3★ |
| Store conversion | Listing visitors → installers | Play Console | +20% vs 28-day baseline |
| Crash-free users | After fatal-mislabel fix (A30) | Crashlytics | ≥ 99.5% |
| Infra cost | Firestore reads per DAU-day | Cloud Monitoring ÷ DAU | ≤ 700 |
| Monetization (post-launch) | Paywall view → purchase; annual-plan share; refund rate | RevenueCat + analytics | ≥ 5% · ≥ 60% · < 3% |

## What's working (keep it)

- The XIRR solver itself is sound: Excel's actual/365 convention, same-day grouping, Newton with a bisection fallback, run off the UI thread. It matched an independent oracle on 557 of 559 random cash-flow sets.
- Sign conventions are centralised (INVEST/FEE out, RETURN/INCOME in), and portfolio XIRR merges flows rather than averaging.
- Historical FX is applied per cash-flow date, the correct method for money-weighted returns in a base currency.
- The FIRE service uses the exact Fisher real-return form, guards degenerate rates, and keeps everything in today's money.
- The analyzer is clean (0 errors and 0 warnings on Flutter 3.38.4) and all 1,477 tests pass. Calculation tests use hand-computed references, not re-implementations.
- Firestore rules are strict per user, with emulator tests. A coverage test fails if a new collection is missing from account deletion.
- Document storage is hardened: per-user directory, path-traversal and symlink checks, magic-byte validation, a 10 MB cap. Files never leave the device.
- The listing is managed as code, and Play screenshots are generated reproducibly, so ASO iteration is cheap.
- Guest mode, quick-add templates, sample data and a Day 0/1/3/7/14 activation sequence already exist. They need fixing, not inventing.
- India-native touches competitors lack: lakh/crore formatting, Indian FY, realistic Indian demo data, and a privacy policy that already says ‘we do not sell your data’.

## How this review was done

- Twelve independent reviewers covered core return formulae, planning formulae (FIRE, goals, income), aggregate analytics and currency, investment-feature bugs, platform bugs (auth, import/export, notifications), security/privacy/compliance, architecture/performance/cost, UX/accessibility/localisation, tests/CI/docs, monetization, marketing/ASO, and adoption/growth. A completeness critic then commissioned four extra probes: archive semantics, money stored without a currency, notification opt-outs, and unit economics.
- Every finding went to a separate adversarial verifier told to refute it. Formula claims were re-computed with Python ports of the Dart code. Of 281 candidate findings, 1 were refuted and 84 were confirmed with corrected severity or details.
- `flutter analyze` (Flutter 3.38.4, the version CI pins): 0 errors, 0 warnings, 2 infos. `flutter test --exclude-tags=golden`: 1,477 passed, 4 skipped, 0 failed.
- Web claims (pricing benchmarks, Play policy, tax rules, API coverage) were checked with search where the sandbox allowed. Re-confirm prices and policy text before publishing anything that relies on them.
- 45 probe findings could not be independently verified and are marked as such in FINDINGS.md.

