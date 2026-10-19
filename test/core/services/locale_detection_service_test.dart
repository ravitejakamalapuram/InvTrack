import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';

void main() {
  group('LocaleDetectionService', () {
    group('proposeCurrencyForCountry', () {
      test('returns correct currency for US', () {
        expect(LocaleDetectionService.proposeCurrencyForCountry('US'), 'USD');
      });

      test('returns correct currency for India', () {
        expect(LocaleDetectionService.proposeCurrencyForCountry('IN'), 'INR');
      });

      test('returns correct currency for UK', () {
        expect(LocaleDetectionService.proposeCurrencyForCountry('GB'), 'GBP');
      });

      test('returns correct currency for Eurozone countries', () {
        expect(LocaleDetectionService.proposeCurrencyForCountry('DE'), 'EUR');
        expect(LocaleDetectionService.proposeCurrencyForCountry('FR'), 'EUR');
        expect(LocaleDetectionService.proposeCurrencyForCountry('IT'), 'EUR');
        expect(LocaleDetectionService.proposeCurrencyForCountry('ES'), 'EUR');
      });

      test('returns correct currency for Japan', () {
        expect(LocaleDetectionService.proposeCurrencyForCountry('JP'), 'JPY');
      });

      test('returns correct currency for Canada', () {
        expect(LocaleDetectionService.proposeCurrencyForCountry('CA'), 'CAD');
      });

      test('returns correct currency for Australia', () {
        expect(LocaleDetectionService.proposeCurrencyForCountry('AU'), 'AUD');
      });

      test('returns null, not USD, for an unknown country code', () {
        expect(LocaleDetectionService.proposeCurrencyForCountry('XX'), isNull);
      });

      test('handles lowercase country codes', () {
        expect(LocaleDetectionService.proposeCurrencyForCountry('us'), 'USD');
        expect(LocaleDetectionService.proposeCurrencyForCountry('in'), 'INR');
      });
    });

    group('getLocaleStringForCountry', () {
      test('returns correct locale for US', () {
        expect(LocaleDetectionService.getLocaleStringForCountry('US'), 'en_US');
      });

      test('returns correct locale for India', () {
        expect(LocaleDetectionService.getLocaleStringForCountry('IN'), 'en_IN');
      });

      test('returns correct locale for UK', () {
        expect(LocaleDetectionService.getLocaleStringForCountry('GB'), 'en_GB');
      });

      test('returns correct locale for Germany', () {
        expect(LocaleDetectionService.getLocaleStringForCountry('DE'), 'de_DE');
      });

      test('returns en_US for unknown country code', () {
        expect(LocaleDetectionService.getLocaleStringForCountry('XX'), 'en_US');
      });
    });

    group('getDateFormatForCountry', () {
      test('returns MDY for US', () {
        expect(
          LocaleDetectionService.getDateFormatForCountry('US'),
          DateFormatPattern.mdy,
        );
      });

      test('returns DMY for UK', () {
        expect(
          LocaleDetectionService.getDateFormatForCountry('GB'),
          DateFormatPattern.dmy,
        );
      });

      test('returns DMY for India', () {
        expect(
          LocaleDetectionService.getDateFormatForCountry('IN'),
          DateFormatPattern.dmy,
        );
      });

      test('returns YMD for Japan', () {
        expect(
          LocaleDetectionService.getDateFormatForCountry('JP'),
          DateFormatPattern.ymd,
        );
      });

      test('returns YMD for China', () {
        expect(
          LocaleDetectionService.getDateFormatForCountry('CN'),
          DateFormatPattern.ymd,
        );
      });

      test('returns YMD for Canada', () {
        expect(
          LocaleDetectionService.getDateFormatForCountry('CA'),
          DateFormatPattern.ymd,
        );
      });

      test('returns MDY for unknown country code', () {
        expect(
          LocaleDetectionService.getDateFormatForCountry('XX'),
          DateFormatPattern.mdy,
        );
      });
    });

    group('getSupportedCurrencies', () {
      test('returns map of supported currencies', () {
        final currencies = LocaleDetectionService.getSupportedCurrencies();

        expect(currencies, isNotEmpty);
        expect(currencies.containsKey('USD'), isTrue);
        expect(currencies.containsKey('INR'), isTrue);
        expect(currencies.containsKey('EUR'), isTrue);
        expect(currencies.containsKey('GBP'), isTrue);
        expect(currencies.containsKey('JPY'), isTrue);
      });

      test('currency display names include symbols', () {
        final currencies = LocaleDetectionService.getSupportedCurrencies();

        expect(currencies['USD'], contains('\$'));
        expect(currencies['INR'], contains('₹'));
        expect(currencies['EUR'], contains('€'));
        expect(currencies['GBP'], contains('£'));
        expect(currencies['JPY'], contains('¥'));
      });
    });
  });
}
