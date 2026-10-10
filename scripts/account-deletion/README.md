# Account-deletion job

Server-side deletion of InvTrack account data (Firestore `users/{uid}` tree + Firebase Auth user), run from GitHub Actions with the Admin SDK. Design: APP-332 plan (Part 2 B and D).

## What it does (`run.mjs`)

1. **Load queue**: `deletionRequests/{uid}` older than 24 h (the withdrawal window). Younger requests are only reported.
2. **Orphan sweep**: uids from `collection('users').listDocuments()` (the parent doc is never written, so `.get()` would be empty) that `auth.getUsers()` reports as not found.
3. **Guest sweep** (off unless `SWEEP_INACTIVE_GUESTS=<days>`, workflow input `sweep_inactive_guests_days`): Auth users with no linked provider and no activity for that many days.
4. **Cap**: more than `max_per_run` (25) candidates and no `force` -> nothing is deleted, `deletionRuns/{runId}` gets `refused: true`, exit 2.
5. **Per uid**: `recursiveDelete(users/{uid})` -> `auth.deleteUser` -> Google Analytics deletion request (live mode only, see below) -> `verify.mjs` -> `deletionAudit/{runId}-{sha256(uid)[:16]}` (no raw uid, no email; includes the Analytics outcome) -> delete the request **last**. A crash, a failed verify or a failed Analytics request leaves the request for the next run.
6. **Alert**: a request still pending after 3 days fails the run (the page promises 7 days).
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
- `verify-run.mjs` (workflow job `verify`, fresh process): re-checks every processed uid, that `deletionRuns/{runId}` exists with `refused: false`, that the orphan sweep finds 0, and that no request older than cooling + 1 day remains.
- Any failure fails the run; the `notify` job opens **one** issue labelled `account-deletion` (a comment is added if one is already open).
- Tests prove the verifier can fail: a deleter that leaves a nested doc behind and a deleter whose `auth.deleteUser` is a no-op must both be reported as mismatches.

The processed uids travel from `run` to `verify` as a job output (the accounts no longer exist anywhere); the step summary and audit use hashes only.

## Tests

CI only (`deletion-job-tests` workflow): `npm install && npm run test:emulator`, which runs the rules tests, `test/job.test.mjs` and `test/ga4.test.mjs` against the Firestore + Auth emulators (`--test-concurrency=1`, the files share one emulator). `test/ga4.test.mjs` needs no emulator: `node --test test/ga4.test.mjs`.

## Credentials (keyless)

`google-github-actions/auth` with Workload Identity Federation:

- provider `projects/784857267556/locations/global/workloadIdentityPools/github/providers/github-oidc`
- service account `account-deletion-bot@invtracker-b19d1.iam.gserviceaccount.com` (roles: Cloud Datastore User, Firebase Authentication Admin)

The provider only accepts `ravitejakamalapuram/InvTrack` on `refs/heads/main`: run the workflow from `main`. No secrets are stored.

## Not included (follow-ups)

- Enabling the `schedule:` trigger (PR 5).
- Purging `deletionAudit` entries after 12 months.
