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
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
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
      missingValues: xirr == null
          ? _missingValues(
              allInvestments,
              fyStart,
              fyEndExclusive,
              openingValues ?? const {},
              closingValues ?? const {},
            )
          : const [],
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

  /// Base-currency value of each holding at the two FY edges, from its
  /// valuation snapshots (#800 slice 2).
  ///
  /// The opening value is the latest snapshot dated before 1 April of
  /// [fyYear], the closing value the latest dated before the next 1 April. A
  /// market value snapshot is preferred; with none, the latest of any kind
  /// is used. Only live snapshots in the holding's own currency count. A
  /// holding with no such snapshot, or whose conversion is impossible, is
  /// left out of the map so the FY XIRR stays null; no value is invented.
  Future<({Map<String, double> opening, Map<String, double> closing})>
  valuationsAtFYEdges({
    required int fyYear,
    required List<InvestmentEntity> investments,
    required List<InvestmentValuationSnapshot> snapshots,
    required String baseCurrency,
  }) async {
    Future<Map<String, double>> at(DateTime edge) async {
      final held = _heldBefore(investments, edge);
      final amounts = <String, double>{};
      final probes = <CashFlowEntity>[];
      for (final inv in investments) {
        if (!held.contains(inv.id)) continue;
        InvestmentValuationSnapshot? market;
        InvestmentValuationSnapshot? any;
        for (final s in snapshots) {
          if (!ValuationSnapshotSelector.applies(s, inv.id, inv.currency)) {
            continue;
          }
          final d = DateTime(
            s.effectiveDate.year,
            s.effectiveDate.month,
            s.effectiveDate.day,
          );
          if (!d.isBefore(edge)) continue;
          if (any == null || ValuationSnapshotSelector.compare(s, any) > 0) {
            any = s;
          }
          if (s.kind == ValuationKind.marketValue &&
              (market == null ||
                  ValuationSnapshotSelector.compare(s, market) > 0)) {
            market = s;
          }
        }
        final chosen = market ?? any;
        if (chosen == null) continue;
        // One unit is converted as a cash flow so the existing conversion
        // applies (the rate for the snapshot date, else the latest known,
        // else dropped) and the rate is checked even for a zero value.
        amounts[inv.id] = chosen.amount;
        probes.add(
          CashFlowEntity(
            id: inv.id,
            investmentId: inv.id,
            amount: 1,
            date: chosen.effectiveDate,
            type: CashFlowType.invest,
            currency: chosen.currency,
            createdAt: chosen.effectiveDate,
          ),
        );
      }
      final converted = await _engine.currency.batchConvertToBase(
        cashFlows: probes,
        baseCurrency: baseCurrency,
      );
      // A rate that is zero or not finite is no rate: the holding is left out.
      final values = <String, double>{};
      for (final cf in converted) {
        if (!cf.amount.isFinite || cf.amount <= 0) continue;
        final value = amounts[cf.investmentId]! * cf.amount;
        if (value.isFinite) values[cf.investmentId] = value;
      }
      return values;
    }

    return (
      opening: await at(DateTime(fyYear, 4, 1)),
      closing: await at(DateTime(fyYear + 1, 4, 1)),
    );
  }

  /// Whether [date] falls in the half-open range [start, endExclusive).
  static bool _inFY(DateTime date, DateTime start, DateTime endExclusive) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  /// Ids of investments that exist at [limit] and were not closed before it,
  /// judged by the investment itself as [_calculatePortfolioValue] does.
  Set<String> _heldBefore(List<InvestmentEntity> investments, DateTime limit) {
    return {
      for (final inv in investments)
        if ((inv.startDate ?? inv.createdAt).isBefore(limit) &&
            !(inv.closedAt != null && inv.closedAt!.isBefore(limit)))
          inv.id,
    };
  }

  /// Holdings held at an FY edge with no value there, in list order.
  List<FYMissingValue> _missingValues(
    List<InvestmentEntity> investments,
    DateTime fyStart,
    DateTime fyEndExclusive,
    Map<String, double> opening,
    Map<String, double> closing,
  ) {
    final heldAtStart = _heldBefore(investments, fyStart);
    final heldAtEnd = _heldBefore(investments, fyEndExclusive);
    return [
      for (final inv in investments)
        if ((heldAtStart.contains(inv.id) && !opening.containsKey(inv.id)) ||
            (heldAtEnd.contains(inv.id) && !closing.containsKey(inv.id)))
          FYMissingValue(
            investment: inv,
            needsOpening:
                heldAtStart.contains(inv.id) && !opening.containsKey(inv.id),
            needsClosing:
                heldAtEnd.contains(inv.id) && !closing.containsKey(inv.id),
          ),
    ];
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
    required List<InvestmentEntity> allInvestments,
    required DateTime fyStart,
    required DateTime fyEndExclusive,
    required Map<String, double>? openingValues,
    required Map<String, double>? closingValues,
  }) {
    final opening = openingValues ?? const <String, double>{};
    final closing = closingValues ?? const <String, double>{};

    if (_heldBefore(
      allInvestments,
      fyStart,
    ).any((id) => !opening.containsKey(id))) {
      return null;
    }
    if (_heldBefore(
      allInvestments,
      fyEndExclusive,
    ).any((id) => !closing.containsKey(id))) {
      return null;
    }

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

  /// Profit realised in the FY. Per investment, profit realised to date is
  /// the highest the running (returns minus money put in) has reached, floored
  /// at zero, so cost is recovered first and a later top-up never makes an
  /// earlier profit count again. The FY figure is that high-water mark at the
  /// FY end less the mark before the FY start. A loss is not income.
  double _realisedProfitInFY(
    List<CashFlowEntity> baseCashFlows,
    DateTime fyStart,
    DateTime fyEndExclusive,
  ) {
    final moves = <(DateTime, CashFlowEntity)>[
      for (final cf in baseCashFlows)
        if (cf.type == CashFlowType.invest ||
            cf.type == CashFlowType.returnFlow)
          (DateTime(cf.date.year, cf.date.month, cf.date.day), cf),
    ];
    // Oldest first; on one day the money put in is counted before the money
    // taken out, which can only lower the high-water mark.
    moves.sort((a, b) {
      final byDay = a.$1.compareTo(b.$1);
      if (byDay != 0) return byDay;
      return (a.$2.type == CashFlowType.invest ? 0 : 1) -
          (b.$2.type == CashFlowType.invest ? 0 : 1);
    });

    final running = <String, double>{};
    final markAtStart = <String, double>{};
    final markAtEnd = <String, double>{};
    final mark = <String, double>{};
    for (final (day, cf) in moves) {
      if (!day.isBefore(fyEndExclusive)) break;
      final id = cf.investmentId;
      final net =
          (running[id] ?? 0) +
          (cf.type == CashFlowType.returnFlow ? cf.amount : -cf.amount);
      running[id] = net;
      final best = mark[id] ?? 0;
      if (net > best) mark[id] = net;
      markAtEnd[id] = mark[id] ?? 0;
      if (day.isBefore(fyStart)) markAtStart[id] = mark[id] ?? 0;
    }

    double total = 0;
    markAtEnd.forEach((id, end) {
      final fyGain = end - (markAtStart[id] ?? 0);
      if (fyGain > 0) total += fyGain;
    });
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
