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
