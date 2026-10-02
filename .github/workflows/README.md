# InvTrack CI/CD workflows

All release logic lives in the shared `release-platform` repo; these files are thin callers.

| File | When it runs | What it does |
|---|---|---|
| `ci.yml` | Pull requests and pushes to `main`/`develop` (skips docs-only changes) | Analyze, test and dry-run build through `release-platform` `app-ci.yml` |
| `auto-release.yml` | Hourly, on `hotfix:` pushes, or manually | Releases once there are unreleased `feat`/`fix`/`perf`/`revert` commits and at least 3 hours since the last release, then promotes to production at 5% (staged rollout). Set the repo variable `RELEASE_HOLD=true` to pause it |
| `release.yml` | Manual (Actions -> release) | Builds and uploads to the Play internal track; use `dry_run` to test |
| `promote.yml` | Manual (Actions -> promote) | Moves a build between Play tracks / rollout fractions. Its guard job (`scripts/promotion_guard.dart`) refuses 100% of production until the latest release is 48 h old and the `crash_free_users` input (from Crashlytics) is at least 99.5%; widening a partial rollout also needs that input. `halt` is never blocked |
| `nightly.yml` | Nightly at 01:37 UTC, or manually | Runs the golden tests (`flutter test --tags golden test/golden`), which PR CI skips |

Staged rollout: auto-release puts a new build on 5% of production. After checking Crashlytics, run promote with `rollout` and `user_fraction` 0.2, then, at least 48 h after the release, `complete` with the crash-free figure. To stop a bad build, run promote with `halt`.

Reviews are done by CodeRabbit (`.coderabbit.yaml`). The old self-hosted `cd.yml` was removed; see git history.
