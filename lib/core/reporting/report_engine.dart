/// Builds a [ReportResult] from a [ReportDefinition]. Pure: it reads no
/// providers. Every number comes from `lib/core/calculations`; this file
/// only selects which cash flows feed which calculation.
library;

import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/reporting/metric_value.dart';
import 'package:inv_tracker/core/reporting/report_definition.dart';
import 'package:inv_tracker/core/reporting/report_period.dart';
import 'package:inv_tracker/core/reporting/report_result.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Converts flows to [baseCurrency]; a flow with no rate must be left out of
/// the returned list (e.g. `CurrencyConverterModule.batchConvertToBase`).
typedef ToBaseConverter =
    Future<List<CashFlowEntity>> Function(
      List<CashFlowEntity> flows,
      String baseCurrency,
    );

class ReportInputs {
  final List<InvestmentEntity> investments;
  final List<CashFlowEntity> cashFlows;
  final String baseCurrency;

  /// Value of the holdings on the first day of the period, in the base
  /// currency, or null when any holding's value is missing.
  final double? openingValue;

  /// Value of the holdings at the end of the period, or null when any
  /// holding's value is missing.
  final double? closingValue;

  const ReportInputs({
    required this.investments,
    required this.cashFlows,
    required this.baseCurrency,
    this.openingValue,
    this.closingValue,
  });
}

class ReportEngine {
  final ToBaseConverter _toBase;
  final DateTime Function() _now;

  ReportEngine({required ToBaseConverter toBase, DateTime Function()? now})
    : _toBase = toBase,
      _now = now ?? DateTime.now;

  static const _flowMetrics = {
    ReportMetric.invested,
    ReportMetric.returned,
    ReportMetric.income,
    ReportMetric.fees,
    ReportMetric.netCashFlow,
  };

  Future<ReportResult> run(
    ReportDefinition definition,
    ReportPeriod period,
    ReportInputs inputs,
  ) async {
    // Archived investments are left out of every total (money rule 9).
    final active = {
      for (final i in inputs.investments)
        if (!i.isArchived) i.id: i,
    };
    final archivedCount = inputs.investments.where((i) => i.isArchived).length;
    final mine = [
      for (final cf in inputs.cashFlows)
        if (active.containsKey(cf.investmentId)) cf,
    ];

    final converted = await _toBase(mine, inputs.baseCurrency);
    final convertedIds = {for (final cf in converted) cf.id};
    final excluded = mine.where((cf) => !convertedIds.contains(cf.id)).length;
    final nativeCurrency = {for (final cf in mine) cf.id: cf.currency};

    List<CashFlowEntity> within(ReportPeriod p) => [
      for (final cf in converted)
        if (p.contains(cf.date)) cf,
    ];

    final flows = within(period);
    final totals = <ReportMetric, MetricValue>{};
    for (final m in definition.metrics) {
      totals[m] = _metric(m, flows, period, inputs);
    }

    Map<ReportMetric, MetricValue>? previous;
    if (definition.comparePrevious) {
      final prevFlows = within(period.previous());
      previous = {
        for (final m in definition.metrics)
          m: _flowMetrics.contains(m)
              ? _metric(m, prevFlows, period.previous(), inputs)
              : const Unknown(UnknownReason.notApplicable),
      };
    }

    final breakdowns = <Breakdown, List<BreakdownRow>>{};
    for (final b in definition.breakdowns) {
      final groups = <String, List<CashFlowEntity>>{};
      switch (b) {
        case Breakdown.byInvestmentType:
          for (final cf in flows) {
            final key = active[cf.investmentId]!.type.name;
            (groups[key] ??= []).add(cf);
          }
        case Breakdown.byCurrency:
          for (final cf in flows) {
            (groups[nativeCurrency[cf.id]!] ??= []).add(cf);
          }
        case Breakdown.byMonth:
          for (final m in period.months()) {
            groups[_monthKey(m)] = [];
          }
          for (final cf in flows) {
            groups[_monthKey(cf.date)]!.add(cf);
          }
      }
      final keys = groups.keys.toList()..sort();
      breakdowns[b] = [
        for (final k in keys)
          BreakdownRow(k, {
            for (final m in definition.metrics)
              m: _flowMetrics.contains(m)
                  ? _metric(m, groups[k]!, period, inputs)
                  : const Unknown(UnknownReason.notApplicable),
          }),
      ];
    }

    return ReportResult(
      definitionId: definition.id,
      period: period,
      baseCurrency: inputs.baseCurrency,
      generatedAt: _now(),
      totals: totals,
      previous: previous,
      breakdowns: breakdowns,
      notes: [
        if (excluded > 0) ReportNote(ReportNoteKind.excludedFlows, excluded),
        if (archivedCount > 0)
          ReportNote(ReportNoteKind.archivedExcluded, archivedCount),
      ],
    );
  }

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  MetricValue _metric(
    ReportMetric metric,
    List<CashFlowEntity> flows,
    ReportPeriod period,
    ReportInputs inputs,
  ) {
    double sumOf(CashFlowType t, double Function(List<CashFlowEntity>) f) => f([
      for (final cf in flows)
        if (cf.type == t) cf,
    ]);
    double invested() =>
        sumOf(CashFlowType.invest, FinancialCalculator.calculateTotalInvested);
    double fees() =>
        sumOf(CashFlowType.fee, FinancialCalculator.calculateTotalInvested);
    double returned() => sumOf(
      CashFlowType.returnFlow,
      FinancialCalculator.calculateTotalReturned,
    );
    double income() =>
        sumOf(CashFlowType.income, FinancialCalculator.calculateTotalReturned);

    switch (metric) {
      case ReportMetric.invested:
        return Known(invested());
      case ReportMetric.fees:
        return Known(fees());
      case ReportMetric.returned:
        return Known(returned());
      case ReportMetric.income:
        return Known(income());
      case ReportMetric.netCashFlow:
        return Known(
          FinancialCalculator.calculateNetCashFlow(
            invested() + fees(),
            returned() + income(),
          ),
        );
      case ReportMetric.portfolioValueStart:
        return _orAwaiting(inputs.openingValue);
      case ReportMetric.portfolioValueEnd:
        return _orAwaiting(inputs.closingValue);
      case ReportMetric.periodXirr:
        final opening = inputs.openingValue;
        final closing = inputs.closingValue;
        if (opening == null || closing == null) {
          return const Unknown(UnknownReason.awaitingValue);
        }
        final dates = <DateTime>[];
        final amounts = <double>[];
        if (opening > 0) {
          dates.add(period.start);
          amounts.add(-opening);
        }
        for (final cf in flows) {
          dates.add(cf.date);
          amounts.add(cf.signedAmount);
        }
        if (closing > 0) {
          dates.add(period.endExclusive);
          amounts.add(closing);
        }
        if (dates.isEmpty) return const Unknown(UnknownReason.notApplicable);
        final xirr = XirrSolver.calculateXirr(dates, amounts);
        return xirr == null
            ? const Unknown(UnknownReason.notApplicable)
            : Known(xirr);
    }
  }

  static MetricValue _orAwaiting(double? v) =>
      v == null ? const Unknown(UnknownReason.awaitingValue) : Known(v);
}
