import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Module for handling currency conversion of transactions, cash flows, and individual rates.
class CurrencyConverterModule implements CalculationModule {
  final CurrencyConversionService? _conversionService;
  final BatchCurrencyConverter? _batchConverter;

  CurrencyConverterModule(this._conversionService)
      : _batchConverter = _conversionService != null
            ? BatchCurrencyConverter(_conversionService)
            : null;

  @override
  String get name => 'Currency';

  /// Whether active currency conversion is available (i.e. user is authenticated).
  bool get isAvailable => _conversionService != null;

  /// Convert a single amount from one currency to another.
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
    ConversionFallbackStrategy fallbackStrategy =
        ConversionFallbackStrategy.useLastKnown,
  }) async {
    if (from == to) return amount;
    if (_batchConverter == null) return amount;

    return _batchConverter.convert(
      amount: amount,
      from: from,
      to: to,
      date: date,
      fallbackStrategy: fallbackStrategy,
    );
  }

  /// Batch convert cash flows to base currency with deduplication.
  Future<List<CashFlowEntity>> batchConvert({
    required List<CashFlowEntity> cashFlows,
    required String baseCurrency,
    ConversionFallbackStrategy fallbackStrategy =
        ConversionFallbackStrategy.useLastKnown,
  }) async {
    if (cashFlows.isEmpty) return [];
    if (_batchConverter == null) return cashFlows;

    return _batchConverter.batchConvert(
      cashFlows: cashFlows,
      baseCurrency: baseCurrency,
      fallbackStrategy: fallbackStrategy,
    );
  }

  /// How many units of [to] one unit of [from] is worth today, for amounts
  /// a user entered in another currency than the base currency (FIRE
  /// settings, goal targets): today's rate, else the last known one. Throws
  /// a [CurrencyConversionException] rather than read one currency as
  /// another when there is no rate at all.
  Future<double> rateToday({required String from, required String to}) async {
    if (from == to) return 1.0;
    if (!isAvailable) {
      throw CurrencyConversionException('Currency conversion is unavailable');
    }
    try {
      return await convert(
        amount: 1,
        from: from,
        to: to,
        fallbackStrategy: ConversionFallbackStrategy.throwError,
      );
    } on CurrencyConversionException {
      final rate = await getLastKnownRate(from: from, to: to);
      if (rate == null) rethrow;
      return rate;
    }
  }

  /// Get last known rate from cache.
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async {
    if (from == to) return 1.0;
    if (_conversionService == null) return null;

    return _conversionService.getLastKnownRate(from: from, to: to);
  }
}
