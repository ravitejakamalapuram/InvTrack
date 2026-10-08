# Engineering Review Context

This directory is operational memory for the autonomous Engineering Operating System. It is not InvTrack product documentation.

## Purpose
Store only durable, evidence-validated review state and reusable engineering-review learning that helps future runs avoid repeating mistakes.

## Structure
- `review-state/` — compact checkpoints such as reviewed PR head SHAs and material review-state watermarks when repository-local persistence is required.
- `learnings/` — RSI lessons from findings, disproofs, fixes, tests, production outcomes, and reviewer disagreements.
- `rules/` — consolidated reusable heuristics validated by evidence.

## Hygiene
Never store secrets, credentials, personal data, customer data, raw logs, arbitrary PR chatter, or transient tool output. Current code, tests, deployment configuration, and project rules outrank this memory.

## Review-state rule
Do not re-review merely because the hourly run occurred. Re-review only when the reviewed head SHA or other material evidence changes: diff, discussion, requested changes, external findings, CI/test state, security/dependency evidence, or relevant release/production state.

## RSI rule
Record a lesson only when evidence materially changes the review process. Preserve unresolved disagreement until evidence resolves it. Prefer a few high-value reusable heuristics over project-specific anecdotes.
