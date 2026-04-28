/// Monthly income and cash flow report entity
///
/// Provides a detailed summary of all income-generating investments and cashflow
/// activity for a given month. Used for tax planning and record-keeping.
library;

import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Monthly income report
class MonthlyIncomeReport {
  /// Report period (year-month)
  final DateTime period;

  /// Total income received (INCOME flows only)
  final double totalIncome;

  /// Total invested this month (INVEST flows)
  final double totalInvested;

  /// Total returns this month (RETURN flows)
  final double totalReturns;

  /// Total fees paid this month (FEE flows)
  final double totalFees;

  /// Net cashflow (income + returns - invested - fees)
  final double netCashFlow;

  /// Income by type (Dividend, Interest, Rent, etc.)
  final Map<String, double> incomeByType;

  /// Top income-generating investments
  final List<InvestmentWithIncome> topEarners;

  /// All income transactions for the month
  final List<IncomeTransaction> transactions;

  const MonthlyIncomeReport({
    required this.period,
    required this.totalIncome,
    required this.totalInvested,
    required this.totalReturns,
    required this.totalFees,
    required this.netCashFlow,
    required this.incomeByType,
    required this.topEarners,
    required this.transactions,
  });

  /// Empty report for initial state
  factory MonthlyIncomeReport.empty(DateTime period) {
    return MonthlyIncomeReport(
      period: period,
      totalIncome: 0,
      totalInvested: 0,
      totalReturns: 0,
      totalFees: 0,
      netCashFlow: 0,
      incomeByType: const {},
      topEarners: const [],
      transactions: const [],
    );
  }

  /// Whether this month had positive cashflow
  bool get isPositiveMonth => netCashFlow > 0;

  /// Whether this month had any income
  bool get hasIncome => totalIncome > 0;

  /// Month name (e.g., "January 2024")
  String monthName() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[period.month - 1]} ${period.year}';
  }
}

/// Investment with income details
class InvestmentWithIncome {
  /// Investment entity
  final InvestmentEntity investment;

  /// Total income from this investment this month
  final double income;

  /// Income type (Dividend, Interest, Rent, etc.)
  final String incomeType;

  const InvestmentWithIncome({
    required this.investment,
    required this.income,
    required this.incomeType,
  });
}

/// Income transaction for display
class IncomeTransaction {
  /// Transaction ID
  final String id;

  /// Investment name
  final String investmentName;

  /// Transaction date
  final DateTime date;

  /// Amount
  final double amount;

  /// Income type (Dividend, Interest, Rent, etc.)
  final String type;

  /// Optional note
  final String? note;

  const IncomeTransaction({
    required this.id,
    required this.investmentName,
    required this.date,
    required this.amount,
    required this.type,
    this.note,
  });
}
