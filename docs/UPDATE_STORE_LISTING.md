# Updating the Google Play store listing

The Play listing (title, short and full description, phone screenshots) lives in this repo at
`android/fastlane/metadata/android/` and is synced to Play by release-platform's `listing`
workflow. Do not edit the listing by hand in Play Console: the next sync makes Play match the repo
again, and a hand edit leaves the repo wrong in the meantime.

This replaces the old `update-store-listing.yml` / fastlane `supply` flow, which needed a
service-account key and no longer exists.

## Change the listing

1. Open a PR that edits files under `android/fastlane/metadata/android/en-US/`:
   - `title.txt` (max 30 chars), `short_description.txt` (max 80), `full_description.txt` (max 4,000)
   - `images/phoneScreenshots/*.png`: 2 to 8 images, aspect ratio at most 2:1, 24-bit PNG or JPEG
     with no alpha channel. Order is by file name. Generate them with
     `STORE_SCREENSHOTS_DIR=android/fastlane/metadata/android/en-US/images/phoneScreenshots flutter test test/store_screenshots/store_screenshots_test.dart`
     (no emulator; see `integration_test/README.md`), which writes 1080x1920 images ready to commit.
2. The PR check (`ci.yml` → release-platform `app-ci`) validates the listing against Play's rules.
3. After the merge, run **Actions → listing → Run workflow** with `dry_run: true` and read the
   summary. Then run it again with `dry_run: false`.

The workflow authenticates keylessly (GitHub OIDC → `release-bot`), sends one Play edit per run,
changes text only where it differs, and replaces an image set only when its ordered SHA-256 list
differs. Image types that are not in the folder (icon, feature graphic, 7" and 10" tablet
screenshots) stay as they are on Play. The workflow shares the release lock, so it never overlaps
a release.

Reference: [release-platform → Store listings](https://github.com/ravitejakamalapuram/release-platform#store-listings).
