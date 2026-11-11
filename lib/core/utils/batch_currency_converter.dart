import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Fallback strategy for failed currency conversions
enum ConversionFallbackStrategy {
  /// Keep original currency and amount (may cause mixed currency calculations)
  useOriginal,

  /// Use last known cached rate (any date)
  useLastKnown,

  /// Throw error and fail the operation
  throwError,

  /// Skip the transaction entirely (exclude from calculation)
  skipTransaction,
}

/// Helper class for batch converting cash flows with deduplication and optimization
///
/// This class provides efficient batch conversion of cash flows by:
/// - Deduplicating requests by (date, currency) pair
/// - Fetching each unique rate only once
/// - Parallel fetching of all unique rates
/// - Graceful error handling with configurable fallback strategies
class BatchCurrencyConverter {
  final CurrencyConversionService _conversionService;

  const BatchCurrencyConverter(this._conversionService);

  /// Batch convert cash flows to base currency with deduplication
  ///
  /// [cashFlows] - List of cash flows to convert
  /// [baseCurrency] - Target currency code
  /// [fallbackStrategy] - Strategy for handling failed conversions
  ///
  /// Returns list of converted cash flows
  ///
  /// Performance: For 100 cash flows with 50 unique (date, currency) pairs,
  /// this makes only 50 API calls instead of 100.
  Future<List<CashFlowEntity>> batchConvert({
    required List<CashFlowEntity> cashFlows,
    required String baseCurrency,
    ConversionFallbackStrategy fallbackStrategy =
        ConversionFallbackStrategy.useLastKnown,
  }) async => (await batchConvertWithApproximation(
    cashFlows: cashFlows,
    baseCurrency: baseCurrency,
    fallbackStrategy: fallbackStrategy,
  )).cashFlows;

  /// Like [batchConvert], and also says whether any flow was converted with
  /// an approximate rate (a cached or last-known rate over 24 hours old, or
  /// from another date). The converted amounts are the same as [batchConvert].
  Future<({List<CashFlowEntity> cashFlows, bool isApproximate})>
  batchConvertWithApproximation({
    required List<CashFlowEntity> cashFlows,
    required String baseCurrency,
    ConversionFallbackStrategy fallbackStrategy =
        ConversionFallbackStrategy.useLastKnown,
  }) async {
    if (cashFlows.isEmpty) {
      return (cashFlows: <CashFlowEntity>[], isApproximate: false);
    }

    // Build conversion requests map with deduplication
    final requests = <String, ConversionRequest>{};

    for (var i = 0; i < cashFlows.length; i++) {
      final cf = cashFlows[i];

      // Skip if already in base currency
      if (cf.currency == baseCurrency) continue;

      // Create deduplication key based on (date, currency) only
      final dedupeKey = '${_formatDate(cf.date)}_${cf.currency}';

      // Create conversion request (deduplicated by date+currency)
      requests.putIfAbsent(
        dedupeKey,
        () => ConversionRequest(
          from: cf.currency,
          amount: 1.0, // Use 1.0 to get the rate, apply to all amounts later
          date: cf.date,
        ),
      );
    }

    // If no conversions needed, return original list
    if (requests.isEmpty) return (cashFlows: cashFlows, isApproximate: false);

    // Batch convert with deduplication
    Map<String, double> convertedAmounts;
    try {
      convertedAmounts = await _conversionService.batchConvertHistorical(
        requests: requests,
        to: baseCurrency,
      );
    } catch (e) {
      if (fallbackStrategy == ConversionFallbackStrategy.throwError) {
        throw CurrencyConversionException('Batch conversion failed', e);
      }
      // One missing rate must not decide the others: retry key by key, and
      // let the strategy apply only to the flows whose own rate failed.
      convertedAmounts = await _convertKeyByKey(requests, baseCurrency);
    }
    return _applyConvertedRates(
      cashFlows: cashFlows,
      baseCurrency: baseCurrency,
      fallbackStrategy: fallbackStrategy,
      convertedAmounts: convertedAmounts,
    );
  }

  /// Retries each key on its own, [_retryChunkSize] at a time, so one failed
  /// lookup neither stops the others nor makes the retries run one by one.
  static const _retryChunkSize = 5;

  Future<Map<String, double>> _convertKeyByKey(
    Map<String, ConversionRequest> requests,
    String baseCurrency,
  ) async {
    final converted = <String, double>{};
    final entries = requests.entries.toList();
    for (var i = 0; i < entries.length; i += _retryChunkSize) {
      final chunk = entries.skip(i).take(_retryChunkSize);
      final results = await Future.wait(
        chunk.map((entry) async {
          try {
            return await _conversionService.batchConvertHistorical(
              requests: {entry.key: entry.value},
              to: baseCurrency,
            );
          } catch (_) {
            // Left out: the caller applies the fallback strategy to this key.
            return <String, double>{};
          }
        }),
      );
      results.forEach(converted.addAll);
    }
    return converted;
  }

  Future<({List<CashFlowEntity> cashFlows, bool isApproximate})>
  _applyConvertedRates({
    required List<CashFlowEntity> cashFlows,
    required String baseCurrency,
    required ConversionFallbackStrategy fallbackStrategy,
    required Map<String, double> convertedAmounts,
  }) async {
    // Apply converted amounts to cash flows
    final result = <CashFlowEntity>[];
    var isApproximate = false;
    for (var i = 0; i < cashFlows.length; i++) {
      final cf = cashFlows[i];

      // Keep cash flows already in base currency
      if (cf.currency == baseCurrency) {
        result.add(cf);
        continue;
      }

      // Use deduplication key to get the rate
      final dedupeKey = '${_formatDate(cf.date)}_${cf.currency}';
      final rate = convertedAmounts[dedupeKey];

      if (rate != null) {
        // Successful conversion - apply rate to this cash flow's amount
        result.add(
          cf.copyWith(amount: cf.amount * rate, currency: baseCurrency),
        );
      } else {
        // Individual conversion failed - apply fallback strategy
        final fallback = await _handleIndividualConversionFailure(
          cashFlow: cf,
          baseCurrency: baseCurrency,
          fallbackStrategy: fallbackStrategy,
        );
        if (fallback.cashFlow != null) {
          result.add(fallback.cashFlow!);
        }
        if (fallback.isApproximate) isApproximate = true;
        // If null, skip this cash flow (skipTransaction strategy)
      }
    }

    return (cashFlows: result, isApproximate: isApproximate);
  }

  /// Handle individual conversion failure
  Future<({CashFlowEntity? cashFlow, bool isApproximate})>
  _handleIndividualConversionFailure({
    required CashFlowEntity cashFlow,
    required String baseCurrency,
    required ConversionFallbackStrategy fallbackStrategy,
  }) async {
    if (kDebugMode) {
      debugPrint(
        'Individual conversion failed for ${cashFlow.currency} → $baseCurrency',
      );
    }

    switch (fallbackStrategy) {
      case ConversionFallbackStrategy.useOriginal:
        return (cashFlow: cashFlow, isApproximate: false); // Keep original

      case ConversionFallbackStrategy.useLastKnown:
        // Try to get last known rate
        RateLookup? lastKnownRate;
        try {
          lastKnownRate = await _conversionService.getLastKnownRateResult(
            from: cashFlow.currency,
            to: baseCurrency,
          );
        } catch (_) {
          // A cache that cannot be read counts as no cached rate.
        }
        if (lastKnownRate != null) {
          return (
            cashFlow: cashFlow.copyWith(
              amount: cashFlow.amount * lastKnownRate.rate,
              currency: baseCurrency,
            ),
            isApproximate: lastKnownRate.isApproximate,
          );
        }
        return (
          cashFlow: cashFlow,
          isApproximate: false,
        ); // Fallback to original

      case ConversionFallbackStrategy.throwError:
        throw CurrencyConversionException(
          'Failed to convert ${cashFlow.currency} → $baseCurrency on ${cashFlow.date}',
        );

      case ConversionFallbackStrategy.skipTransaction:
        return (cashFlow: null, isApproximate: false); // Skip this cash flow
    }
  }

  /// Convert a single amount from one currency to another
  ///
  /// This is a convenience method that uses the same fallback strategy as [batchConvert].
  /// Use this for simple one-off conversions (e.g., converting goal target amounts).
  ///
  /// For converting multiple cash flows, prefer [batchConvert] for better performance.
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
    ConversionFallbackStrategy fallbackStrategy =
        ConversionFallbackStrategy.useLastKnown,
  }) async {
    // Skip conversion if already in target currency
    if (from == to) return amount;

    try {
      return await _conversionService.convert(
        amount: amount,
        from: from,
        to: to,
        date: date,
      );
    } catch (error) {
      // Apply same fallback strategy as batchConvert
      switch (fallbackStrategy) {
        case ConversionFallbackStrategy.useOriginal:
          return amount;

        case ConversionFallbackStrategy.useLastKnown:
          final rate = await _conversionService.getLastKnownRate(
            from: from,
            to: to,
          );
          if (rate != null) return amount * rate;
          return amount; // Fall back to original if no cached rate

        case ConversionFallbackStrategy.throwError:
          throw CurrencyConversionException('Failed to convert $from → $to');

        case ConversionFallbackStrategy.skipTransaction:
          return 0.0; // Exclude from calculation
      }
    }
  }

  /// The last cached rate from [from] to [to] (any date), or null when
  /// there is none.
  Future<double?> getLastKnownRate({required String from, required String to}) {
    if (from == to) return Future.value(1.0);
    return _conversionService.getLastKnownRate(from: from, to: to);
  }

  /// Format date as YYYY-MM-DD (delegates to shared utility)
  String _formatDate(DateTime date) {
    return CurrencyConversionService.formatDate(date);
  }
}
