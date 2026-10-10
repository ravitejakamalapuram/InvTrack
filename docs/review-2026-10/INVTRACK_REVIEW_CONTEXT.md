# InvTrack Review Context Baseline

> Internal engineering context for AI-assisted code and PR review.
> Snapshot: 2026-10-06.
> Source of truth remains current main, CLAUDE.md, .augment/rules/invtrack_rules.md, current tests, linked review issues, and the current October 2026 findings register.
> This file is a durable review aid, not a substitute for reading the affected code, issue, PR diff, comments, reviews, and current main.

## 1. Product and trust model

InvTrack is an India-first Flutter + Firebase investment tracker, live on Google Play. It stores real financial data.

Core product:
- Track investments such as FDs, P2P lending, bonds, gold, chit funds, property, stocks/MFs and other alternatives.
- Track cash flows: INVEST, RETURN, INCOME, FEE.
- Provide financially correct XIRR, MOIC, net cash flow, current value, goals and FIRE planning.
- Support 40+ currencies and Indian financial-year semantics.
- Correctness, privacy, deletion, backup/restore and currency semantics take priority over speed or architectural elegance.
- Android activation/retention is the current product focus; iOS is deferred.
- Premium must add new value; do not silently take away existing free capabilities.
- Dormant ads code should be removed, not expanded.
- Income Guardian stays hidden until there is a real generator for expected cash flows.

## 2. Review workflow

For any review-2026-10 ticket:
1. Re-read the issue and linked findings against current main.
2. Check blocked-by items and overlapping open PRs.
3. Stay inside the ticket; unrelated findings become separate issues.
4. Calculations, data, currency, notifications, auth, import/export and security work is test-first.
5. Inspect test quality, not only test count.
6. Run or verify the checks actually available; never claim a command was run unless it was.
7. Read the PR description, commits, review comments, PR comments and unresolved threads.
8. Base merge decisions on the current PR diff against current main.
9. Do not approve an architecture improvement that leaves a higher-priority correctness or privacy invariant unsafe.

## 3. Architecture

The repository is a sizable Flutter app with:
- Core calculations, analytics/Crashlytics, notifications, services, providers, routing, performance and security utilities.
- Features for auth, bulk import, FIRE, goals, income projection/guardian, investments/documents, onboarding, overview, portfolio health, reports, security, settings and user profile.
- Riverpod for state management.
- Firestore repositories for persistence.
- Active and archived investment/cash-flow data stored separately.
- User data under users/{uid} subcollections.
- Account deletion, export/import, notifications and local attachments as distinct lifecycle concerns.
- Release feature flags must use code defaults; production behavior must not depend on a hidden debug menu.

The core calculation layer is intended to be the single source of truth for financial metrics. Screens, reports, notifications and planning features should consume those results rather than reimplement the formulas.

## 4. Canonical data model

Investment data includes identity/lifecycle fields plus:
- maturity date
- income frequency
- archive state
- start date
- expected rate
- tenure
- platform
- payout/compounding/risk settings
- currency
- current value and valuation date

Cash flow:
- INVEST and FEE are outflows.
- RETURN and INCOME are inflows.
- Stored amount is positive; signed amount is derived.
- Each cash flow has its own currency.

Other persisted concerns currently include:
- investments
- cashflows
- archivedInvestments
- archivedCashflows
- goals
- archivedGoals
- expectedCashFlows
- documents
- fireSettings
- profile
- exchangeRates
- healthScores
- account deletion structures outside the user tree

Every persisted collection must be reflected in:
1. Firestore rules
2. account deletion
3. export
4. import/restore
5. migration/backward compatibility
6. tests

## 5. Hard financial invariants

### Currency
1. Never silently default a missing currency to USD.
2. Preserve original stored currency.
3. Use the user's confirmed base currency only when that fallback is explicitly safe.
4. Convert cash flows to base currency before aggregation and XIRR.
5. Never show a native foreign amount under a base-currency symbol.
6. FX failure must not become an implicit 1.0 conversion.
7. Historical FX requests should be coalesced/deduplicated where possible.
8. A new cash flow should normally use the investment's currency, not merely the user's base currency.

### Canonical metrics
The calculations layer is authoritative for:
- total invested
- paid-in capital
- total returned
- net cash flow
- XIRR
- MOIC
- absolute return
- current/terminal value
- projection inputs

Watch for divergent implementations in FIRE, goals, reports, health, overview and notification code.

### XIRR
- Cash-flow dates are date-only.
- Use the agreed actual/365 style day count.
- Undefined XIRR remains undefined/null; never turn it into 0%.
- Approximate fallback results must be labelled.
- Open investments need current/terminal value for meaningful XIRR/MOIC/return percentage.
- Calculation tests must use exact expected values with tight tolerances, not only broad positivity checks.

### MOIC and invested capital
Watch for:
- double counting reinvested/rolled-over capital
- fees included in the wrong definition
- lifetime gross cash movement used where paid-in capital is required

### FY and dates
- Indian financial year is [1 Apr, next 1 Apr).
- Do not double count 31 Mar or 1 Apr.
- Date-only fields must not drift with time zone/DST.
- Month arithmetic must clamp month ends correctly.

### Rounding
Use consistent money rounding. Floating point noise must not flip a break-even result.

## 6. Current value and aggregate snapshot

Current value is a first-class input.
- Manual value plus valuation date may exist.
- A derived value may exist when supported.
- Current/terminal value is a terminal inflow for return metrics.
- Cash-only metrics remain separate from terminal-value metrics.
- Missing current value is not zero.

Preferred aggregation path:
1. Load active, valid source data.
2. Build one converted base-currency cash-flow snapshot.
3. Calculate current/terminal values from source-currency data.
4. Convert those terminal values into the same base currency.
5. Calculate investment stats from the matched snapshot.
6. Reuse those canonical results across overview, lists, charts, goals, FIRE, health and reports.

A second aggregation path is a review warning.

## 7. Archive semantics

Founder decision: archived investments stay excluded from totals, goals and FIRE.

Therefore review archive changes for:
- overview totals
- realized P&L
- YoY
- goals
- FIRE
- health
- reports
- notifications
- documents
- delete/restore behavior

Archive is not merely cosmetic. The UI should disclose material calculation impact where a user could misunderstand it.

Archived detail screens must never accidentally write to active collections.

Archive/unarchive/delete/bulk-delete operations must respect Firestore's 500-operation batch limit.

## 8. Goals

Goals can have target amounts, target dates, monthly income targets and investment/type links.

Review:
- progress must use consistent base-currency data
- nullable edits must really clear fields
- equality/change detection must include meaningful linked fields
- archived/deleted investments must not create silently stale goal state
- currency/base-currency changes and restore/import must preserve target semantics
- loading/error must not be converted into fake empty or 0% states

Do not use ambiguous copyWith(null) semantics when null means clear.

## 9. FIRE and Portfolio Health

FIRE:
- Current portfolio must represent current value, not lifetime gross contributions.
- Reinvested capital must not be double counted.
- Savings rate and units must be coherent.
- Time/age inputs must continue advancing appropriately.
- FIRE currency must survive export/import/base-currency changes.

Portfolio Health:
- Must use canonical stats and base-currency values.
- Open investments need meaningful terminal values.
- Empty portfolios must not receive fake positive health simply because data is missing.
- Archive semantics must remain consistent.
- Historical snapshots must be deletable with the account.

## 10. Auth, guest mode and account switching

Guest-to-Google linking should preserve the anonymous Firebase UID and Firestore data.

Guest backup data must be owner-scoped on-device and recoverable after process death.

Account transitions must prevent leakage of:
- Firestore cache
- local attachments
- scheduled notifications
- analytics identity
- Crashlytics identity
- pending UI/dialog state

Analytics and Crashlytics identity should follow the signed-in UID and clear on sign-out.

Identity synchronization must not rely on swallowed provider errors. A failed identity update needs a reliable retry path.

Review initial auth, anonymous auth, linking, token changes, sign-out, deletion, process death and offline/resume behavior.

## 11. Account deletion

Normal offline-first write semantics must not be copied blindly into deletion.

Server deletion must:
- discover every relevant user collection
- delete in batches of <=500
- wait for server confirmation
- only then treat data as deleted and proceed with Auth deletion

The deletion pipeline includes:
- deletionRequests
- scripts/account-deletion
- verification
- audit/run records

Every new persisted collection requires deletion coverage.

Also review:
- local attachments
- guest backups
- notifications
- analytics/crash identity
- external/web deletion path
- Auth account removal

## 12. Offline-first semantics

Normal Firestore edits may succeed locally and sync later.

Business-critical destructive operations are different:
- account deletion needs server confirmation
- irreversible cascades need a clear guarantee
- success UI must match the actual guarantee

A PR that swallows every timeout is suspicious if it touches destructive integrity.

## 13. Import, export and backup

Backup/restore must be lossless.

Preserve:
- stable IDs where appropriate
- full investment metadata
- original currencies
- cash-flow currencies
- current valuations
- goals and links
- documents
- FIRE settings/currency
- base currency
- schema version

Import must:
- validate before destructive Replace
- parse quoted newlines robustly
- detect duplicates where appropriate
- never treat missing currency as USD
- never merge distinct investments solely by name
- never silently drop newer fields

New persisted fields should get round-trip coverage.

## 14. Documents

Documents are sensitive.

Review:
- path traversal protection
- file-size checks before loading large files
- memory use for thumbnails/photos
- partial-save rollback
- duplicate handling on retry
- deletion on account/investment deletion
- export
- crash-report privacy

Do not send document names, filenames, paths or user content to analytics/crash reporting.

## 15. Notifications

Notifications are tied to account and investment lifecycle.

Rules:
- clear old user's scheduled notifications after sign-out/account change
- closed/archived investments should not retain active investment reminders
- IDs must not collide
- deep links must respect app lock
- killed-app entry points must work
- privacy mode must affect notification contents
- opt-out toggles must actually cancel existing alarms
- launch/resume must not continually move a reminder into the future
- lock-screen financial data must be protected

Test foreground, background, terminated app, locked state, signed-out state and account switching.

## 16. App lock and privacy

Security review must include:
- no portfolio rendering before lock decision
- no blocking dialogs above the lock screen
- no biometric/PIN race
- clock-change resistance for lockout
- sleep-aware elapsed time
- safe behavior when secure storage fails
- sensitive state cleanup on sign-out
- app-wide screenshot/snapshot protection when required

A Dart Stopwatch is not automatically equivalent to iOS sleep-inclusive monotonic timing. Platform semantics matter.

## 17. Analytics and Crashlytics

Never send:
- names
- emails
- exact amounts
- document names
- filenames
- local filesystem paths
- account numbers
- arbitrary Firestore paths
- sensitive IDs

Amounts may use coarse buckets.

Crash reporting should:
- sanitize exception messages
- retain only machine-safe codes/types where useful
- sanitize metadata values even when the key is allow-listed
- exclude expected network/timeouts from crash rate
- prevent duplicate reporting across layered handlers
- not mark recoverable framework errors fatal without a clear reason

Any change to logging must be reviewed at both the service layer and call sites.

## 18. Feature flags and router lifecycle

Release builds use code defaults. Debug overrides are for development/testing.

Do not make production behavior depend on a hidden debug menu.

GoRouter must not rebuild unnecessarily on unrelated auth/security/flag changes.

Review auto-lock, auth linking, forms with unsaved state, deep links and feature gates for navigation loss.

## 19. Performance and cost

Watch for:
- N+1 Firestore listeners
- repeated portfolio-wide queries
- per-investment streams where a shared stream can be derived
- repeated historical FX calls
- health recomputation loops
- XIRR/ZIP/PDF on the UI isolate
- full-resolution image decoding for thumbnails
- expensive services initialized while their feature is disabled

A simpler implementation that introduces one listener/query per investment may be worse for this product.

## 20. Testing standard

For financial/data/security PRs require tests for:
- exact formula values
- failure paths
- offline/cache behavior
- active vs archived separation
- schema evolution
- import/export round trips
- multi-currency
- deletion cascades
- notification lifecycle
- auth identity lifecycle
- process-death or restart-sensitive behavior where applicable

Watch for vacuous tests, weak thresholds, over-mocking, skipped tests, wrong expected behavior, and tests that only cover happy paths.

## 21. October 2026 review themes

The October register contains 282 findings and a growing action plan. The important themes are:
- current/terminal value correctness
- silent USD defaults
- currency conversion and aggregation
- archive semantics
- goal/FIRE correctness
- destructive cascades
- lossless backup/restore
- offline-first reliability
- App Check/rules/cost controls
- notification correctness
- app-lock security
- Crashlytics/Analytics privacy and deduplication
- CI/release safety
- activation and first-investment flow
- growth, marketing and monetization
- test coverage and repo hygiene

Later A74+ actions also cover formatting/codegen, release safety, currency E2E, import privacy, deletion/privacy disclosures, crash identity, lock races, edit/clear-field lifecycle, sample-data safety, loading/error behavior and Play Data Safety accuracy.

## 22. Review decision hierarchy

When concerns conflict:
1. Financial/data correctness
2. Security/privacy/compliance
3. Data-loss/destructive integrity
4. Cross-account isolation
5. User-visible correctness
6. Regression protection/test quality
7. Performance/cost
8. Architecture/maintainability
9. UX polish
10. Documentation

## 23. Work-class PR review questions

For every PR answer:
1. What user/product problem is solved?
2. Which invariants are touched?
3. What else consumes the changed behavior?
4. Could any financial number become wrong?
5. Could one user's data leak into another user's account/device?
6. Could offline/cache state create a false assumption?
7. What happens after process death, restart, sleep, timezone changes or account switch?
8. Could Firestore 500-op/query/index constraints break it?
9. Do deletion/export/import still cover the data?
10. Do active/archived semantics remain correct?
11. Is currency explicit and consistent?
12. Are loading/error states distinguished from empty/no-data?
13. Do tests prove the actual invariant?
14. Do other open PRs touch the same invariant/files?
15. What is the merge-order interaction?
16. Are CI/release/security implications covered?

## 24. Maintenance

Keep this document stable and durable. Do not turn it into a status diary.

Update it only when:
- architecture changes
- product decisions change
- durable correctness/security invariants change
- a newly confirmed review finding materially changes how PRs must be reviewed

Use GitHub issues and PRs for current status.
