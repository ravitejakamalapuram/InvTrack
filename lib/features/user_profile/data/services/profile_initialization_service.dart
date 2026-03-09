import 'package:inv_tracker/core/logging/logger_service.dart';
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
        LoggerService.debug(
          'User profile already exists',
          metadata: {'userId': userId},
        );
        return false;
      }

      // Check if we've already initialized (in case of offline mode)
      final hasInitialized =
          _prefs.getBool('profile_initialized_$userId') ?? false;
      if (hasInitialized) {
        LoggerService.debug(
          'Profile initialization already attempted',
          metadata: {'userId': userId},
        );
        return false;
      }

      LoggerService.info(
        'Initializing profile for new user',
        metadata: {'userId': userId},
      );

      // Detect device locale
      final deviceLocale = LocaleDetectionService.detectDeviceLocale();
      final countryCode = LocaleDetectionService.getCountryCode(deviceLocale);
      final languageCode = LocaleDetectionService.getLanguageCode(deviceLocale);

      LoggerService.debug(
        'Detected locale',
        metadata: {
          'locale': '$languageCode-$countryCode',
          'languageCode': languageCode,
          'countryCode': countryCode,
        },
      );

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

      LoggerService.debug(
        'Auto-selected settings',
        metadata: {
          'currency': currency,
          'locale': localeString,
          'dateFormat': dateFormat.name,
        },
      );

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

      LoggerService.info(
        'Profile initialized successfully',
        metadata: {
          'userId': userId,
          'currency': currency,
          'locale': localeString,
          'country': countryCode,
          'dateFormat': dateFormat.name,
        },
      );

      return true;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error initializing profile',
        error: e,
        stackTrace: stackTrace,
        metadata: {'userId': userId},
      );
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

      LoggerService.debug(
        'Synced profile to local settings',
        metadata: {
          'currency': profile.preferredCurrency,
          'locale': profile.preferredLocale,
          'dateFormat': profile.dateFormatPattern.name,
        },
      );
    } catch (e) {
      LoggerService.error('Error syncing profile to local settings', error: e);
    }
  }
}
