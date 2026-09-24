# 0001 In-app review prompt after the first recorded exit

Status: accepted   Date: 2026-09-25   Issue: POR-91

## Context

InvTrack has 100+ Play downloads and **0 ratings** (`metrics/latest.md`, 2026-09-24). Nobody has
ever been asked to rate it. The product goal is 1,000+ downloads by 2026-12-31, and a listing with
no star rating converts worse than one with any rating at all.

Constraints that shape the design:

- **Production-critical app, real user financial data in Firebase.** POR-91 forbids new Firebase
  reads/writes and any data model change. The merge to `main` needs board approval (`company.md`).
- The prompt must fire after a **genuine success moment**, once, and never on every launch.
- It must not read anything about the user's money beyond what the app already computes locally.
- Play policy (`developer.android.com/guide/playcore/in-app-review`) forbids asking the user an
  opinion question before or while the review flow is shown, forbids custom rating UI, and
  quota-limits the request: the app cannot know whether the sheet was actually displayed.

What the repo already provides and this design reuses:

- `shared_preferences` with `sharedPreferencesProvider` (`lib/core/providers/`) — local, no Firebase.
- Play Core precedent: `in_app_update` + `lib/core/providers/in_app_update_provider.dart` +
  `lib/core/widgets/in_app_update_initializer.dart` (Android-only, non-blocking, failures logged).
- `AnalyticsService.logEvent` (`lib/core/analytics/`), `LoggerService`, Riverpod DI, `mocktail`.
- A natural success moment: `CashFlowType.returnFlow` ("money returned (exit/sale)") recorded from
  `lib/features/investment/presentation/screens/add_transaction_screen.dart::_submit()`. Recording a
  return is the moment the app pays off — it is the input that makes XIRR meaningful.

There is no rating or review code in the app today (checked before designing: no `in_app_review`
in `pubspec.yaml`, no "rate this app" string in `lib/l10n/app_en.arb`).

## Decision

Add the **Play in-app review API** via the `in_app_review` package (MIT), requested **at most once
per install**, fired from the UI success path after the user records their **first return/exit cash
flow manually**. All gating state is local `SharedPreferences`. No custom prompt UI, no new strings,
no new permission, no Firestore access, no data model change.

Shape:

1. `lib/core/review/review_prompt_service.dart` — `ReviewPromptService` holding `SharedPreferences`
   and a narrow `ReviewLauncher` interface (`isAvailable()`, `requestReview()`) so tests inject a
   fake instead of the plugin. One public method, e.g.
   `Future<void> maybeRequestAfterExitRecorded()`.
2. Keys, versioned so a future policy change starts clean:
   `review_prompt_v1_requested_at` (epoch ms, absent = never asked) and
   `review_prompt_v1_success_count` (int).
3. Gate order, cheapest first, every check local:
   `!kIsWeb && Platform.isAndroid` → not already requested → success count (after increment) ≥ 1 →
   no in-app update flow currently pending → `launcher.isAvailable()` → persist `requested_at`
   → `launcher.requestReview()`.
4. `requested_at` is written **before** the request and never cleared: one shot per install. The Play
   API is quota-limited and returns no result, so a retry-on-failure loop would risk interrupting the
   user twice for nothing. A device where the sheet silently did not appear simply never asks again.
5. Call site: `add_transaction_screen.dart::_submit()`, non-editing branch only, when
   `_selectedType == CashFlowType.returnFlow`, after the success feedback and `context.safePop()`,
   fire-and-forget (`unawaited`, ~1s delay) and wrapped so no failure can ever reach the save path.
6. One analytics event, `review_prompt_requested`, no parameters, through the existing
   `AnalyticsService`. This is the only externally visible write the change adds.

Placing the trigger in the manual add-transaction UI (not in the notifier or repository)
automatically excludes bulk CSV import, sample data (`sample_data_service.dart`), seed data
(`seed_data_service.dart`) and edits of an existing transaction — none of those are success moments,
and a prompt after a 200-row import would be the worst possible timing.

## Rejected

- **Custom "Enjoying InvTrack?" dialog first, Play sheet only if the user says yes.** This is the
  common pre-prompt pattern and it is explicitly against Play's in-app review policy ("don't ask the
  user any questions before or while presenting the rating card"). It also adds localized strings and
  a second interruption for no measured gain. Rejected on policy.
- **`url_launcher` deep link to the Play listing's review page.** Works everywhere and needs no new
  dependency, but throws the user out of the app mid-task and converts far worse than the in-line
  sheet. Kept only as the theoretical fallback if Play ever pulls the in-app API.
- **Trigger on viewing a computed XIRR (overview/detail screen).** A tempting "success moment", but
  it fires on a passive screen view, repeats every session, and is reached with seeded/sample data
  during onboarding. Recording a return is an intentional act with a clear before/after.
- **Trigger on app launch or after N launches.** POR-91 rules it out, and it is what produces the
  "pushy app" reviews we are trying to avoid.
- **Remote-config / Firestore gating or a kill switch.** Needs new Firebase reads, which POR-91
  forbids. Blast radius without it is one sheet per install; that is acceptable.
- **Counting more than one success moment before asking (e.g. 3 exits).** Safer against asking a
  brand-new user, but most InvTrack users record very few exits, so a threshold of 3 would keep the
  rating count near zero — the exact problem being fixed. One genuine exit is the threshold.

## Consequences

- Risk: a user who records an exit and dislikes the app rates it 1 star. Accepted — 0 ratings is
  worse than a real distribution, and Play's own sheet is the lowest-friction ask available.
- Risk: the sheet collides with the in-app update dialog. Mitigated by the pending-update check in
  gate 3; when it suppresses, the one shot is **not** spent.
- Risk: new Android dependency (`in_app_review` ^2.0.12 — MIT, OSI-approved, 160/160 pub points,
  2.4k likes; pulls `com.google.android.play:review`). Permissive licence, so no board gate for the
  dependency itself, but it is disclosed in the merge approval along with everything else. The
  app already ships Play Core through `in_app_update`, so this is a sibling, not a new platform
  surface. The dev issue must prove Gradle still resolves with an Android build.
- The app cannot measure whether the sheet was shown. We watch the Play listing rating count in
  `metrics/latest.md` and the `review_prompt_requested` event; a rating count moving off 0 within a
  few weeks of the release is the success signal.
- Behaviour is untestable end-to-end on a debug build (the Play API no-ops outside a Play-installed
  build), so QA verifies the gating logic and that nothing regresses in the transaction flow; the
  sheet itself is verified against an internal-track install or accepted as Play-side behaviour.
- Board approval is required before merge to `main`, and the PR must not bump the version (a version
  bump triggers CD, which is board-only).

## Build plan

One PR, ~300 lines including tests. Ordered steps:

1. Add `in_app_review: ^2.0.12` to `pubspec.yaml`; `flutter pub get`.
2. `ReviewPromptService` + `ReviewLauncher` (+ real `InAppReview` adapter) and its Riverpod provider,
   mirroring the placement and error handling of `in_app_update_provider.dart`.
3. Wire the call site in `add_transaction_screen.dart::_submit()` (return/exit, new transaction only).
4. Unit tests with `SharedPreferences.setMockInitialValues` and a fake launcher: first exit requests
   once; a second exit does not; invest/income/fee never request; non-Android is a no-op; launcher
   unavailable does not spend the one shot; a throwing launcher cannot break the save path.
5. Verify with `flutter analyze`, `flutter test`, and one Android build so the new Play dependency is
   proven to resolve.

Out of scope for the PR: version bump, CI/CD or fastlane changes, `firestore.rules`, new strings,
any settings-screen entry point.
