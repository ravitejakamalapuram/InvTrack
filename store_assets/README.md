# Play Store Assets

This folder contains all assets needed for Google Play Store submission.

## Folder Structure

```
store_assets/
├── README.md                    # This file
├── descriptions/
│   ├── short_description.txt    # 80 characters max
│   └── full_description.txt     # 4000 characters max
├── graphics/
│   ├── feature_graphic.png      # 1024x500 (required)
│   ├── icon_512.png             # 512x512 high-res icon
│   └── promo_graphic.png        # 180x120 (optional)
├── screenshots/
│   ├── phone/                   # 2-8 screenshots required
│   └── tablet/                  # Optional but recommended
├── privacy/
│   ├── privacy_policy.md        # Privacy policy content
│   └── terms_of_service.md      # Terms of service content
└── release/
    └── keystore_instructions.md # How to generate signing key
```

## Checklist

- [ ] Short description (80 chars)
- [ ] Full description (4000 chars)
- [ ] Feature graphic (1024x500)
- [ ] High-res icon (512x512)
- [ ] Phone screenshots (min 2, max 8)
- [ ] Privacy policy URL
- [ ] Terms of service URL
- [ ] Release keystore generated
- [ ] App bundle built

## Quick Commands

### Build Release APK
```bash
flutter build appbundle --release
```

### Generate Screenshots
Run the app and take screenshots of:
1. Onboarding screen (first page)
2. Dashboard/Overview screen
3. Investment list
4. Investment detail with transactions
5. Add investment form
6. Settings screen

