# InvTrack CI/CD workflows

All release logic lives in the shared `release-platform` repo; these files are thin callers.

| File | When it runs | What it does |
|---|---|---|
| `ci.yml` | Pull requests and pushes to `main`/`develop` (skips docs-only changes) | Analyze, test and dry-run build through `release-platform` `app-ci.yml` |
| `auto-release.yml` | Hourly, on `hotfix:` pushes, or manually | Releases once there are unreleased `feat`/`fix`/`perf`/`revert` commits and at least 3 hours since the last release, then promotes to production at 5% (staged rollout). Set the repo variable `RELEASE_HOLD=true` to pause it |
| `release.yml` | Manual (Actions -> release) | Builds and uploads to the Play internal track; use `dry_run` to test |
| `promote.yml` | Manual (Actions -> promote) | Moves a build between Play tracks / rollout fractions. Its guard job (`scripts/promotion_guard.dart`) refuses `promote` to production at 100% (start at a fraction below 1), and refuses 100% of production until the build has been at a partial production rollout for 48 h and the `crash_free_users` input (from Crashlytics) is at least 99.5%; widening a partial rollout also needs that input. The 48 h count starts at the later of the latest GitHub Release and the latest successful partial `promote` to production (found by the run title). `halt` is never blocked |
| `nightly.yml` | Nightly at 01:37 UTC, or manually | Runs the golden tests (`flutter test --tags golden test/golden`), which PR CI skips, and the critical integration flows in `integration_test` on an Android emulator. A failure does not block auto-release, and GitHub emails it only to whoever last changed the cron line, so check the Actions tab |

Staged rollout: auto-release puts a new build on 5% of production. After checking Crashlytics, run promote with `rollout` and `user_fraction` 0.2, then, at least 48 h after the partial rollout started, `complete` with the crash-free figure. A build released with `release.yml` (internal only) goes to production with `promote` at a fraction below 1 first. To stop a bad build, run promote with `halt`.

Know before relying on it:
- The crash-free gate checks a figure the operator types in from Crashlytics; the guard does not read Crashlytics itself, so the gate is only as good as that figure.
- Hotfixes follow the same path: they start at 5% and need 48 h before 100%. With hourly auto-release, frequent `feat`/`fix` merges can replace each 5% build before it reaches 48 h, leaving most users on an older version. Set `RELEASE_HOLD=true` or merge less often when a build must reach everyone.

Reviews are done by CodeRabbit (`.coderabbit.yaml`). The old self-hosted `cd.yml` was removed; see git history.
