# Engineering Review Learning Log

Compact, evidence-backed reusable lessons from engineering reviews. Keep this file free of secrets, personal data, customer data, raw logs, and transient PR chatter. Current code and evidence outrank older lessons.

## 2026-10-09 — Opening valuation is not a cash flow

- **Pattern:** A tracking-start/opening valuation must be modeled separately from actual cash flows and from an ending/terminal valuation.
- **Why it was missed:** Existing calculation paths can return `null` when no cash flows exist before considering a manual value, while financial metrics also use current valuations as terminal inflows. Without an explicit contract, implementation can either hide a known value or accidentally manufacture lifetime performance.
- **Evidence:** InvTrack issues #941 and #944; the reviewed `CurrentValueCalculator.valuationOf()` behavior and central financial calculation contract. #941 requires a visible ₹5L baseline with no historical flows while lifetime return/XIRR remain unknown.
- **Improved heuristic:** For every valuation feature, separately specify (1) display eligibility, (2) performance-history eligibility, (3) tracking-period start/end semantics, and (4) actual cash-flow accounting. Never create a synthetic transaction to satisfy a calculator. For as-of queries select the latest applicable snapshot, never sum snapshots. If historical flows arrive later, require deterministic rebase/precedence behavior.
- **Regression tests:** Baseline with no cash flows; principal repayment vs income receipt; earlier transactions imported later; latest snapshot selection; edit/clear; offline conflict; mixed currency; archive/close/reopen.
- **Confidence:** High for the modeling invariant; implementation details must be revalidated against the current main branch when the feature PR is opened.

## 2026-10-09 — Preserve ambiguity in duplicate matching

- **Pattern:** Duplicate detection must preserve all candidate entity IDs for a fingerprint rather than collapse to one ID before ambiguity checks.
- **Why it was missed:** A map using `putIfAbsent` can discard competing matches. Tests that cover only different fingerprints or distinct transaction keys do not expose collisions across two otherwise identical entities.
- **Evidence:** Prior review of InvTrack import duplicate detection in PR #935 identified a same-name, same-transaction-key collision that could leave a row assigned to whichever investment ID was retained first.
- **Improved heuristic:** Model a fingerprint as a set of candidate IDs. If a row maps to multiple active entities, fail closed or require explicit user resolution. Test two identical candidate transactions plus an additional non-duplicate row with duplicate-skip both enabled and disabled.
- **Confidence:** High for the general matching invariant; re-check exact implementation and current PR head before acting on this lesson.


## 2026-10-09 — Ticket edits must be testable

- **Pattern:** Every material ticket change must leave the issue actionable, not merely descriptive. Include explicit acceptance criteria and concrete test scenarios.
- **Why it was missed:** A ticket can receive a useful design clarification in a comment while the canonical issue body still lacks testable Given/When/Then coverage or clear completion conditions. Comments alone make requirements harder to discover and maintain.
- **Evidence:** Follow-up update to InvTrack #941 and #944 added detailed acceptance checklists and scenario coverage for baseline valuation, principal vs income, historical import, snapshot selection, currency, legacy migration, lifecycle, account isolation, consumer consistency, and telemetry privacy.
- **Improved heuristic (default for future ticket changes):** Before finishing any ticket creation or edit, verify the canonical issue body contains: (1) problem/context, (2) intended behavior/scope, (3) explicit acceptance criteria, (4) concrete test scenarios including failure/edge cases, and (5) dependencies/migration or rollout notes where relevant. For a small maintenance ticket, keep these sections concise rather than omitting them. Update the issue body, not only a comment, when requirements change. Do not invent tests or claim they ran; distinguish required test scenarios from executed tests.
- **Confidence:** High. Apply across active repositories; adapt detail to risk and scope.

## 2026-10-09 — Regression assertions must observe the behavior under test

- **Pattern:** A test that asserts an initially empty capture list remains empty can pass even when the code under test never reaches or incorrectly invokes the persistence boundary. Assert the relevant call count or observable side effect directly.
- **Why it was missed:** The ambiguous-import regression tests checked that captured investments and cash flows were empty, but the test notifier initializes both lists empty. Those assertions did not prove that `bulkImport` was never called.
- **Evidence:** InvTrack PR #935 review found the vacuous assertions; the follow-up adds a `bulkImportCalls` counter and asserts zero calls in both the ambiguous-match and skip-duplicates cases.
- **Improved heuristic:** For every negative-path test, identify the exact prohibited behavior and instrument its boundary (method invocation, write attempt, network request, event emission, or persisted state). Prove the test fails if the guard is removed. Empty output alone is insufficient when the output container starts empty or the operation can fail before writing.
- **Confidence:** High.
