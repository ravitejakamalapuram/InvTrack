# Localization & Internationalization (L10n/I18n)

## Overview

InvTrack implements enterprise-grade localization supporting multiple currencies, number formats, date formats, and languages. The system automatically detects the user's locale on first login and configures appropriate settings.

## Features

### 1. **Automatic Locale Detection**
- Detects user's country and language on first login
- Auto-selects currency based on detected country
- Configures number formatting (e.g., Indian lakh system: 1,00,000)
- Sets appropriate date format (MDY, DMY, or YMD)

### 2. **Supported Currencies**
The app supports 40+ currencies including:
- **Americas**: USD, CAD, BRL, MXN, ARS, CLP, COP, PEN
- **Europe**: EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, HUF, RON
- **Asia**: INR, JPY, CNY, KRW, SGD, HKD, TWD, THB, MYR, IDR, PHP, VND, BDT, PKR, LKR, AED, SAR, ILS, TRY
- **Oceania**: AUD, NZD
- **Africa**: ZAR, NGN, KES, EGP

### 3. **Number Formatting**
- **Locale-aware grouping**: 
  - US: 1,000,000.50
  - India: 10,00,000.50 (lakh system)
  - Europe: 1.000.000,50
- **Compact notation**:
  - US: $1.2M
  - India: ₹1.2Cr (Crore), ₹1.5L (Lakh)
  - Europe: €1,2M

### 4. **Date Formatting**
- **MDY (US)**: 12/31/2026, Dec 31, 2026
- **DMY (UK/India)**: 31/12/2026, 31 Dec 2026
- **YMD (ISO/Japan)**: 2026-12-31

### 5. **User Profile Storage**
User preferences are stored in Firestore at:
```
users/{userId}/profile/settings
```

Fields:
- `preferredCurrency`: Currency code (e.g., 'USD', 'INR')
- `preferredLocale`: Locale string (e.g., 'en_US', 'en_IN')
- `countryCode`: Detected country (e.g., 'US', 'IN')
- `languageCode`: Language code (e.g., 'en', 'hi')
- `dateFormatPattern`: Date format preference ('mdy', 'dmy', 'ymd')
- `isFirstLogin`: Whether this is the user's first login
- `createdAt`: Profile creation timestamp
- `updatedAt`: Last update timestamp

## Architecture

### Core Components

#### 1. **LocaleDetectionService**
Location: `lib/core/services/locale_detection_service.dart`

Provides:
- Device locale detection
- Country-to-currency mapping
- Country-to-locale mapping
- Country-to-date-format mapping

```dart
// Detect device locale
final locale = LocaleDetectionService.detectDeviceLocale();

// Get currency for country
final currency = LocaleDetectionService.getCurrencyForCountry('IN'); // Returns 'INR'

// Get locale string for country
final localeStr = LocaleDetectionService.getLocaleStringForCountry('IN'); // Returns 'en_IN'

// Get date format for country
final dateFormat = LocaleDetectionService.getDateFormatForCountry('IN'); // Returns DateFormatPattern.dmy
```

#### 2. **UserProfileEntity**
Location: `lib/features/user_profile/domain/entities/user_profile_entity.dart`

Stores user's locale preferences.

```dart
// Create profile from detected locale
final profile = UserProfileEntity.fromDetectedLocale(
  userId: 'user123',
  countryCode: 'IN',
  languageCode: 'en',
);

// Update currency
final updated = profile.copyWith(preferredCurrency: 'USD');
```

#### 3. **Enhanced Date Utilities**
Location: `lib/core/utils/date_utils.dart`

Locale-aware date formatting:

```dart
// Format by pattern
final usDate = AppDateUtils.formatByPattern(
  DateTime.now(),
  DateFormatPattern.mdy,
); // Returns "12/31/2026"

final ukDate = AppDateUtils.formatByPattern(
  DateTime.now(),
  DateFormatPattern.dmy,
); // Returns "31/12/2026"

// Format for display
final displayDate = AppDateUtils.formatForDisplay(
  DateTime.now(),
  DateFormatPattern.dmy,
); // Returns "31 Dec 2026"
```

#### 4. **Enhanced Currency Utilities**
Location: `lib/core/utils/currency_utils.dart`

Supports 40+ currencies with proper symbols and locale-aware formatting.

```dart
// Get currency symbol
final symbol = getCurrencySymbol('INR'); // Returns '₹'

// Format currency (full precision)
final formatted = formatCurrency(100000, '₹', 'en_IN'); // Returns '₹1,00,000'

// Compact notation (locale-aware)
final compact = formatCompactCurrency(1500000, symbol: '₹', locale: 'en_IN'); // Returns '₹1.5Cr'
```

## Usage

### First-Time User Flow

1. User signs in for the first time
2. `ProfileInitializer` widget detects this is a new user
3. Device locale is detected (e.g., `en-IN`)
4. User profile is created with:
   - Currency: INR (auto-selected for India)
   - Locale: en_IN (Indian number formatting)
   - Date Format: DMY (DD/MM/YYYY)
5. Settings are synced to SharedPreferences for offline access

### Changing Preferences

Users can manually change their preferences in Settings:

```dart
// Change currency
await ref.read(settingsProvider.notifier).setCurrency('USD');

// Change locale
await ref.read(settingsProvider.notifier).setLocale('en_US');

// Change date format
await ref.read(settingsProvider.notifier).setDateFormatPattern(DateFormatPattern.mdy);
```

## Testing

Comprehensive tests are provided:

- **Locale Detection**: `test/core/services/locale_detection_service_test.dart`
- **User Profile Entity**: `test/features/user_profile/domain/entities/user_profile_entity_test.dart`
- **Firestore Model**: `test/features/user_profile/data/models/user_profile_model_test.dart`
- **Date Utilities**: `test/core/utils/date_utils_test.dart`
- **Settings Provider**: `test/features/settings/presentation/providers/settings_provider_test.dart`

Run tests:
```bash
flutter test
```

## Future Enhancements

- [ ] Add more languages (Hindi, Spanish, French, German, Japanese)
- [ ] Text localization using ARB files (infrastructure already in place)
- [ ] Time zone support
- [ ] 12-hour vs 24-hour time format
- [ ] First day of week preference (Sunday vs Monday)
- [ ] Measurement units (metric vs imperial)

## Migration Notes

### For Existing Users

Existing users will have their current currency setting preserved. On next app launch:
1. A user profile will be created with their existing currency
2. Locale and date format will be detected from device
3. No data loss or disruption

### Firestore Schema

Schema version: 1

Future schema changes will be handled via the `schemaVersion` field in the user profile document.

