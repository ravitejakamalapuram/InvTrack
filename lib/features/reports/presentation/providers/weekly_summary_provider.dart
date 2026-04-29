/// Provider for weekly investment summary report
///
/// Generates a weekly summary report by aggregating cashflows, investments,
/// and XIRR calculations for the current or specified week.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/reports/data/services/weekly_summary_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/weekly_summary.dart';

/// Provider for current week's summary (Monday-Sunday)
final currentWeeklySummaryProvider =
    FutureProvider.autoDispose<WeeklySummary>((ref) async {
  final now = DateTime.now();
  final weekStart = _getWeekStart(now);
  final weekEnd = _getWeekEnd(weekStart);

  return ref.watch(
    weeklySummaryProvider((periodStart: weekStart, periodEnd: weekEnd)).future,
  );
});

/// Provider for weekly summary with custom date range
/// Optimized: Uses date-range filtered cashflows (server-side) instead of fetching all
final weeklySummaryProvider = FutureProvider.autoDispose
    .family<WeeklySummary, ({DateTime periodStart, DateTime periodEnd})>(
  (ref, params) async {
    // Get all investments (needed for XIRR and maturity checks)
    final investmentsAsync = ref.watch(activeInvestmentsProvider);

    // Get only cashflows in date range (optimized - server-side filtering)
    final cashFlowsAsync = ref.watch(
      cashFlowsInDateRangeProvider((
        start: params.periodStart,
        end: params.periodEnd,
      )),
    );

    final xirrMapAsync = ref.watch(activeInvestmentXirrMapProvider);

    // Wait for all data to load
    final investments = await investmentsAsync.when(
      data: (data) => Future.value(data),
      loading: () => Future.value(<InvestmentEntity>[]),
      error: (e, st) => throw e,
    );

    final cashFlows = await cashFlowsAsync.when(
      data: (data) => Future.value(data),
      loading: () => Future.value(<CashFlowEntity>[]),
      error: (e, st) => throw e,
    );

    final xirrMap = await xirrMapAsync.when(
      data: (data) => Future.value(data),
      loading: () => Future.value(<String, double>{}),
      error: (e, st) => throw e,
    );

    // Generate summary
    final service = ref.read(weeklySummaryServiceProvider);
    return service.generateSummary(
      periodStart: params.periodStart,
      periodEnd: params.periodEnd,
      allCashFlows: cashFlows,
      allInvestments: investments,
      xirrMap: xirrMap,
    );
  },
);

/// Get week start date (Monday) for a given date
DateTime _getWeekStart(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day);
}

/// Get week end date (Sunday) for a given week start
DateTime _getWeekEnd(DateTime weekStart) {
  final sunday = weekStart.add(const Duration(days: 6));
  return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
}

/// Helper to get previous week's date range
({DateTime start, DateTime end}) getPreviousWeek(DateTime current) {
  final start = _getWeekStart(current).subtract(const Duration(days: 7));
  final end = _getWeekEnd(start);
  return (start: start, end: end);
}

/// Helper to get next week's date range
({DateTime start, DateTime end}) getNextWeek(DateTime current) {
  final start = _getWeekStart(current).add(const Duration(days: 7));
  final end = _getWeekEnd(start);
  return (start: start, end: end);
}
