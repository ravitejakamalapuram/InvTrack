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
    final startBound = periodStart.subtract(const Duration(days: 1));
    final endBound = periodEnd.add(const Duration(days: 1));

    // Optimization: Single pass loop for week cashflows and multiple metrics replacing sequential .where().toList() calls
    double invested = 0;
    double returned = 0;
    double income = 0;

    final weekCashFlows = <CashFlowEntity>[];

    for (final cf in allCashFlows) {
      if (cf.date.isAfter(startBound) && cf.date.isBefore(endBound)) {
        weekCashFlows.add(cf);
        if (cf.type == CashFlowType.invest) {
          invested += cf.amount;
        } else if (cf.type == CashFlowType.returnFlow) {
          returned += cf.amount;
        } else if (cf.type == CashFlowType.income) {
          income += cf.amount;
        }
      }
    }

    // Calculate totals
    final netPosition = (returned + income) - invested;

    // Optimization: Single pass loop for investments and multiple metrics replacing sequential .where().toList() calls
    final newInvestments = <InvestmentEntity>[];
    final upcomingMaturities = <InvestmentEntity>[];
    InvestmentEntity? topPerformer;
    double? topXirr;

    final nextWeekEnd = periodEnd.add(const Duration(days: 7));
    final nextWeekEndBound = nextWeekEnd.add(const Duration(days: 1));

    for (final inv in allInvestments) {
      // Find new investments created this week
      if (inv.createdAt.isAfter(startBound) &&
          inv.createdAt.isBefore(endBound)) {
        newInvestments.add(inv);
      }

      if (inv.isOpen) {
        // Find upcoming maturities (next 7 days)
        if (inv.maturityDate != null &&
            inv.maturityDate!.isAfter(periodEnd) &&
            inv.maturityDate!.isBefore(nextWeekEndBound)) {
          upcomingMaturities.add(inv);
        }

        // Find top performer by XIRR
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

    // Calculate previous week's net position (optional)
    final prevWeekStart = periodStart.subtract(const Duration(days: 7));
    final prevWeekEnd = periodStart.subtract(const Duration(days: 1));
    final prevWeekStartBound = prevWeekStart.subtract(const Duration(days: 1));
    final prevWeekEndBound = prevWeekEnd.add(const Duration(days: 1));

    // Optimization: Replace .where().toList() with standard loop and calculate net position simultaneously
    double prevInvested = 0;
    double prevReturned = 0;
    double prevIncome = 0;

    for (final cf in allCashFlows) {
      if (cf.date.isAfter(prevWeekStartBound) &&
          cf.date.isBefore(prevWeekEndBound)) {
        if (cf.type == CashFlowType.invest) {
          prevInvested += cf.amount;
        } else if (cf.type == CashFlowType.returnFlow) {
          prevReturned += cf.amount;
        } else if (cf.type == CashFlowType.income) {
          prevIncome += cf.amount;
        }
      }
    }

    final prevWeekNet = (prevReturned + prevIncome) - prevInvested;

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

    final endBound = end.add(const Duration(days: 1));

    while (current.isBefore(endBound)) {
      // Optimization: Replace multiple sequential .where() and .fold() calls with standard loop
      double outflows = 0;
      double inflows = 0;

      for (final cf in cashFlows) {
        if (cf.date.year == current.year &&
            cf.date.month == current.month &&
            cf.date.day == current.day) {
          if (cf.type == CashFlowType.invest || cf.type == CashFlowType.fee) {
            outflows += cf.amount;
          } else if (cf.type == CashFlowType.returnFlow ||
              cf.type == CashFlowType.income) {
            inflows += cf.amount;
          }
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
}
