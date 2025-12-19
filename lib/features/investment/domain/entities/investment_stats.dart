import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Investment statistics for display.
/// Contains calculated metrics like returns, MOIC, and XIRR.
class InvestmentStats {
  /// Sum of INVEST + FEE (money out)
  final double totalInvested;

  /// Sum of RETURN + INCOME (money in)
  final double totalReturned;

  /// Net cash flow (Returned - Invested)
  final double netCashFlow;

  /// Percentage return on investment
  final double absoluteReturn;

  /// Multiple on Invested Capital
  final double moic;

  /// Annualized return (XIRR)
  final double xirr;

  /// Number of cash flow transactions
  final int cashFlowCount;

  /// Date of the first cash flow
  final DateTime? firstCashFlowDate;

  /// Date of the most recent cash flow
  final DateTime? lastCashFlowDate;

  const InvestmentStats({
    required this.totalInvested,
    required this.totalReturned,
    required this.netCashFlow,
    required this.absoluteReturn,
    required this.moic,
    required this.xirr,
    required this.cashFlowCount,
    this.firstCashFlowDate,
    this.lastCashFlowDate,
  });

  /// Creates an empty stats object with all values set to zero
  factory InvestmentStats.empty() => const InvestmentStats(
        totalInvested: 0,
        totalReturned: 0,
        netCashFlow: 0,
        absoluteReturn: 0,
        moic: 0,
        xirr: 0,
        cashFlowCount: 0,
      );

  /// Returns true if there is at least one cash flow
  bool get hasData => cashFlowCount > 0;

  /// Returns true if net cash flow is positive
  bool get isProfit => netCashFlow > 0;

  /// Returns true if net cash flow is negative
  bool get isLoss => netCashFlow < 0;
}

/// Monthly cash flow data for trend visualization.
class MonthlyCashFlowData {
  final DateTime month;
  final double inflows;
  final double outflows;

  const MonthlyCashFlowData({
    required this.month,
    required this.inflows,
    required this.outflows,
  });

  /// Net cash flow for the month (inflows - outflows)
  double get net => inflows - outflows;
}

/// Investment type distribution for portfolio breakdown.
class TypeDistribution {
  final InvestmentType type;
  final double totalInvested;
  final int count;

  const TypeDistribution({
    required this.type,
    required this.totalInvested,
    required this.count,
  });
}

/// Year-over-Year comparison statistics.
class YoYComparison {
  final double thisYearNet;
  final double lastYearNet;
  final double thisYearInvested;
  final double lastYearInvested;
  final double thisYearReturned;
  final double lastYearReturned;

  const YoYComparison({
    required this.thisYearNet,
    required this.lastYearNet,
    required this.thisYearInvested,
    required this.lastYearInvested,
    required this.thisYearReturned,
    required this.lastYearReturned,
  });

  /// Percentage change in net position year-over-year
  double get netChange =>
      lastYearNet != 0 ? ((thisYearNet - lastYearNet) / lastYearNet.abs()) * 100 : 0;

  /// Returns true if this year's net is better than last year's
  bool get isImproved => thisYearNet > lastYearNet;
}

