/// A single amount that cannot be converted must fail, never come back in its
/// own currency to be summed or shown under the base-currency symbol (money
/// rule 2).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';

import '../../mocks/mock_currency_conversion_service.dart';

/// No live or dated rate for anything but USD (83); the last known EUR rate
/// is [cachedEurRate], or the cache cannot be read when [cacheThrows].
class _NoLiveRateService extends MockCurrencyConversionService {
  _NoLiveRateService({this.cachedEurRate, this.cacheThrows = false});

  final double? cachedEurRate;
  final bool cacheThrows;

  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    if (from == 'USD') return amount * 83.0;
    throw CurrencyConversionException('no rate for $from');
  }

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async {
    if (cacheThrows) throw StateError('cache unreadable');
    return from == 'EUR' ? cachedEurRate : null;
  }
}

void main() {
  group('BatchCurrencyConverter.convert', () {
    test('useLastKnown with no cached rate throws, not the raw amount', () {
      final converter = BatchCurrencyConverter(_NoLiveRateService());

      expect(
        converter.convert(amount: 100, from: 'EUR', to: 'INR'),
        throwsA(isA<CurrencyConversionException>()),
      );
    });

    test('useLastKnown with an unreadable cache throws the same way', () {
      final converter = BatchCurrencyConverter(
        _NoLiveRateService(cacheThrows: true),
      );

      expect(
        converter.convert(amount: 100, from: 'EUR', to: 'INR'),
        throwsA(isA<CurrencyConversionException>()),
      );
    });

    test('useLastKnown converts with the cached rate', () async {
      final converter = BatchCurrencyConverter(
        _NoLiveRateService(cachedEurRate: 90),
      );

      expect(
        await converter.convert(amount: 100, from: 'EUR', to: 'INR'),
        closeTo(9000, 1e-9),
      );
    });

    test('a live rate still wins and the same currency needs none', () async {
      final converter = BatchCurrencyConverter(_NoLiveRateService());

      expect(
        await converter.convert(amount: 100, from: 'USD', to: 'INR'),
        closeTo(8300, 1e-9),
      );
      expect(await converter.convert(amount: 7, from: 'INR', to: 'INR'), 7);
    });

    test('useOriginal is still an explicit opt-in to the raw amount', () async {
      final converter = BatchCurrencyConverter(_NoLiveRateService());

      expect(
        await converter.convert(
          amount: 100,
          from: 'EUR',
          to: 'INR',
          fallbackStrategy: ConversionFallbackStrategy.useOriginal,
        ),
        100,
      );
    });
  });

  group('CurrencyConverterModule.convert', () {
    test('with the default strategy and no rate throws', () {
      final module = CurrencyConverterModule(_NoLiveRateService());

      expect(
        module.convert(amount: 100, from: 'EUR', to: 'INR'),
        throwsA(isA<CurrencyConversionException>()),
      );
    });

    test('throws when conversion is unavailable (signed out)', () {
      final module = CurrencyConverterModule(null);

      expect(
        module.convert(amount: 100, from: 'EUR', to: 'INR'),
        throwsA(isA<CurrencyConversionException>()),
      );
    });

    test('the same currency needs no converter', () async {
      final module = CurrencyConverterModule(null);

      expect(await module.convert(amount: 100, from: 'INR', to: 'INR'), 100);
    });
  });
}
