/// The built-in reports. Each is data for [ReportEngine]; none has code of
/// its own.
library;

import 'package:inv_tracker/core/reporting/report_definition.dart';
import 'package:inv_tracker/core/reporting/report_period.dart';

const _flowMetrics = [
  ReportMetric.invested,
  ReportMetric.returned,
  ReportMetric.income,
  ReportMetric.fees,
  ReportMetric.netCashFlow,
];

const weeklyReport = ReportDefinition(
  id: 'weekly',
  metrics: _flowMetrics,
  breakdowns: [Breakdown.byInvestmentType],
  comparePrevious: true,
);

const monthlyReport = ReportDefinition(
  id: 'monthly',
  metrics: _flowMetrics,
  breakdowns: [Breakdown.byInvestmentType, Breakdown.byCurrency],
  comparePrevious: true,
);

// Yearly period XIRR and opening/closing values wait for the FY migration
// (docs/reporting-engine.md), so valuationsAtFYEdges is not duplicated.
const yearlyReport = ReportDefinition(
  id: 'yearly',
  metrics: _flowMetrics,
  breakdowns: [
    Breakdown.byMonth,
    Breakdown.byInvestmentType,
    Breakdown.byCurrency,
  ],
  comparePrevious: true,
);

/// The report shown for a period kind; week, month and fy only.
ReportDefinition definitionFor(ReportPeriodKind kind) {
  switch (kind) {
    case ReportPeriodKind.week:
      return weeklyReport;
    case ReportPeriodKind.month:
      return monthlyReport;
    case ReportPeriodKind.fy:
      return yearlyReport;
    case ReportPeriodKind.quarter:
    case ReportPeriodKind.custom:
      throw ArgumentError('No built-in report for $kind');
  }
}
