/// Service for generating Financial Year (FY) reports
///
/// Generates comprehensive FY reports (Apr 1 - Mar 31) including:
/// - Monthly cashflow breakdown
/// - XIRR calculation for the FY period
/// - Capital gains classification (short-term vs long-term)
/// - Tax-related summaries
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/tax_and_basis_calculator.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';

/// Provider for FY report generation service
final fyReportServiceProvider = Provider((ref) {
  final engine = ref.watch(calculationEngineProvider);
  return FYReportService(engine);
});

/// Service to generate Financial Year reports
class FYReportService {
  final CalculationEngine _engine;

  FYReportService(this._engine);

  /// Generate FY report for a given FY year
  /// FY year is the year when FY starts (e.g., 2023 for FY 2023-24)
  Future<FYReport> generateReport({
    required int fyYear,
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
    required String baseCurrency,
  }) async {
    // FY period: Apr 1 of fyYear to Mar 31 of (fyYear+1)
    final fyStart = DateTime(fyYear, 4, 1);
    final fyEnd = DateTime(fyYear + 1, 3, 31, 23, 59, 59);
    final fyLabel = '$fyYear-${(fyYear + 1) % 100}';

    // Convert all cash flows to base currency
    final baseCashFlows = await _engine.currency.batchConvert(
      cashFlows: allCashFlows,
      baseCurrency: baseCurrency,
      fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
    );

    // Filter cashflows for this FY using the converted cashflows
    final fyCashFlows = baseCashFlows.where((cf) {
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

    final netCashFlow =
        (totalIncome + totalReturns) - (totalInvested + totalFees);

    // Calculate monthly breakdown
    final monthlyBreakdown = _calculateMonthlyBreakdown(fyCashFlows, fyYear);

    // Calculate XIRR for the FY period
    final xirr = _calculateFYXIRR(fyCashFlows, allInvestments, fyEnd);

    // Calculate capital gains (short-term vs long-term)
    final capitalGains = _calculateCapitalGains(
      fyCashFlows,
      allInvestments,
      fyEnd,
    );

    // Calculate top performers
    final topPerformers = _calculateTopPerformers(allInvestments, fyCashFlows);

    // Calculate portfolio values at start and end of FY
    final portfolioValueAtStart = _calculatePortfolioValue(
      allInvestments,
      baseCashFlows,
      fyStart,
    );
    final portfolioValueAtEnd = _calculatePortfolioValue(
      allInvestments,
      baseCashFlows,
      fyEnd,
    );

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
  Future<FYReport> getCurrentFY({
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
    required String baseCurrency,
  }) async {
    final now = DateTime.now();
    // Current FY is Apr 1 of current year if we're past April, else previous year
    final fyYear = now.month >= 4 ? now.year : now.year - 1;
    return generateReport(
      fyYear: fyYear,
      allCashFlows: allCashFlows,
      allInvestments: allInvestments,
      baseCurrency: baseCurrency,
    );
  }

  /// Get previous FY report
  Future<FYReport> getPreviousFY({
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
    required String baseCurrency,
  }) async {
    final now = DateTime.now();
    final currentFYYear = now.month >= 4 ? now.year : now.year - 1;
    return generateReport(
      fyYear: currentFYYear - 1,
      allCashFlows: allCashFlows,
      allInvestments: allInvestments,
      baseCurrency: baseCurrency,
    );
  }

  /// Calculate monthly breakdown for the FY
  List<MonthlyFYData> _calculateMonthlyBreakdown(
    List<CashFlowEntity> fyCashFlows,
    int fyYear,
  ) {
    final monthlyBuckets = TaxAndBasisCalculator.calculateMonthlyBuckets(
      fyCashFlows,
    );
    final breakdown = <MonthlyFYData>[];

    // Generate 12 months from Apr to Mar
    for (int i = 0; i < 12; i++) {
      final month = (4 + i) > 12 ? (4 + i) - 12 : (4 + i);
      final year = month < 4 ? fyYear + 1 : fyYear;

      final monthStart = DateTime(year, month, 1);
      final bucket = monthlyBuckets[monthStart] ?? const MonthlyBucket();

      breakdown.add(
        MonthlyFYData(
          month: month,
          year: year,
          invested: bucket.invested,
          returns: bucket.returns,
          income: bucket.income,
          fees: bucket.fees,
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
    final investmentStartDates = {
      for (final inv in allInvestments) inv.id: inv.startDate ?? inv.createdAt,
    };

    return TaxAndBasisCalculator.calculateCapitalGains(
      cashFlows: fyCashFlows,
      investmentStartDates: investmentStartDates,
      assumedGainPercentage: 0.10,
    );
  }

  /// Calculate top performers by returns and XIRR
  (List<InvestmentWithReturns>, List<InvestmentWithReturns>)
  _calculateTopPerformers(
    List<InvestmentEntity> allInvestments,
    List<CashFlowEntity> fyCashFlows,
  ) {
    final performers = <InvestmentWithReturns>[];

    // Optimization: Pre-group cashflows by investmentId for O(1) lookup
    final cashFlowsByInvestment = <String, List<CashFlowEntity>>{};
    for (final cf in fyCashFlows) {
      (cashFlowsByInvestment[cf.investmentId] ??= []).add(cf);
    }

    for (final investment in allInvestments) {
      // Get cashflows for this investment
      final investmentCFs = cashFlowsByInvestment[investment.id] ?? [];

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
  /// Calculates outstanding cost basis by summing all investments (outflows)
  /// minus partial exits (inflows) up to the specified date, converted to base currency.
  double _calculatePortfolioValue(
    List<InvestmentEntity> allInvestments,
    List<CashFlowEntity> allCashFlows,
    DateTime date,
  ) {
    double totalValue = 0.0;

    // Optimization: Group cash flows by investment ID to change O(N*M) nested loop into O(N+M)
    final cashFlowsByInvestment = <String, List<CashFlowEntity>>{};
    for (final cf in allCashFlows) {
      (cashFlowsByInvestment[cf.investmentId] ??= []).add(cf);
    }

    final dateLimit = date.add(const Duration(days: 1));

    for (final investment in allInvestments) {
      final startDate = investment.startDate ?? investment.createdAt;

      // Only count investments that existed at this date
      if (startDate.isBefore(dateLimit)) {
        // If investment was closed before this date, value is 0
        if (investment.closedAt != null &&
            investment.closedAt!.isBefore(date)) {
          continue;
        }

        // Get cash flows for this investment up to the given date
        final allInvestmentFlows = cashFlowsByInvestment[investment.id] ?? [];
        final investmentFlows = <CashFlowEntity>[];
        for (final cf in allInvestmentFlows) {
          if (cf.date.isBefore(dateLimit)) {
            investmentFlows.add(cf);
          }
        }

        double invested = 0.0;
        double returned = 0.0;

        for (final cf in investmentFlows) {
          final convertedAmount = cf.amount;

          if (cf.type.isOutflow) {
            invested += convertedAmount;
          } else if (cf.type == CashFlowType.returnFlow) {
            returned += convertedAmount;
          }
        }

        final netValue = invested - returned;
        if (netValue > 0) {
          totalValue += netValue;
        }
      }
    }

    return totalValue;
  }
}
