/// Service for generating weekly investment summary reports
///
/// Aggregates cashflows, investments, and statistics for a given week
/// (Monday-Sunday) to create a comprehensive weekly summary.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/reports/data/services/report_cache_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';
import 'package:inv_tracker/features/reports/domain/entities/weekly_summary.dart';

/// Provider for weekly summary service
final weeklySummaryServiceProvider = Provider<WeeklySummaryService>((ref) {
  return WeeklySummaryService(
    cacheService: ref.read(reportCacheServiceProvider),
  );
});

/// Weekly summary generation service
class WeeklySummaryService {
  final ReportCacheService cacheService;

  WeeklySummaryService({required this.cacheService});

  /// Generate weekly summary for the given period
  Future<WeeklySummary> generateSummary({
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
    required Map<String, double> xirrMap,
  }) async {
    // Check cache first
    final cached = cacheService.get<WeeklySummary>(
      ReportType.weeklySummary,
      periodStart,
      periodEnd,
    );
    if (cached != null) return cached;

    LoggerService.info(
      'Generating weekly summary',
      metadata: {
        'start': periodStart.toString(),
        'end': periodEnd.toString(),
      },
    );

    // Filter cashflows for this week
    final weekCashFlows = allCashFlows.where((cf) {
      return cf.date.isAfter(periodStart.subtract(const Duration(days: 1))) &&
          cf.date.isBefore(periodEnd.add(const Duration(days: 1)));
    }).toList();

    // Calculate totals
    final invested = weekCashFlows
        .where((cf) => cf.type == CashFlowType.invest)
        .fold<double>(0, (sum, cf) => sum + cf.amount);

    final returned = weekCashFlows
        .where((cf) => cf.type == CashFlowType.returnFlow)
        .fold<double>(0, (sum, cf) => sum + cf.amount);

    final income = weekCashFlows
        .where((cf) => cf.type == CashFlowType.income)
        .fold<double>(0, (sum, cf) => sum + cf.amount);

    final netPosition = (returned + income) - invested;

    // Find new investments created this week
    final newInvestments = allInvestments.where((inv) {
      return inv.createdAt.isAfter(periodStart.subtract(const Duration(days: 1))) &&
          inv.createdAt.isBefore(periodEnd.add(const Duration(days: 1)));
    }).toList();

    // Find upcoming maturities (next 7 days)
    final nextWeekEnd = periodEnd.add(const Duration(days: 7));
    final upcomingMaturities = allInvestments.where((inv) {
      if (inv.maturityDate == null || !inv.isOpen) return false;
      return inv.maturityDate!.isAfter(periodEnd) &&
          inv.maturityDate!.isBefore(nextWeekEnd.add(const Duration(days: 1)));
    }).toList();

    // Find top performer by XIRR
    InvestmentEntity? topPerformer;
    double? topXirr;
    for (final inv in allInvestments.where((i) => i.isOpen)) {
      final xirr = xirrMap[inv.id];
      if (xirr != null && (topXirr == null || xirr > topXirr)) {
        topXirr = xirr;
        topPerformer = inv;
      }
    }

    // Generate daily cashflows for chart
    final dailyCashFlows = _generateDailyCashFlows(
      periodStart,
      periodEnd,
      weekCashFlows,
    );

    // Calculate previous week's net position (optional)
    final prevWeekStart = periodStart.subtract(const Duration(days: 7));
    final prevWeekEnd = periodStart.subtract(const Duration(days: 1));
    final prevWeekFlows = allCashFlows.where((cf) {
      return cf.date.isAfter(prevWeekStart.subtract(const Duration(days: 1))) &&
          cf.date.isBefore(prevWeekEnd.add(const Duration(days: 1)));
    }).toList();

    final prevWeekNet = _calculateNetPosition(prevWeekFlows);

    final summary = WeeklySummary(
      periodStart: periodStart,
      periodEnd: periodEnd,
      totalInvested: invested,
      totalReturns: returned + income,
      netPosition: netPosition,
      totalIncome: income,
      topPerformer: topPerformer,
      topPerformerXirr: topXirr,
      newInvestments: newInvestments,
      upcomingMaturities: upcomingMaturities,
      dailyCashFlows: dailyCashFlows,
      previousWeekNet: prevWeekNet,
    );

    // Cache the result
    cacheService.set(ReportType.weeklySummary, periodStart, periodEnd, summary);

    return summary;
  }

  /// Generate daily cashflow breakdown for chart
  List<DailyCashFlow> _generateDailyCashFlows(
    DateTime start,
    DateTime end,
    List<CashFlowEntity> cashFlows,
  ) {
    final dailyFlows = <DailyCashFlow>[];
    var current = start;

    while (current.isBefore(end.add(const Duration(days: 1)))) {
      final dayFlows = cashFlows.where((cf) {
        return cf.date.year == current.year &&
            cf.date.month == current.month &&
            cf.date.day == current.day;
      }).toList();

      final outflows = dayFlows
          .where((cf) => cf.type == CashFlowType.invest || cf.type == CashFlowType.fee)
          .fold<double>(0, (sum, cf) => sum + cf.amount);

      final inflows = dayFlows
          .where((cf) => cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income)
          .fold<double>(0, (sum, cf) => sum + cf.amount);

      dailyFlows.add(DailyCashFlow(
        dayOfWeek: current.weekday - 1, // 0=Monday
        date: current,
        outflows: outflows,
        inflows: inflows,
      ));

      current = current.add(const Duration(days: 1));
    }

    return dailyFlows;
  }

  /// Calculate net position from cashflows
  double _calculateNetPosition(List<CashFlowEntity> cashFlows) {
    final invested = cashFlows
        .where((cf) => cf.type == CashFlowType.invest)
        .fold<double>(0, (sum, cf) => sum + cf.amount);

    final returned = cashFlows
        .where((cf) => cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income)
        .fold<double>(0, (sum, cf) => sum + cf.amount);

    return returned - invested;
  }
}
