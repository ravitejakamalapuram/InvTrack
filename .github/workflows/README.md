# InvTrack CI/CD workflows

All release logic lives in the shared `release-platform` repo; these files are thin callers.

| File | When it runs | What it does |
|---|---|---|
| `ci.yml` | Pull requests and pushes to `main`/`develop` (skips docs-only changes) | Analyze, test and dry-run build through `release-platform` `app-ci.yml` |
| `auto-release.yml` | Hourly, on `hotfix:` pushes, or manually | Releases once there are unreleased `feat`/`fix`/`perf`/`revert` commits and at least 3 hours since the last release, then promotes to production. Set the repo variable `RELEASE_HOLD=true` to pause it |
| `release.yml` | Manual (Actions -> release) | Builds and uploads to the Play internal track; use `dry_run` to test |
| `promote.yml` | Manual (Actions -> promote) | Moves a build between Play tracks / rollout fractions |

Reviews are done by CodeRabbit (`.coderabbit.yaml`). The old self-hosted `cd.yml` was removed; see git history.
