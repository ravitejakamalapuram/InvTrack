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

    // Boundaries for date filtering hoisted out of loop
    final weekStartBoundary = periodStart.subtract(const Duration(days: 1));
    final weekEndBoundary = periodEnd.add(const Duration(days: 1));

    final prevWeekStart = periodStart.subtract(const Duration(days: 7));
    final prevWeekEnd = periodStart.subtract(const Duration(days: 1));
    final prevWeekStartBoundary = prevWeekStart.subtract(const Duration(days: 1));
    final prevWeekEndBoundary = prevWeekEnd.add(const Duration(days: 1));

    // Calculate totals, weekCashFlows and prevWeekFlows concurrently in single pass
    double invested = 0;
    double returned = 0;
    double income = 0;

    final weekCashFlows = <CashFlowEntity>[];
    final prevWeekFlows = <CashFlowEntity>[];

    for (final cf in allCashFlows) {
      // Current week cashflows
      if (cf.date.isAfter(weekStartBoundary) && cf.date.isBefore(weekEndBoundary)) {
        weekCashFlows.add(cf);
        if (cf.type == CashFlowType.invest) {
          invested += cf.amount;
        } else if (cf.type == CashFlowType.returnFlow) {
          returned += cf.amount;
        } else if (cf.type == CashFlowType.income) {
          income += cf.amount;
        }
      }

      // Previous week cashflows
      if (cf.date.isAfter(prevWeekStartBoundary) && cf.date.isBefore(prevWeekEndBoundary)) {
        prevWeekFlows.add(cf);
      }
    }

    final netPosition = (returned + income) - invested;

    // Single pass loop for investments replacing multiple sequential .where().toList() calls
    final newInvestments = <InvestmentEntity>[];
    final upcomingMaturities = <InvestmentEntity>[];

    final nextWeekEnd = periodEnd.add(const Duration(days: 7));
    final nextWeekEndBoundary = nextWeekEnd.add(const Duration(days: 1));

    InvestmentEntity? topPerformer;
    double? topXirr;

    for (final inv in allInvestments) {
      // Find new investments created this week
      if (inv.createdAt.isAfter(weekStartBoundary) && inv.createdAt.isBefore(weekEndBoundary)) {
        newInvestments.add(inv);
      }

      if (!inv.isOpen) continue;

      // Find upcoming maturities (next 7 days)
      if (inv.maturityDate != null &&
          inv.maturityDate!.isAfter(periodEnd) &&
          inv.maturityDate!.isBefore(nextWeekEndBoundary)) {
        upcomingMaturities.add(inv);
      }

      // Find top performer by XIRR
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

    // Calculate previous week's net position
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

    // Group cash flows by date string to avoid O(days * N) lookups
    final Map<String, List<CashFlowEntity>> flowsByDate = {};
    for (final cf in cashFlows) {
      final dateKey = '${cf.date.year}-${cf.date.month}-${cf.date.day}';
      flowsByDate.putIfAbsent(dateKey, () => []).add(cf);
    }

    var current = start;
    final endBoundary = end.add(const Duration(days: 1));

    while (current.isBefore(endBoundary)) {
      final dateKey = '${current.year}-${current.month}-${current.day}';
      final dayFlows = flowsByDate[dateKey] ?? [];

      double outflows = 0;
      double inflows = 0;

      for (final cf in dayFlows) {
        if (cf.type == CashFlowType.invest || cf.type == CashFlowType.fee) {
          outflows += cf.amount;
        } else if (cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income) {
          inflows += cf.amount;
        }
      }

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
    double invested = 0;
    double returned = 0;

    for (final cf in cashFlows) {
      if (cf.type == CashFlowType.invest) {
        invested += cf.amount;
      } else if (cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income) {
        returned += cf.amount;
      }
    }

    return returned - invested;
  }
}
