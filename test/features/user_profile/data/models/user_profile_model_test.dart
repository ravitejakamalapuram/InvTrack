import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/features/user_profile/data/models/user_profile_model.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';

void main() {
  group('UserProfileModel', () {
    final testDate = DateTime(2026, 1, 1);
    final testTimestamp = Timestamp.fromDate(testDate);

    group('toFirestore', () {
      test('converts entity to Firestore document', () {
        final entity = UserProfileEntity(
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

        final doc = UserProfileModel.toFirestore(entity);

        expect(doc['schemaVersion'], UserProfileModel.currentSchemaVersion);
        expect(doc['userId'], 'test_user');
        expect(doc['preferredCurrency'], 'USD');
        expect(doc['preferredLocale'], 'en_US');
        expect(doc['countryCode'], 'US');
        expect(doc['languageCode'], 'en');
        expect(doc['dateFormatPattern'], 'mdy');
        expect(doc['isFirstLogin'], true);
        expect(doc['createdAt'], isA<Timestamp>());
        expect(doc['updatedAt'], FieldValue.serverTimestamp());
      });

      test('converts entity with DMY date format', () {
        final entity = UserProfileEntity(
          userId: 'test_user',
          preferredCurrency: 'INR',
          preferredLocale: 'en_IN',
          countryCode: 'IN',
          languageCode: 'en',
          dateFormatPattern: DateFormatPattern.dmy,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final doc = UserProfileModel.toFirestore(entity);

        expect(doc['dateFormatPattern'], 'dmy');
        expect(doc['preferredCurrency'], 'INR');
      });

      test('converts entity with YMD date format', () {
        final entity = UserProfileEntity(
          userId: 'test_user',
          preferredCurrency: 'JPY',
          preferredLocale: 'ja_JP',
          countryCode: 'JP',
          languageCode: 'ja',
          dateFormatPattern: DateFormatPattern.ymd,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final doc = UserProfileModel.toFirestore(entity);

        expect(doc['dateFormatPattern'], 'ymd');
        expect(doc['preferredCurrency'], 'JPY');
      });
    });

    group('fromFirestore', () {
      test('converts Firestore document to entity', () {
        final doc = {
          'schemaVersion': 1,
          'userId': 'test_user',
          'preferredCurrency': 'USD',
          'preferredLocale': 'en_US',
          'countryCode': 'US',
          'languageCode': 'en',
          'dateFormatPattern': 'mdy',
          'isFirstLogin': true,
          'createdAt': testTimestamp,
          'updatedAt': testTimestamp,
        };

        final entity = UserProfileModel.fromFirestore(doc, 'test_user');

        expect(entity.userId, 'test_user');
        expect(entity.preferredCurrency, 'USD');
        expect(entity.preferredLocale, 'en_US');
        expect(entity.countryCode, 'US');
        expect(entity.languageCode, 'en');
        expect(entity.dateFormatPattern, DateFormatPattern.mdy);
        expect(entity.isFirstLogin, true);
        expect(entity.createdAt, testDate);
        expect(entity.updatedAt, testDate);
      });

      test('handles missing optional fields with defaults', () {
        final doc = {
          'userId': 'test_user',
        };

        final entity = UserProfileModel.fromFirestore(doc, 'test_user');

        expect(entity.userId, 'test_user');
        expect(entity.preferredCurrency, 'USD');
        expect(entity.preferredLocale, 'en_US');
        expect(entity.countryCode, 'US');
        expect(entity.languageCode, 'en');
        expect(entity.dateFormatPattern, DateFormatPattern.mdy);
        expect(entity.isFirstLogin, false);
      });

      test('parses DMY date format correctly', () {
        final doc = {
          'userId': 'test_user',
          'dateFormatPattern': 'dmy',
          'preferredCurrency': 'INR',
          'preferredLocale': 'en_IN',
          'countryCode': 'IN',
          'languageCode': 'en',
        };

        final entity = UserProfileModel.fromFirestore(doc, 'test_user');

        expect(entity.dateFormatPattern, DateFormatPattern.dmy);
      });

      test('parses YMD date format correctly', () {
        final doc = {
          'userId': 'test_user',
          'dateFormatPattern': 'ymd',
          'preferredCurrency': 'JPY',
          'preferredLocale': 'ja_JP',
          'countryCode': 'JP',
          'languageCode': 'ja',
        };

        final entity = UserProfileModel.fromFirestore(doc, 'test_user');

        expect(entity.dateFormatPattern, DateFormatPattern.ymd);
      });

      test('handles invalid date format with default', () {
        final doc = {
          'userId': 'test_user',
          'dateFormatPattern': 'invalid',
        };

        final entity = UserProfileModel.fromFirestore(doc, 'test_user');

        expect(entity.dateFormatPattern, DateFormatPattern.mdy);
      });

      test('handles missing timestamps with current time', () {
        final doc = {
          'userId': 'test_user',
        };

        final entity = UserProfileModel.fromFirestore(doc, 'test_user');

        // Should be close to current time
        final now = DateTime.now();
        expect(
          entity.createdAt.difference(now).inSeconds.abs(),
          lessThan(5),
        );
        expect(
          entity.updatedAt.difference(now).inSeconds.abs(),
          lessThan(5),
        );
      });
    });

    group('round-trip conversion', () {
      test('entity survives round-trip conversion', () {
        final original = UserProfileEntity(
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

        final doc = UserProfileModel.toFirestore(original);
        // Simulate Firestore by replacing FieldValue.serverTimestamp()
        doc['updatedAt'] = testTimestamp;
        
        final restored = UserProfileModel.fromFirestore(doc, 'test_user');

        expect(restored.userId, original.userId);
        expect(restored.preferredCurrency, original.preferredCurrency);
        expect(restored.preferredLocale, original.preferredLocale);
        expect(restored.countryCode, original.countryCode);
        expect(restored.languageCode, original.languageCode);
        expect(restored.dateFormatPattern, original.dateFormatPattern);
        expect(restored.isFirstLogin, original.isFirstLogin);
      });
    });
  });
}

