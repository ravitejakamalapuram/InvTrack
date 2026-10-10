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

## Turning it on

`.github/workflows/account-deletion.yml` runs the job every day at 20:41 UTC (02:11 IST) and can also be started by hand. On the schedule it does nothing until the repo variable `ACCOUNT_DELETION_SCHEDULE_ENABLED` is `true`. Founder steps, in this order:

1. **Do one manual dry run first.** Actions -> account-deletion -> Run workflow, branch `main`, leave `dry_run` ticked. Read the step summary (uid hashes only). Nothing is deleted or written.
2. **Optional until the Google Analytics deletion step (A102) is merged, required before step 3 after that.** Set the repo variable `GA4_PROPERTY_ID` (the numeric GA4 property ID), enable the Google Analytics API in the `invtracker-b19d1` Cloud project and give `account-deletion-bot@invtracker-b19d1.iam.gserviceaccount.com` Editor access on the GA4 property. Today the job does not read `GA4_PROPERTY_ID`. Accounts deleted before it is set cannot get an Analytics request later, because the job keeps only a hash of the uid.
3. **Turn the schedule on:** Settings -> Secrets and variables -> Actions -> Variables -> set `ACCOUNT_DELETION_SCHEDULE_ENABLED` to `true`. To pause, delete the variable or set anything else; manual runs still work.

How the workflow behaves:

- Three jobs. `run` authenticates keylessly and runs `run.mjs`. `verify` starts a fresh job with `verify-run.mjs` for a live run (it is skipped for a dry run, an email request or a skipped run). `notify` runs when either fails and opens one issue labelled `account-deletion`, or comments on the open one. The issue holds a link to the run and the job results, never a uid, email or name.
- Only `refs/heads/main` runs it. Only one run at a time, and a running deletion is never cancelled.
- A manual run is a dry run unless `dry_run` is unticked; the schedule is always live. `sweep_inactive_guests_days` and `max_per_run` must be whole numbers or the run stops before it touches anything. `force` is false on the schedule.
- `request_email` is masked and never printed or put in the step summary. GitHub itself stores dispatch inputs with the run record and the job cannot hide that, so use the in-app request where you can and this input only as a fallback.
- Dependencies are installed with `npm install --omit=dev --ignore-scripts` and there is no lockfile yet, so versions float inside their ranges.
- If the repository is public and sees no activity for 60 days, GitHub pauses scheduled workflows. The 3-day stale-request alert lives in the job, so it cannot fire while the schedule is paused: look at the Actions tab after a quiet period.
- `test/workflow.test.mjs` fails if one of these guards is removed (top-level `permissions: {}`, the schedule gate, `dry_run` defaulting to true, every action pinned to a SHA, no `inputs.*` inside a script, the email kept out of logs). It needs no emulator: `node --test test/workflow.test.mjs`.

## Not included (follow-ups)

- Purging `deletionAudit` entries after 12 months.
- A lockfile for the job's dependencies, and an alert when the schedule has not run for two days.
