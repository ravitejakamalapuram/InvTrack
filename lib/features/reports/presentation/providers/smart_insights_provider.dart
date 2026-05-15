/// Smart Insights Provider
///
/// Provides auto-generated insights based on user data
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/reports/data/services/smart_insights_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/smart_insight.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

part 'smart_insights_provider.g.dart';

/// Service provider for smart insights generation
@riverpod
SmartInsightsService smartInsightsService(Ref ref) {
  return SmartInsightsService();
}

/// Provider for smart insights (auto-generated from user data)
/// Requires AppLocalizations for localized strings
@riverpod
Future<List<SmartInsight>> smartInsights(Ref ref, AppLocalizations l10n) async {
  // Watch all required data
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
  final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);
  final goalsAsync = ref.watch(activeGoalsProvider);

  // Watch currency and locale for proper formatting
  final currencySymbol = ref.watch(currencySymbolProvider);
  final currencyLocale = ref.watch(currencyLocaleProvider);

  // Wait for all data to load - errors propagate to UI for proper handling
  final investments = investmentsAsync.when(
    data: (data) => data.toList(),
    loading: () => throw StateError('Investments data is still loading'),
    error: (e, st) => throw e,
  );

  final cashFlows = cashFlowsAsync.when(
    data: (data) => data.toList(),
    loading: () => throw StateError('Cash flows data is still loading'),
    error: (e, st) => throw e,
  );

  final goals = goalsAsync.when(
    data: (data) => data.toList(),
    loading: () => throw StateError('Goals data is still loading'),
    error: (e, st) => throw e,
  );

  // Generate insights with currency, locale, and localization
  final service = ref.read(smartInsightsServiceProvider);
  final insights = service.generateInsights(
    investments: investments,
    cashFlows: cashFlows,
    goals: goals,
    currencySymbol: currencySymbol,
    locale: currencyLocale,
    l10n: l10n,
  );

  // Filter out expired insights
  return insights.where((insight) => !insight.isExpired).toList();
}

/// Provider for high-priority insights (urgent/warning only)
/// Requires AppLocalizations for localized strings
@riverpod
Future<List<SmartInsight>> priorityInsights(Ref ref, AppLocalizations l10n) async {
  final allInsights = await ref.watch(smartInsightsProvider(l10n).future);

  return allInsights
      .where((insight) =>
        insight.priority == InsightPriority.urgent ||
        insight.priority == InsightPriority.warning
      )
      .toList();
}
