# Google Play Store Metadata

This directory contains the store listing metadata for Google Play.

## Structure

```
android/
└── en-US/                          # Locale (BCP 47 format)
    ├── title.txt                   # App title (max 30 chars)
    ├── short_description.txt       # Short description (max 80 chars)
    ├── full_description.txt        # Full description (max 4000 chars)
    ├── changelogs/
    │   └── default.txt             # Default changelog
    └── images/
        ├── icon.png                # App icon (512x512)
        ├── featureGraphic.png      # Feature graphic (1024x500)
        ├── phoneScreenshots/       # Phone screenshots (2-8 images)
        │   ├── 1_home.png
        │   ├── 2_portfolio.png
        │   └── ...
        ├── sevenInchScreenshots/   # 7" tablet screenshots
        ├── tenInchScreenshots/     # 10" tablet screenshots
        └── tvBanner.png            # TV banner (optional)
```

## Updating Store Listing

### Via GitHub Actions (Recommended)
1. Update the files in this directory
2. Commit and push to main
3. Go to Actions → "Update Store Listing" → Run workflow
4. Select what to update (metadata, screenshots, or both)

### Manually via fastlane
```bash
# Install fastlane
gem install fastlane

# Update metadata only
fastlane supply --metadata_path fastlane/metadata/android --skip_upload_apk --skip_upload_aab --skip_upload_images

# Update screenshots only
fastlane supply --metadata_path fastlane/metadata/android --skip_upload_apk --skip_upload_aab --skip_upload_metadata
```

## Screenshot Guidelines
- Phone: 1080x1920 or 1440x2560 (portrait)
- Tablet 7": 1200x1920
- Tablet 10": 1600x2560
- Format: PNG or JPEG
- Minimum 2, maximum 8 screenshots per device type

