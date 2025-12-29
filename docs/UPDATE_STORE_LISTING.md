# Update Store Listing - GitHub Action Guide

This document explains how the **Update Store Listing** GitHub Action works and how to use it.

---

## Overview

The `update-store-listing.yml` workflow allows you to update your Google Play Store listing (descriptions, title, screenshots) **without deploying a new app version**. This is useful for:

- Fixing typos in descriptions
- Updating screenshots with new UI
- Refreshing promotional text
- A/B testing different descriptions

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    UPDATE STORE LISTING FLOW                    │
└─────────────────────────────────────────────────────────────────┘

  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
  │   Trigger    │ ──▶  │  GitHub      │ ──▶  │  Fastlane    │
  │  (Manual)    │      │  Actions     │      │   Supply     │
  └──────────────┘      └──────────────┘      └──────────────┘
                                                     │
                                                     ▼
                                            ┌──────────────┐
                                            │ Google Play  │
                                            │  Console     │
                                            └──────────────┘
```

### Workflow Steps

1. **Checkout code** - Clones the repository
2. **Set up Ruby** - Installs Ruby 3.2 for fastlane
3. **Install fastlane** - Installs the fastlane gem
4. **Create service account file** - Writes Play Store credentials from secrets
5. **Update metadata** (if selected) - Uploads descriptions & title
6. **Update screenshots** (if selected) - Uploads new screenshots
7. **Cleanup** - Removes credentials file

---

## File Structure

The workflow reads from two locations:

### Fastlane Metadata (Primary - Used by Action)
```
fastlane/metadata/android/
└── en-US/
    ├── title.txt              # App title (max 30 chars)
    ├── short_description.txt  # Short desc (max 80 chars)
    ├── full_description.txt   # Full desc (max 4000 chars)
    └── images/
        └── phoneScreenshots/  # Phone screenshots (2-8 images)
            ├── 1_home.png
            ├── 2_detail.png
            └── ...
```

### Store Assets (Source of Truth)
```
store_assets/descriptions/
├── full_description.txt       # Master full description
├── short_description.txt      # Master short description
└── google_play_listing.md     # Complete listing reference
```

> **Note**: When updating descriptions, edit files in `store_assets/descriptions/` then copy to `fastlane/metadata/android/en-US/`.

---

## How to Use

### Step 1: Update Your Content

**For metadata (descriptions):**
```bash
# Edit the source files
vim store_assets/descriptions/full_description.txt
vim store_assets/descriptions/short_description.txt

# Copy to fastlane directory
cp store_assets/descriptions/full_description.txt fastlane/metadata/android/en-US/
cp store_assets/descriptions/short_description.txt fastlane/metadata/android/en-US/
```

**For screenshots:**
```bash
# Add screenshots to fastlane directory
# Name them sequentially: 1_name.png, 2_name.png, etc.
cp my_screenshot.png fastlane/metadata/android/en-US/images/phoneScreenshots/1_home.png
```

### Step 2: Commit & Push
```bash
git add .
git commit -m "chore: Update store listing"
git push origin main
```

### Step 3: Run the Workflow

1. Go to **GitHub → Actions → Update Store Listing**
2. Click **Run workflow**
3. Select options:
   - ✅ **Update metadata** - For descriptions/title
   - ✅ **Update screenshots** - For images
4. Click **Run workflow**

![Run Workflow](https://docs.github.com/assets/images/help/actions/actions-manually-run-workflow.png)

---

## Required Secrets

| Secret | Description |
|--------|-------------|
| `PLAY_STORE_CREDENTIALS` | Google Play Service Account JSON key |

### Setting Up Play Store Credentials

1. Go to [Google Play Console](https://play.google.com/console)
2. Navigate to **Settings → API access**
3. Create or use existing service account
4. Download the JSON key
5. Add to GitHub: **Settings → Secrets → Actions → New secret**
   - Name: `PLAY_STORE_CREDENTIALS`
   - Value: Paste entire JSON content

---

## Workflow Options

| Option | Default | Description |
|--------|---------|-------------|
| `update_metadata` | `true` | Upload title, short & full descriptions |
| `update_screenshots` | `false` | Upload screenshots from images folder |

---

## Screenshot Guidelines

| Type | Dimensions | Required |
|------|------------|----------|
| Phone | 1080x1920 or 1440x2560 | 2-8 images |
| Tablet 7" | 1200x1920 | Optional |
| Tablet 10" | 1600x2560 | Optional |

- Format: PNG or JPEG
- Naming: Sequential (1_name.png, 2_name.png)

---

## Troubleshooting

### "Authentication failed"
- Verify `PLAY_STORE_CREDENTIALS` secret is set correctly
- Ensure service account has **Release Manager** permissions

### "Package not found"
- Confirm package name matches: `com.invtracker.inv_tracker`
- App must have at least one published version

### "Metadata validation failed"
- Title: Max 30 characters
- Short description: Max 80 characters
- Full description: Max 4000 characters

---

## Related Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `update-store-listing.yml` | Manual | Update store metadata only |
| `deploy-android.yml` | Tag push (`v*`) | Build & deploy app + whatsnew |

---

## Quick Reference

```bash
# Update descriptions only
1. Edit store_assets/descriptions/*.txt
2. Copy to fastlane/metadata/android/en-US/
3. Push to main
4. Run "Update Store Listing" workflow with update_metadata=true

# Update screenshots only
1. Add images to fastlane/metadata/android/en-US/images/phoneScreenshots/
2. Push to main
3. Run "Update Store Listing" workflow with update_screenshots=true
```

