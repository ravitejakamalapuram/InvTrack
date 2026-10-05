/// Providers for FIRE Number feature.
/// Handles FIRE settings, calculations, and projections.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/calculations/planning_inputs_calculator.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/utils/async_value_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/fire_number/data/repositories/firestore_fire_settings_repository.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_calculation_service.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

// ============ REPOSITORY PROVIDER ============

/// Provider for FIRE settings repository
final fireSettingsRepositoryProvider = Provider<FireSettingsRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  final user = authState.value;
  if (user == null) {
    throw StateError('User not authenticated');
  }

  return FirestoreFireSettingsRepository(firestore: firestore, userId: user.id);
});

// ============ CALCULATION SERVICE ============

/// Provider for FIRE calculation service
final fireCalculationServiceProvider = Provider<FireCalculationService>((ref) {
  return FireCalculationService();
});

// ============ STREAM PROVIDERS ============

/// Watch FIRE settings (real-time updates)
/// Returns null if user hasn't set up FIRE settings yet
/// Uses autoDispose to clean up when no longer needed
/// Errors propagate to UI for proper error handling
final fireSettingsProvider = StreamProvider.autoDispose<FireSettingsEntity?>((
  ref,
) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value(null);
  }
  // Let errors propagate to UI - FIRE dashboard handles AsyncValue.error properly
  return ref.watch(fireSettingsRepositoryProvider).watchSettings();
});

/// Check if FIRE setup is complete
final isFireSetupCompleteProvider = Provider<bool>((ref) {
  final settings = ref.watch(fireSettingsProvider).value;
  return settings?.isSetupComplete ?? false;
});

// ============ PORTFOLIO INPUTS ============

/// The portfolio side of the FIRE inputs, in [currency] (the base currency).
class FirePortfolioInputs {
  final CorpusValue corpus;
  final MonthlySavingsEstimate savings;
  final String currency;
  final DateTime asOf;

  const FirePortfolioInputs({
    required this.corpus,
    required this.savings,
    required this.currency,
    required this.asOf,
  });
}

/// FIRE corpus and monthly savings, from the converted snapshot every stats
/// screen reads (A13) and the current values of open investments (A10).
/// Archived investments are left out (money rule 9).
final firePortfolioInputsProvider =
    FutureProvider.autoDispose<FirePortfolioInputs>((ref) async {
      final baseCurrency = ref.watch(currencyCodeProvider);
      final asOf = ref.watch(valuationDateProvider);
      final investmentsAsync = ref.watch(activeInvestmentsProvider);
      final snapshotAsync = ref.watch(convertedCashFlowsSnapshotProvider);
      final convertedAsync = ref.watch(convertedTerminalValuesProvider);

      // Stay loading, or fail, with the sources: an empty portfolio here
      // would show a FIRE number with no progress to users who have data.
      // The snapshot is checked itself so that its load error shows even
      // while Riverpod retries it.
      final investments = await dataOf(investmentsAsync);
      await dataOf(snapshotAsync);
      final converted = await dataOf(convertedAsync);
      // Amounts are never used under a currency they were not converted to.
      if (converted.snapshot.baseCurrency != baseCurrency) {
        return Completer<FirePortfolioInputs>().future;
      }

      final cashFlows = converted.snapshot.cashFlows;
      return FirePortfolioInputs(
        corpus: PlanningInputsCalculator.corpus(
          investments: investments,
          cashFlows: cashFlows,
          terminalValues: converted.byInvestment,
        ),
        savings: PlanningInputsCalculator.monthlySavings(
          cashFlows: cashFlows,
          asOf: asOf,
        ),
        currency: baseCurrency,
        asOf: asOf,
      );
    });

/// How many units of `to` one unit of `from` is worth today, for FIRE
/// amounts entered in another currency than the base currency (GAP2-01).
/// Fails rather than reading one currency as another when there is no rate.
final fireCurrencyRateProvider = FutureProvider.autoDispose
    .family<double, ({String from, String to})>((ref, pair) async {
      if (pair.from == pair.to) return 1.0;
      return ref
          .watch(calculationEngineProvider)
          .currency
          .rateToday(from: pair.from, to: pair.to);
    });

/// Reloads what the FIRE calculation reads after a load error: the
/// portfolio, and the exchange rate for FIRE amounts in another currency
/// (which Riverpod stops retrying after a while).
void reloadFireInputs(WidgetRef ref) {
  reloadPortfolio(ref);
  ref.invalidate(fireCurrencyRateProvider);
}

// ============ CALCULATION PROVIDERS ============

/// Calculate FIRE numbers based on settings and current portfolio, all in
/// the base currency.
/// Uses autoDispose to clean up when no longer needed
final fireCalculationProvider =
    Provider.autoDispose<AsyncValue<FireCalculationResult>>((ref) {
      final settingsAsync = ref.watch(fireSettingsProvider);

      return settingsAsync.when(
        data: (settings) {
          if (settings == null || !settings.isSetupComplete) {
            return AsyncValue.data(FireCalculationResult.empty());
          }

          final baseCurrency = ref.watch(currencyCodeProvider);
          // errorFirst: a load error is an error even while Riverpod
          // retries it, so the FIRE card and screen show it with a retry
          // action instead of loading indefinitely, and no FIRE number is
          // ever computed from a portfolio that failed to load.
          final portfolioAsync = errorFirst(
            ref.watch(firePortfolioInputsProvider),
          );
          // Settings saved before amounts had a currency are read in the
          // base currency, as they always were. A base-currency change
          // stamps them with the old one first (LegacyCurrencyBackfill).
          final rateAsync = errorFirst(
            ref.watch(
              fireCurrencyRateProvider((
                from: settings.currency ?? baseCurrency,
                to: baseCurrency,
              )),
            ),
          );

          for (final async in [portfolioAsync, rateAsync]) {
            if (async.hasError) {
              return AsyncValue.error(
                async.error!,
                async.stackTrace ?? StackTrace.current,
              );
            }
            // A refresh keeps the previous data; a reload (another user or
            // base currency) does not.
            if (async.isLoading && !async.isRefreshing) {
              return const AsyncValue.loading();
            }
          }
          final portfolio = portfolioAsync.value;
          final rate = rateAsync.value;
          if (portfolio == null ||
              rate == null ||
              portfolio.currency != baseCurrency) {
            return const AsyncValue.loading();
          }

          final converted = settings.convertedTo(baseCurrency, rate);
          final declaredSip = converted.monthlySip;
          final estimate = portfolio.savings.amount;
          final inputs = FireInputsSummary(
            investmentsValue: portfolio.corpus.currentValues,
            principalWithoutValue: portfolio.corpus.principalWithoutValue,
            otherAssets: converted.otherAssets,
            savingsSource: declaredSip != null
                ? MonthlySavingsSource.declared
                : estimate != null
                ? MonthlySavingsSource.history
                : MonthlySavingsSource.notEnoughHistory,
          );

          return AsyncValue.data(
            ref
                .read(fireCalculationServiceProvider)
                .calculate(
                  settings: converted,
                  currentPortfolioValue: inputs.corpus,
                  currentMonthlySavings: declaredSip ?? estimate ?? 0,
                  asOf: portfolio.asOf,
                  inputs: inputs,
                ),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// Provider for FIRE progress percentage
final fireProgressProvider = Provider.autoDispose<double>((ref) {
  final calculation = ref.watch(fireCalculationProvider);
  return calculation.when(
    data: (result) => result.progressPercentage,
    loading: () => 0,
    error: (_, st) => 0,
  );
});

/// Provider for FIRE status
final fireStatusProvider = Provider.autoDispose<FireProgressStatus>((ref) {
  final calculation = ref.watch(fireCalculationProvider);
  return calculation.when(
    data: (result) => result.status,
    loading: () => FireProgressStatus.notStarted,
    error: (_, st) => FireProgressStatus.notStarted,
  );
});
