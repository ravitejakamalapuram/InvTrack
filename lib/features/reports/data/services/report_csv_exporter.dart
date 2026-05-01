/// CSV Exporter for Reports
///
/// Exports all report types to CSV format with privacy masking support
library;

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/utils/csv_utils.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';

/// CSV exporter service for reports
class ReportCsvExporter {
  final AnalyticsService? _analytics;

  /// Create CSV exporter with optional analytics service
  ReportCsvExporter({AnalyticsService? analytics}) : _analytics = analytics;

  /// Export any report data to CSV
  Future<ExportResult> export({
    required dynamic reportData,
    required ReportType reportType,
    String currencySymbol = '\$',
    String locale = 'en_US',
    bool isPrivacyMode = false,
  }) async {
    // Generate CSV rows based on report type
    final rows = _generateCsvRows(reportData, reportType, currencySymbol, locale, isPrivacyMode);

    // Convert to CSV string
    final csvData = const ListToCsvConverter().convert(rows);

    // Save to file
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${reportType.fileName}_$timestamp.csv';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsString(csvData);

    // Get file size
    final fileSize = await file.length();

    // Track export analytics (rows - 1 for header row)
    await _analytics?.logReportExported(
      reportType: reportType.name,
      format: 'csv',
      recordCount: rows.length > 1 ? rows.length - 1 : 0,
    );

    return ExportResult(
      filePath: filePath,
      format: ExportFormat.csv,
      reportType: reportType,
      fileSizeBytes: fileSize,
      exportedAt: DateTime.now(),
    );
  }

  /// Format amount with privacy masking support and locale-aware formatting
  String _formatAmount(double amount, String symbol, bool isPrivacyMode, String locale) {
    if (isPrivacyMode) {
      return '••••••';
    }
    // Use locale-aware currency formatting (Rule 16.5 compliance)
    final formatter = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  /// Generate CSV rows based on report type
  List<List<dynamic>> _generateCsvRows(
    dynamic reportData,
    ReportType reportType,
    String currencySymbol,
    String locale,
    bool isPrivacyMode,
  ) {
    switch (reportType) {
      case ReportType.weeklySummary:
        return _exportWeeklySummary(reportData, currencySymbol, locale, isPrivacyMode);
      case ReportType.monthlyIncome:
        return _exportMonthlyIncome(reportData, currencySymbol, locale, isPrivacyMode);
      case ReportType.fyReport:
        return _exportFyReport(reportData, currencySymbol, locale, isPrivacyMode);
      case ReportType.performance:
        return _exportPerformance(reportData, currencySymbol, locale, isPrivacyMode);
      case ReportType.goalProgress:
        return _exportGoalProgress(reportData, currencySymbol, locale, isPrivacyMode);
      case ReportType.maturityCalendar:
        return _exportMaturityCalendar(reportData, currencySymbol, locale, isPrivacyMode);
      case ReportType.actionRequired:
        return _exportActionRequired(reportData, currencySymbol, locale, isPrivacyMode);
      case ReportType.portfolioHealth:
        return _exportPortfolioHealth(reportData, currencySymbol, locale, isPrivacyMode);
    }
  }

  /// Export Weekly Summary Report to CSV
  List<List<dynamic>> _exportWeeklySummary(dynamic report, String symbol, String locale, bool isPrivacyMode) {
    final rows = <List<dynamic>>[];

    // Header
    rows.add(['InvTrack - Weekly Summary Report']);
    rows.add(['Week of ${report.weekStart.toString().split(' ')[0]}']);
    rows.add([]);

    // Summary Stats
    rows.add(['Summary']);
    rows.add(['Total Invested', _formatAmount(report.totalInvested, symbol, isPrivacyMode, locale)]);
    rows.add(['Total Returned', _formatAmount(report.totalReturned, symbol, isPrivacyMode, locale)]);
    rows.add(['Net Position', _formatAmount(report.netPosition, symbol, isPrivacyMode, locale)]);
    rows.add(['New Investments', report.newInvestments.toString()]);
    rows.add([]);

    // Daily Cashflows
    rows.add(['Daily Cashflows']);
    rows.add(['Date', 'Inflow', 'Outflow', 'Net']);
    for (final day in report.dailyCashflows) {
      rows.add([
        day.date.toString().split(' ')[0],
        CsvUtils.sanitizeField(_formatAmount(day.inflow, symbol, isPrivacyMode, locale)),
        CsvUtils.sanitizeField(_formatAmount(day.outflow, symbol, isPrivacyMode, locale)),
        CsvUtils.sanitizeField(_formatAmount(day.net, symbol, isPrivacyMode, locale)),
      ]);
    }
    rows.add([]);

    // Top Performers
    rows.add(['Top Performers']);
    rows.add(['Investment', 'Returns', 'XIRR %']);
    for (final performer in report.topPerformers.take(5)) {
      rows.add([
        CsvUtils.sanitizeField(performer.investment.name),
        CsvUtils.sanitizeField(_formatAmount(performer.returns, symbol, isPrivacyMode, locale)),
        CsvUtils.sanitizeField('${performer.xirr.toStringAsFixed(2)}%'),
      ]);
    }

    return rows;
  }

  /// Export FY Report to CSV
  List<List<dynamic>> _exportFyReport(dynamic report, String symbol, String locale, bool isPrivacyMode) {
    final rows = <List<dynamic>>[];
    rows.add(['InvTrack - Financial Year Report']);
    rows.add(['FY ${report.fyYear}-${report.fyYear + 1} (Apr-Mar)']);
    rows.add([]);
    rows.add(['Summary']);
    rows.add(['Total Invested', _formatAmount(report.totalInvested, symbol, isPrivacyMode, locale)]);
    rows.add(['Total Returned', _formatAmount(report.totalReturned, symbol, isPrivacyMode, locale)]);
    rows.add(['Net Position', _formatAmount(report.netPosition, symbol, isPrivacyMode, locale)]);
    rows.add(['XIRR', '${report.xirr.toStringAsFixed(2)}%']);
    rows.add([]);
    rows.add(['Monthly Breakdown']);
    rows.add(['Month', 'Invested', 'Returns', 'Income', 'Fees', 'Net']);
    for (final month in report.monthlyBreakdown) {
      rows.add([
        month.monthName,
        CsvUtils.sanitizeField(_formatAmount(month.invested, symbol, isPrivacyMode, locale)),
        CsvUtils.sanitizeField(_formatAmount(month.returns, symbol, isPrivacyMode, locale)),
        CsvUtils.sanitizeField(_formatAmount(month.income, symbol, isPrivacyMode, locale)),
        CsvUtils.sanitizeField(_formatAmount(month.fees, symbol, isPrivacyMode, locale)),
        CsvUtils.sanitizeField(_formatAmount(month.net, symbol, isPrivacyMode, locale)),
      ]);
    }
    return rows;
  }

  /// Export Performance Report to CSV
  List<List<dynamic>> _exportPerformance(dynamic report, String symbol, String locale, bool isPrivacyMode) {
    final rows = <List<dynamic>>[];
    rows.add(['InvTrack - Performance Report']);
    rows.add([]);
    rows.add(['Top Performers']);
    rows.add(['Investment', 'Returns', 'XIRR %']);
    for (final p in report.topPerformers) {
      rows.add([
        CsvUtils.sanitizeField(p.investment.name),
        CsvUtils.sanitizeField(_formatAmount(p.returns, symbol, isPrivacyMode, locale)),
        '${p.xirr.toStringAsFixed(2)}%',
      ]);
    }
    rows.add([]);
    rows.add(['Bottom Performers']);
    rows.add(['Investment', 'Returns', 'XIRR %']);
    for (final p in report.bottomPerformers) {
      rows.add([
        CsvUtils.sanitizeField(p.investment.name),
        CsvUtils.sanitizeField(_formatAmount(p.returns, symbol, isPrivacyMode, locale)),
        '${p.xirr.toStringAsFixed(2)}%',
      ]);
    }
    return rows;
  }

  /// Export Goal Progress Report to CSV
  List<List<dynamic>> _exportGoalProgress(dynamic report, String symbol, String locale, bool isPrivacyMode) {
    final rows = <List<dynamic>>[];
    rows.add(['InvTrack - Goal Progress Report']);
    rows.add([]);
    rows.add(['On-Track Goals']);
    rows.add(['Goal', 'Progress', 'Target', 'Current']);
    for (final g in report.onTrackGoals) {
      rows.add([
        CsvUtils.sanitizeField(g.name),
        '${g.progressPercentage.toStringAsFixed(1)}%',
        CsvUtils.sanitizeField(_formatAmount(g.targetAmount, symbol, isPrivacyMode, locale)),
        CsvUtils.sanitizeField(_formatAmount(g.currentAmount, symbol, isPrivacyMode, locale)),
      ]);
    }
    rows.add([]);
    rows.add(['At-Risk Goals']);
    rows.add(['Goal', 'Progress', 'Target', 'Current']);
    for (final g in report.atRiskGoals) {
      rows.add([
        CsvUtils.sanitizeField(g.name),
        '${g.progressPercentage.toStringAsFixed(1)}%',
        CsvUtils.sanitizeField(_formatAmount(g.targetAmount, symbol, isPrivacyMode, locale)),
        CsvUtils.sanitizeField(_formatAmount(g.currentAmount, symbol, isPrivacyMode, locale)),
      ]);
    }
    return rows;
  }

  /// Export Maturity Calendar Report to CSV
  List<List<dynamic>> _exportMaturityCalendar(dynamic report, String symbol, String locale, bool isPrivacyMode) {
    final rows = <List<dynamic>>[];
    rows.add(['InvTrack - Maturity Calendar Report']);
    rows.add([]);
    rows.add(['Investment', 'Maturity Date', 'Days Until Maturity', 'Urgency']);
    for (final m in report.maturities) {
      rows.add([
        CsvUtils.sanitizeField(m.investment.name),
        m.maturityDate.toString().split(' ')[0],
        m.daysUntilMaturity.toString(),
        m.urgency.displayName,
      ]);
    }
    return rows;
  }

  /// Export Action Required Report to CSV
  List<List<dynamic>> _exportActionRequired(dynamic report, String symbol, String locale, bool isPrivacyMode) {
    final rows = <List<dynamic>>[];
    rows.add(['InvTrack - Action Required Report']);
    rows.add([]);
    rows.add(['Upcoming Maturities']);
    rows.add(['Investment', 'Maturity Date', 'Days Remaining']);
    for (final m in report.upcomingMaturities) {
      rows.add([
        CsvUtils.sanitizeField(m.investment.name),
        m.maturityDate.toString().split(' ')[0],
        m.daysUntilMaturity.toString(),
      ]);
    }
    rows.add([]);
    rows.add(['Idle Investments']);
    rows.add(['Investment', 'Last Activity', 'Days Idle']);
    for (final i in report.idleInvestments) {
      rows.add([
        CsvUtils.sanitizeField(i.name),
        i.updatedAt.toString().split(' ')[0],
        DateTime.now().difference(i.updatedAt).inDays.toString(),
      ]);
    }
    return rows;
  }

  /// Export Portfolio Health Report to CSV
  List<List<dynamic>> _exportPortfolioHealth(dynamic report, String symbol, String locale, bool isPrivacyMode) {
    final rows = <List<dynamic>>[];
    rows.add(['InvTrack - Portfolio Health Report']);
    rows.add([]);
    rows.add(['Health Score', report.scoreValue.toString()]);
    rows.add(['Status', report.overallScore.displayName]);
    rows.add([]);
    rows.add(['Diversification']);
    rows.add(['Type', 'Count', 'Amount', 'Percentage']);
    for (final d in report.diversification) {
      rows.add([
        d.type.displayName,
        d.count.toString(),
        CsvUtils.sanitizeField(_formatAmount(d.amount, symbol, isPrivacyMode, locale)),
        '${d.percentage.toStringAsFixed(1)}%',
      ]);
    }
    return rows;
  }

  /// Export Monthly Income Report to CSV
  List<List<dynamic>> _exportMonthlyIncome(dynamic report, String symbol, String locale, bool isPrivacyMode) {
    final rows = <List<dynamic>>[];

    // Header
    rows.add(['InvTrack - Monthly Income Report']);
    rows.add(['Month: ${report.monthName} ${report.year}']);
    rows.add([]);

    // Summary
    rows.add(['Summary']);
    rows.add(['Total Income', _formatAmount(report.totalIncome, symbol, isPrivacyMode, locale)]);
    rows.add(['Total Transactions', report.totalTransactions.toString()]);
    rows.add([]);

    // Income by Type
    rows.add(['Income Breakdown by Type']);
    rows.add(['Type', 'Amount', 'Percentage']);
    for (final entry in report.incomeByType.entries) {
      final percentage = report.totalIncome > 0
          ? (entry.value / report.totalIncome * 100).toStringAsFixed(1)
          : '0.0';
      rows.add([
        entry.key.displayName,
        CsvUtils.sanitizeField(_formatAmount(entry.value, symbol, isPrivacyMode, locale)),
        '$percentage%',
      ]);
    }

    return rows;
  }
}
