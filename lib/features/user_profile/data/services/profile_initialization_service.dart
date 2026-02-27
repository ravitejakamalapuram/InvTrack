import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';
import 'package:inv_tracker/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for initializing user profile on first login
/// Detects locale and auto-selects currency based on user's country
class ProfileInitializationService {
  final UserProfileRepository _profileRepository;
  final SharedPreferences _prefs;

  ProfileInitializationService({
    required UserProfileRepository profileRepository,
    required SharedPreferences prefs,
  }) : _profileRepository = profileRepository,
       _prefs = prefs;

  /// Initialize profile for a user if it doesn't exist
  /// Returns true if profile was created, false if it already existed
  Future<bool> initializeProfileIfNeeded(String userId) async {
    try {
      // Check if profile already exists
      final exists = await _profileRepository.profileExists();
      if (exists) {
        if (kDebugMode) {
          debugPrint('📍 User profile already exists for $userId');
        }
        return false;
      }

      // Check if we've already initialized (in case of offline mode)
      final hasInitialized =
          _prefs.getBool('profile_initialized_$userId') ?? false;
      if (hasInitialized) {
        if (kDebugMode) {
          debugPrint('📍 Profile initialization already attempted for $userId');
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint('📍 Initializing profile for new user: $userId');
      }

      // Detect device locale
      final deviceLocale = LocaleDetectionService.detectDeviceLocale();
      final countryCode = LocaleDetectionService.getCountryCode(deviceLocale);
      final languageCode = LocaleDetectionService.getLanguageCode(deviceLocale);

      if (kDebugMode) {
        debugPrint('📍 Detected locale: $languageCode-$countryCode');
      }

      // Auto-select currency based on country
      final currency = LocaleDetectionService.getCurrencyForCountry(
        countryCode,
      );
      final localeString = LocaleDetectionService.getLocaleStringForCountry(
        countryCode,
      );
      final dateFormat = LocaleDetectionService.getDateFormatForCountry(
        countryCode,
      );

      if (kDebugMode) {
        debugPrint(
          '📍 Auto-selected: currency=$currency, locale=$localeString, dateFormat=${dateFormat.name}',
        );
      }

      // Create profile
      final profile = UserProfileEntity.fromDetectedLocale(
        userId: userId,
        countryCode: countryCode,
        languageCode: languageCode,
      );

      // Save to Firestore
      await _profileRepository.saveProfile(profile);

      // Mark as initialized
      await _prefs.setBool('profile_initialized_$userId', true);

      if (kDebugMode) {
        debugPrint('✅ Profile initialized successfully for $userId');
        debugPrint('   Currency: $currency');
        debugPrint('   Locale: $localeString');
        debugPrint('   Country: $countryCode');
        debugPrint('   Date Format: ${dateFormat.name}');
      }

      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error initializing profile: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Sync user profile settings to local SharedPreferences
  /// This ensures settings are available even when offline
  Future<void> syncProfileToLocalSettings(UserProfileEntity profile) async {
    try {
      await _prefs.setString('currency', profile.preferredCurrency);
      await _prefs.setString('locale', profile.preferredLocale);
      await _prefs.setString(
        'dateFormatPattern',
        profile.dateFormatPattern.name,
      );

      if (kDebugMode) {
        debugPrint('✅ Synced profile to local settings');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error syncing profile to local settings: $e');
      }
    }
  }
}
