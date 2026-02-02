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

  /// Duration in years from first to last cash flow (or to now if ongoing)
  double? get durationYears {
    if (firstCashFlowDate == null) return null;
    final endDate = lastCashFlowDate ?? DateTime.now();
    final days = endDate.difference(firstCashFlowDate!).inDays;
    return days / 365.0;
  }

  /// Formatted duration string (e.g., "2.3y" or "8mo")
  String? get durationFormatted {
    final years = durationYears;
    if (years == null) return null;
    if (years < 0.08) return '<1mo'; // Less than 1 month
    if (years < 1) return '${(years * 12).round()}mo';
    return '${years.toStringAsFixed(1)}y';
  }

  /// Creates a copy with the given fields replaced
  InvestmentStats copyWith({
    double? totalInvested,
    double? totalReturned,
    double? netCashFlow,
    double? absoluteReturn,
    double? moic,
    double? xirr,
    int? cashFlowCount,
    DateTime? firstCashFlowDate,
    DateTime? lastCashFlowDate,
  }) {
    return InvestmentStats(
      totalInvested: totalInvested ?? this.totalInvested,
      totalReturned: totalReturned ?? this.totalReturned,
      netCashFlow: netCashFlow ?? this.netCashFlow,
      absoluteReturn: absoluteReturn ?? this.absoluteReturn,
      moic: moic ?? this.moic,
      xirr: xirr ?? this.xirr,
      cashFlowCount: cashFlowCount ?? this.cashFlowCount,
      firstCashFlowDate: firstCashFlowDate ?? this.firstCashFlowDate,
      lastCashFlowDate: lastCashFlowDate ?? this.lastCashFlowDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InvestmentStats &&
        other.totalInvested == totalInvested &&
        other.totalReturned == totalReturned &&
        other.netCashFlow == netCashFlow &&
        other.absoluteReturn == absoluteReturn &&
        other.moic == moic &&
        other.xirr == xirr &&
        other.cashFlowCount == cashFlowCount &&
        other.firstCashFlowDate == firstCashFlowDate &&
        other.lastCashFlowDate == lastCashFlowDate;
  }

  @override
  int get hashCode {
    return totalInvested.hashCode ^
        totalReturned.hashCode ^
        netCashFlow.hashCode ^
        absoluteReturn.hashCode ^
        moic.hashCode ^
        xirr.hashCode ^
        cashFlowCount.hashCode ^
        firstCashFlowDate.hashCode ^
        lastCashFlowDate.hashCode;
  }
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

  /// Creates a copy with the given fields replaced
  MonthlyCashFlowData copyWith({
    DateTime? month,
    double? inflows,
    double? outflows,
  }) {
    return MonthlyCashFlowData(
      month: month ?? this.month,
      inflows: inflows ?? this.inflows,
      outflows: outflows ?? this.outflows,
    );
  }
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

  /// Creates a copy with the given fields replaced
  TypeDistribution copyWith({
    InvestmentType? type,
    double? totalInvested,
    int? count,
  }) {
    return TypeDistribution(
      type: type ?? this.type,
      totalInvested: totalInvested ?? this.totalInvested,
      count: count ?? this.count,
    );
  }
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
  double get netChange => lastYearNet != 0
      ? ((thisYearNet - lastYearNet) / lastYearNet.abs()) * 100
      : 0;

  /// Returns true if this year's net is better than last year's
  bool get isImproved => thisYearNet > lastYearNet;

  /// Creates a copy with the given fields replaced
  YoYComparison copyWith({
    double? thisYearNet,
    double? lastYearNet,
    double? thisYearInvested,
    double? lastYearInvested,
    double? thisYearReturned,
    double? lastYearReturned,
  }) {
    return YoYComparison(
      thisYearNet: thisYearNet ?? this.thisYearNet,
      lastYearNet: lastYearNet ?? this.lastYearNet,
      thisYearInvested: thisYearInvested ?? this.thisYearInvested,
      lastYearInvested: lastYearInvested ?? this.lastYearInvested,
      thisYearReturned: thisYearReturned ?? this.thisYearReturned,
      lastYearReturned: lastYearReturned ?? this.lastYearReturned,
    );
  }
}
