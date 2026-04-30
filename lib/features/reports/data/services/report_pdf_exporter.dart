/// PDF Exporter for Reports
///
/// Exports all report types to PDF format with basic formatting
library;

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';

/// PDF exporter service for reports
class ReportPdfExporter {
  final AnalyticsService? _analytics;

  /// Create PDF exporter with optional analytics service
  ReportPdfExporter({AnalyticsService? analytics}) : _analytics = analytics;

  /// Export any report data to PDF
  Future<ExportResult> export({
    required dynamic reportData,
    required ReportType reportType,
    String currencySymbol = '\$',
    String locale = 'en_US',
    bool isPrivacyMode = false,
    Map<String, String>? localizedStrings,
  }) async {
    // Create PDF document
    final pdf = pw.Document();

    // Add pages based on report type
    _addReportPages(pdf, reportData, reportType, currencySymbol, isPrivacyMode, localizedStrings);

    // Save to file
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${reportType.fileName}_$timestamp.pdf';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Get file size
    final fileSize = await file.length();

    // Track export analytics
    await _analytics?.logReportExported(
      reportType: reportType.name,
      format: 'pdf',
      recordCount: _getRecordCount(reportData),
    );

    return ExportResult(
      filePath: filePath,
      format: ExportFormat.pdf,
      reportType: reportType,
      fileSizeBytes: fileSize,
      exportedAt: DateTime.now(),
    );
  }

  /// Get localized string with fallback to English key
  String _l10n(Map<String, String>? localizedStrings, String key, String fallback) {
    return localizedStrings?[key] ?? fallback;
  }

  /// Format amount with privacy masking support
  String _formatAmount(double amount, String symbol, bool isPrivacyMode) {
    if (isPrivacyMode) {
      return '••••••';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Extract record count from report data for analytics
  int? _getRecordCount(dynamic reportData) {
    if (reportData == null) return null;

    // Try to extract count from common report data structures
    if (reportData is Map) {
      // Weekly/Monthly reports have transactions list
      if (reportData['transactions'] is List) {
        return (reportData['transactions'] as List).length;
      }
      // Maturity calendar has upcoming maturities
      if (reportData['upcomingMaturities'] is List) {
        return (reportData['upcomingMaturities'] as List).length;
      }
      // Action required has actionItems
      if (reportData['actionItems'] is List) {
        return (reportData['actionItems'] as List).length;
      }
    }

    return null;
  }

  /// Add report pages to PDF
  void _addReportPages(
    pw.Document pdf,
    dynamic reportData,
    ReportType reportType,
    String currencySymbol,
    bool isPrivacyMode,
    Map<String, String>? localizedStrings,
  ) {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader(reportType),
          pw.SizedBox(height: 20),
          _buildContent(reportData, reportType, currencySymbol, isPrivacyMode, localizedStrings),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ),
    );
  }

  /// Build PDF header
  pw.Widget _buildHeader(ReportType reportType) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'InvTrack',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          reportType.displayName,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          'Generated: ${DateTime.now().toString().split('.')[0]}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Build PDF content based on report type
  pw.Widget _buildContent(
    dynamic reportData,
    ReportType reportType,
    String currencySymbol,
    bool isPrivacyMode,
    Map<String, String>? localizedStrings,
  ) {
    switch (reportType) {
      case ReportType.weeklySummary:
        return _buildWeeklySummary(reportData, currencySymbol, isPrivacyMode, localizedStrings);
      case ReportType.monthlyIncome:
        return _buildMonthlyIncome(reportData, currencySymbol, isPrivacyMode, localizedStrings);
      case ReportType.fyReport:
        return _buildFyReport(reportData, currencySymbol, isPrivacyMode, localizedStrings);
      case ReportType.performance:
        return _buildPerformance(reportData, currencySymbol, isPrivacyMode, localizedStrings);
      case ReportType.goalProgress:
        return _buildGoalProgress(reportData, currencySymbol, isPrivacyMode, localizedStrings);
      case ReportType.maturityCalendar:
        return _buildMaturityCalendar(reportData, currencySymbol, isPrivacyMode, localizedStrings);
      case ReportType.actionRequired:
        return _buildActionRequired(reportData, currencySymbol, isPrivacyMode, localizedStrings);
      case ReportType.portfolioHealth:
        return _buildPortfolioHealth(reportData, currencySymbol, isPrivacyMode, localizedStrings);
    }
  }

  /// Build Weekly Summary PDF
  pw.Widget _buildWeeklySummary(dynamic report, String symbol, bool isPrivacyMode, Map<String, String>? l10n) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_l10n(l10n, 'reportPdfWeekOf', 'Week of ${report.weekStart.toString().split(' ')[0]}')),
        pw.SizedBox(height: 10),
        _buildKeyValueRow('Total Invested', _formatAmount(report.totalInvested, symbol, isPrivacyMode)),
        _buildKeyValueRow('Total Returned', _formatAmount(report.totalReturned, symbol, isPrivacyMode)),
        _buildKeyValueRow('Net Position', _formatAmount(report.netPosition, symbol, isPrivacyMode)),
        _buildKeyValueRow('New Investments', report.newInvestments.toString()),
        pw.SizedBox(height: 20),
        pw.Text(_l10n(l10n, 'reportPdfDailyCashflows', 'Daily Cashflows'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Inflow', 'Outflow', 'Net'],
          data: report.dailyCashflows.map((d) => [
            d.date.toString().split(' ')[0],
            _formatAmount(d.inflow, symbol, isPrivacyMode),
            _formatAmount(d.outflow, symbol, isPrivacyMode),
            _formatAmount(d.net, symbol, isPrivacyMode),
          ]).toList(),
        ),
      ],
    );
  }

  /// Helper to build key-value row
  pw.Widget _buildKeyValueRow(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(key),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
  /// Build Monthly Income PDF
  pw.Widget _buildMonthlyIncome(dynamic report, String symbol, bool isPrivacyMode, Map<String, String>? l10n) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('${report.monthName} ${report.year}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        _buildKeyValueRow('Total Income', _formatAmount(report.totalIncome, symbol, isPrivacyMode)),
        _buildKeyValueRow('Transactions', report.totalTransactions.toString()),
        pw.SizedBox(height: 20),
        pw.Text(_l10n(l10n, 'reportPdfIncomeByType', 'Income by Type'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Type', 'Amount', '%'],
          data: report.incomeByType.entries.map((e) {
            final pct = report.totalIncome > 0 ? (e.value / report.totalIncome * 100).toStringAsFixed(1) : '0.0';
            return [e.key.displayName, _formatAmount(e.value, symbol, isPrivacyMode), '$pct%'];
          }).toList(),
        ),
      ],
    );
  }

  /// Build FY Report PDF
  pw.Widget _buildFyReport(dynamic report, String symbol, bool isPrivacyMode, Map<String, String>? l10n) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('FY ${report.fyYear}-${report.fyYear + 1}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        _buildKeyValueRow('Total Invested', _formatAmount(report.totalInvested, symbol, isPrivacyMode)),
        _buildKeyValueRow('Total Returned', _formatAmount(report.totalReturned, symbol, isPrivacyMode)),
        _buildKeyValueRow('Net Position', _formatAmount(report.netPosition, symbol, isPrivacyMode)),
        _buildKeyValueRow('XIRR', '${report.xirr.toStringAsFixed(2)}%'),
        pw.SizedBox(height: 20),
        pw.Text(_l10n(l10n, 'reportPdfMonthlyBreakdown', 'Monthly Breakdown'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Month', 'Invested', 'Returns', 'Income', 'Fees'],
          data: report.monthlyBreakdown.map((m) => [
            m.monthName,
            _formatAmount(m.invested, symbol, isPrivacyMode),
            _formatAmount(m.returns, symbol, isPrivacyMode),
            _formatAmount(m.income, symbol, isPrivacyMode),
            _formatAmount(m.fees, symbol, isPrivacyMode),
          ]).toList(),
        ),
      ],
    );
  }

  /// Build Performance Report PDF
  pw.Widget _buildPerformance(dynamic report, String symbol, bool isPrivacyMode, Map<String, String>? l10n) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_l10n(l10n, 'reportPdfTopPerformers', 'Top Performers'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Investment', 'Returns', 'XIRR %'],
          data: report.topPerformers.map((p) => [
            p.investment.name,
            _formatAmount(p.returns, symbol, isPrivacyMode),
            '${p.xirr.toStringAsFixed(2)}%',
          ]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text(_l10n(l10n, 'reportPdfBottomPerformers', 'Bottom Performers'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Investment', 'Returns', 'XIRR %'],
          data: report.bottomPerformers.map((p) => [
            p.investment.name,
            _formatAmount(p.returns, symbol, isPrivacyMode),
            '${p.xirr.toStringAsFixed(2)}%',
          ]).toList(),
        ),
      ],
    );
  }

  /// Build Goal Progress PDF
  pw.Widget _buildGoalProgress(dynamic report, String symbol, bool isPrivacyMode, Map<String, String>? l10n) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_l10n(l10n, 'reportPdfOnTrackGoals', 'On-Track Goals'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Goal', 'Progress', 'Target', 'Current'],
          data: report.onTrackGoals.map((g) => [
            g.name,
            '${g.progressPercentage.toStringAsFixed(1)}%',
            _formatAmount(g.targetAmount, symbol, isPrivacyMode),
            _formatAmount(g.currentAmount, symbol, isPrivacyMode),
          ]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text(_l10n(l10n, 'reportPdfAtRiskGoals', 'At-Risk Goals'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Goal', 'Progress', 'Target', 'Current'],
          data: report.atRiskGoals.map((g) => [
            g.name,
            '${g.progressPercentage.toStringAsFixed(1)}%',
            _formatAmount(g.targetAmount, symbol, isPrivacyMode),
            _formatAmount(g.currentAmount, symbol, isPrivacyMode),
          ]).toList(),
        ),
      ],
    );
  }

  /// Build Maturity Calendar PDF
  pw.Widget _buildMaturityCalendar(dynamic report, String symbol, bool isPrivacyMode, Map<String, String>? l10n) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.TableHelper.fromTextArray(
          headers: ['Investment', 'Maturity Date', 'Days Left', 'Urgency'],
          data: report.maturities.map((m) => [
            m.investment.name,
            m.maturityDate.toString().split(' ')[0],
            m.daysUntilMaturity.toString(),
            m.urgency.displayName,
          ]).toList(),
        ),
      ],
    );
  }

  /// Build Action Required PDF
  pw.Widget _buildActionRequired(dynamic report, String symbol, bool isPrivacyMode, Map<String, String>? l10n) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_l10n(l10n, 'reportPdfUpcomingMaturities', 'Upcoming Maturities'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Investment', 'Maturity Date', 'Days Left'],
          data: report.upcomingMaturities.map((m) => [
            m.investment.name,
            m.maturityDate.toString().split(' ')[0],
            m.daysUntilMaturity.toString(),
          ]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text(_l10n(l10n, 'reportPdfIdleInvestments', 'Idle Investments'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Investment', 'Last Activity', 'Days Idle'],
          data: report.idleInvestments.map((i) => [
            i.name,
            i.updatedAt.toString().split(' ')[0],
            DateTime.now().difference(i.updatedAt).inDays.toString(),
          ]).toList(),
        ),
      ],
    );
  }

  /// Build Portfolio Health PDF
  pw.Widget _buildPortfolioHealth(dynamic report, String symbol, bool isPrivacyMode, Map<String, String>? l10n) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildKeyValueRow('Health Score', report.scoreValue.toString()),
        _buildKeyValueRow('Status', report.overallScore.displayName),
        pw.SizedBox(height: 20),
        pw.Text(_l10n(l10n, 'reportPdfDiversification', 'Diversification'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Type', 'Count', 'Amount', '%'],
          data: report.diversification.map((d) => [
            d.type.displayName,
            d.count.toString(),
            _formatAmount(d.amount, symbol, isPrivacyMode),
            '${d.percentage.toStringAsFixed(1)}%',
          ]).toList(),
        ),
      ],
    );
  }
}
