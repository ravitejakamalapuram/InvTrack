# Daily crash-fix routine

Two parts: a GitHub Action files crashes as issues, and the daily scheduled session fixes the open ones. The session never fetches from Crashlytics.

## Part 1: filing (shared GitHub Action)

`.github/workflows/crash-issues.yml` runs daily at 07:53 IST (and on demand, dry run by default) and calls release-platform's reusable `crash-issues.yml`, shared by every app. It reads the Crashlytics REST API with release-bot (keyless, no secret), takes fatal crashes and ANRs from the last 7 days that are not closed, and files up to 5 new issues per run, labelled `crash`, titled `[crash <id8>] <title>`, with counts, first/last seen versions, device/OS/app version of the latest sample, and the stack trace. App log lines are left out (they can hold personal data); the shared workflow's `include_logs` input opts in, and this caller does not set it. A hidden marker `crashlytics-issue:<full id>` in the body dedupes across runs, open or closed. User, installation, session and event ids and custom keys are never copied (rule 7 in `CLAUDE.md`).

One-time setup (owner): grant `release-bot@rk-release-platform.iam.gserviceaccount.com` the Firebase Crashlytics Viewer role on `invtracker-b19d1`, and enable the Firebase Crashlytics API once in `rk-release-platform`. Then run the workflow with dry run on, and again with it off.

## Part 2: fixing (daily scheduled session)

1. Read the Founder Inbox answers first; mark handled ones.
2. List open issues labelled `crash`, highest impacted users first. Skip any with an open PR.
3. Triage each against current `main` (standing rule): find the blamed code, check `git log` for a fix newer than the first/last seen version. Already fixed: comment with the commit and close. Cannot locate or reproduce: comment with what you checked and leave it open.
4. Otherwise fix it: failing test first, smallest change, `flutter analyze` and `flutter test --exclude-tags=golden`, branch `crash/<id8>-<slug>`, conventional title `fix(<area>): ...`, body starting `Closes #<issue>`.
5. PR size rule: small and obvious fix: self-review once, squash-merge on green CI with no conflict. Money, data, notifications, sign-in, security or larger: comment `@coderabbitai review` and merge only after approval and green CI. Never deploy or touch Play.
6. Cap at 3 fixes per run. Quote only the exception and top frames in PRs.
7. Finish with one line: open crash issues, fixed, already fixed, skipped. Silent when there are none.
