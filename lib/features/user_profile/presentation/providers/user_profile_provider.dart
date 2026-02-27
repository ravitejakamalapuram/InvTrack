import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/user_profile/data/repositories/firestore_user_profile_repository.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';
import 'package:inv_tracker/features/user_profile/domain/repositories/user_profile_repository.dart';

/// Provider for user profile repository
final userProfileRepositoryProvider =
    Provider.family<UserProfileRepository, String>((ref, userId) {
      final firestore = ref.watch(firestoreProvider);
      return FirestoreUserProfileRepository(
        firestore: firestore,
        userId: userId,
      );
    });

/// Stream provider for user profile
/// Returns null if user is not authenticated or profile doesn't exist
final userProfileProvider = StreamProvider<UserProfileEntity?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) {
    return Stream.value(null);
  }

  final repository = ref.watch(userProfileRepositoryProvider(user.id));
  return repository.watchProfile();
});

/// Provider for user profile notifier
final userProfileNotifierProvider =
    NotifierProvider<UserProfileNotifier, AsyncValue<UserProfileEntity?>>(
      UserProfileNotifier.new,
    );

/// Notifier for managing user profile state and operations
class UserProfileNotifier extends Notifier<AsyncValue<UserProfileEntity?>> {
  @override
  AsyncValue<UserProfileEntity?> build() {
    // Watch the stream provider
    final profileStream = ref.watch(userProfileProvider);
    return profileStream.when(
      data: (profile) => AsyncValue.data(profile),
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
    );
  }

  /// Initialize profile for first-time user
  /// Detects locale from device and creates profile with auto-selected currency
  Future<void> initializeProfileForNewUser(String userId) async {
    state = const AsyncValue.loading();

    try {
      final repository = ref.read(userProfileRepositoryProvider(userId));

      // Check if profile already exists
      final exists = await repository.profileExists();
      if (exists) {
        // Profile already exists, just load it
        final profile = await repository.getProfile();
        state = AsyncValue.data(profile);
        return;
      }

      // Detect device locale
      final deviceLocale = LocaleDetectionService.detectDeviceLocale();
      final countryCode = LocaleDetectionService.getCountryCode(deviceLocale);
      final languageCode = LocaleDetectionService.getLanguageCode(deviceLocale);

      // Create profile with detected locale
      final profile = UserProfileEntity.fromDetectedLocale(
        userId: userId,
        countryCode: countryCode,
        languageCode: languageCode,
      );

      // Save to Firestore
      await repository.saveProfile(profile);

      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Update currency preference
  Future<void> updateCurrency(String currencyCode) async {
    final currentProfile = state.value;
    if (currentProfile == null) return;

    state = const AsyncValue.loading();

    try {
      final userId = currentProfile.userId;
      final repository = ref.read(userProfileRepositoryProvider(userId));

      // Update profile with new currency
      final updatedProfile = currentProfile.copyWith(
        preferredCurrency: currencyCode,
        isFirstLogin: false,
      );

      await repository.saveProfile(updatedProfile);
      state = AsyncValue.data(updatedProfile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Update locale preference
  Future<void> updateLocale(String localeString) async {
    final currentProfile = state.value;
    if (currentProfile == null) return;

    state = const AsyncValue.loading();

    try {
      final userId = currentProfile.userId;
      final repository = ref.read(userProfileRepositoryProvider(userId));

      final updatedProfile = currentProfile.copyWith(
        preferredLocale: localeString,
        isFirstLogin: false,
      );

      await repository.saveProfile(updatedProfile);
      state = AsyncValue.data(updatedProfile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Update date format preference
  Future<void> updateDateFormat(DateFormatPattern pattern) async {
    final currentProfile = state.value;
    if (currentProfile == null) return;

    state = const AsyncValue.loading();

    try {
      final userId = currentProfile.userId;
      final repository = ref.read(userProfileRepositoryProvider(userId));

      final updatedProfile = currentProfile.copyWith(
        dateFormatPattern: pattern,
        isFirstLogin: false,
      );

      await repository.saveProfile(updatedProfile);
      state = AsyncValue.data(updatedProfile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
