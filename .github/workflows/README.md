# InvTrack CI/CD workflows

All release logic lives in the shared `release-platform` repo; these files are thin callers.

| File | When it runs | What it does |
|---|---|---|
| `ci.yml` | Pull requests and pushes to `main`/`develop` (skips docs-only changes) | Analyze, test and dry-run build through `release-platform` `app-ci.yml` |
| `auto-release.yml` | Hourly, on `hotfix:` pushes, or manually | Releases once there are unreleased `feat`/`fix`/`perf`/`revert` commits and at least 3 hours since the last release, then promotes to production at 5% (staged rollout). Set the repo variable `RELEASE_HOLD=true` to pause it |
| `release.yml` | Manual (Actions -> release) | Builds and uploads to the Play internal track; use `dry_run` to test |
| `promote.yml` | Manual (Actions -> promote), from main only | Moves a build between Play tracks / rollout fractions. Its guard job (`scripts/promotion_guard.dart`) refuses `promote` to production above 5%, and refuses any production rollout above 5% until the build has been at a partial production rollout for 48 h and the `crash_free_users` input (from Crashlytics) is at least 99.5%; any other production `rollout` also needs that input. The 48 h count starts when the Play call for the latest GitHub Release finished: the end of the auto-release run that created it, or of a later successful partial `promote` to production from main (found by the run title), whichever is later. If neither is found, going above 5% is refused. Only the first attempt of a run dispatched from main may change Play: re-runs reuse the old inputs and guard result, so dispatch a new run instead. `halt` is never blocked |
| `nightly.yml` | Nightly at 01:37 UTC, or manually | Runs the golden tests (`flutter test --tags golden test/golden`), which PR CI skips, and the critical integration flows in `integration_test` on an Android emulator. A failure does not block auto-release, and GitHub emails it only to whoever last changed the cron line, so check the Actions tab |
| `account-deletion.yml` | Daily at 20:41 UTC once the repo variable `ACCOUNT_DELETION_SCHEDULE_ENABLED` is `true`; or manually (Actions -> account-deletion), main only | Deletes the data of accounts that asked to be deleted (`scripts/account-deletion`), re-checks it in a second job and opens an `account-deletion` issue on failure. A manual run is a dry run unless `dry_run` is unticked. See `scripts/account-deletion/README.md` |

Staged rollout: auto-release puts a new build on 5% of production. At least 48 h after the 5% rollout started, and after checking Crashlytics, run promote with `rollout` and `user_fraction` 0.2, or `complete`, with the crash-free figure. A build released with `release.yml` (internal only) goes to production with `promote` at 0.05 or less first. To stop a bad build, run promote with `halt`.

Know before relying on it:
- The crash-free gate checks a figure the operator types in from Crashlytics; the guard does not read Crashlytics itself, so the gate is only as good as that figure.
- Hotfixes follow the same path: they start at 5% and need 48 h before going above 5%. With hourly auto-release, frequent `feat`/`fix` merges can replace each 5% build before it reaches 48 h, leaving most users on an older version. Set `RELEASE_HOLD=true` or merge less often when a build must reach everyone.

Reviews are done by CodeRabbit (`.coderabbit.yaml`). The old self-hosted `cd.yml` was removed; see git history.
