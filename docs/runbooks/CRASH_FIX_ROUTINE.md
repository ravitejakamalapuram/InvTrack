# Daily crash-fix routine

Runbook for the scheduled session that fetches Crashlytics crashes and fixes them. The session follows this file; it should not rediscover how to fetch anything.

## Fetch method

Firebase's Crashlytics tools, via the Firebase MCP server (`npx -y firebase-tools@latest mcp`, tools `crashlytics_get_report`, `crashlytics_get_issue`, `crashlytics_list_events`, `crashlytics_create_note`, `crashlytics_update_issue`). Firebase project `invtracker-b19d1`, Android app id `1:784857267556:android:5ba7e064263d78f61dce71`. No BigQuery export or Blaze-only feature is needed.

Auth is a Google service account, not `firebase login`: a scheduled session has no browser. Credentials come from `GOOGLE_APPLICATION_CREDENTIALS` (path to the key file) or `GOOGLE_SERVICE_ACCOUNT_JSON` in the routine's cloud environment.

### One-time setup (owner only)

1. Google Cloud console, project `invtracker-b19d1`, IAM, Service accounts: create `crash-triage`.
2. Grant it **Firebase Crashlytics Viewer** (add **Firebase Crashlytics Admin** only if the routine should add notes and close issues; viewer is enough to start).
3. Create a JSON key and store its whole text in the routine's cloud environment as the secret/variable `FIREBASE_CRASH_SA_JSON`. Never paste it in chat or commit it.
4. Tell Claude. It then runs the verification below.

### Session start (every run)

```bash
mkdir -p "$HOME/.crash" && printf '%s' "$FIREBASE_CRASH_SA_JSON" > "$HOME/.crash/sa.json" && chmod 600 "$HOME/.crash/sa.json"
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.crash/sa.json"
npx -y firebase-tools@latest mcp --only crashlytics --dir . &   # or the plugin's firebase MCP if it is already authenticated
```

Verification: `crashlytics_get_report` with `report=topIssues`, `appId` above, `pageSize=10` returns rows. If it returns an auth error, stop and put one card in the Founder Inbox; do not try other methods.

## Daily workflow

1. Read the Founder Inbox answers first; mark handled ones.
2. Fetch `topIssues` for the last 24 h and last 7 days, `issueErrorTypes` `FATAL` and `ANR`. Candidate = new, regressed, or at least 3 users in 7 days. Ignore non-fatals.
3. Dedupe: search GitHub issues (open and closed, label `crash`) for the Crashlytics issue id (kept in the issue title as `[crash <id>]`). Existing open issue: add a comment with the new counts only if they grew.
4. Triage each candidate against current `main` (standing rule): read the stack trace via `crashlytics_get_issue` and `crashlytics_list_events`, find the code in `main`, check `git log` for a fix newer than the affected app version. Already fixed: note it on the Crashlytics issue (if admin) and skip. Cannot reproduce or locate: file an issue with the evidence, no code change.
5. Otherwise file a GitHub issue `[crash <id>] <exception> in <class>` (label `crash`), then fix it: failing test first, smallest change, `flutter analyze` and `flutter test --exclude-tags=golden`, branch `crash/<id>-<slug>`, conventional title `fix(<area>): ...`.
6. PR size rule: small and obvious fix: self-review the diff once, squash-merge on green CI with no conflict. Money, data, notifications, sign-in, security or larger: comment `@coderabbitai review`, merge only after approval and green CI. Never deploy or touch Play.
7. Cap the run at 3 fixes; the rest wait for the next day.

## Privacy

Crash events carry no names or amounts by design (rule 7 in `CLAUDE.md`). Do not copy device ids, user ids or raw event payloads into issues or PRs; quote the exception and top frames only.

## Daily output

One line in the thread or inbox: candidates found, fixed, already fixed, skipped. Silent when there are no new crashes.
