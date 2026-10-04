# InvTrack: guide for Claude Code sessions

InvTrack is a Flutter + Firebase (Firestore, Auth, Analytics, Crashlytics) Android app, `com.invtracker.inv_tracker`, live on Google Play. Users track alternative investments (FDs, P2P lending, bonds, gold, chit funds, property) as cash flows (`INVEST`, `RETURN`, `INCOME`, `FEE`) and see XIRR, MOIC, goals and a FIRE number. It is India-first (INR, lakh/crore formatting, April–March financial year) and supports 40+ currencies. Users' financial data is real, so correctness and privacy come before speed.

## Setup and commands

- Flutter is pinned by CI in `release.yaml` (3.38.4, Dart 3.10). In cloud sessions `.claude/hooks/session-start.sh` installs it and runs `pub get` and `gen-l10n`.
- Same checks as CI:
  - `flutter pub get && flutter gen-l10n`
  - `flutter analyze --fatal-warnings --no-fatal-infos`
  - `flutter test --exclude-tags=golden` (about 3.5 minutes; 1,477 tests green at the Oct 2026 review)
- One file or test: `flutter test test/core/calculations/xirr_solver_test.dart --plain-name "name"`.
- Generated code: `dart run build_runner build --delete-conflicting-outputs` for Riverpod `*.g.dart`. Strings live in `lib/l10n/app_en.arb`, then `flutter gen-l10n`. Never hand-edit generated files.

## Coding standards

Follow `.augment/rules/invtrack_rules.md`: layer boundaries, Riverpod patterns, offline-first Firestore, localisation, accessibility, privacy mode and analytics privacy. Read the sections that apply to your change. Where that file and this one disagree, this file wins, because it records later decisions.

- Feature flags: build a new feature behind a `FeatureFlag` as the rules say. Shipping it means changing the flag's default in code in a release PR. Production behaviour must never depend on the hidden debug menu.

## Money and data rules

These came out of the October 2026 review (`docs/review-2026-10/`). Breaking one is a bug even if tests pass.

1. Never default a missing currency to `'USD'`. Use the user's base currency (`currencyCodeProvider`), or fail visibly.
2. Convert every cash flow to the base currency (`BatchCurrencyConverter` / `batchConvert`) before summing or computing XIRR. Never sum unconverted amounts, and never show a native amount under the base-currency symbol.
3. One implementation per metric. Invested, returned, net, XIRR, MOIC and current value come from `lib/core/calculations`; screens and services must not re-derive them.
4. An open investment needs a current value for XIRR, MOIC and return %. Without one, show “—” or “Awaiting first payout”, never 0% or −100%.
5. Cash-flow dates are date-only; normalise them before saving and before computing. XIRR uses actual/365 like Excel. The Indian FY is the half-open range [1 Apr, next 1 Apr).
6. Every Firestore collection must be covered by account deletion (`AccountDataDeletionService`; a test enforces this) and by export/import.
7. Never send names, amounts, file names or paths to Analytics or Crashlytics. Amounts may be sent only as buckets.
8. Privacy mode hides every amount, including semantics labels, notifications and share text.
9. Archived investments are deliberately left out of totals, goals and FIRE. The UI must say so wherever it matters.

## How to implement a review ticket

Tickets are GitHub issues labelled `review-2026-10` and titled `[Axx] …`. The plan is `docs/review-2026-10/ACTION_PLAN.md`, and the evidence for every finding ID (e.g. `CALC-01`) is in `docs/review-2026-10/FINDINGS.md`. If the Superpowers plugin is installed, use the skills named below. If not, follow the same steps by hand.

1. **Understand.** Read the issue and every finding it links. Re-check them against current `main`: the review ran at `f08e452` and main has moved since. If a finding no longer reproduces, say so on the issue, and narrow the work or stop.
2. **Check order.** Every “Blocked by” issue must be merged. No open PR may already cover the same ticket or the same files; if one does, coordinate in the issue first.
3. **Plan** (`superpowers:writing-plans`). Post a short plan as an issue comment: the files to change, the tests to add, and the risks. Stay inside the ticket. Anything else you notice becomes a new issue, not part of this PR.
4. **Test first** (`superpowers:test-driven-development`). This is mandatory for calculations, data, currency, notifications, auth, import/export and security.
   1. Write the failing tests first, from the issue's “Tests to write first” and acceptance criteria, with exact expected values: rates to 1e-6, money to the paisa.
   2. Run them and confirm they fail for the reason the issue describes. Quote that failure in the PR.
   3. Make the smallest change that turns them green, then refactor with the tests still green.
   4. If an existing test pins the wrong behaviour (the issue names it), change it and explain why in the PR. Never delete, skip or loosen a test just to get green.
   5. Copy or layout changes need a widget test asserting the new text and semantics.
5. **Debug systematically** (`superpowers:systematic-debugging`). Reproduce, find the root cause, then fix. No guess-and-check edits.
6. **Verify before saying done** (`superpowers:verification-before-completion`):
   1. Run `flutter analyze` and the full `flutter test`.
   2. Check every acceptance criterion in the issue.
   3. If you changed `.github/`, run `zizmor --offline .github/` and `actionlint` on the changed workflows, and compare with `main`. If you changed a shell script, run `shellcheck` on it. Add no new findings. (`pip install --user zizmor actionlint-py shellcheck-py` if they are missing.)
   4. Put the command output summary in the PR.
7. **Open the PR:**
   - Use one ticket per branch and PR. Name the branch `review/a03-usd-default`.
   - Use conventional-commit titles, e.g. `fix(currency): default missing currency to base currency [A03]`. The changelog and Play release notes are generated from these, so write the subject for users.
   - Start the body with `Closes #<issue>`. Then cover:
     - what changed and why;
     - the tests added, with red-then-green evidence;
     - how you verified it;
     - screenshots for UI changes;
     - migration or rollback notes;
     - follow-ups.
   - Run `superpowers:requesting-code-review` before marking the PR ready. Handle review feedback with `superpowers:receiving-code-review`.
   - Right after opening any PR, comment `@coderabbitai review` on it. The repo gets no automatic CodeRabbit reviews, and the free plan allows one review an hour. If CodeRabbit replies "Review limit reached", ask again after the time it names, one PR at a time. Ask again after you push fixes for a "changes requested" review, because that review blocks the merge until CodeRabbit approves.
   - The review covers more than correctness and tests. It must also check:
     - **Security and privacy:** workflow token permissions, checkout credentials, untrusted `${{ }}` in `run:`, secrets, auth and deletion flows, and PII or amounts in logs.
     - **Bypass:** for every guard, check or gate, how it could pass falsely, for example on deleted, renamed or symlinked files, re-runs, time zones, process death or offline.
     - **Integration:** merge the other open PRs of the same wave together with this one and run the full suite.
   - Before calling a PR ready or done, read its GitHub reviews, review comments and PR comments (CodeRabbit included). Treat every unresolved finding as yours to fix or answer.
   - In a wave, list the merge order whenever one PR changes a signature or default that another PR relies on.
8. **Leave a trail.** Tick the issue's checklist and post progress there, so another session can pick up where you stopped.

## Decisions already made

- 2026-10-02: archived investments stay excluded from totals; add explicit warnings and disclosure (A17).
- 2026-10-02: iOS is deferred until Android activation and retention targets are met.
- 2026-10-03: records saved without a currency are stamped once, after the user confirms which currency they are in (A03-F1).
- Plan defaults that hold until the founder says otherwise: Premium is built from new features only, and nothing free today becomes paid (A58); the dormant ads SDK is removed (A34, A57); Income Guardian is hidden until something generates expected payouts (A42).
- Account deletion builds on the existing pipeline: `deletionRequests` rules (APP-331), the processing job in `scripts/account-deletion` (APP-332) and in-app requests (APP-334). Extend that work; don't replace it.

## Don't

- Push to `main`, deploy to Firebase, or change production Play listings from a session. Merges and deploys are the founder's.
- Edit CI workflows or `release.yaml` unless the ticket asks for it.
- Add a dependency without the checklist in the rules (§11).
- Add new files under `docs/` beyond what the ticket needs.
- Commit secrets, or real user data in test fixtures.
