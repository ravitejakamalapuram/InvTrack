import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/di/database_module.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/logging/logger_service.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/services/currency_conversion_service.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../investment/presentation/providers/investment_providers.dart';
import 'settings_provider.dart';

part 'currency_switch_provider.g.dart';

/// State for currency switch operation
enum CurrencySwitchState {
  idle,

  /// Checking, asking about and stamping records saved without a currency,
  /// before the new base currency is applied.
  checkingRecords,
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

  /// Set when the switch was blocked because records saved without a
  /// currency could not first be stamped with this (the old) base currency.
  final String? unstampedLegacyCurrency;

  /// Cached progress value (pre-calculated to avoid repeated division on every frame)
  final double? _cachedProgress;

  const CurrencySwitchStatus({
    required this.state,
    this.errorMessage,
    this.targetCurrency,
    this.totalRates,
    this.fetchedRates,
  }) : unstampedLegacyCurrency = null,
       _cachedProgress = null;

  const CurrencySwitchStatus.idle()
    : state = CurrencySwitchState.idle,
      errorMessage = null,
      targetCurrency = null,
      totalRates = null,
      fetchedRates = null,
      unstampedLegacyCurrency = null,
      _cachedProgress = null;

  const CurrencySwitchStatus.checkingRecords({required this.targetCurrency})
    : state = CurrencySwitchState.checkingRecords,
      errorMessage = null,
      totalRates = null,
      fetchedRates = null,
      unstampedLegacyCurrency = null,
      _cachedProgress = null;

  CurrencySwitchStatus.fetchingRates({
    required this.targetCurrency,
    required int this.totalRates,
    required int this.fetchedRates,
  }) : state = CurrencySwitchState.fetchingRates,
       errorMessage = null,
       unstampedLegacyCurrency = null,
       // Pre-calculate progress to avoid repeated division on every frame
       _cachedProgress = totalRates > 0 ? fetchedRates / totalRates : 0.0;

  const CurrencySwitchStatus.success({required this.targetCurrency})
    : state = CurrencySwitchState.success,
      errorMessage = null,
      totalRates = null,
      fetchedRates = null,
      unstampedLegacyCurrency = null,
      _cachedProgress = null;

  const CurrencySwitchStatus.failed({
    this.errorMessage,
    required this.targetCurrency,
    this.unstampedLegacyCurrency,
  }) : state = CurrencySwitchState.failed,
       totalRates = null,
       fetchedRates = null,
       _cachedProgress = null;

  bool get isIdle => state == CurrencySwitchState.idle;
  bool get isFetchingRates => state == CurrencySwitchState.fetchingRates;
  bool get isSuccess => state == CurrencySwitchState.success;
  bool get isFailed => state == CurrencySwitchState.failed;

  bool get isCheckingRecords => state == CurrencySwitchState.checkingRecords;

  /// Whether a change is running; the currency tile is disabled meanwhile.
  bool get isBusy => isCheckingRecords || isFetchingRates;

  /// Get progress value (0.0 to 1.0)
  /// Returns cached value to avoid repeated division on every frame during animation
  double? get progress => _cachedProgress;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurrencySwitchStatus &&
        other.state == state &&
        other.errorMessage == errorMessage &&
        other.targetCurrency == targetCurrency &&
        other.totalRates == totalRates &&
        other.fetchedRates == fetchedRates &&
        other.unstampedLegacyCurrency == unstampedLegacyCurrency;
  }

  @override
  int get hashCode {
    return Object.hash(
      state,
      errorMessage,
      targetCurrency,
      totalRates,
      fetchedRates,
      unstampedLegacyCurrency,
    );
  }
}

/// Asks whether records saved without a currency were entered in [currency],
/// the current base currency. Returns true for yes, false for no, and null
/// when the user cancelled the currency change.
typedef LegacyCurrencyQuestion = Future<bool?> Function(String currency);

/// Provider for currency switch status
@riverpod
class CurrencySwitch extends _$CurrencySwitch {
  Timer? _debounceTimer;
  String? _pendingCurrency;

  /// True while a change runs. Only one change runs at a time: a second one
  /// would ask about the same records with a currency that the first may
  /// be about to replace, and its answer could override the first answer.
  bool _inFlight = false;

  @override
  CurrencySwitchStatus build() {
    // Clean up timer on dispose
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    return const CurrencySwitchStatus.idle();
  }

  /// Switch currency with debouncing (prevents race conditions from rapid selection)
  ///
  /// This is the public API that should be called from UI.
  /// It debounces rapid currency changes to prevent race conditions.
  ///
  /// [askLegacyCurrency] is called before the change when this user still has
  /// records without a currency and has not confirmed which currency they are
  /// in. Without it, such a change is not applied.
  void switchCurrencyDebounced(
    String newCurrency, {
    LegacyCurrencyQuestion? askLegacyCurrency,
  }) {
    // Cancel any pending switch
    _debounceTimer?.cancel();

    // Store pending currency
    _pendingCurrency = newCurrency;

    // Schedule switch after 300ms of inactivity
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_pendingCurrency != null) {
        _switchCurrencyImmediate(_pendingCurrency!, askLegacyCurrency);
        _pendingCurrency = null;
      }
    });
  }

  /// Switch currency immediately (for testing)
  ///
  /// This method is exposed for testing purposes to avoid dealing with Timer delays.
  /// In production code, use switchCurrencyDebounced() instead.
  @visibleForTesting
  Future<void> switchCurrencyImmediate(
    String newCurrency, {
    LegacyCurrencyQuestion? askLegacyCurrency,
  }) async {
    return _switchCurrencyImmediate(newCurrency, askLegacyCurrency);
  }

  /// Internal method: Switch currency with optimistic UI updates and parallel rate fetching
  ///
  /// OPTIMIZED Flow:
  /// 1. **Optimistic Update**: Apply currency switch immediately (instant perceived speed)
  /// 2. **Background Fetch**: Fetch all required exchange rates in parallel (5-10x faster)
  /// 3. **Rollback on Failure**: Revert to old currency if rate fetching fails
  /// 4. **Progress Updates**: Show granular progress as rates complete
  ///
  /// Benefits:
  /// - Instant perceived speed (UI updates immediately)
  /// - 5-10x faster actual execution (parallel fetching)
  /// - Graceful failure handling (rollback on error)
  /// - Real-time progress feedback (updates as each rate completes)
  ///
  /// Note: This is an internal method. Use switchCurrencyDebounced() from UI.
  Future<void> _switchCurrencyImmediate(
    String newCurrency,
    LegacyCurrencyQuestion? askLegacyCurrency,
  ) async {
    final currentCurrency = ref.read(currencyCodeProvider);

    // Same currency - no-op
    if (currentCurrency == newCurrency) {
      return;
    }

    // Single flight: the tile is disabled while a change runs, so this only
    // refuses a change started another way (debounce timer, Retry).
    if (_inFlight) {
      LoggerService.warn(
        'Currency switch refused - another switch is running',
        metadata: {'from': currentCurrency, 'to': newCurrency},
      );
      return;
    }
    _inFlight = true;
    try {
      await _runSwitch(currentCurrency, newCurrency, askLegacyCurrency);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _runSwitch(
    String currentCurrency,
    String newCurrency,
    LegacyCurrencyQuestion? askLegacyCurrency,
  ) async {
    // The user whose records step 0b checks and stamps.
    final userId = ref.read(legacyCurrencyBackfillServiceProvider)?.userId;
    state = CurrencySwitchStatus.checkingRecords(targetCurrency: newCurrency);

    try {
      // Step 0: Check connectivity before attempting switch
      // This provides better error messages for offline users
      final connectivityService = ref.read(connectivityServiceProvider);
      final isConnected = await connectivityService.checkConnectivity();

      if (!isConnected) {
        // Set failed state with offline error
        state = CurrencySwitchStatus.failed(
          errorMessage: null, // UI will show localized offline message
          targetCurrency: newCurrency,
        );

        LoggerService.warn(
          'Currency switch aborted - no internet connection',
          metadata: {'from': currentCurrency, 'to': newCurrency},
        );

        // Throw NetworkException for consistent error handling
        throw NetworkException.noConnection();
      }

      // Step 0b: Stamp records saved without a currency with the CURRENT
      // base currency before switching, once the user confirmed it (A03-F1).
      // Otherwise the repositories would label them with the new currency and
      // their amounts would change currency without conversion. If this
      // fails, the switch is not applied; if the user cancels, nothing is.
      if (!await _stampLegacyRecords(
            currentCurrency,
            userId,
            askLegacyCurrency,
          ) ||
          !_stillCurrent(currentCurrency, userId)) {
        state = const CurrencySwitchStatus.idle();
        return;
      }

      // Analytics: Track currency switch attempt
      final analytics = ref.read(analyticsServiceProvider);
      await analytics.logEvent(
        name: 'currency_switch_started',
        parameters: {
          'from_currency': currentCurrency,
          'to_currency': newCurrency,
        },
      );

      // Step 1: OPTIMISTIC UPDATE - Apply currency switch immediately
      // This provides instant perceived speed while rates fetch in background
      await ref.read(settingsProvider.notifier).setCurrency(newCurrency);

      // Step 1b: Set loading state (subtle indicator that rates are fetching)
      state = CurrencySwitchStatus.fetchingRates(
        targetCurrency: newCurrency,
        totalRates: 0,
        fetchedRates: 0,
      );

      // Step 2: Get all cashflows to determine required currency pairs
      // ARCHITECTURAL NOTE: This creates a dependency from settings → investment feature.
      // This is acceptable because:
      // 1. Currency switching is inherently tied to investment data (need to know which currencies are in use)
      // 2. The coupling is read-only (settings doesn't modify investment data)
      // 3. Alternative (use case layer) would add complexity without clear benefit
      // 4. If this becomes problematic, refactor to: CurrencySwitchUseCase that encapsulates validCashFlowsProvider
      final cashFlowsAsync = ref.read(validCashFlowsProvider);
      final cashFlows = cashFlowsAsync.when(
        data: (data) => data,
        loading: () => <CashFlowEntity>[],
        error: (e, st) => <CashFlowEntity>[],
      );

      // Step 3: Collect unique currency pairs that need conversion
      final uniqueCurrencies = <String>{};
      for (final cf in cashFlows) {
        if (cf.currency != newCurrency) {
          uniqueCurrencies.add(cf.currency);
        }
      }

      final totalRates = uniqueCurrencies.length;

      // Short-circuit: no rates to fetch (all cashflows already in target currency)
      if (totalRates == 0) {
        // Currency already set in optimistic update (line 202), no need to set again
        state = CurrencySwitchStatus.success(targetCurrency: newCurrency);

        // Analytics: Track successful currency switch (no rates needed)
        await analytics.logEvent(
          name: 'currency_switch_completed',
          parameters: {
            'from_currency': currentCurrency,
            'to_currency': newCurrency,
            'rates_fetched': 0,
          },
        );

        LoggerService.info(
          'Currency switched successfully (no rates needed)',
          metadata: {'from': currentCurrency, 'to': newCurrency},
        );
        return;
      }

      // Update state with total count
      state = CurrencySwitchStatus.fetchingRates(
        targetCurrency: newCurrency,
        totalRates: totalRates,
        fetchedRates: 0,
      );

      // Step 4: Pre-fetch all required exchange rates (PARALLEL with progress updates)
      //
      // OPTIMIZATION: Use parallel fetching with Future.wait for 5-10x faster execution
      // while maintaining granular progress updates. Each rate fetch updates progress
      // as it completes, providing real-time feedback (e.g., "Loading: 2 of 5").
      //
      // Benefits:
      // - 5-10x faster for users with multiple currencies (parallel API calls)
      // - Still shows granular progress (updates as each rate completes)
      // - Leverages request coalescing in CurrencyConversionService
      // - Fails fast if any rate fetch fails (better error handling)
      final conversionService = ref.read(currencyConversionServiceProvider);

      // BUG FIX (2026-05-04): Handle null service when user is not authenticated
      if (conversionService == null) {
        throw Exception(
          'Currency conversion service unavailable. Please sign in.',
        );
      }

      int fetchedCount = 0;

      // Create all rate fetch futures (starts parallel execution)
      final rateFutures = uniqueCurrencies.map((fromCurrency) async {
        final rate = await conversionService.getRate(
          from: fromCurrency,
          to: newCurrency,
        );

        // Update progress as each rate completes (real-time feedback)
        fetchedCount++;
        state = CurrencySwitchStatus.fetchingRates(
          targetCurrency: newCurrency,
          totalRates: totalRates,
          fetchedRates: fetchedCount,
        );

        return rate;
      }).toList();

      // Wait for all rates to complete (parallel execution)
      await Future.wait(rateFutures);

      // Step 5: All rates fetched successfully - currency already applied (optimistic update)
      // No need to call setCurrency again

      // Step 6: Set success state
      state = CurrencySwitchStatus.success(targetCurrency: newCurrency);

      // Analytics: Track successful currency switch
      await analytics.logEvent(
        name: 'currency_switch_completed',
        parameters: {
          'from_currency': currentCurrency,
          'to_currency': newCurrency,
          'rates_fetched': totalRates,
        },
      );

      LoggerService.info(
        'Currency switched successfully',
        metadata: {
          'from': currentCurrency,
          'to': newCurrency,
          'ratesFetched': totalRates,
        },
      );
    } catch (e, st) {
      // Step 7: ROLLBACK - Revert to old currency on failure
      // This ensures UI consistency when rate fetching fails. Only this
      // change is undone, never a currency set elsewhere meanwhile.
      if (ref.read(currencyCodeProvider) == newCurrency) {
        await ref.read(settingsProvider.notifier).setCurrency(currentCurrency);
      }

      // Step 8: Set failed state
      // Use null for errorMessage - UI will show localized l10n.currencySwitchFailed
      state = CurrencySwitchStatus.failed(
        errorMessage: null,
        targetCurrency: newCurrency,
        unstampedLegacyCurrency: e is LegacyCurrencyStampException
            ? currentCurrency
            : null,
      );

      // Analytics: Track currency switch failure
      final analytics = ref.read(analyticsServiceProvider);
      await analytics.logEvent(
        name: 'currency_switch_failed',
        parameters: {
          'from_currency': currentCurrency,
          'to_currency': newCurrency,
          'error_type': e.runtimeType.toString(),
        },
      );

      LoggerService.error(
        'Currency switch failed - rolled back to $currentCurrency',
        error: e,
        stackTrace: st,
        metadata: {
          'from': currentCurrency,
          'to': newCurrency,
          'rolledBack': true,
        },
      );
    }
  }

  /// Whether the base currency is still [currency] and the signed-in user is
  /// still [userId], as when the change started. If either changed while the
  /// records were checked or the question was open, the answer and the
  /// change no longer apply.
  bool _stillCurrent(String currency, String? userId) =>
      ref.read(currencyCodeProvider) == currency &&
      ref.read(legacyCurrencyBackfillServiceProvider)?.userId == userId;

  /// Returns false when the change must not go ahead (the user cancelled,
  /// could not be asked, or the base currency or user changed meanwhile).
  /// Throws [LegacyCurrencyStampException] when the records could not be
  /// checked or stamped.
  Future<bool> _stampLegacyRecords(
    String currency,
    String? userId,
    LegacyCurrencyQuestion? ask,
  ) async {
    final backfill = ref.read(legacyCurrencyBackfillServiceProvider);
    if (backfill == null) return true;
    try {
      // Stamp only a currency this user confirmed for their account. On a
      // fresh install the device currency is the default INR, and on a shared
      // device it is the previous user's, so without a confirmation the user
      // is asked now. A launch-time "Not Now" or an offline launch must not
      // let the records silently take the new currency.
      if (!backfill.isConfirmedFor(currency)) {
        if (!await backfill.hasUnstampedRecords()) return true;
        if (!_stillCurrent(currency, userId)) return false;
        final enteredInCurrency = ask == null ? null : await ask(currency);
        if (enteredInCurrency == null) return false;
        // The question named [currency] for this user; if either changed
        // while it was open, the answer is about something no longer shown.
        if (!_stillCurrent(currency, userId)) return false;
        // No: they were not entered in this currency, so they follow the new
        // base currency as before.
        if (!enteredInCurrency) return true;
        await backfill.confirm(currency);
      }
      await backfill.backfill(currency);
      return true;
    } catch (e) {
      throw LegacyCurrencyStampException.from(e);
    }
  }

  /// Reset state to idle
  void reset() {
    state = const CurrencySwitchStatus.idle();
  }
}

/// Thrown when records saved without a currency could not be stamped with the
/// current base currency, so a base-currency change must not be applied.
/// Carries only the cause's type, never document paths or values.
class LegacyCurrencyStampException implements Exception {
  const LegacyCurrencyStampException(this.causeType);

  /// Keeps the cause's type, and a Firestore error's code (for example
  /// `deadline-exceeded` or `unavailable`), so a report can tell a timeout
  /// from an unreachable server. Never the message, which can hold a path.
  factory LegacyCurrencyStampException.from(Object error) =>
      LegacyCurrencyStampException(
        error is FirebaseException
            ? 'FirebaseException(${error.code})'
            : error.runtimeType.toString(),
      );

  final String causeType;

  @override
  String toString() => 'LegacyCurrencyStampException($causeType)';
}

/// The message shown when a currency switch failed.
String currencySwitchFailureMessage(
  AppLocalizations l10n,
  CurrencySwitchStatus status,
) {
  final target = status.targetCurrency ?? 'Unknown';
  final unstamped = status.unstampedLegacyCurrency;
  if (unstamped != null) {
    return l10n.currencySwitchBlockedLegacyRecords(unstamped, target);
  }
  return l10n.currencySwitchFailed(target);
}
