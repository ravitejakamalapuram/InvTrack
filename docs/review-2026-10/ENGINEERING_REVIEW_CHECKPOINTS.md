# Engineering Review Checkpoints

Last refreshed: 2026-10-09 UTC. This is a delta-review checkpoint, not a claim that every open PR has been fully reviewed. Re-fetch each exact head, discussion, and CI state before acting; code/evidence outrank this file. Never store secrets, raw logs, or customer data here.

| Project / PR | Last reviewed head | Review state | Verification state | Next action |
|---|---|---|---|---|
| InvTrack #935 — ambiguous import routing | `3aa58e878e8b538ae0f35c7b926ab07da66a0b6d` | Reviewed; test-quality finding addressed by asserting `bulkImport` call count is zero. Draft. Review comment persisted. | CI run `37949921169` was in progress at checkpoint time. | Recheck CI; keep draft until Flutter tests/analyze are green. |
| appforge-control #103 — flow-keeper TDZ | `b438001c2398ad03922a1fdc92a008614f8da52d` | Reviewed; entrypoint-level offline regression test added. Draft. Review comment persisted. | `scripts tests` run `37949999730` passed. | Recheck latest head and CI before marking ready. |
| StellarTab #14 — AppForge workflow wiring | `0aaa16c6496a3c6631c56e9de1e64bbe7cfc9a6e` | Reviewed; reusable workflow and internal AppForge CLI refs pinned to immutable commits. Draft. Review comment persisted. | CI run `37950289660` passed; notification jobs were skipped because this PR is draft. | Recheck workflow/security output after the PR is ready for review. |
| cors-enabler #7 — AppForge workflow wiring | `73f485341ed93755d505677a955c4c7cfd437eae` | Reviewed; reusable workflow refs pinned. Draft. Review comment persisted. | CI run `37950295526` failed in AppForge checks. Existing lockfile still resolves vulnerable Vite/Vitest packages; CSP check also flags `style-src 'unsafe-inline'`. | Do not merge. Regenerate manifest/lockfile with patched dependency versions, test compatibility, and re-run OSV/CSP checks. |
| InvTrack #948 — review learning log | `c171fc0e34c0bab0ad9a829326a442814dd0d3c0` | Draft documentation PR; records the non-vacuous regression assertion heuristic. | No code tests required; workflow run was skipped. | Inspect the doc diff and keep separate from code changes. |
| pr-triage #2 / #3 — sync and auth gate | #2 `ad2485c87a23d88424252e06f2a19c36abed9972`; #3 `10c85d2f80d56ce357f5a9e84c0e61bc23a4c040` | Both now draft. #2 is intentionally unauthenticated; #3 adds the fail-closed Basic-auth gate. | Do not treat draft status or historical local tests as release evidence. | Do not deploy #2. Recheck current CI and stacked-base/retargeting before any deployment. |
| InvTrack website #6 — account-deletion page | `08f091107ef0b6e3bb9d2faa06ed4d8f8718998f` | Previously flagged race: a withdrawal can race with a processor that has already discovered a pending request. No fix persisted in this pass. | Backend claim/processing protocol has not been verified in the website repository. | Locate and review the authoritative deletion processor before changing client rules; require an atomic server-side claim/withdrawal protocol and regression tests. |

## Checkpoint discipline

- Skip a PR when its head SHA, diff, discussion/review state, requested changes, external findings, and relevant CI evidence are unchanged.
- When any material input changes, review the delta first and reassess affected prior findings.
- Store only durable conclusions and identifiers needed to resume review. Record tests as executed only when the workflow/run proves they executed.
