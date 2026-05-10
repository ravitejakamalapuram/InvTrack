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

    // Optimization: Single pass loop for all cashflow metrics
    final weekCashFlows = <CashFlowEntity>[];
    double invested = 0;
    double returned = 0;
    double income = 0;

    double prevInvested = 0;
    double prevReturned = 0;

    final weekStartLimit = periodStart.subtract(const Duration(days: 1));
    final weekEndLimit = periodEnd.add(const Duration(days: 1));

    final prevWeekStartLimit = periodStart.subtract(const Duration(days: 8));
    final prevWeekEndLimit = periodStart;

    for (final cf in allCashFlows) {
      if (cf.date.isAfter(weekStartLimit) && cf.date.isBefore(weekEndLimit)) {
        weekCashFlows.add(cf);
        if (cf.type == CashFlowType.invest) {
          invested += cf.amount;
        } else if (cf.type == CashFlowType.returnFlow) {
          returned += cf.amount;
        } else if (cf.type == CashFlowType.income) {
          income += cf.amount;
        }
      }

      if (cf.date.isAfter(prevWeekStartLimit) && cf.date.isBefore(prevWeekEndLimit)) {
        if (cf.type == CashFlowType.invest) {
          prevInvested += cf.amount;
        } else if (cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income) {
          prevReturned += cf.amount;
        }
      }
    }

    final netPosition = (returned + income) - invested;
    final prevWeekNet = prevReturned - prevInvested;

    // Optimization: Single pass loop for all investment metrics
    final newInvestments = <InvestmentEntity>[];
    final upcomingMaturities = <InvestmentEntity>[];
    InvestmentEntity? topPerformer;
    double? topXirr;

    final nextWeekEndLimit = periodEnd.add(const Duration(days: 8));

    for (final inv in allInvestments) {
      if (inv.createdAt.isAfter(weekStartLimit) && inv.createdAt.isBefore(weekEndLimit)) {
        newInvestments.add(inv);
      }

      if (inv.isOpen) {
        if (inv.maturityDate != null &&
            inv.maturityDate!.isAfter(periodEnd) &&
            inv.maturityDate!.isBefore(nextWeekEndLimit)) {
          upcomingMaturities.add(inv);
        }

        final xirr = xirrMap[inv.id];
        if (xirr != null && (topXirr == null || xirr > topXirr)) {
          topXirr = xirr;
          topPerformer = inv;
        }
      }
    }

    // Generate daily cashflows for chart
    final dailyCashFlows = _generateDailyCashFlows(
      periodStart,
      periodEnd,
      weekCashFlows,
    );

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

    // Optimization: Pre-group cashflows by date to change O(D*N) to O(N+D)
    final flowMap = <String, List<CashFlowEntity>>{};
    for (final cf in cashFlows) {
      final key = '${cf.date.year}-${cf.date.month}-${cf.date.day}';
      flowMap.putIfAbsent(key, () => []).add(cf);
    }

    var current = start;
    final endLimit = end.add(const Duration(days: 1));

    while (current.isBefore(endLimit)) {
      final key = '${current.year}-${current.month}-${current.day}';
      final dayFlows = flowMap[key] ?? [];

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

}
