import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';

void main() {
  group('UserProfileEntity', () {
    final testDate = DateTime(2026, 1, 1);

    test('creates entity with all required fields', () {
      final profile = UserProfileEntity(
        userId: 'test_user',
        preferredCurrency: 'USD',
        preferredLocale: 'en_US',
        countryCode: 'US',
        languageCode: 'en',
        dateFormatPattern: DateFormatPattern.mdy,
        isFirstLogin: true,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(profile.userId, 'test_user');
      expect(profile.preferredCurrency, 'USD');
      expect(profile.preferredLocale, 'en_US');
      expect(profile.countryCode, 'US');
      expect(profile.languageCode, 'en');
      expect(profile.dateFormatPattern, DateFormatPattern.mdy);
      expect(profile.isFirstLogin, true);
      expect(profile.createdAt, testDate);
      expect(profile.updatedAt, testDate);
    });

    test('creates entity with default isFirstLogin as false', () {
      final profile = UserProfileEntity(
        userId: 'test_user',
        preferredCurrency: 'USD',
        preferredLocale: 'en_US',
        countryCode: 'US',
        languageCode: 'en',
        dateFormatPattern: DateFormatPattern.mdy,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(profile.isFirstLogin, false);
    });

    group('fromDetectedLocale', () {
      test('creates profile from US locale', () {
        final profile = UserProfileEntity.fromDetectedLocale(
          userId: 'test_user',
          countryCode: 'US',
          languageCode: 'en',
        );

        expect(profile.userId, 'test_user');
        expect(profile.preferredCurrency, 'USD');
        expect(profile.preferredLocale, 'en_US');
        expect(profile.countryCode, 'US');
        expect(profile.languageCode, 'en');
        expect(profile.dateFormatPattern, DateFormatPattern.mdy);
        expect(profile.isFirstLogin, true);
      });

      test('creates profile from India locale', () {
        final profile = UserProfileEntity.fromDetectedLocale(
          userId: 'test_user',
          countryCode: 'IN',
          languageCode: 'en',
        );

        expect(profile.preferredCurrency, 'INR');
        expect(profile.preferredLocale, 'en_IN');
        expect(profile.countryCode, 'IN');
        expect(profile.dateFormatPattern, DateFormatPattern.dmy);
        expect(profile.isFirstLogin, true);
      });

      test('creates profile from UK locale', () {
        final profile = UserProfileEntity.fromDetectedLocale(
          userId: 'test_user',
          countryCode: 'GB',
          languageCode: 'en',
        );

        expect(profile.preferredCurrency, 'GBP');
        expect(profile.preferredLocale, 'en_GB');
        expect(profile.countryCode, 'GB');
        expect(profile.dateFormatPattern, DateFormatPattern.dmy);
      });

      test('creates profile from Japan locale', () {
        final profile = UserProfileEntity.fromDetectedLocale(
          userId: 'test_user',
          countryCode: 'JP',
          languageCode: 'ja',
        );

        expect(profile.preferredCurrency, 'JPY');
        expect(profile.preferredLocale, 'ja_JP');
        expect(profile.countryCode, 'JP');
        expect(profile.languageCode, 'ja');
        expect(profile.dateFormatPattern, DateFormatPattern.ymd);
      });
    });

    group('copyWith', () {
      test('creates copy with updated currency', () {
        final original = UserProfileEntity.fromDetectedLocale(
          userId: 'test_user',
          countryCode: 'US',
          languageCode: 'en',
        );

        final updated = original.copyWith(preferredCurrency: 'EUR');

        expect(updated.preferredCurrency, 'EUR');
        expect(updated.userId, original.userId);
        expect(updated.preferredLocale, original.preferredLocale);
        expect(updated.countryCode, original.countryCode);
      });

      test('creates copy with updated locale', () {
        final original = UserProfileEntity.fromDetectedLocale(
          userId: 'test_user',
          countryCode: 'US',
          languageCode: 'en',
        );

        final updated = original.copyWith(preferredLocale: 'en_GB');

        expect(updated.preferredLocale, 'en_GB');
        expect(updated.preferredCurrency, original.preferredCurrency);
      });

      test('creates copy with updated date format', () {
        final original = UserProfileEntity.fromDetectedLocale(
          userId: 'test_user',
          countryCode: 'US',
          languageCode: 'en',
        );

        final updated = original.copyWith(dateFormatPattern: DateFormatPattern.dmy);

        expect(updated.dateFormatPattern, DateFormatPattern.dmy);
        expect(updated.preferredCurrency, original.preferredCurrency);
      });

      test('creates copy with isFirstLogin set to false', () {
        final original = UserProfileEntity.fromDetectedLocale(
          userId: 'test_user',
          countryCode: 'US',
          languageCode: 'en',
        );

        expect(original.isFirstLogin, true);

        final updated = original.copyWith(isFirstLogin: false);

        expect(updated.isFirstLogin, false);
      });
    });

    group('equality', () {
      test('two profiles with same values are equal', () {
        final profile1 = UserProfileEntity(
          userId: 'test_user',
          preferredCurrency: 'USD',
          preferredLocale: 'en_US',
          countryCode: 'US',
          languageCode: 'en',
          dateFormatPattern: DateFormatPattern.mdy,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final profile2 = UserProfileEntity(
          userId: 'test_user',
          preferredCurrency: 'USD',
          preferredLocale: 'en_US',
          countryCode: 'US',
          languageCode: 'en',
          dateFormatPattern: DateFormatPattern.mdy,
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(profile1, equals(profile2));
        expect(profile1.hashCode, equals(profile2.hashCode));
      });

      test('two profiles with different currencies are not equal', () {
        final profile1 = UserProfileEntity.fromDetectedLocale(
          userId: 'test_user',
          countryCode: 'US',
          languageCode: 'en',
        );

        final profile2 = profile1.copyWith(preferredCurrency: 'EUR');

        expect(profile1, isNot(equals(profile2)));
      });
    });
  });
}

