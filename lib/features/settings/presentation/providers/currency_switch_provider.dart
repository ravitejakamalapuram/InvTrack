import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/logger_service.dart';
import '../../../../core/services/currency_conversion_service.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../investment/domain/entities/transaction_entity.dart';
import '../../../investment/presentation/providers/investment_providers.dart';
import 'settings_provider.dart';

part 'currency_switch_provider.g.dart';

/// State for currency switch operation
enum CurrencySwitchState {
  idle,
  fetchingRates,
  success,
  failed,
}

/// Currency switch status
class CurrencySwitchStatus {
  final CurrencySwitchState state;
  final String? errorMessage;
  final String? targetCurrency;
  final int? totalRates;
  final int? fetchedRates;

  const CurrencySwitchStatus({
    required this.state,
    this.errorMessage,
    this.targetCurrency,
    this.totalRates,
    this.fetchedRates,
  });

  const CurrencySwitchStatus.idle()
      : state = CurrencySwitchState.idle,
        errorMessage = null,
        targetCurrency = null,
        totalRates = null,
        fetchedRates = null;

  const CurrencySwitchStatus.fetchingRates({
    required String targetCurrency,
    required int totalRates,
    required int fetchedRates,
  })  : state = CurrencySwitchState.fetchingRates,
        errorMessage = null,
        targetCurrency = targetCurrency,
        totalRates = totalRates,
        fetchedRates = fetchedRates;

  const CurrencySwitchStatus.success({required String targetCurrency})
      : state = CurrencySwitchState.success,
        errorMessage = null,
        targetCurrency = targetCurrency,
        totalRates = null,
        fetchedRates = null;

  const CurrencySwitchStatus.failed({
    required String errorMessage,
    required String targetCurrency,
  })  : state = CurrencySwitchState.failed,
        errorMessage = errorMessage,
        targetCurrency = targetCurrency,
        totalRates = null,
        fetchedRates = null;

  bool get isIdle => state == CurrencySwitchState.idle;
  bool get isFetchingRates => state == CurrencySwitchState.fetchingRates;
  bool get isSuccess => state == CurrencySwitchState.success;
  bool get isFailed => state == CurrencySwitchState.failed;

  double? get progress {
    if (totalRates == null || fetchedRates == null || totalRates == 0) {
      return null;
    }
    return fetchedRates! / totalRates!;
  }
}

/// Provider for currency switch status
@riverpod
class CurrencySwitch extends _$CurrencySwitch {
  @override
  CurrencySwitchStatus build() {
    return const CurrencySwitchStatus.idle();
  }

  /// Switch currency with pre-fetching of all required exchange rates
  ///
  /// Flow:
  /// 1. Show loading state (non-blocking)
  /// 2. Fetch all required exchange rates for cashflows
  /// 3. Only on success: Apply currency switch
  /// 4. Show success/failure notification
  Future<void> switchCurrency(String newCurrency) async {
    final currentCurrency = ref.read(currencyCodeProvider);

    // Same currency - no-op
    if (currentCurrency == newCurrency) {
      return;
    }

    try {
      // Step 1: Set loading state
      state = CurrencySwitchStatus.fetchingRates(
        targetCurrency: newCurrency,
        totalRates: 0,
        fetchedRates: 0,
      );

      // Step 2: Get all cashflows to determine required currency pairs
      final cashFlowsAsync = ref.read(validCashFlowsProvider);
      final cashFlows = await cashFlowsAsync.when(
        data: (data) async => data,
        loading: () async => <CashFlowEntity>[],
        error: (e, st) async => <CashFlowEntity>[],
      );

      // Step 3: Collect unique currency pairs that need conversion
      final uniqueCurrencies = <String>{};
      for (final cf in cashFlows) {
        if (cf.currency != newCurrency) {
          uniqueCurrencies.add(cf.currency);
        }
      }

      final totalRates = uniqueCurrencies.length;

      // Update state with total count
      state = CurrencySwitchStatus.fetchingRates(
        targetCurrency: newCurrency,
        totalRates: totalRates,
        fetchedRates: 0,
      );

      // Step 4: Pre-fetch all required exchange rates
      final conversionService = ref.read(currencyConversionServiceProvider);
      int fetchedCount = 0;

      for (final fromCurrency in uniqueCurrencies) {
        // Fetch rate (this will cache it)
        await conversionService.getRate(
          from: fromCurrency,
          to: newCurrency,
        );

        fetchedCount++;

        // Update progress
        state = CurrencySwitchStatus.fetchingRates(
          targetCurrency: newCurrency,
          totalRates: totalRates,
          fetchedRates: fetchedCount,
        );
      }

      // Step 5: All rates fetched successfully - apply currency switch
      await ref.read(settingsProvider.notifier).setCurrency(newCurrency);

      // Step 6: Set success state
      state = CurrencySwitchStatus.success(targetCurrency: newCurrency);

      LoggerService.info(
        'Currency switched successfully',
        metadata: {
          'from': currentCurrency,
          'to': newCurrency,
          'ratesFetched': totalRates,
        },
      );
    } catch (e, st) {
      // Step 7: Set failed state (keep old currency)
      state = CurrencySwitchStatus.failed(
        errorMessage: e.toString(),
        targetCurrency: newCurrency,
      );

      LoggerService.error(
        'Currency switch failed',
        error: e,
        stackTrace: st,
        metadata: {
          'from': currentCurrency,
          'to': newCurrency,
        },
      );
    }
  }

  /// Reset state to idle
  void reset() {
    state = const CurrencySwitchStatus.idle();
  }
}

