# Account-deletion job

Server-side deletion of InvTrack account data (Firestore `users/{uid}` tree + Firebase Auth user), run from GitHub Actions with the Admin SDK. Design: APP-332 plan (Part 2 B and D).

## What it does (`run.mjs`)

1. **Load queue**: `deletionRequests/{uid}` older than 24 h (the withdrawal window). Younger requests are only reported.
2. **Orphan sweep**: uids from `collection('users').listDocuments()` (the parent doc is never written, so `.get()` would be empty) that `auth.getUsers()` reports as not found.
3. **Guest sweep** (off unless `SWEEP_INACTIVE_GUESTS=<days>`, workflow input `sweep_inactive_guests_days`): Auth users with no linked provider and no activity for that many days.
4. **Cap**: more than `max_per_run` (25) candidates and no `force` -> nothing is deleted, `deletionRuns/{runId}` gets `refused: true`, exit 2.
5. **Per uid**: `recursiveDelete(users/{uid})` -> `auth.deleteUser` -> `verify.mjs` -> `deletionAudit/{runId}-{sha256(uid)[:16]}` (no raw uid, no email) -> delete the request **last**. A crash or a failed verify leaves the request for the next run.
6. **Alert**: a request still pending after 3 days fails the run (the page promises 7 days).
7. `dry_run` (default **true**) prints the plan and writes nothing: no audit, no run record, no deletes.

`REQUEST_EMAIL` (workflow input `request_email`): the operator email fallback. Looks the uid up with `getUserByEmail` and creates a normal queue entry (source `app`). Deletes nothing in that run.

Exit codes: 0 ok, 1 failure (verify mismatch, error, stale request), 2 refused by the cap.

## Verification

- `verify.mjs`: per uid, `users/{uid}` absent, no subcollections, zero document paths below it, and `auth.getUser` -> `user-not-found`. Shares no code with `delete.mjs`.
- `verify-run.mjs` (workflow job `verify`, fresh process): re-checks every processed uid, that `deletionRuns/{runId}` exists with `refused: false`, that the orphan sweep finds 0, and that no request older than cooling + 1 day remains.
- Any failure fails the run; the `notify` job opens **one** issue labelled `account-deletion` (a comment is added if one is already open).
- Tests prove the verifier can fail: a deleter that leaves a nested doc behind and a deleter whose `auth.deleteUser` is a no-op must both be reported as mismatches.

The processed uids travel from `run` to `verify` as a job output (the accounts no longer exist anywhere); the step summary and audit use hashes only.

## Tests

CI only (`deletion-job-tests` workflow): `npm install && npm run test:emulator`, which runs the rules tests and `test/job.test.mjs` against the Firestore + Auth emulators (`--test-concurrency=1`, the files share one emulator).

## Credentials (keyless)

`google-github-actions/auth` with Workload Identity Federation:

- provider `projects/784857267556/locations/global/workloadIdentityPools/github/providers/github-oidc`
- service account `account-deletion-bot@invtracker-b19d1.iam.gserviceaccount.com` (roles: Cloud Datastore User, Firebase Authentication Admin)

The provider only accepts `ravitejakamalapuram/InvTrack` on `refs/heads/main`: run the workflow from `main`. No secrets are stored.

## Not included (follow-ups)

- Enabling the `schedule:` trigger (PR 5).
- Purging `deletionAudit` entries after 12 months.
