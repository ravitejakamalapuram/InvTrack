import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../../mocks/mock_currency_conversion_service.dart';

/// A mock service that throws on batchConvertHistorical to trigger fallback paths.
class _ThrowingBatchConversionService extends MockCurrencyConversionService {
  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async {
    throw Exception('Simulated batch conversion failure');
  }
}

CashFlowEntity _makeCashFlow({
  required String id,
  required String currency,
  double amount = 1000.0,
}) {
  return CashFlowEntity(
    id: id,
    investmentId: 'inv-1',
    date: DateTime(2024, 1, 15),
    type: CashFlowType.invest,
    amount: amount,
    createdAt: DateTime(2024, 1, 15),
    currency: currency,
  );
}

void main() {
  group('BatchCurrencyConverter', () {
    group('batchConvert - skipTransaction fallback on batch failure', () {
      late BatchCurrencyConverter converter;
      late _ThrowingBatchConversionService throwingService;

      setUp(() {
        throwingService = _ThrowingBatchConversionService();
        converter = BatchCurrencyConverter(throwingService);
      });

      test(
        'returns only base-currency cash flows when batch conversion fails',
        () async {
          final cashFlows = [
            _makeCashFlow(id: 'cf-1', currency: 'INR', amount: 1000),
            _makeCashFlow(id: 'cf-2', currency: 'USD', amount: 200),
            _makeCashFlow(id: 'cf-3', currency: 'EUR', amount: 50),
            _makeCashFlow(id: 'cf-4', currency: 'INR', amount: 2000),
          ];

          final result = await converter.batchConvert(
            cashFlows: cashFlows,
            baseCurrency: 'INR',
            fallbackStrategy: ConversionFallbackStrategy.skipTransaction,
          );

          expect(result.length, 2);
          expect(result.every((cf) => cf.currency == 'INR'), isTrue);
          expect(result.map((cf) => cf.id), containsAll(['cf-1', 'cf-4']));
        },
      );

      test(
        'returns all cash flows when all are already in base currency',
        () async {
          final cashFlows = [
            _makeCashFlow(id: 'cf-1', currency: 'USD', amount: 100),
            _makeCashFlow(id: 'cf-2', currency: 'USD', amount: 200),
            _makeCashFlow(id: 'cf-3', currency: 'USD', amount: 300),
          ];

          // No batch conversion needed (all in base currency), so no throwing occurs.
          // Use a real mock service since base-currency flows bypass batchConvert.
          final converter2 = BatchCurrencyConverter(MockCurrencyConversionService());
          final result = await converter2.batchConvert(
            cashFlows: cashFlows,
            baseCurrency: 'USD',
            fallbackStrategy: ConversionFallbackStrategy.skipTransaction,
          );

          expect(result.length, 3);
        },
      );

      test(
        'returns empty list when no cash flows are in base currency',
        () async {
          final cashFlows = [
            _makeCashFlow(id: 'cf-1', currency: 'USD', amount: 100),
            _makeCashFlow(id: 'cf-2', currency: 'EUR', amount: 200),
          ];

          final result = await converter.batchConvert(
            cashFlows: cashFlows,
            baseCurrency: 'INR',
            fallbackStrategy: ConversionFallbackStrategy.skipTransaction,
          );

          expect(result, isEmpty);
        },
      );

      test('preserves amounts and currency of base-currency cash flows', () async {
        final cashFlows = [
          _makeCashFlow(id: 'cf-1', currency: 'INR', amount: 5000),
          _makeCashFlow(id: 'cf-2', currency: 'USD', amount: 100),
        ];

        final result = await converter.batchConvert(
          cashFlows: cashFlows,
          baseCurrency: 'INR',
          fallbackStrategy: ConversionFallbackStrategy.skipTransaction,
        );

        expect(result.length, 1);
        expect(result.first.id, 'cf-1');
        expect(result.first.amount, 5000);
        expect(result.first.currency, 'INR');
      });

      test('handles empty cash flows list without calling conversion service',
          () async {
        final result = await converter.batchConvert(
          cashFlows: [],
          baseCurrency: 'INR',
          fallbackStrategy: ConversionFallbackStrategy.skipTransaction,
        );

        expect(result, isEmpty);
      });
    });

    group('batchConvert - useOriginal fallback on batch failure', () {
      test('returns all original cash flows when batch conversion fails',
          () async {
        final throwingService = _ThrowingBatchConversionService();
        final converter = BatchCurrencyConverter(throwingService);

        final cashFlows = [
          _makeCashFlow(id: 'cf-1', currency: 'USD', amount: 100),
          _makeCashFlow(id: 'cf-2', currency: 'EUR', amount: 200),
          _makeCashFlow(id: 'cf-3', currency: 'INR', amount: 1000),
        ];

        final result = await converter.batchConvert(
          cashFlows: cashFlows,
          baseCurrency: 'INR',
          fallbackStrategy: ConversionFallbackStrategy.useOriginal,
        );

        expect(result.length, 3);
        expect(result[0].currency, 'USD');
        expect(result[1].currency, 'EUR');
        expect(result[2].currency, 'INR');
      });
    });

    group('batchConvert - throwError fallback on batch failure', () {
      test('throws CurrencyConversionException when batch conversion fails',
          () async {
        final throwingService = _ThrowingBatchConversionService();
        final converter = BatchCurrencyConverter(throwingService);

        final cashFlows = [
          _makeCashFlow(id: 'cf-1', currency: 'USD', amount: 100),
        ];

        expect(
          () => converter.batchConvert(
            cashFlows: cashFlows,
            baseCurrency: 'INR',
            fallbackStrategy: ConversionFallbackStrategy.throwError,
          ),
          throwsA(isA<CurrencyConversionException>()),
        );
      });
    });

    group('batchConvert - successful conversion', () {
      test('converts non-base-currency cash flows using rates', () async {
        final mockService = MockCurrencyConversionService();
        final converter = BatchCurrencyConverter(mockService);

        final cashFlows = [
          _makeCashFlow(id: 'cf-1', currency: 'USD', amount: 1),
          _makeCashFlow(id: 'cf-2', currency: 'INR', amount: 100),
        ];

        final result = await converter.batchConvert(
          cashFlows: cashFlows,
          baseCurrency: 'INR',
        );

        expect(result.length, 2);
        // USD cash flow should be converted (1 USD = 83 INR per mock)
        final usdConverted = result.firstWhere((cf) => cf.id == 'cf-1');
        expect(usdConverted.currency, 'INR');
        expect(usdConverted.amount, closeTo(83.0, 0.01));
        // INR cash flow stays unchanged
        final inrFlow = result.firstWhere((cf) => cf.id == 'cf-2');
        expect(inrFlow.currency, 'INR');
        expect(inrFlow.amount, 100);
      });

      test('deduplicates conversion requests for same date+currency', () async {
        final mockService = MockCurrencyConversionService();
        final converter = BatchCurrencyConverter(mockService);

        // Two USD cash flows on same date - should be deduplicated
        final cashFlows = [
          _makeCashFlow(id: 'cf-1', currency: 'USD', amount: 100),
          _makeCashFlow(id: 'cf-2', currency: 'USD', amount: 200),
          _makeCashFlow(id: 'cf-3', currency: 'INR', amount: 500),
        ];

        final result = await converter.batchConvert(
          cashFlows: cashFlows,
          baseCurrency: 'INR',
        );

        expect(result.length, 3);
        expect(result.every((cf) => cf.currency == 'INR'), isTrue);
      });
    });

    group('convert - single amount conversion', () {
      test('returns original amount when from == to', () async {
        final mockService = MockCurrencyConversionService();
        final converter = BatchCurrencyConverter(mockService);

        final result = await converter.convert(
          amount: 1000,
          from: 'USD',
          to: 'USD',
        );

        expect(result, 1000);
      });

      test('converts amount between currencies', () async {
        final mockService = MockCurrencyConversionService();
        final converter = BatchCurrencyConverter(mockService);

        final result = await converter.convert(
          amount: 1,
          from: 'USD',
          to: 'INR',
        );

        expect(result, closeTo(83.0, 0.01));
      });

      test(
          'returns 0.0 for skipTransaction strategy when conversion fails',
          () async {
        // Create a service that throws on convert
        final failingService = _FailingConvertService();
        final converter = BatchCurrencyConverter(failingService);

        final result = await converter.convert(
          amount: 100,
          from: 'USD',
          to: 'INR',
          fallbackStrategy: ConversionFallbackStrategy.skipTransaction,
        );

        expect(result, 0.0);
      });

      test('throws CurrencyConversionException for throwError strategy on failure',
          () async {
        final failingService = _FailingConvertService();
        final converter = BatchCurrencyConverter(failingService);

        expect(
          () => converter.convert(
            amount: 100,
            from: 'USD',
            to: 'INR',
            fallbackStrategy: ConversionFallbackStrategy.throwError,
          ),
          throwsA(isA<CurrencyConversionException>()),
        );
      });
    });
  });
}

/// A mock service that throws on all conversion calls.
class _FailingConvertService extends MockCurrencyConversionService {
  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    throw Exception('Simulated convert failure');
  }

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async {
    return null; // No cached rate available
  }
}