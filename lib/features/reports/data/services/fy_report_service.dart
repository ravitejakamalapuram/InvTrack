/// Service for generating Financial Year (FY) reports
///
/// Generates comprehensive FY reports (Apr 1 - Mar 31) including:
/// - Monthly cashflow breakdown
/// - XIRR calculation for the FY period
/// - Realised profit on maturity or exit, reported as interest/income (no
///   capital gains are reported: the data cannot prove a sale)
/// - Tax-related summaries
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/calculations/tax_and_basis_calculator.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
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
    Map<String, double>? openingValues,
    Map<String, double>? closingValues,
  }) async {
    // FY period is the half-open range [1 Apr fyYear, 1 Apr fyYear+1) on
    // date-only values. [fyEnd] is kept as the last instant of 31 Mar for
    // display; every comparison uses [fyEndExclusive].
    final fyStart = DateTime(fyYear, 4, 1);
    final fyEndExclusive = DateTime(fyYear + 1, 4, 1);
    final fyEnd = DateTime(fyYear + 1, 3, 31, 23, 59, 59);
    final fyLabel = '$fyYear-${(fyYear + 1) % 100}';

    // Convert all cash flows to base currency; a flow with no rate is left
    // out rather than summed in its own currency.
    final baseCashFlows = await _engine.currency.batchConvertToBase(
      cashFlows: allCashFlows,
      baseCurrency: baseCurrency,
    );

    // Calculate totals
    double totalInvested = 0;
    double totalReturns = 0;
    double totalIncome = 0;
    double totalFees = 0;
    double dividendIncome = 0;
    double interestIncome = 0;

    // ⚡ Bolt: Single pass loop replacing .where().toList() to avoid intermediate array allocation
    final fyCashFlows = <CashFlowEntity>[];

    for (final cf in baseCashFlows) {
      if (_inFY(cf.date, fyStart, fyEndExclusive)) {
        fyCashFlows.add(cf);
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
    }

    final netCashFlow =
        (totalIncome + totalReturns) - (totalInvested + totalFees);

    // Calculate monthly breakdown
    final monthlyBreakdown = _calculateMonthlyBreakdown(fyCashFlows, fyYear);

    // Calculate XIRR for the FY period
    final xirr = _calculateFYXIRR(
      fyCashFlows: fyCashFlows,
      baseCashFlows: baseCashFlows,
      allInvestments: allInvestments,
      fyStart: fyStart,
      fyEndExclusive: fyEndExclusive,
      openingValues: openingValues,
      closingValues: closingValues,
    );

    // Profit realised on maturity or exit is interest/income at slab rates.
    // Capital gains need a proven sale with its own cost and holding period,
    // which the cash-flow model cannot show, so none are reported.
    final realisedProfit = _realisedProfitInFY(
      baseCashFlows,
      fyStart,
      fyEndExclusive,
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
      fyEndExclusive,
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
      shortTermCapitalGains: 0,
      longTermCapitalGains: 0,
      dividendIncome: dividendIncome,
      interestIncome: interestIncome + realisedProfit,
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

  /// Whether [date] falls in the half-open range [start, endExclusive).
  static bool _inFY(DateTime date, DateTime start, DateTime endExclusive) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  /// Net cost still held per investment, counting only flows dated before
  /// [limit]. Only investments with a positive balance are returned.
  Map<String, double> _heldBefore(
    List<CashFlowEntity> baseCashFlows,
    DateTime limit,
  ) {
    final net = <String, double>{};
    for (final cf in baseCashFlows) {
      if (!_inFY(cf.date, DateTime(1900), limit)) continue;
      if (cf.type == CashFlowType.invest) {
        net[cf.investmentId] = (net[cf.investmentId] ?? 0) + cf.amount;
      } else if (cf.type == CashFlowType.returnFlow) {
        net[cf.investmentId] = (net[cf.investmentId] ?? 0) - cf.amount;
      }
    }
    net.removeWhere((_, v) => v <= 0);
    return net;
  }

  /// FY XIRR, or null when it is undefined or cannot be proven.
  ///
  /// The opening value is an outflow on the FY start and the closing value
  /// an inflow on the next 1 April (a full year is then 365 days). An
  /// investment still held at either edge needs a value there; without one
  /// the rate is unknown, so the result is null rather than a rate that
  /// ignores the money already in the investment.
  double? _calculateFYXIRR({
    required List<CashFlowEntity> fyCashFlows,
    required List<CashFlowEntity> baseCashFlows,
    required List<InvestmentEntity> allInvestments,
    required DateTime fyStart,
    required DateTime fyEndExclusive,
    required Map<String, double>? openingValues,
    required Map<String, double>? closingValues,
  }) {
    final opening = openingValues ?? const <String, double>{};
    final closing = closingValues ?? const <String, double>{};

    final heldAtStart = _heldBefore(baseCashFlows, fyStart);
    final heldAtEnd = _heldBefore(baseCashFlows, fyEndExclusive);
    if (heldAtStart.keys.any((id) => !opening.containsKey(id))) return null;
    if (heldAtEnd.keys.any((id) => !closing.containsKey(id))) return null;

    final dates = <DateTime>[];
    final amounts = <double>[];
    final openingTotal = opening.values.fold<double>(0, (a, b) => a + b);
    final closingTotal = closing.values.fold<double>(0, (a, b) => a + b);
    if (openingTotal > 0) {
      dates.add(fyStart);
      amounts.add(-openingTotal);
    }
    for (final cf in fyCashFlows) {
      dates.add(cf.date);
      amounts.add(cf.signedAmount);
    }
    if (closingTotal > 0) {
      dates.add(fyEndExclusive);
      amounts.add(closingTotal);
    }
    if (dates.isEmpty) return null;

    return XirrSolver.calculateXirr(dates, amounts);
  }

  /// Profit realised in the FY: for each investment, returns beyond the
  /// money put in (cost is recovered first), less what was realised before
  /// the FY. A loss is not income, so it is floored at zero.
  double _realisedProfitInFY(
    List<CashFlowEntity> baseCashFlows,
    DateTime fyStart,
    DateTime fyEndExclusive,
  ) {
    final atStart = <String, double>{};
    final atEnd = <String, double>{};
    void add(Map<String, double> m, CashFlowEntity cf) {
      m[cf.investmentId] =
          (m[cf.investmentId] ?? 0) +
          (cf.type == CashFlowType.returnFlow ? cf.amount : -cf.amount);
    }

    for (final cf in baseCashFlows) {
      if (cf.type != CashFlowType.invest &&
          cf.type != CashFlowType.returnFlow) {
        continue;
      }
      final day = DateTime(cf.date.year, cf.date.month, cf.date.day);
      if (day.isBefore(fyStart)) add(atStart, cf);
      if (day.isBefore(fyEndExclusive)) add(atEnd, cf);
    }

    double total = 0;
    for (final entry in atEnd.entries) {
      final gainEnd = entry.value > 0 ? entry.value : 0.0;
      final startNet = atStart[entry.key] ?? 0;
      final gainStart = startNet > 0 ? startNet : 0.0;
      final fyGain = gainEnd - gainStart;
      if (fyGain > 0) total += fyGain;
    }
    return total;
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

      // An open investment still awaiting a value has no return to rank
      // (money rule 4); a cash-only "so far" return is a minimum and stays.
      if (investment.isOpen && stats.awaitsValue) continue;

      performers.add(
        InvestmentWithReturns(
          investment: investment,
          absoluteReturns: stats.netCashFlow,
          xirr: stats.xirr,
          percentageGain: stats.absoluteReturn,
        ),
      );
    }

    // Optimization: Use a single-pass O(N) bounded list instead of O(N log N) sorting
    // to extract the top 5 elements.
    final topByReturns = <InvestmentWithReturns>[];
    final topByXIRR = <InvestmentWithReturns>[];

    for (final p in performers) {
      if (topByReturns.length < 5) {
        topByReturns.add(p);
        topByReturns.sort(
          (a, b) => b.absoluteReturns.compareTo(a.absoluteReturns),
        );
      } else if (p.absoluteReturns > topByReturns.last.absoluteReturns) {
        topByReturns.removeLast();
        topByReturns.add(p);
        topByReturns.sort(
          (a, b) => b.absoluteReturns.compareTo(a.absoluteReturns),
        );
      }

      // An undefined XIRR is not ranked: it is not 0%.
      final xirr = p.xirr;
      if (xirr == null) continue;
      if (topByXIRR.length < 5) {
        topByXIRR.add(p);
        topByXIRR.sort((a, b) => b.xirr!.compareTo(a.xirr!));
      } else if (xirr > topByXIRR.last.xirr!) {
        topByXIRR.removeLast();
        topByXIRR.add(p);
        topByXIRR.sort((a, b) => b.xirr!.compareTo(a.xirr!));
      }
    }

    return (topByReturns, topByXIRR);
  }

  /// Calculate portfolio value before an exclusive date limit
  ///
  /// Calculates outstanding cost basis by summing all investments (outflows)
  /// minus partial exits (inflows) up to the specified date, converted to base currency.
  double _calculatePortfolioValue(
    List<InvestmentEntity> allInvestments,
    List<CashFlowEntity> allCashFlows,
    DateTime dateLimit,
  ) {
    double totalValue = 0.0;

    // Optimization: Group cash flows by investment ID to change O(N*M) nested loop into O(N+M)
    final cashFlowsByInvestment = <String, List<CashFlowEntity>>{};
    for (final cf in allCashFlows) {
      (cashFlowsByInvestment[cf.investmentId] ??= []).add(cf);
    }

    for (final investment in allInvestments) {
      final startDate = investment.startDate ?? investment.createdAt;

      // Only count investments that existed at this date
      if (startDate.isBefore(dateLimit)) {
        // If investment was closed before this date, value is 0
        if (investment.closedAt != null &&
            investment.closedAt!.isBefore(dateLimit)) {
          continue;
        }

        // Get cash flows for this investment up to the given date
        final allInvestmentFlows = cashFlowsByInvestment[investment.id] ?? [];
        final investmentFlows = <CashFlowEntity>[];
        for (final cf in allInvestmentFlows) {
          if (DateTime(
            cf.date.year,
            cf.date.month,
            cf.date.day,
          ).isBefore(dateLimit)) {
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
