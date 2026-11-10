# Six roadmap asks: triage and plan

Date: 2026-11-10. Plan only, no code. Triaged against `main` at `eca168a`. Nothing here is approved to build; Raviteja decides in the project thread.

## Summary

| # | Ask | Already in repo? | Value | Effort | Verdict |
|---|---|---|---|---|---|
| 1 | Gold, silver, metals in grams | Issue #946 (label `later`); `InvestmentType.gold` exists, no quantity or unit price | High (India-first) | L | Do a thin slice first |
| 2 | More login options | Google plus guest only (`AuthRepository`) | Low on Android, required on iOS | M | Refactor, then Apple and email link |
| 3 | Family accounts and sharing | Nothing (rules are owner-only) | Medium, uncertain | XL | Start with an owner tag, validate before real sharing |
| 4 | Replace Firestore with Google Sheets | No | Negative as a database | XL | No. Offer a Drive backup instead |
| 5 | iOS build and App Store push | `ios/` scaffold, Firebase iOS app id, no release lane | High later | L | His job; the 2026-10-02 deferral still stands |
| 6 | Ads or other monetization | A34 removes ads, A57 to A61 plan Premium | High | M | Premium first; no traditional ads |

## 1. Gold, silver and metals in grams

**Triage.** Not built. `InvestmentType.gold` ("Gold/Commodities") is a label only. The model holds cash flows plus one amount-based `currentValue` with `currentValueDate`. #946 already specifies quantity, unit and dated unit price, and depends on #941 (valuation history), #945 (money precision) and #944 (data model contract). Check those three before starting; #946 says not to build a second valuation pipeline.

**Value.** High for the India-first audience: gold is the most common asset after FDs, and "10 g bought at ₹6,000/g" is how people think. Today they must type a rupee value by hand and update it on every price move.

**Plan (thin slice).**
- Optional per-investment quantity, unit and price-per-unit, with a currency and an effective date. Amount-only stays the default.
- Valuation = quantity × price, rounded by the #945 rules. Cash flows stay money; units never replace them.
- v1 price is manual (user types today's ₹/g). Quantity is a user-confirmed baseline. No inference from cash flows, and a dividend or fee never reduces units.
- Units: gram, kilogram, troy ounce, sovereign/tola as display presets that convert to grams.
- Metal as a sub-choice (gold, silver, platinum, palladium) under the existing gold type, not new enum values: an older app version reads an unknown enum as `other`.

**What else makes sense besides grams.**
- Units and NAV for mutual funds, shares for stocks, coins for crypto: same mechanism, so the "unit-based type" list should be configurable, as #946 asks.
- Area for property (₹ per sq ft) is a poor fit; skip it.
- Types worth adding as presets, not enum values: Sovereign Gold Bond (grams plus 2.5% interest, tracked in #1161), digital gold, gold ETF.
- Do not add PPF/EPF/NPS or REITs now. Balance-style accounts belong with the parked net worth plan.

**Risks.** Money rules 1, 2, 3 and 6: every new field needs Firestore, export/import and account-deletion coverage. A wrong price silently misstates value, so show the price date next to it ("price as of 3 Nov"). Live price feeds need a licence and a server; defer, and keep manual entry.

**Recommendation.** Build the slice behind a `FeatureFlag` after #759 and #768 clear the queue. Skip auto prices.

## 2. More login options

**Triage.** `AuthRepository` offers `signInWithGoogle`, `signInAnonymously`, `linkAnonymousToGoogle` and `reauthenticateWithGoogle`. Guests can link to Google later and merge their data.

**Honest value.** On Android almost everyone has a Google account, so more providers will not move adoption much. Two real reasons exist:
- **Sign in with Apple is mandatory** on iOS if any third-party social login is offered (App Store guideline 4.8). It becomes needed with ask 5.
- Email link covers people who do not want Google tied to their money data, and devices without Google services.

**Plan.**
1. Make the repository provider-agnostic (`signIn(provider)`, `link(provider)`, `reauthenticate(provider)`). Account deletion and the guest merge both rely on re-authentication, so test them per provider. Size S to M.
2. Add passwordless email link (Firebase, free, no passwords to store). Size M.
3. Add Sign in with Apple together with iOS.

**Not recommended.** Phone OTP (SMS cost, DLT registration in India, abuse), passwords (reset flows, breach risk), Facebook and other socials.

**Risks.** Account collisions when the same email arrives via two providers (Firebase's one-account-per-email setting must be chosen deliberately), and lock-out if a user deletes the only provider they linked.

## 3. Family accounts and sharing with controls

**Triage.** Nothing exists. Firestore rules allow only `request.auth.uid == userId`. The "shared goals" chip is unrelated (it means one investment counts toward several goals). #1069 proposes a names-and-types-only share text, no amounts.

**Value.** Uncertain. The common real case in India is one person tracking parents' or a spouse's investments, not several people editing together. Real multi-user sharing is the most expensive thing on this list.

**Cost of real sharing.** A household collection with members and roles, per-investment visibility, security rules that need their own tests, change feeds for several readers (Firestore cost, see A62), per-person versus combined XIRR, privacy mode per viewer, invite and revoke flows, deletion rules when one member leaves, and export/import. That is a quarter of work and a permanent security surface for money data.

**Plan in steps.**
- **Step A (S to M):** a "Holder" tag on each investment (Self, Spouse, Parent, custom). Filter and total by holder inside the one account. No new login, no rules change. Fits Premium under A58 as a new feature.
- **Step B (S):** the #1069 share-my-list action, text only.
- **Step C (XL, only on demand):** invite a read-only viewer to selected investments. Viewer first; editor only if users ask. Go only if step A shows people want it, for example many holders per account.

**Recommendation.** Do A and B, validate, then decide on C. Do not build real sharing speculatively.

## 4. Firestore versus Google Sheets

**Verdict: no, Sheets is a poor database for this app.** Reasons:
- Quotas and latency: Sheets API allows roughly 60 requests per minute per user, with calls taking up to seconds; offline-first reads and writes would break.
- No security rules, transactions or queries. Account deletion (rule 6), the Firestore rules tests and our calculation pipeline all assume a real database.
- A user edits a cell and the schema drifts; one bad edit corrupts XIRR.
- Full spreadsheet access is a sensitive OAuth scope with Google verification; per-file `drive.file` is lighter but still needs the user to own the file.
- Switching to another database (Supabase and the like) would cost a rewrite for no user-visible gain. Cost per user is better solved by A62.

**What users actually want:** to own their data and take it elsewhere. Lighter options:
- CSV/ZIP export and bulk import already exist. A "Google Sheets" button adds little over them.
- **Drive backup and restore** (M): an encrypted JSON backup to the user's own Drive app-data folder (`drive.appdata`, a non-sensitive scope), one tap to restore. This gives the "my data sits in my account" story and a safety net.

**Recommendation.** Keep Firestore. Treat the Drive backup as optional and low priority; build it only if users ask for it.

## 5. iOS build and App Store push (Raviteja's job)

**Triage.** `ios/` exists with `GoogleService-Info.plist` and an iOS Firebase app id. The bundle id is `com.invtracker.invTracker` (Android is `com.invtracker.inv_tracker`; pick the final iOS id deliberately, it cannot change later). There is no iOS release lane, and the CI runners are Linux.

**Decision on record:** 2026-10-02, iOS is deferred until Android activation and retention targets are met. I recommend keeping it, because iOS adds a second store, a second billing system and a second support load while Android is still being fixed.

**His part, needs his Apple account:**
- Apple Developer Program (US$99 a year), App Store Connect app record, bundle id, signing certificates and provisioning profiles, APNs key uploaded to Firebase.
- App Privacy answers, screenshots, review notes, and the submit and release buttons.

**My part, once he gives the go:** an iOS readiness audit (plugins, minimum iOS, Podfile), Sign in with Apple (ask 2), StoreKit through RevenueCat (ask 6), notification permission flow, and a macOS CI lane in `release-platform`. Needs the keys above stored as secrets; I will not handle credentials.

**Risks.** macOS runners cost about ten times Linux minutes. App review may ask for the in-app account deletion we already have, plus the Apple sign-in rule.

## 6. Ads and other monetization

**Existing plan.** A34 (#778) removes the ads SDK, AD_ID and the fake consent flow; `google_mobile_ads` is still in `pubspec.yaml` and unused in `lib/`. A58 sets Premium at ₹149 a month, ₹999 a year, and an optional ₹2,999 lifetime launch offer, with everything free today staying free. A59 adds billing through RevenueCat, A60 the Tax-Year report, A61 tracking. A58 also drops lead-gen, data-insight and referral revenue because of privacy and SEBI/RBI rules. #1051 proposes a paywall fake door to measure demand; #1098 and #1161 cover UPI Autopay and a prepaid plan.

**Honest take on ads.** Ads in a screen showing someone's net worth cost trust, need the Advertising ID (the thing A34 removes), a consent flow, and a Data safety rewrite. At our user count the revenue would be small. Financial product ads would also clash with the lead-gen rule above.

**Options, ranked.**
1. **Premium subscription** (A58, A59, A60). The main route. Anchor: Tax-Year report for your CA.
2. **Supporter or lifetime purchase.** A one-time "support InvTrack" tier; low cost, trust-building, rides the same billing.
3. **Rewarded ad, only if he insists on ads.** Opt-in ("watch one ad to export this report once"), never on a screen showing amounts, non-personalised, behind a flag. Needs the AD_ID reversal, so it conflicts with A34. Not recommended before Premium is measured.
4. **Affiliate cards and sponsored content.** Not recommended (A58).

**Recommendation.** Finish A34 now, ship A58 to A60 on the existing schedule (Premium before 15 March), measure the paywall, and revisit the rewarded ad only if conversion is weak.

## Overlap with parked plans

- Net worth (PR #1061, parked): metals give a better current value for net worth, but build nothing there until he confirms. Liabilities and snapshots stay Premium candidates.
- Reports engine (`REPORTS_ENGINE_PLAN.md`): the Tax-Year report (phase 4, A60) is the Premium anchor for ask 6. Gold quantity needs to appear in that report later, so keep #946's data model compatible with it.

## What can be built in parallel

Safe together (disjoint files and no shared data model change):
- **Ask 1 metals slice** (investment entity, form, calculations, export/import).
- **Ask 2 auth refactor** (`lib/features/auth`, account deletion re-auth).
- **Ask 6 groundwork**: A34 ads removal (#778), then A58 and A59 billing in a new module.

Sequence, do not parallelise:
- Ask 3 step A touches the investment entity and form like ask 1: after ask 1 merges.
- Ask 5 depends on ask 2 (Apple sign-in) and ask 6 (StoreKit).
- Ask 4 Drive backup is independent but low priority; run it alone when wanted.

Cost note: three parallel sessions triple token use. If cost is the concern, run ask 1 and ask 6 groundwork now, and ask 2 after.

## Decisions needed from Raviteja

1. Approve ask 1 slice, ask 2 refactor plus email link, and A34 plus billing groundwork to start.
2. Keep iOS deferred (recommended) or start the Apple account steps now.
3. Family: tag and share-list first (recommended), or skip.
4. Drop Sheets-as-database and the traditional ads idea (recommended).
