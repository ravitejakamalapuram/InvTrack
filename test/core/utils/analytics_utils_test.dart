/// Unit tests for analytics utility functions.
///
/// Tests verify privacy-safe amount range bucketing for analytics tracking,
/// ensuring compliance with InvTrack Enterprise Rules (Rule 9 and Rule 17.4).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/analytics_utils.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../../mocks/mock_currency_conversion_service.dart';

/// Converts every non-base flow at a fixed [rate], whatever it is.
class _FixedRateConversionService extends MockCurrencyConversionService {
  _FixedRateConversionService(this.rate);

  final double rate;

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => {for (final key in requests.keys) key: rate};
}

CashFlowEntity _flow({required double amount, required String currency}) =>
    CashFlowEntity(
      id: 'cf',
      investmentId: 'inv',
      date: DateTime(2026, 4, 1),
      type: CashFlowType.invest,
      amount: amount,
      createdAt: DateTime(2026, 4, 1),
      currency: currency,
    );

void main() {
  group('getAmountRange', () {
    group('boundary tests', () {
      test('999 -> under_1k', () {
        expect(getAmountRange(999), 'under_1k');
      });

      test('1000 -> 1k_10k', () {
        expect(getAmountRange(1000), '1k_10k');
      });

      test('9999 -> 1k_10k', () {
        expect(getAmountRange(9999), '1k_10k');
      });

      test('10000 -> 10k_50k', () {
        expect(getAmountRange(10000), '10k_50k');
      });

      test('49999 -> 10k_50k', () {
        expect(getAmountRange(49999), '10k_50k');
      });

      test('50000 -> 50k_1L', () {
        expect(getAmountRange(50000), '50k_1L');
      });

      test('99999 -> 50k_1L', () {
        expect(getAmountRange(99999), '50k_1L');
      });

      test('100000 -> 1L_5L', () {
        expect(getAmountRange(100000), '1L_5L');
      });

      test('499999 -> 1L_5L', () {
        expect(getAmountRange(499999), '1L_5L');
      });

      test('500000 -> 5L_10L', () {
        expect(getAmountRange(500000), '5L_10L');
      });

      test('999999 -> 5L_10L', () {
        expect(getAmountRange(999999), '5L_10L');
      });

      test('1000000 -> over_10L', () {
        expect(getAmountRange(1000000), 'over_10L');
      });
    });

    group('edge cases', () {
      test('0 -> under_1k', () {
        expect(getAmountRange(0), 'under_1k');
      });

      test('0.01 -> under_1k', () {
        expect(getAmountRange(0.01), 'under_1k');
      });

      test('very large amount -> over_10L', () {
        expect(getAmountRange(10000000), 'over_10L');
      });

      test('decimal values round correctly - 999.99 -> under_1k', () {
        expect(getAmountRange(999.99), 'under_1k');
      });

      test('decimal values round correctly - 1000.01 -> 1k_10k', () {
        expect(getAmountRange(1000.01), '1k_10k');
      });
    });

    group('privacy compliance', () {
      test('exact amounts are masked to ranges', () {
        // Verify that different exact amounts in same range
        // return the same bucket (privacy-preserving)
        expect(getAmountRange(5000), '1k_10k');
        expect(getAmountRange(5500), '1k_10k');
        expect(getAmountRange(6000), '1k_10k');
      });

      test('sensitive amounts are properly bucketed', () {
        // Test typical investment amounts
        expect(getAmountRange(25000), '10k_50k');
        expect(getAmountRange(75000), '50k_1L');
        expect(getAmountRange(250000), '1L_5L');
        expect(getAmountRange(750000), '5L_10L');
        expect(getAmountRange(2500000), 'over_10L');
      });
    });
  });

  group('getBaseCurrencyAmountRange', () {
    Future<String> bucket(double amount, double rate) =>
        getBaseCurrencyAmountRange(
          cashFlow: _flow(amount: amount, currency: 'USD'),
          baseCurrency: 'INR',
          converter: BatchCurrencyConverter(_FixedRateConversionService(rate)),
        );

    test('buckets the amount in the base currency', () async {
      expect(await bucket(1000, 83), '50k_1L');
    });

    test('a flow already in the base currency is bucketed as is', () async {
      expect(
        await getBaseCurrencyAmountRange(
          cashFlow: _flow(amount: 25000, currency: 'INR'),
          baseCurrency: 'INR',
          converter: null,
        ),
        '10k_50k',
      );
    });

    test('no converter -> unknown', () async {
      expect(
        await getBaseCurrencyAmountRange(
          cashFlow: _flow(amount: 1000, currency: 'USD'),
          baseCurrency: 'INR',
          converter: null,
        ),
        unknownAmountRange,
      );
    });

    for (final entry in {
      'a zero rate': 0.0,
      'a negative rate': -83.0,
      'a NaN rate': double.nan,
      'an infinite rate': double.infinity,
    }.entries) {
      test('${entry.key} -> unknown, never a bucket', () async {
        expect(await bucket(1000, entry.value), unknownAmountRange);
      });
    }
  });
}
