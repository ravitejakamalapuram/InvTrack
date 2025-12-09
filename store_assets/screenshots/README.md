# Screenshot Guide

## Requirements

### Phone Screenshots (REQUIRED)
- **Minimum**: 2 screenshots
- **Maximum**: 8 screenshots
- **Size**: 16:9 or 9:16 aspect ratio
- **Recommended**: 1080 x 1920 pixels (portrait)
- **Format**: PNG or JPEG

### Tablet Screenshots (OPTIONAL)
- **Size**: 16:9 or 9:16 aspect ratio
- **Recommended**: 1920 x 1200 or 2048 x 1536

## Recommended Screenshots (in order)

### 1. onboarding.png - First Impression
- Show onboarding screen with "Track Your Investments" message
- Highlights the app's purpose immediately

### 2. dashboard.png - Main Value
- Overview screen with net position
- Shows the hero card with key metrics
- Demonstrates the beautiful dark UI

### 3. investment_list.png - Investment Management
- List of investments with types and returns
- Shows the variety of investment types supported

### 4. investment_detail.png - Transaction Tracking
- Single investment with transaction history
- Shows XIRR, MOIC, and cash flow details

### 5. add_investment.png - Easy Input
- Add investment form
- Shows the 12 investment types available

### 6. google_sync.png - Cloud Backup
- Settings screen showing Google Sheets sync
- Demonstrates the cloud backup feature

## How to Take Screenshots

### On Emulator
1. Run the app: `flutter run -d emulator-5554`
2. Navigate to the screen
3. Click camera icon in emulator toolbar
4. Screenshots saved to Desktop

### On Physical Device (Android)
1. Install app: `flutter install`
2. Press Power + Volume Down simultaneously
3. Screenshots in Photos/Gallery app

### Using Flutter Screenshot
```dart
// Add to pubspec.yaml (dev_dependencies)
# screenshot: ^1.2.0

// Take screenshot programmatically
```

## Post-Processing Tips

1. **Add device frame** (optional):
   - Use mockuphone.com
   - Or Android Studio Device Art Generator

2. **Add captions** (recommended):
   - "Track All Your Investments"
   - "Professional XIRR Calculations"
   - "Sync to Google Sheets"
   - "Beautiful Dark Mode"

3. **Consistent styling**:
   - Same device frame for all
   - Same caption style/position
   - Brand colors for text overlays

