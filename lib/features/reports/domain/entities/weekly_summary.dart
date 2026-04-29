/// Weekly investment summary report entity
///
/// Provides a snapshot of investment activity for a given week (Monday-Sunday).
/// Includes cashflow totals, top performers, new investments, and upcoming maturities.
library;

import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Weekly investment summary report
class WeeklySummary {
  /// Report period start date (Monday)
  final DateTime periodStart;

  /// Report period end date (Sunday)
  final DateTime periodEnd;

  /// Total amount invested this week (INVEST flows)
  final double totalInvested;

  /// Total returns this week (RETURN + INCOME flows)
  final double totalReturns;

  /// Net position change (totalReturns - totalInvested)
  final double netPosition;

  /// Total income received (INCOME flows only)
  final double totalIncome;

  /// Top performing investment by XIRR
  final InvestmentEntity? topPerformer;

  /// XIRR of top performer
  final double? topPerformerXirr;

  /// New investments created this week
  final List<InvestmentEntity> newInvestments;

  /// Investments maturing next week (within 7 days)
  final List<InvestmentEntity> upcomingMaturities;

  /// Daily cashflow breakdown for chart (Mon-Sun)
  final List<DailyCashFlow> dailyCashFlows;

  /// Week-over-week comparison (previous week's net position)
  final double? previousWeekNet;

  const WeeklySummary({
    required this.periodStart,
    required this.periodEnd,
    required this.totalInvested,
    required this.totalReturns,
    required this.netPosition,
    required this.totalIncome,
    this.topPerformer,
    this.topPerformerXirr,
    required this.newInvestments,
    required this.upcomingMaturities,
    required this.dailyCashFlows,
    this.previousWeekNet,
  });

  /// Empty summary for initial state
  factory WeeklySummary.empty(DateTime start, DateTime end) {
    return WeeklySummary(
      periodStart: start,
      periodEnd: end,
      totalInvested: 0,
      totalReturns: 0,
      netPosition: 0,
      totalIncome: 0,
      newInvestments: const [],
      upcomingMaturities: const [],
      dailyCashFlows: const [],
    );
  }

  /// Calculate week-over-week change percentage
  double? get weekOverWeekChange {
    if (previousWeekNet == null || previousWeekNet == 0) return null;
    return ((netPosition - previousWeekNet!) / previousWeekNet!.abs()) * 100;
  }

  /// Whether this week had net positive cashflow
  bool get isPositiveWeek => netPosition > 0;

  /// Total number of action items (new investments + maturities)
  int get actionItemsCount =>
      newInvestments.length + upcomingMaturities.length;
}

/// Daily cashflow data for chart visualization
class DailyCashFlow {
  /// Day of week (0=Monday, 6=Sunday)
  final int dayOfWeek;

  /// Date
  final DateTime date;

  /// Total outflows (INVEST + FEE)
  final double outflows;

  /// Total inflows (RETURN + INCOME)
  final double inflows;

  const DailyCashFlow({
    required this.dayOfWeek,
    required this.date,
    required this.outflows,
    required this.inflows,
  });

  /// Net cashflow for the day
  double get net => inflows - outflows;
}
