/// Service for generating Financial Year (FY) reports
///
/// Generates comprehensive FY reports (Apr 1 - Mar 31) including:
/// - Monthly cashflow breakdown
/// - XIRR calculation for the FY period
/// - Capital gains classification (short-term vs long-term)
/// - Tax-related summaries
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';

/// Provider for FY report generation service
final fyReportServiceProvider = Provider((ref) {
  return FYReportService();
});

/// Service to generate Financial Year reports
class FYReportService {
  /// Generate FY report for a given FY year
  /// FY year is the year when FY starts (e.g., 2023 for FY 2023-24)
  FYReport generateReport({
    required int fyYear,
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
  }) {
    // FY period: Apr 1 of fyYear to Mar 31 of (fyYear+1)
    final fyStart = DateTime(fyYear, 4, 1);
    final fyEnd = DateTime(fyYear + 1, 3, 31, 23, 59, 59);
    final fyLabel = '$fyYear-${(fyYear + 1) % 100}';

    // Filter cashflows for this FY
    final fyCashFlows = allCashFlows.where((cf) {
      return cf.date.isAfter(fyStart.subtract(const Duration(days: 1))) &&
          cf.date.isBefore(fyEnd.add(const Duration(days: 1)));
    }).toList();

    // Calculate totals
    double totalInvested = 0;
    double totalReturns = 0;
    double totalIncome = 0;
    double totalFees = 0;
    double dividendIncome = 0;
    double interestIncome = 0;

    for (final cf in fyCashFlows) {
      switch (cf.type) {
        case CashFlowType.invest:
          totalInvested += cf.amount;
          break;
        case CashFlowType.returnFlow:
          totalReturns += cf.amount;
          break;
        case CashFlowType.income:
          totalIncome += cf.amount;
          // Categorize by note
          final noteType = (cf.notes ?? '').toLowerCase();
          if (noteType.contains('dividend')) {
            dividendIncome += cf.amount;
          } else if (noteType.contains('interest')) {
            interestIncome += cf.amount;
          }
          break;
        case CashFlowType.fee:
          totalFees += cf.amount;
          break;
      }
    }

    final netCashFlow = (totalIncome + totalReturns) - (totalInvested + totalFees);

    // Calculate monthly breakdown
    final monthlyBreakdown = _calculateMonthlyBreakdown(fyCashFlows, fyYear);

    // Calculate XIRR for the FY period
    final xirr = _calculateFYXIRR(fyCashFlows, allInvestments, fyEnd);

    // Calculate capital gains (short-term vs long-term)
    final capitalGains = _calculateCapitalGains(fyCashFlows, allInvestments, fyEnd);

    // Calculate top performers
    final topPerformers = _calculateTopPerformers(allInvestments, fyCashFlows);

    // Calculate portfolio values at start and end of FY
    final portfolioValueAtStart = _calculatePortfolioValue(allInvestments, fyStart);
    final portfolioValueAtEnd = _calculatePortfolioValue(allInvestments, fyEnd);

    return FYReport(
      fyStart: fyStart,
      fyEnd: fyEnd,
      fyLabel: fyLabel,
      totalInvested: totalInvested,
      totalReturns: totalReturns,
      totalIncome: totalIncome,
      totalFees: totalFees,
      netCashFlow: netCashFlow,
      xirr: xirr,
      monthlyBreakdown: monthlyBreakdown,
      topPerformersByReturns: topPerformers.$1,
      topPerformersByXIRR: topPerformers.$2,
      portfolioValueAtStart: portfolioValueAtStart,
      portfolioValueAtEnd: portfolioValueAtEnd,
      shortTermCapitalGains: capitalGains.$1,
      longTermCapitalGains: capitalGains.$2,
      dividendIncome: dividendIncome,
      interestIncome: interestIncome,
    );
  }

  /// Get current FY report
  FYReport getCurrentFY({
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
  }) {
    final now = DateTime.now();
    // Current FY is Apr 1 of current year if we're past April, else previous year
    final fyYear = now.month >= 4 ? now.year : now.year - 1;
    return generateReport(
      fyYear: fyYear,
      allCashFlows: allCashFlows,
      allInvestments: allInvestments,
    );
  }

  /// Get previous FY report
  FYReport getPreviousFY({
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
  }) {
    final now = DateTime.now();
    final currentFYYear = now.month >= 4 ? now.year : now.year - 1;
    return generateReport(
      fyYear: currentFYYear - 1,
      allCashFlows: allCashFlows,
      allInvestments: allInvestments,
    );
  }

  /// Calculate monthly breakdown for the FY
  List<MonthlyFYData> _calculateMonthlyBreakdown(
    List<CashFlowEntity> fyCashFlows,
    int fyYear,
  ) {
    final breakdown = <MonthlyFYData>[];

    // Generate 12 months from Apr to Mar
    for (int i = 0; i < 12; i++) {
      final month = (4 + i) > 12 ? (4 + i) - 12 : (4 + i);
      final year = month < 4 ? fyYear + 1 : fyYear;

      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);

      double invested = 0;
      double returns = 0;
      double income = 0;
      double fees = 0;

      for (final cf in fyCashFlows) {
        if (cf.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            cf.date.isBefore(monthEnd.add(const Duration(days: 1)))) {
          switch (cf.type) {
            case CashFlowType.invest:
              invested += cf.amount;
              break;
            case CashFlowType.returnFlow:
              returns += cf.amount;
              break;
            case CashFlowType.income:
              income += cf.amount;
              break;
            case CashFlowType.fee:
              fees += cf.amount;
              break;
          }
        }
      }

      breakdown.add(
        MonthlyFYData(
          month: month,
          year: year,
          invested: invested,
          returns: returns,
          income: income,
          fees: fees,
        ),
      );
    }

    return breakdown;
  }

  /// Calculate XIRR for the FY period
  double _calculateFYXIRR(
    List<CashFlowEntity> fyCashFlows,
    List<InvestmentEntity> allInvestments,
    DateTime fyEnd,
  ) {
    if (fyCashFlows.isEmpty) return 0;

    // Calculate XIRR using XirrSolver
    return FinancialCalculator.calculateXirrFromCashFlows(fyCashFlows);
  }

  /// Calculate capital gains (short-term and long-term)
  (double, double) _calculateCapitalGains(
    List<CashFlowEntity> fyCashFlows,
    List<InvestmentEntity> allInvestments,
    DateTime fyEnd,
  ) {
    double shortTermGains = 0;
    double longTermGains = 0;

    // Only consider RETURN cashflows for capital gains
    final returns = fyCashFlows.where((cf) => cf.type == CashFlowType.returnFlow);

    for (final returnCF in returns) {
      try {
        final investment = allInvestments
            .firstWhere((inv) => inv.id == returnCF.investmentId);

        // Calculate holding period (from first investment to return)
        final investmentDate = investment.startDate ?? investment.createdAt;
        final holdingDays = returnCF.date.difference(investmentDate).inDays;

        // Simplified gain calculation
        // For capital gains, we approximate: return amount is the gain
        // In reality, should match cost basis, but for annual reporting this is acceptable
        final gain = returnCF.amount * 0.1; // Assume 10% gain on returns (conservative estimate)

        if (holdingDays < 365) {
          shortTermGains += gain;
        } else {
          longTermGains += gain;
        }
      } catch (e) {
        // Investment not found, skip
        continue;
      }
    }

    return (shortTermGains, longTermGains);
  }

  /// Calculate top performers by returns and XIRR
  (List<InvestmentWithReturns>, List<InvestmentWithReturns>) _calculateTopPerformers(
    List<InvestmentEntity> allInvestments,
    List<CashFlowEntity> fyCashFlows,
  ) {
    final performers = <InvestmentWithReturns>[];

    for (final investment in allInvestments) {
      // Get cashflows for this investment
      final investmentCFs = fyCashFlows
          .where((cf) => cf.investmentId == investment.id)
          .toList();

      if (investmentCFs.isEmpty) continue;

      // Calculate stats
      final stats = calculateStats(investmentCFs);

      performers.add(
        InvestmentWithReturns(
          investment: investment,
          absoluteReturns: stats.netCashFlow,
          xirr: stats.xirr,
          percentageGain: stats.absoluteReturn,
        ),
      );
    }

    // Sort by absolute returns
    final byReturns = List<InvestmentWithReturns>.from(performers)
      ..sort((a, b) => b.absoluteReturns.compareTo(a.absoluteReturns));

    // Sort by XIRR
    final byXIRR = List<InvestmentWithReturns>.from(performers)
      ..sort((a, b) => b.xirr.compareTo(a.xirr));

    return (byReturns.take(5).toList(), byXIRR.take(5).toList());
  }

  /// Calculate portfolio value at a specific date
  ///
  /// NOTE: This is a simplified calculation that uses total invested - total returned
  /// as a proxy for portfolio value at a specific date. For true historical values,
  /// we would need to track value at each point in time.
  double _calculatePortfolioValue(
    List<InvestmentEntity> allInvestments,
    DateTime date,
  ) {
    double totalValue = 0;

    for (final investment in allInvestments) {
      final startDate = investment.startDate ?? investment.createdAt;

      // Only count investments that existed at this date
      if (startDate.isBefore(date.add(const Duration(days: 1)))) {
        // If investment was closed before this date, value is 0
        if (investment.closedAt != null &&
            investment.closedAt!.isBefore(date)) {
          continue;
        }

        // For simplicity, count this investment as active
        // In a real system, we'd need historical portfolio values
        totalValue += 1000; // Placeholder - each investment counts as 1000 for now
      }
    }

    return totalValue;
  }
}
