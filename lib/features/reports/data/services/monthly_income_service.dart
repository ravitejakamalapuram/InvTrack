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

    // Optimization: Hoist invariant date boundary calculations outside the loop
    final startBoundary = monthStart.subtract(const Duration(days: 1));
    final endBoundary = monthEnd.add(const Duration(days: 1));

    // Optimization: Pre-compute dictionary comprehension to avoid O(N*M) nested iterations
    final investmentMap = {for (final inv in allInvestments) inv.id: inv};

    // Calculate totals by type
    double totalIncome = 0;
    double totalInvested = 0;
    double totalReturns = 0;
    double totalFees = 0;
    final Map<String, double> incomeByType = {};
    final List<IncomeTransaction> transactions = [];
    final investmentIncomeMap = <String, double>{};
    final investmentTypeMap = <String, String>{};

    // Optimization: Single pass loop replacing multiple sequential .where().toList() and .where() calls
    for (final cf in allCashFlows) {
      if (cf.date.isAfter(startBoundary) && cf.date.isBefore(endBoundary)) {
        switch (cf.type) {
          case CashFlowType.income:
            // Find investment name
            final investment = investmentMap[cf.investmentId];
            if (investment == null) continue; // Fallback for invalid references

            totalIncome += cf.amount;
            // Group by notes (type) if available
            final type = (cf.notes == null || cf.notes!.isEmpty)
                ? 'Other'
                : cf.notes!;
            incomeByType[type] = (incomeByType[type] ?? 0) + cf.amount;

            transactions.add(
              IncomeTransaction(
                id: cf.id,
                investmentName: investment.name,
                date: cf.date,
                amount: cf.amount,
                currency: cf.currency,
                type: type,
                note: cf.notes,
              ),
            );

            // Calculate top earners (investments with most income)
            investmentIncomeMap[cf.investmentId] =
                (investmentIncomeMap[cf.investmentId] ?? 0) + cf.amount;
            investmentTypeMap[cf.investmentId] = type;
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
    }

    // ⚡ Bolt: Maintain a bounded list of top 5 earners to avoid O(N log N) sorting
    final topEarners = <InvestmentWithIncome>[];

    for (final e in investmentIncomeMap.entries) {
      final investment = investmentMap[e.key];
      if (investment == null) continue;

      final income = e.value;
      if (topEarners.length < 5) {
        topEarners.add(
          InvestmentWithIncome(
            investment: investment,
            income: income,
            incomeType: investmentTypeMap[e.key] ?? 'Other',
          ),
        );
        topEarners.sort((a, b) => b.income.compareTo(a.income));
      } else if (income > topEarners.last.income) {
        topEarners[4] = InvestmentWithIncome(
          investment: investment,
          income: income,
          incomeType: investmentTypeMap[e.key] ?? 'Other',
        );
        topEarners.sort((a, b) => b.income.compareTo(a.income));
      }
    }

    return MonthlyIncomeReport(
      period: monthStart,
      totalIncome: totalIncome,
      totalInvested: totalInvested,
      totalReturns: totalReturns,
      totalFees: totalFees,
      netCashFlow: (totalIncome + totalReturns) - (totalInvested + totalFees),
      incomeByType: incomeByType,
      topEarners: topEarners,
      transactions: transactions..sort((a, b) => b.date.compareTo(a.date)),
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
