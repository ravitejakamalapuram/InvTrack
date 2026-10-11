# Localization Feature - Migration Guide

## Overview

This document describes the migration path for existing InvTrack users when the localization feature is deployed.

## What's Changing?

### New Features
1. **User Profile**: A new Firestore collection `users/{userId}/profile/settings` stores locale preferences
2. **Automatic Locale Detection**: First-time users get automatic currency/locale selection
3. **Enhanced Number Formatting**: Locale-aware formatting (Indian lakh system, European formatting, etc.)
4. **Enhanced Date Formatting**: Regional date format preferences (MDY, DMY, YMD)
5. **40+ Currencies**: Expanded from 5 to 40+ supported currencies

### Backward Compatibility

✅ **100% Backward Compatible** - No breaking changes for existing users.

## Migration Behavior

### For Existing Users

When an existing user opens the app after the update:

1. **Currency Preserved**: Their existing currency setting (from SharedPreferences) is preserved
2. **Profile Auto-Created**: A user profile is created in Firestore with:
   - `preferredCurrency`: Their existing currency
   - `preferredLocale`: Detected from device
   - `countryCode`: Detected from device
   - `languageCode`: Detected from device
   - `dateFormatPattern`: Detected based on country
   - `isFirstLogin`: false (since they're existing users)

3. **No Data Loss**: All existing investments, goals, and settings remain unchanged

4. **Seamless Experience**: Users won't notice any difference unless they:
   - Change their currency in Settings (now see 40+ options instead of 5)
   - Notice improved number formatting (e.g., Indian users see ₹1,00,000 instead of ₹100,000)

### For New Users

New users get the full experience:

1. **Automatic Detection**: On first sign-in, the app detects their country
2. **Smart Defaults**: Currency, locale, and date format are auto-configured
3. **Example**:
   - User in India → INR currency, en_IN locale, DD/MM/YYYY dates
   - User in US → USD currency, en_US locale, MM/DD/YYYY dates
   - User in Japan → JPY currency, ja_JP locale, YYYY-MM-DD dates

## Technical Details

### Database Schema

#### New Firestore Collection
```
users/{userId}/profile/settings
```

Fields:
- `schemaVersion`: 1 (for future migrations)
- `userId`: String
- `preferredCurrency`: String (e.g., 'USD', 'INR')
- `preferredLocale`: String (e.g., 'en_US', 'en_IN')
- `countryCode`: String (e.g., 'US', 'IN')
- `languageCode`: String (e.g., 'en', 'hi')
- `dateFormatPattern`: String ('mdy', 'dmy', 'ymd')
- `isFirstLogin`: Boolean
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

#### Existing SharedPreferences (Unchanged)
- `currency`: String (still used for offline-first access)
- `locale`: String (new, synced from profile)
- `dateFormatPattern`: String (new, synced from profile)
- `themeMode`: int (unchanged)

### Migration Flow

```
User Opens App
    ↓
Auth State Changes (User Logged In)
    ↓
ProfileInitializer Widget Activated
    ↓
Check if Profile Exists in Firestore
    ↓
    ├─ YES → Load Profile & Sync to SharedPreferences
    │         (Existing User Path)
    │
    └─ NO → Detect Device Locale
              ↓
           Create Profile with:
              - Detected country/language
              - Auto-selected currency
              - Existing currency from SharedPreferences (if any)
              ↓
           Save to Firestore
              ↓
           Sync to SharedPreferences
```

### Code Changes

#### New Files
- `lib/core/services/locale_detection_service.dart`
- `lib/features/user_profile/domain/entities/user_profile_entity.dart`
- `lib/features/user_profile/data/models/user_profile_model.dart`
- `lib/features/user_profile/domain/repositories/user_profile_repository.dart`
- `lib/features/user_profile/data/repositories/firestore_user_profile_repository.dart`
- `lib/features/user_profile/presentation/providers/user_profile_provider.dart`
- `lib/features/user_profile/data/services/profile_initialization_service.dart`
- `lib/features/user_profile/presentation/widgets/profile_initializer.dart`
- `lib/l10n/app_en.arb`
- `l10n.yaml`

#### Modified Files
- `lib/core/utils/currency_utils.dart` - Added 35+ new currencies
- `lib/core/utils/date_utils.dart` - Added locale-aware formatting methods
- `lib/features/settings/presentation/providers/settings_provider.dart` - Added locale and date format
- `lib/features/settings/presentation/screens/settings_screen.dart` - Enhanced currency picker
- `pubspec.yaml` - Added flutter_localizations
- `README.md` - Updated with localization info
- `docs/LOCALIZATION.md` - New comprehensive documentation

## Testing

### Pre-Deployment Testing

1. **New User Flow**:
   ```bash
   # Test with different device locales
   flutter run --dart-define=LOCALE=en_US
   flutter run --dart-define=LOCALE=en_IN
   flutter run --dart-define=LOCALE=ja_JP
   ```

2. **Existing User Flow**:
   - Install previous version
   - Create account, add investments
   - Update to new version
   - Verify currency preserved
   - Verify profile created
   - Verify no data loss

3. **Offline Behavior**:
   - Disable network
   - Open app
   - Verify settings load from SharedPreferences
   - Enable network
   - Verify sync to Firestore

### Post-Deployment Monitoring

Monitor these metrics:
- Profile creation success rate
- Currency distribution (analytics)
- Locale detection accuracy
- Error rates in profile initialization

## Rollback Plan

If issues arise, rollback is safe:

1. **Revert Code**: Deploy previous version
2. **Data Preserved**: User profiles in Firestore remain (no harm)
3. **Settings Intact**: SharedPreferences still has currency setting
4. **No Data Loss**: Investments and goals unaffected

## Support

### Common Issues

**Q: User's currency changed after update**
A: This shouldn't happen. Profile initialization preserves existing currency from SharedPreferences.

**Q: Number formatting looks different**
A: This is expected. The new locale-aware formatting is more accurate (e.g., Indian lakh system).

**Q: Profile not syncing**
A: Check Firestore permissions. Profile initialization has offline fallback.

### Debug Commands

```dart
// Check if profile exists
final exists = await ref.read(userProfileRepositoryProvider(userId)).profileExists();

// Get current profile
final profile = await ref.read(userProfileRepositoryProvider(userId)).getProfile();

// Force re-initialize
await ref.read(userProfileNotifierProvider.notifier).initializeProfileForNewUser(userId);
```

## Timeline

- **Development**: Completed
- **Testing**: 2-3 days
- **Deployment**: Gradual rollout (10% → 50% → 100%)
- **Monitoring**: 1 week post-deployment

