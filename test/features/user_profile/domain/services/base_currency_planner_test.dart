import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';
import 'package:inv_tracker/features/user_profile/domain/services/base_currency_planner.dart';

void main() {
  UserProfileEntity profile(String currency) => UserProfileEntity(
    userId: 'u1',
    preferredCurrency: currency,
    preferredLocale: 'en_US',
    countryCode: 'US',
    languageCode: 'en',
    dateFormatPattern: DateFormatPattern.mdy,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );

  group('LocaleDetectionService.proposeCurrencyForCountry', () {
    test('proposes the mapped currency, case-insensitively', () {
      expect(LocaleDetectionService.proposeCurrencyForCountry('US'), 'USD');
      expect(LocaleDetectionService.proposeCurrencyForCountry('in'), 'INR');
    });

    test('proposes nothing for an unknown country, never USD', () {
      expect(LocaleDetectionService.proposeCurrencyForCountry('XX'), isNull);
      expect(LocaleDetectionService.proposeCurrencyForCountry(''), isNull);
    });
  });

  group('planBaseCurrency', () {
    test('a first run on a US phone proposes USD', () {
      final plan = planBaseCurrency(
        profile: null,
        inUseCurrency: null,
        countryCode: 'US',
      );
      expect(plan.action, BaseCurrencyAction.propose);
      expect(plan.currency, 'USD');
    });

    test('an unknown country proposes nothing', () {
      final plan = planBaseCurrency(
        profile: null,
        inUseCurrency: null,
        countryCode: 'XX',
      );
      expect(plan.action, BaseCurrencyAction.none);
      expect(plan.currency, isNull);
    });

    test(
      'an existing user keeps the currency in use, not the detected one',
      () {
        final plan = planBaseCurrency(
          profile: null,
          inUseCurrency: 'INR',
          countryCode: 'US',
        );
        expect(plan.action, BaseCurrencyAction.saveDevice);
        expect(plan.currency, 'INR');
      },
    );

    test('a new device restores the profile currency', () {
      final plan = planBaseCurrency(
        profile: profile('USD'),
        inUseCurrency: null,
        countryCode: 'IN',
      );
      expect(plan.action, BaseCurrencyAction.adoptProfile);
      expect(plan.currency, 'USD');
    });

    test('a device that already shows the profile currency adopts it', () {
      final plan = planBaseCurrency(
        profile: profile('USD'),
        inUseCurrency: 'USD',
        countryCode: 'IN',
      );
      expect(plan.action, BaseCurrencyAction.adoptProfile);
      expect(plan.currency, 'USD');
    });

    test('a device with data in another currency is left alone', () {
      final plan = planBaseCurrency(
        profile: profile('USD'),
        inUseCurrency: 'INR',
        countryCode: 'US',
      );
      expect(plan.action, BaseCurrencyAction.none);
    });
  });
}
