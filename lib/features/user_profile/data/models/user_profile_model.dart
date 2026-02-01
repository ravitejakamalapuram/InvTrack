import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';

/// Firestore model for UserProfile entity
class UserProfileModel {
  /// Current schema version for migrations
  static const int currentSchemaVersion = 1;

  /// Convert UserProfileEntity to Firestore document
  static Map<String, dynamic> toFirestore(UserProfileEntity profile) {
    return {
      'schemaVersion': currentSchemaVersion,
      'userId': profile.userId,
      'preferredCurrency': profile.preferredCurrency,
      'preferredLocale': profile.preferredLocale,
      'countryCode': profile.countryCode,
      'languageCode': profile.languageCode,
      'dateFormatPattern': profile.dateFormatPattern.name,
      'isFirstLogin': profile.isFirstLogin,
      'createdAt': Timestamp.fromDate(profile.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert Firestore document to UserProfileEntity
  static UserProfileEntity fromFirestore(
    Map<String, dynamic> data,
    String userId,
  ) {
    // Parse date format pattern
    final dateFormatStr = data['dateFormatPattern'] as String? ?? 'mdy';
    final dateFormat = DateFormatPattern.values.firstWhere(
      (e) => e.name == dateFormatStr,
      orElse: () => DateFormatPattern.mdy,
    );

    // Parse timestamps
    final createdAtTimestamp = data['createdAt'] as Timestamp?;
    final updatedAtTimestamp = data['updatedAt'] as Timestamp?;
    final now = DateTime.now();

    return UserProfileEntity(
      userId: userId,
      preferredCurrency: data['preferredCurrency'] as String? ?? 'USD',
      preferredLocale: data['preferredLocale'] as String? ?? 'en_US',
      countryCode: data['countryCode'] as String? ?? 'US',
      languageCode: data['languageCode'] as String? ?? 'en',
      dateFormatPattern: dateFormat,
      isFirstLogin: data['isFirstLogin'] as bool? ?? false,
      createdAt: createdAtTimestamp?.toDate() ?? now,
      updatedAt: updatedAtTimestamp?.toDate() ?? now,
    );
  }
}

