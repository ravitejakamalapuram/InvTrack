/// One rate that cannot be fetched must not stop the other flows converting.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../../mocks/mock_currency_conversion_service.dart';

/// Converts USD at 83 and fails for every other currency, throwing for the
/// whole call when any requested key is not USD (like the real service).
class _OnlyUsdService extends MockCurrencyConversionService {
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
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => null;
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

void main() {
  final flows = [
    _flow('usd', 100, 'USD'),
    _flow('eur', 100, 'EUR'),
    _flow('inr', 500, 'INR'),
  ];
  final converter = BatchCurrencyConverter(_OnlyUsdService());

  test('useLastKnown converts the flows whose rate is available', () async {
    final out = await converter.batchConvert(
      cashFlows: flows,
      baseCurrency: 'INR',
    );

    final usd = out.firstWhere((cf) => cf.id == 'usd');
    expect(usd.currency, 'INR');
    expect(usd.amount, closeTo(8300, 1e-9));
  });

  test('skipTransaction drops only the flow whose rate failed', () async {
    final out = await converter.batchConvert(
      cashFlows: flows,
      baseCurrency: 'INR',
      fallbackStrategy: ConversionFallbackStrategy.skipTransaction,
    );

    expect(out.map((cf) => cf.id), unorderedEquals(['usd', 'inr']));
    expect(out.firstWhere((cf) => cf.id == 'usd').amount, closeTo(8300, 1e-9));
  });

  test('throwError still throws when any rate fails', () async {
    expect(
      converter.batchConvert(
        cashFlows: flows,
        baseCurrency: 'INR',
        fallbackStrategy: ConversionFallbackStrategy.throwError,
      ),
      throwsA(isA<CurrencyConversionException>()),
    );
  });
}
