/// Service for generating monthly income and cashflow reports
///
/// Aggregates all income transactions and cashflows for a given month
/// to provide tax planning and record-keeping insights.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/domain/entities/monthly_income_report.dart';

/// Provider for monthly income report generation service
final monthlyIncomeServiceProvider = Provider((ref) {
  return MonthlyIncomeService();
});

/// Service to generate monthly income reports
class MonthlyIncomeService {
  /// Generate monthly income report for a given period
  MonthlyIncomeReport generateReport({
    required DateTime period,
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
  }) {
    // Normalize period to start of month
    final monthStart = DateTime(period.year, period.month, 1);
    final monthEnd = DateTime(period.year, period.month + 1, 0);

    // Filter cashflows for this month
    final monthCashFlows = allCashFlows.where((cf) {
      return cf.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          cf.date.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();

    // Calculate totals by type
    double totalIncome = 0;
    double totalInvested = 0;
    double totalReturns = 0;
    double totalFees = 0;
    final Map<String, double> incomeByType = {};
    final List<IncomeTransaction> transactions = [];

    for (final cf in monthCashFlows) {
      switch (cf.type) {
        case CashFlowType.income:
          totalIncome += cf.amount;
          // Group by notes (type) if available
          final type = (cf.notes == null || cf.notes!.isEmpty) ? 'Other' : cf.notes!;
          incomeByType[type] = (incomeByType[type] ?? 0) + cf.amount;

          // Find investment name
          final investment =
              allInvestments.firstWhere((inv) => inv.id == cf.investmentId);
          transactions.add(
            IncomeTransaction(
              id: cf.id,
              investmentName: investment.name,
              date: cf.date,
              amount: cf.amount,
              type: type,
              note: cf.notes,
            ),
          );
          break;
        case CashFlowType.invest:
          totalInvested += cf.amount;
          break;
        case CashFlowType.returnFlow:
          totalReturns += cf.amount;
          break;
        case CashFlowType.fee:
          totalFees += cf.amount;
          break;
      }
    }

    // Calculate top earners (investments with most income)
    final investmentIncomeMap = <String, double>{};
    final investmentTypeMap = <String, String>{};

    for (final cf in monthCashFlows.where((cf) => cf.type == CashFlowType.income)) {
      investmentIncomeMap[cf.investmentId] =
          (investmentIncomeMap[cf.investmentId] ?? 0) + cf.amount;
      investmentTypeMap[cf.investmentId] =
          (cf.notes == null || cf.notes!.isEmpty) ? 'Other' : cf.notes!;
    }

    final topEarners = investmentIncomeMap.entries
        .map((e) {
          final investment =
              allInvestments.firstWhere((inv) => inv.id == e.key);
          return InvestmentWithIncome(
            investment: investment,
            income: e.value,
            incomeType: investmentTypeMap[e.key] ?? 'Other',
          );
        })
        .toList()
      ..sort((a, b) => b.income.compareTo(a.income));

    return MonthlyIncomeReport(
      period: monthStart,
      totalIncome: totalIncome,
      totalInvested: totalInvested,
      totalReturns: totalReturns,
      totalFees: totalFees,
      netCashFlow: (totalIncome + totalReturns) - (totalInvested + totalFees),
      incomeByType: incomeByType,
      topEarners: topEarners.take(5).toList(),
      transactions: transactions
        ..sort((a, b) => b.date.compareTo(a.date)),
    );
  }

  /// Get current month report
  MonthlyIncomeReport getCurrentMonth({
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
  }) {
    return generateReport(
      period: DateTime.now(),
      allCashFlows: allCashFlows,
      allInvestments: allInvestments,
    );
  }

  /// Get previous month report
  MonthlyIncomeReport getPreviousMonth({
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
  }) {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    return generateReport(
      period: previousMonth,
      allCashFlows: allCashFlows,
      allInvestments: allInvestments,
    );
  }
}
