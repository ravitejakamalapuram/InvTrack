import 'package:inv_tracker/core/services/locale_detection_service.dart';

/// User profile entity containing locale and regional preferences
/// Stored in Firestore at users/{userId}/profile/settings
class UserProfileEntity {
  /// User ID (matches Firebase Auth UID)
  final String userId;

  /// Preferred currency code (e.g., 'USD', 'INR', 'EUR')
  final String preferredCurrency;

  /// Preferred locale for number formatting (e.g., 'en_US', 'en_IN')
  final String preferredLocale;

  /// Country code detected on first login (e.g., 'US', 'IN', 'GB')
  final String countryCode;

  /// Language code (e.g., 'en', 'hi', 'es')
  final String languageCode;

  /// Date format preference
  final DateFormatPattern dateFormatPattern;

  /// Whether this is the user's first login
  final bool isFirstLogin;

  /// When the profile was created
  final DateTime createdAt;

  /// When the profile was last updated
  final DateTime updatedAt;

  const UserProfileEntity({
    required this.userId,
    required this.preferredCurrency,
    required this.preferredLocale,
    required this.countryCode,
    required this.languageCode,
    required this.dateFormatPattern,
    this.isFirstLogin = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a default profile from detected locale
  factory UserProfileEntity.fromDetectedLocale({
    required String userId,
    required String countryCode,
    required String languageCode,
  }) {
    final now = DateTime.now();
    final currency = LocaleDetectionService.getCurrencyForCountry(countryCode);
    final locale = LocaleDetectionService.getLocaleStringForCountry(
      countryCode,
    );
    final dateFormat = LocaleDetectionService.getDateFormatForCountry(
      countryCode,
    );

    return UserProfileEntity(
      userId: userId,
      preferredCurrency: currency,
      preferredLocale: locale,
      countryCode: countryCode,
      languageCode: languageCode,
      dateFormatPattern: dateFormat,
      isFirstLogin: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a copy with updated fields
  UserProfileEntity copyWith({
    String? preferredCurrency,
    String? preferredLocale,
    String? countryCode,
    String? languageCode,
    DateFormatPattern? dateFormatPattern,
    bool? isFirstLogin,
    DateTime? updatedAt,
  }) {
    return UserProfileEntity(
      userId: userId,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      preferredLocale: preferredLocale ?? this.preferredLocale,
      countryCode: countryCode ?? this.countryCode,
      languageCode: languageCode ?? this.languageCode,
      dateFormatPattern: dateFormatPattern ?? this.dateFormatPattern,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserProfileEntity &&
        other.userId == userId &&
        other.preferredCurrency == preferredCurrency &&
        other.preferredLocale == preferredLocale &&
        other.countryCode == countryCode &&
        other.languageCode == languageCode &&
        other.dateFormatPattern == dateFormatPattern &&
        other.isFirstLogin == isFirstLogin;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
        preferredCurrency.hashCode ^
        preferredLocale.hashCode ^
        countryCode.hashCode ^
        languageCode.hashCode ^
        dateFormatPattern.hashCode ^
        isFirstLogin.hashCode;
  }

  @override
  String toString() {
    return 'UserProfileEntity(userId: $userId, currency: $preferredCurrency, '
        'locale: $preferredLocale, country: $countryCode, '
        'language: $languageCode, dateFormat: $dateFormatPattern, '
        'isFirstLogin: $isFirstLogin)';
  }
}
