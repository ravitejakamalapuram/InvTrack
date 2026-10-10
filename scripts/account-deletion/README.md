# Account-deletion job

Server-side deletion of InvTrack account data (Firestore `users/{uid}` tree + Firebase Auth user), run from GitHub Actions with the Admin SDK. Design: APP-332 plan (Part 2 B and D).

## What it does (`run.mjs`)

1. **Load queue**: `deletionRequests/{uid}` older than 24 h (the withdrawal window). Younger requests are only reported. A request is written either by the app (`source: 'app'`, APP-334) or by the APP-333 web page after a Google sign-in (`source: 'web'`); both are the same document and either can withdraw it by deleting it.
2. **Orphan sweep**: uids from `collection('users').listDocuments()` (the parent doc is never written, so `.get()` would be empty) that `auth.getUsers()` reports as not found.
3. **Guest sweep** (off unless `SWEEP_INACTIVE_GUESTS=<days>`, workflow input `sweep_inactive_guests_days`): Auth users with no linked provider and no activity for that many days.
4. **Cap**: more than `max_per_run` (25) candidates and no `force` -> nothing is deleted, `deletionRuns/{runId}` gets `refused: true`, exit 2.
5. **Per uid**: `recursiveDelete(users/{uid})` -> `auth.deleteUser` -> Google Analytics deletion request (live mode only, see below) -> `verify.mjs` -> `deletionAudit/{runId}-{sha256(uid)[:16]}` (the run id, the hash and the Analytics outcome; no raw uid, no email) -> delete the request **last**. A crash, a failed verify or a failed Analytics request leaves the request for the next run.
6. **Alert**: a request still pending after 3 days fails the run (the APP-333 web page, `https://ravitejakamalapuram.github.io/delete/invtrack.html`, promises 7 days).
7. `dry_run` (default **true**) prints the plan and writes nothing: no audit, no run record, no deletes, no Analytics calls.

`REQUEST_EMAIL` (workflow input `request_email`): the operator email fallback. Looks the uid up with `getUserByEmail` and creates a normal queue entry (source `app`). Deletes nothing in that run.

Exit codes: 0 ok, 1 failure (verify mismatch, error, stale request), 2 refused by the cap.

## Google Analytics user deletion (A102)

The app sets the Analytics user ID to the Firebase UID (`lib/app/user_identity_sync.dart`), so Analytics events are tied to it. After a uid's data and Auth user are deleted, `ga4.mjs` sends a GA4 User Deletion API request for it:

`POST https://www.googleapis.com/analytics/v3/userDeletion/userDeletionRequests:upsert` with `{"kind": "analytics#userDeletionRequest", "id": {"type": "USER_ID", "userId": "<uid>"}, "propertyId": "<GA4_PROPERTY_ID>"}`, OAuth scope `https://www.googleapis.com/auth/analytics.user.deletion`, authenticated with `google-auth-library` and the same keyless credentials as the rest of the job.

- **Configuration**: set the environment variable `GA4_PROPERTY_ID` (the numeric GA4 property ID, not a secret) where `run.mjs` runs. Unset or not a number: the step is skipped with audit outcome `not-configured`, no call is made, and a live run logs a `WARNING` with the number of accounts that were deleted without an Analytics request. That request cannot be replayed afterwards, because the job keeps only a hash of the uid, so set `GA4_PROPERTY_ID` and grant access (next bullet) **before** enabling the schedule.
- **Access**: the job's service account needs the GA4 property role that the [User Deletion API documentation](https://developers.google.com/analytics/devguides/config/userdeletion/v3) requires, and the Google Analytics API enabled in its Cloud project.
- **Never blocks deletion, retried until asked**: a failed request never blocks or undoes the Firestore and Auth deletion. It is recorded (`deletionAudit` fields `ga4` = `requested` | `failed` | `not-configured`, and `ga4Status`, the HTTP status when there was one) and logged as a count only. For an account that came from a `deletionRequests` doc, a `failed` outcome keeps that doc, so the next run deletes nothing more, asks Google Analytics again and removes the doc once the request has gone out. A request that keeps failing makes the run fail after 3 days (the pending-request alert) and `verify-run.mjs` flags it after cooling + 1 day. Orphan and guest sweeps have no doc to keep, so a failure there is only counted. The uid is never logged or stored by this step, and error messages are dropped because they can contain it.
- **Dry run** makes zero calls.
- Google carries out the deletion on its own schedule. Crashlytics reports are not deleted by the job: the app clears the Crashlytics identifier at sign-out, and the reports expire under Crashlytics' own retention.

## Verification

- `verify.mjs`: per uid, `users/{uid}` absent, no subcollections, zero document paths below it, and `auth.getUser` -> `user-not-found`. Shares no code with `delete.mjs`.
- `verify-run.mjs` (workflow job `verify`, fresh process): takes the run id only. It reads that run's `deletionAudit` records (hashes), lists the `users/` documents and the Auth users that exist now and fails if the hash of any of them is in the run's set (an account or its data came back); that `deletionRuns/{runId}` exists with `refused: false`; that the orphan sweep finds 0; and that no request older than cooling + 1 day remains. The Auth listing costs one call per 1,000 accounts and is skipped when the run deleted nothing.
- Any failure fails the run; the `notify` job opens **one** issue labelled `account-deletion` (a comment is added if one is already open).
- Tests prove the verifier can fail: a deleter that leaves a nested doc behind and a deleter whose `auth.deleteUser` is a no-op must both be reported as mismatches.

No uid leaves the `run` job: not as a job output, not in a step `env:`, not in the step summary. A step's `env:` is printed at the top of its log, this repository is public, and the app sets the Analytics user ID to the Firebase uid, so a uid there would be world-readable. `run.mjs` hands on the run id only, and writes it before it deletes anything, so `verify` still runs (and reads the audit) when `run` fails part-way. A cancelled run is not checked by `verify`. A failed account is recorded as a short error code only (`safe-error.mjs`: the error's `code` when it is up to 40 characters of letters, digits and `_ . / -`, else the word `error`), never as its message, because a message can carry the uid; the step summary shows that code. A failure outside the per-account loop (a lookup, a scan or a write that throws) reaches the top-level handler of `run.mjs` or `verify-run.mjs`, which prints a fixed message and that code, never the error or its message; the verifier reports leftover subcollections by count, because their names are not ours to publish.

## Tests

CI only (`deletion-job-tests` workflow): `npm ci && npm run test:emulator`, which runs the rules tests, `test/job.test.mjs`, `test/ga4.test.mjs` and `test/workflow.test.mjs` against the Firestore + Auth emulators (`--test-concurrency=1`, the files share one emulator). `test/ga4.test.mjs` and `test/workflow.test.mjs` need no emulator: `node --test test/ga4.test.mjs`.

## Credentials (keyless)

`google-github-actions/auth` with Workload Identity Federation:

- provider `projects/784857267556/locations/global/workloadIdentityPools/github/providers/github-oidc`
- service account `account-deletion-bot@invtracker-b19d1.iam.gserviceaccount.com` (roles: Cloud Datastore User, Firebase Authentication Admin)

The provider only accepts `ravitejakamalapuram/InvTrack` on `refs/heads/main`: run the workflow from `main`. No secrets are stored.

## Turning it on

`.github/workflows/account-deletion.yml` runs the job every day at 20:41 UTC (02:11 IST) and can also be started by hand. On the schedule it does nothing until the repo variable `ACCOUNT_DELETION_SCHEDULE_ENABLED` is `true`. Founder steps, in this order:

1. **Do one manual dry run first.** Actions -> account-deletion -> Run workflow, branch `main`, leave `dry_run` ticked. Read the step summary (uid hashes only). Nothing is deleted or written.
2. **Required before step 3.** Set the repo variable `GA4_PROPERTY_ID` (the numeric GA4 property ID; the workflow passes it to the deletion step as `vars.GA4_PROPERTY_ID`), enable the Google Analytics API in the `invtracker-b19d1` Cloud project and give `account-deletion-bot@invtracker-b19d1.iam.gserviceaccount.com` Editor access on the GA4 property. Left unset, the job still deletes but skips the Analytics request and logs a warning. Accounts deleted before it is set cannot get an Analytics request later, because the job keeps only a hash of the uid.
3. **Turn the schedule on:** Settings -> Secrets and variables -> Actions -> Variables -> set `ACCOUNT_DELETION_SCHEDULE_ENABLED` to `true`. To pause, delete the variable or set anything else; manual runs still work.

How the workflow behaves:

- Three jobs. `run` authenticates keylessly and runs `run.mjs`. `verify` starts a fresh job with `verify-run.mjs` for a live run (it is skipped for a dry run, an email request, a skipped run or a cancelled run). `notify` runs when either fails and opens one issue labelled `account-deletion`, or comments on the open one. The issue holds a link to the run and the job results, never a uid, email or name.
- Only `refs/heads/main` runs it. Only one run at a time, and a running deletion is never cancelled.
- A manual run is a dry run unless `dry_run` is unticked; the schedule is always live. `sweep_inactive_guests_days` and `max_per_run` must be whole numbers or the run stops before it touches anything. `force` is false on the schedule.
- `request_email` is read from the event file in the first step, checked to be one address without a `%` (the runner percent-decodes the data of `::add-mask::`, so `%0A` or `%25` would be masked as a different string) and masked before anything else runs; later steps that receive it print `***`. It is never put in the step summary or an output. It is not hidden everywhere: GitHub shows dispatch inputs on the run page and stores them with the run record, and the job cannot hide that, so use the in-app request where you can and this input only as a fallback.
- Re-running a manually dispatched run does nothing (the `run` job is skipped unless it is the first attempt): a re-run would replay the old inputs, such as `dry_run` unticked or `force`, on the old commit with production credentials. Dispatch a new run instead. A re-run of a scheduled run is allowed, because a schedule is never forced and works from the current queue.
- Dependencies are installed with `npm ci --omit=dev --ignore-scripts` before the cloud login, so the job runs exactly the versions pinned (with integrity hashes) in `package-lock.json` and no package can run an install script while the job holds a deletion-capable credential. To change a dependency, run `npm install` here and commit the new `package-lock.json`; `npm ci` fails when the lockfile and `package.json` disagree.
- If the repository is public and sees no activity for 60 days, GitHub pauses scheduled workflows. The 3-day stale-request alert lives in the job, so it cannot fire while the schedule is paused: look at the Actions tab after a quiet period.
- `test/workflow.test.mjs` fails if one of these guards is removed or weakened: top-level `permissions: {}`; the exact `if:` of the `run` and `verify` jobs (main only, the schedule variable, first attempt only for a dispatch); the whole env of the mode, deletion and verify steps (cap, sweep, `force`, `dry_run`); a daily cron; no uid in a job output or env; every action pinned to a SHA; the dependencies installed with `npm ci --omit=dev --ignore-scripts` before the cloud login (and a lockfile pinned by integrity hash to the npm registry); no `inputs.*` inside a script; and the email kept out of logs. It also runs the real mode-step script for a table of inputs (only an explicit `false` is live, an email request is never live, bad numbers and bad emails stop the run, the email is masked and never echoed). Each rule has a deliberately broken copy that must fail it. It needs no emulator, only bash and jq: `node --test test/workflow.test.mjs`.

## Not included (follow-ups)

- Purging `deletionAudit` entries after 12 months.
- An alert when the schedule has not run for two days.
