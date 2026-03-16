# Localization - Quick Start Guide

## For Developers

### Setup (One-Time)

1. **Install dependencies**:
```bash
flutter pub get
```

2. **Generate localization files**:
```bash
flutter gen-l10n
```

3. **Run the app**:
```bash
flutter run
```

---

## Using Localization in Code

### 1. Detecting User's Locale

```dart
import 'package:inv_tracker/core/services/locale_detection_service.dart';

// Detect device locale
final locale = LocaleDetectionService.detectDeviceLocale();

// Get country code
final country = LocaleDetectionService.getCountryCode(locale); // 'US', 'IN', etc.

// Get currency for country
final currency = LocaleDetectionService.getCurrencyForCountry('IN'); // 'INR'

// Get locale string for country
final localeStr = LocaleDetectionService.getLocaleStringForCountry('IN'); // 'en_IN'

// Get date format for country
final dateFormat = LocaleDetectionService.getDateFormatForCountry('IN'); // DateFormatPattern.dmy
```

### 2. Formatting Currency

```dart
import 'package:inv_tracker/core/utils/currency_utils.dart';

// Get currency symbol
final symbol = getCurrencySymbol('INR'); // '₹'

// Format currency (full precision)
final formatted = formatCurrency(100000, '₹', 'en_IN'); // '₹1,00,000'

// Compact notation (locale-aware)
final compact = formatCompactCurrency(1500000, symbol: '₹', locale: 'en_IN'); // '₹1.5Cr'

// Using providers (recommended)
final currencyFormat = ref.watch(currencyFormatProvider);
final formatted = currencyFormat.format(100000); // Uses user's currency
```

### 3. Formatting Dates

```dart
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';

final date = DateTime(2026, 12, 31);

// Format by pattern
final usDate = AppDateUtils.formatByPattern(date, DateFormatPattern.mdy); // '12/31/2026'
final ukDate = AppDateUtils.formatByPattern(date, DateFormatPattern.dmy); // '31/12/2026'
final isoDate = AppDateUtils.formatByPattern(date, DateFormatPattern.ymd); // '2026-12-31'

// Format for display
final display = AppDateUtils.formatForDisplay(date, DateFormatPattern.dmy); // '31 Dec 2026'

// Relative dates
final relative = AppDateUtils.formatRelative(DateTime.now()); // 'today'
```

### 4. User Profile

```dart
import 'package:inv_tracker/features/user_profile/presentation/providers/user_profile_provider.dart';

// Watch user profile
final profileAsync = ref.watch(userProfileNotifierProvider);

profileAsync.when(
  data: (profile) {
    if (profile != null) {
      print('Currency: ${profile.preferredCurrency}');
      print('Locale: ${profile.preferredLocale}');
      print('Date Format: ${profile.dateFormatPattern}');
    }
  },
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => Text('Error: $error'),
);

// Update currency
await ref.read(userProfileNotifierProvider.notifier).updateCurrency('USD');

// Update locale
await ref.read(userProfileNotifierProvider.notifier).updateLocale('en_US');

// Update date format
await ref.read(userProfileNotifierProvider.notifier).updateDateFormat(DateFormatPattern.mdy);
```

### 5. Settings Integration

```dart
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

// Get current settings
final settings = ref.watch(settingsProvider);
print('Currency: ${settings.currency}');
print('Locale: ${settings.locale}');
print('Date Format: ${settings.dateFormatPattern}');

// Update settings
await ref.read(settingsProvider.notifier).setCurrency('USD');
await ref.read(settingsProvider.notifier).setLocale('en_US');
await ref.read(settingsProvider.notifier).setDateFormatPattern(DateFormatPattern.mdy);
```

---

## Adding New Currencies

1. **Add to LocaleDetectionService**:
```dart
// In lib/core/services/locale_detection_service.dart
static const Map<String, String> _countryToCurrencyMap = {
  // ... existing mappings
  'XX': 'XXX', // Add new country code and currency
};

static const Map<String, String> _countryToLocaleMap = {
  // ... existing mappings
  'XX': 'xx_XX', // Add locale string
};
```

2. **Add to currency_utils.dart**:
```dart
// In lib/core/utils/currency_utils.dart
const Map<String, String> _currencySymbols = {
  // ... existing symbols
  'XXX': 'X', // Add currency symbol
};

const Map<String, String> _currencyLocales = {
  // ... existing locales
  'XXX': 'xx_XX', // Add locale for number formatting
};
```

3. **Add tests**:
```dart
// In test/core/services/locale_detection_service_test.dart
test('returns correct currency for XX', () {
  expect(LocaleDetectionService.getCurrencyForCountry('XX'), 'XXX');
});
```

---

## Testing

### Run All Tests
```bash
flutter test
```

### Run Specific Test Suite
```bash
flutter test test/core/services/locale_detection_service_test.dart
flutter test test/features/user_profile/
```

### Run with Coverage
```bash
flutter test --coverage
```

---

## Common Patterns

### Display Amount with User's Currency
```dart
final currencyFormat = ref.watch(currencyFormatProvider);
final amount = 100000.0;

// Full format
Text(currencyFormat.format(amount)); // '₹1,00,000' or '$100,000'

// Compact format
Text(currencyFormat.formatCompact(amount)); // '₹1.00L' or '$100.00K'
```

### Display Date with User's Preference
```dart
final settings = ref.watch(settingsProvider);
final date = DateTime.now();

final formatted = AppDateUtils.formatForDisplay(
  date,
  settings.dateFormatPattern,
);
```

### Initialize Profile for New User
```dart
// This happens automatically via ProfileInitializer widget
// But you can also do it manually:
await ref.read(userProfileNotifierProvider.notifier)
    .initializeProfileForNewUser(userId);
```

---

## Troubleshooting

### Profile not syncing?
Check Firestore permissions and network connectivity.

### Currency not changing?
Ensure you're updating both user profile and settings:
```dart
await ref.read(userProfileNotifierProvider.notifier).updateCurrency('USD');
await ref.read(settingsProvider.notifier).setCurrency('USD');
```

### Date format not applying?
Make sure you're using the pattern-based formatting methods:
```dart
AppDateUtils.formatByPattern(date, settings.dateFormatPattern)
```

---

## Resources

- [Full Documentation](LOCALIZATION.md)
- [Migration Guide](LOCALIZATION_MIGRATION.md)
- [Implementation Summary](../IMPLEMENTATION_SUMMARY.md)

