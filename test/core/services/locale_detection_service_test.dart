import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';

void main() {
  group('LocaleDetectionService', () {
    group('getCurrencyForCountry', () {
      test('returns correct currency for US', () {
        expect(LocaleDetectionService.getCurrencyForCountry('US'), 'USD');
      });

      test('returns correct currency for India', () {
        expect(LocaleDetectionService.getCurrencyForCountry('IN'), 'INR');
      });

      test('returns correct currency for UK', () {
        expect(LocaleDetectionService.getCurrencyForCountry('GB'), 'GBP');
      });

      test('returns correct currency for Eurozone countries', () {
        expect(LocaleDetectionService.getCurrencyForCountry('DE'), 'EUR');
        expect(LocaleDetectionService.getCurrencyForCountry('FR'), 'EUR');
        expect(LocaleDetectionService.getCurrencyForCountry('IT'), 'EUR');
        expect(LocaleDetectionService.getCurrencyForCountry('ES'), 'EUR');
      });

      test('returns correct currency for Japan', () {
        expect(LocaleDetectionService.getCurrencyForCountry('JP'), 'JPY');
      });

      test('returns correct currency for Canada', () {
        expect(LocaleDetectionService.getCurrencyForCountry('CA'), 'CAD');
      });

      test('returns correct currency for Australia', () {
        expect(LocaleDetectionService.getCurrencyForCountry('AU'), 'AUD');
      });

      test('returns USD for unknown country code', () {
        expect(LocaleDetectionService.getCurrencyForCountry('XX'), 'USD');
      });

      test('handles lowercase country codes', () {
        expect(LocaleDetectionService.getCurrencyForCountry('us'), 'USD');
        expect(LocaleDetectionService.getCurrencyForCountry('in'), 'INR');
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

