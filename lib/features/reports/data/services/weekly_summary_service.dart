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
      metadata: {'start': periodStart.toString(), 'end': periodEnd.toString()},
    );

    // Filter cashflows for this week
    final weekCashFlows = allCashFlows.where((cf) {
      return cf.date.isAfter(periodStart.subtract(const Duration(days: 1))) &&
          cf.date.isBefore(periodEnd.add(const Duration(days: 1)));
    }).toList();

    // Calculate totals
    double invested = 0;
    double returned = 0;
    double income = 0;

    for (final cf in weekCashFlows) {
      if (cf.type == CashFlowType.invest) {
        invested += cf.amount;
      } else if (cf.type == CashFlowType.returnFlow) {
        returned += cf.amount;
      } else if (cf.type == CashFlowType.income) {
        income += cf.amount;
      }
    }

    final netPosition = (returned + income) - invested;

    // Find new investments created this week, upcoming maturities, and top performer
    // Optimization: Single pass loop replacing multiple sequential .where().toList() calls
    final newInvestments = <InvestmentEntity>[];
    final upcomingMaturities = <InvestmentEntity>[];
    InvestmentEntity? topPerformer;
    double? topXirr;

    // Pre-calculate boundary dates to avoid recalculation in the loop
    final periodStartBoundary = periodStart.subtract(const Duration(days: 1));
    final periodEndBoundary = periodEnd.add(const Duration(days: 1));
    final nextWeekEnd = periodEnd.add(const Duration(days: 7));
    final maturityBoundary = nextWeekEnd.add(const Duration(days: 1));

    for (final inv in allInvestments) {
      // 1. Check if new investment
      if (inv.createdAt.isAfter(periodStartBoundary) &&
          inv.createdAt.isBefore(periodEndBoundary)) {
        newInvestments.add(inv);
      }

      // Remaining checks only apply to open investments
      if (!inv.isOpen) continue;

      // 2. Check for upcoming maturities
      if (inv.maturityDate != null &&
          inv.maturityDate!.isAfter(periodEnd) &&
          inv.maturityDate!.isBefore(maturityBoundary)) {
        upcomingMaturities.add(inv);
      }

      // 3. Find top performer
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
    // Optimization: Pre-group cashflows by date to avoid O(N*M) nested iteration
    final flowsByDate = <String, List<CashFlowEntity>>{};
    for (final cf in cashFlows) {
      final key = '${cf.date.year}-${cf.date.month}-${cf.date.day}';
      flowsByDate.putIfAbsent(key, () => []).add(cf);
    }

    final dailyFlows = <DailyCashFlow>[];
    var current = start;
    final endBoundary = end.add(const Duration(days: 1));

    while (current.isBefore(endBoundary)) {
      final key = '${current.year}-${current.month}-${current.day}';
      final dayFlows = flowsByDate[key] ?? [];

      double outflows = 0;
      double inflows = 0;

      for (final cf in dayFlows) {
        if (cf.type == CashFlowType.invest || cf.type == CashFlowType.fee) {
          outflows += cf.amount;
        } else if (cf.type == CashFlowType.returnFlow ||
            cf.type == CashFlowType.income) {
          inflows += cf.amount;
        }
      }

      dailyFlows.add(
        DailyCashFlow(
          dayOfWeek: current.weekday - 1, // 0=Monday
          date: current,
          outflows: outflows,
          inflows: inflows,
        ),
      );

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
      } else if (cf.type == CashFlowType.returnFlow ||
          cf.type == CashFlowType.income) {
        returned += cf.amount;
      }
    }

    return returned - invested;
  }
}
