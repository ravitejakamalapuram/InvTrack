/// Financial Year Report Entity
///
/// Represents a comprehensive FY (Apr 1 - Mar 31) summary including:
/// - Total invested, returns, income, fees across the full year
/// - Month-by-month breakdown for trend analysis
/// - XIRR calculation for the FY period
/// - Top performers by absolute returns and XIRR
/// - Tax-related summaries (capital gains, dividend income)
library;

import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Financial year report for Apr 1 - Mar 31 period
class FYReport {
  /// Start of FY (Apr 1)
  final DateTime fyStart;

  /// End of FY (Mar 31)
  final DateTime fyEnd;

  /// FY identifier (e.g., "2023-24")
  final String fyLabel;

  /// Total amount invested during the FY
  final double totalInvested;

  /// Total returns/exits during the FY
  final double totalReturns;

  /// Total income (dividends, interest) during the FY
  final double totalIncome;

  /// Total fees paid during the FY
  final double totalFees;

  /// Net cashflow for the FY (income + returns - invested - fees)
  final double netCashFlow;

  /// XIRR for the entire FY period
  final double xirr;

  /// Monthly breakdown of cashflows
  final List<MonthlyFYData> monthlyBreakdown;

  /// Top performing investments by absolute returns
  final List<InvestmentWithReturns> topPerformersByReturns;

  /// Top performing investments by XIRR
  final List<InvestmentWithReturns> topPerformersByXIRR;

  /// Portfolio value at start of FY
  final double portfolioValueAtStart;

  /// Portfolio value at end of FY
  final double portfolioValueAtEnd;

  /// Short-term capital gains (assets held < 1 year)
  final double shortTermCapitalGains;

  /// Long-term capital gains (assets held >= 1 year)
  final double longTermCapitalGains;

  /// Total dividend income for tax purposes
  final double dividendIncome;

  /// Total interest income for tax purposes
  final double interestIncome;

  const FYReport({
    required this.fyStart,
    required this.fyEnd,
    required this.fyLabel,
    required this.totalInvested,
    required this.totalReturns,
    required this.totalIncome,
    required this.totalFees,
    required this.netCashFlow,
    required this.xirr,
    required this.monthlyBreakdown,
    required this.topPerformersByReturns,
    required this.topPerformersByXIRR,
    required this.portfolioValueAtStart,
    required this.portfolioValueAtEnd,
    required this.shortTermCapitalGains,
    required this.longTermCapitalGains,
    required this.dividendIncome,
    required this.interestIncome,
  });

  /// Portfolio growth percentage for the FY
  double get portfolioGrowth {
    if (portfolioValueAtStart == 0) return 0;
    return ((portfolioValueAtEnd - portfolioValueAtStart) /
            portfolioValueAtStart) *
        100;
  }

  /// Total capital gains (short-term + long-term)
  double get totalCapitalGains =>
      shortTermCapitalGains + longTermCapitalGains;

  /// Total taxable income (dividends + interest + capital gains)
  double get totalTaxableIncome =>
      dividendIncome + interestIncome + totalCapitalGains;

  /// Returns true if this was a profitable year
  bool get isProfitable => netCashFlow > 0;
}

/// Monthly data for FY breakdown
class MonthlyFYData {
  /// Month (1-12, where 4=Apr, 3=Mar)
  final int month;

  /// Year
  final int year;

  /// Total invested in this month
  final double invested;

  /// Total returns in this month
  final double returns;

  /// Total income in this month
  final double income;

  /// Total fees in this month
  final double fees;

  const MonthlyFYData({
    required this.month,
    required this.year,
    required this.invested,
    required this.returns,
    required this.income,
    required this.fees,
  });

  /// Net cashflow for the month
  double get net => (income + returns) - (invested + fees);

  /// Month name abbreviation (Apr, May, Jun, ...)
  String get monthName {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}

/// Investment with returns data for top performers
class InvestmentWithReturns {
  final InvestmentEntity investment;
  final double absoluteReturns;
  final double xirr;
  final double percentageGain;

  const InvestmentWithReturns({
    required this.investment,
    required this.absoluteReturns,
    required this.xirr,
    required this.percentageGain,
  });
}
