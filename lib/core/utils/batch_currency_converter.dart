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
    ConversionFallbackStrategy fallbackStrategy = ConversionFallbackStrategy.useLastKnown,
  }) async {
    if (cashFlows.isEmpty) return [];

    // Build conversion requests map with deduplication
    final requests = <String, ConversionRequest>{};
    final cashFlowsByKey = <String, List<CashFlowEntity>>{};

    for (var i = 0; i < cashFlows.length; i++) {
      final cf = cashFlows[i];

      // Skip if already in base currency
      if (cf.currency == baseCurrency) continue;

      // Create deduplication key based on (date, currency) only
      final dedupeKey = '${_formatDate(cf.date)}_${cf.currency}';

      // Create conversion request (deduplicated by date+currency)
      requests.putIfAbsent(dedupeKey, () => ConversionRequest(
        from: cf.currency,
        amount: 1.0, // Use 1.0 to get the rate, apply to all amounts later
        date: cf.date,
      ));

      // Track which cash flows need this conversion (by index for result mapping)
      final indexKey = 'cf_$i';
      cashFlowsByKey.putIfAbsent(dedupeKey, () => []).add(cf);
    }

    // If no conversions needed, return original list
    if (requests.isEmpty) return cashFlows;

    // Batch convert with deduplication
    Map<String, double> convertedAmounts;
    try {
      convertedAmounts = await _conversionService.batchConvertHistorical(
        requests: requests,
        to: baseCurrency,
      );
    } catch (e) {
      // Handle batch conversion failure based on strategy
      return _handleBatchConversionFailure(
        cashFlows: cashFlows,
        baseCurrency: baseCurrency,
        fallbackStrategy: fallbackStrategy,
        error: e,
      );
    }

    // Apply converted amounts to cash flows
    final result = <CashFlowEntity>[];
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
        result.add(cf.copyWith(
          amount: cf.amount * rate,
          currency: baseCurrency,
        ));
      } else {
        // Individual conversion failed - apply fallback strategy
        final fallbackCf = await _handleIndividualConversionFailure(
          cashFlow: cf,
          baseCurrency: baseCurrency,
          fallbackStrategy: fallbackStrategy,
        );
        if (fallbackCf != null) {
          result.add(fallbackCf);
        }
        // If null, skip this cash flow (skipTransaction strategy)
      }
    }

    return result;
  }

  /// Handle batch conversion failure
  Future<List<CashFlowEntity>> _handleBatchConversionFailure({
    required List<CashFlowEntity> cashFlows,
    required String baseCurrency,
    required ConversionFallbackStrategy fallbackStrategy,
    required Object error,
  }) async {
    debugPrint('Batch conversion failed: $error');

    switch (fallbackStrategy) {
      case ConversionFallbackStrategy.useOriginal:
        return cashFlows; // Return original cash flows

      case ConversionFallbackStrategy.useLastKnown:
        // Try individual conversions with last known rates
        return _convertWithLastKnownRates(cashFlows, baseCurrency);

      case ConversionFallbackStrategy.throwError:
        throw CurrencyConversionException('Batch conversion failed', error);

      case ConversionFallbackStrategy.skipTransaction:
        // Return only cash flows already in base currency
        return cashFlows.where((cf) => cf.currency == baseCurrency).toList();
    }
  }

  /// Handle individual conversion failure
  Future<CashFlowEntity?> _handleIndividualConversionFailure({
    required CashFlowEntity cashFlow,
    required String baseCurrency,
    required ConversionFallbackStrategy fallbackStrategy,
  }) async {
    debugPrint('Individual conversion failed for ${cashFlow.currency} → $baseCurrency');

    switch (fallbackStrategy) {
      case ConversionFallbackStrategy.useOriginal:
        return cashFlow; // Keep original

      case ConversionFallbackStrategy.useLastKnown:
        // Try to get last known rate
        final lastKnownRate = await _conversionService.getLastKnownRate(
          from: cashFlow.currency,
          to: baseCurrency,
        );
        if (lastKnownRate != null) {
          return cashFlow.copyWith(
            amount: cashFlow.amount * lastKnownRate,
            currency: baseCurrency,
          );
        }
        return cashFlow; // Fallback to original

      case ConversionFallbackStrategy.throwError:
        throw CurrencyConversionException(
          'Failed to convert ${cashFlow.currency} → $baseCurrency on ${cashFlow.date}',
        );

      case ConversionFallbackStrategy.skipTransaction:
        return null; // Skip this cash flow
    }
  }

  /// Convert cash flows using last known rates (fallback)
  Future<List<CashFlowEntity>> _convertWithLastKnownRates(
    List<CashFlowEntity> cashFlows,
    String baseCurrency,
  ) async {
    final result = <CashFlowEntity>[];

    for (final cf in cashFlows) {
      if (cf.currency == baseCurrency) {
        result.add(cf);
        continue;
      }

      try {
        final lastKnownRate = await _conversionService.getLastKnownRate(
          from: cf.currency,
          to: baseCurrency,
        );

        if (lastKnownRate != null) {
          result.add(cf.copyWith(
            amount: cf.amount * lastKnownRate,
            currency: baseCurrency,
          ));
        } else {
          result.add(cf); // Keep original if no cached rate
        }
      } catch (e) {
        debugPrint('Failed to get last known rate: $e');
        result.add(cf); // Keep original on error
      }
    }

    return result;
  }

  /// Format date as YYYY-MM-DD (delegates to shared utility)
  String _formatDate(DateTime date) {
    return CurrencyConversionService._formatDate(date);
  }
}

