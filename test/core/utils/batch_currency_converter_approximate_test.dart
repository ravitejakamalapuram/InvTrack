/// A14 / #759: the converter reports when a flow used an approximate rate,
/// without changing any converted amount.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../../mocks/mock_currency_conversion_service.dart';

/// Converts USD at 83; every other currency has no exact rate and falls back
/// to [lastKnown].
class _Service extends MockCurrencyConversionService {
  _Service(this.lastKnown);

  final RateLookup? lastKnown;

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async {
    if (requests.values.any((r) => r.from != 'USD')) {
      throw CurrencyConversionException('no rate');
    }
    return {for (final key in requests.keys) key: 83.0};
  }

  @override
  Future<RateLookup?> getLastKnownRateResult({
    required String from,
    required String to,
  }) async => lastKnown;
}

CashFlowEntity _flow(String id, double amount, String currency) =>
    CashFlowEntity(
      id: id,
      investmentId: 'inv',
      date: DateTime(2026, 4, 1),
      type: CashFlowType.invest,
      amount: amount,
      createdAt: DateTime(2026, 4, 1),
      currency: currency,
    );

Future<({List<CashFlowEntity> cashFlows, bool isApproximate})> _run(
  RateLookup? lastKnown,
  List<CashFlowEntity> flows,
) => BatchCurrencyConverter(
  _Service(lastKnown),
).batchConvertWithApproximation(cashFlows: flows, baseCurrency: 'INR');

void main() {
  test('exact rates are not approximate', () async {
    final out = await _run(null, [_flow('a', 10, 'USD'), _flow('b', 5, 'INR')]);

    expect(out.isApproximate, isFalse);
    expect(out.cashFlows.first.amount, 830);
  });

  test(
    'a stale last-known rate marks the result approximate, same amount',
    () async {
      final out = await _run(const RateLookup(90, isApproximate: true), [
        _flow('a', 10, 'USD'),
        _flow('b', 2, 'EUR'),
      ]);

      expect(out.isApproximate, isTrue);
      expect(out.cashFlows.map((c) => c.amount), [830, 180]);
    },
  );

  test('a fresh last-known rate is not approximate', () async {
    final out = await _run(const RateLookup(90, isApproximate: false), [
      _flow('b', 2, 'EUR'),
    ]);

    expect(out.isApproximate, isFalse);
    expect(out.cashFlows.single.amount, 180);
  });

  test('batchConvert returns the same flows as before', () async {
    final out = await BatchCurrencyConverter(
      _Service(const RateLookup(90, isApproximate: true)),
    ).batchConvert(cashFlows: [_flow('b', 2, 'EUR')], baseCurrency: 'INR');

    expect(out.single.amount, 180);
    expect(out.single.currency, 'INR');
  });
}
