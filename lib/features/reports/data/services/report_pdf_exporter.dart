/// PDF Exporter for Reports
///
/// Exports all report types to PDF format with basic formatting
library;

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:path_provider/path_provider.dart';

/// PDF exporter service for reports
class ReportPdfExporter {
  /// Export any report data to PDF
  Future<ExportResult> export({
    required dynamic reportData,
    required ReportType reportType,
    String currencySymbol = '\$',
    String locale = 'en_US',
  }) async {
    // Create PDF document
    final pdf = pw.Document();

    // Add pages based on report type
    _addReportPages(pdf, reportData, reportType, currencySymbol);

    // Save to file
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${reportType.fileName}_$timestamp.pdf';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Get file size
    final fileSize = await file.length();

    return ExportResult(
      filePath: filePath,
      format: ExportFormat.pdf,
      reportType: reportType,
      fileSizeBytes: fileSize,
      exportedAt: DateTime.now(),
    );
  }

  /// Add report pages to PDF
  void _addReportPages(
    pw.Document pdf,
    dynamic reportData,
    ReportType reportType,
    String currencySymbol,
  ) {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader(reportType),
          pw.SizedBox(height: 20),
          _buildContent(reportData, reportType, currencySymbol),
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
  ) {
    switch (reportType) {
      case ReportType.weeklySummary:
        return _buildWeeklySummary(reportData, currencySymbol);
      case ReportType.monthlyIncome:
        return _buildMonthlyIncome(reportData, currencySymbol);
      case ReportType.fyReport:
        return _buildFyReport(reportData, currencySymbol);
      case ReportType.performance:
        return _buildPerformance(reportData, currencySymbol);
      case ReportType.goalProgress:
        return _buildGoalProgress(reportData, currencySymbol);
      case ReportType.maturityCalendar:
        return _buildMaturityCalendar(reportData, currencySymbol);
      case ReportType.actionRequired:
        return _buildActionRequired(reportData, currencySymbol);
      case ReportType.portfolioHealth:
        return _buildPortfolioHealth(reportData, currencySymbol);
    }
  }

  /// Build Weekly Summary PDF
  pw.Widget _buildWeeklySummary(dynamic report, String symbol) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Week of ${report.weekStart.toString().split(' ')[0]}'),
        pw.SizedBox(height: 10),
        _buildKeyValueRow('Total Invested', '$symbol${report.totalInvested.toStringAsFixed(2)}'),
        _buildKeyValueRow('Total Returned', '$symbol${report.totalReturned.toStringAsFixed(2)}'),
        _buildKeyValueRow('Net Position', '$symbol${report.netPosition.toStringAsFixed(2)}'),
        _buildKeyValueRow('New Investments', report.newInvestments.toString()),
        pw.SizedBox(height: 20),
        pw.Text('Daily Cashflows', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Inflow', 'Outflow', 'Net'],
          data: report.dailyCashflows.map((d) => [
            d.date.toString().split(' ')[0],
            '$symbol${d.inflow.toStringAsFixed(2)}',
            '$symbol${d.outflow.toStringAsFixed(2)}',
            '$symbol${d.net.toStringAsFixed(2)}',
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
  pw.Widget _buildMonthlyIncome(dynamic report, String symbol) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('${report.monthName} ${report.year}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        _buildKeyValueRow('Total Income', '$symbol${report.totalIncome.toStringAsFixed(2)}'),
        _buildKeyValueRow('Transactions', report.totalTransactions.toString()),
        pw.SizedBox(height: 20),
        pw.Text('Income by Type', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Type', 'Amount', '%'],
          data: report.incomeByType.entries.map((e) {
            final pct = report.totalIncome > 0 ? (e.value / report.totalIncome * 100).toStringAsFixed(1) : '0.0';
            return [e.key.displayName, '$symbol${e.value.toStringAsFixed(2)}', '$pct%'];
          }).toList(),
        ),
      ],
    );
  }

  /// Build FY Report PDF
  pw.Widget _buildFyReport(dynamic report, String symbol) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('FY ${report.fyYear}-${report.fyYear + 1}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        _buildKeyValueRow('Total Invested', '$symbol${report.totalInvested.toStringAsFixed(2)}'),
        _buildKeyValueRow('Total Returned', '$symbol${report.totalReturned.toStringAsFixed(2)}'),
        _buildKeyValueRow('Net Position', '$symbol${report.netPosition.toStringAsFixed(2)}'),
        _buildKeyValueRow('XIRR', '${report.xirr.toStringAsFixed(2)}%'),
        pw.SizedBox(height: 20),
        pw.Text('Monthly Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Month', 'Invested', 'Returns', 'Income', 'Fees'],
          data: report.monthlyBreakdown.map((m) => [
            m.monthName,
            '$symbol${m.invested.toStringAsFixed(2)}',
            '$symbol${m.returns.toStringAsFixed(2)}',
            '$symbol${m.income.toStringAsFixed(2)}',
            '$symbol${m.fees.toStringAsFixed(2)}',
          ]).toList(),
        ),
      ],
    );
  }

  /// Build Performance Report PDF
  pw.Widget _buildPerformance(dynamic report, String symbol) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Top Performers', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Investment', 'Returns', 'XIRR %'],
          data: report.topPerformers.map((p) => [
            p.investment.name,
            '$symbol${p.returns.toStringAsFixed(2)}',
            '${p.xirr.toStringAsFixed(2)}%',
          ]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Bottom Performers', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Investment', 'Returns', 'XIRR %'],
          data: report.bottomPerformers.map((p) => [
            p.investment.name,
            '$symbol${p.returns.toStringAsFixed(2)}',
            '${p.xirr.toStringAsFixed(2)}%',
          ]).toList(),
        ),
      ],
    );
  }

  /// Build Goal Progress PDF
  pw.Widget _buildGoalProgress(dynamic report, String symbol) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('On-Track Goals', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Goal', 'Progress', 'Target', 'Current'],
          data: report.onTrackGoals.map((g) => [
            g.name,
            '${g.progressPercentage.toStringAsFixed(1)}%',
            '$symbol${g.targetAmount.toStringAsFixed(2)}',
            '$symbol${g.currentAmount.toStringAsFixed(2)}',
          ]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text('At-Risk Goals', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Goal', 'Progress', 'Target', 'Current'],
          data: report.atRiskGoals.map((g) => [
            g.name,
            '${g.progressPercentage.toStringAsFixed(1)}%',
            '$symbol${g.targetAmount.toStringAsFixed(2)}',
            '$symbol${g.currentAmount.toStringAsFixed(2)}',
          ]).toList(),
        ),
      ],
    );
  }

  /// Build Maturity Calendar PDF
  pw.Widget _buildMaturityCalendar(dynamic report, String symbol) {
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
  pw.Widget _buildActionRequired(dynamic report, String symbol) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Upcoming Maturities', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
        pw.Text('Idle Investments', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
  pw.Widget _buildPortfolioHealth(dynamic report, String symbol) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildKeyValueRow('Health Score', report.scoreValue.toString()),
        _buildKeyValueRow('Status', report.overallScore.displayName),
        pw.SizedBox(height: 20),
        pw.Text('Diversification', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Type', 'Count', 'Amount', '%'],
          data: report.diversification.map((d) => [
            d.type.displayName,
            d.count.toString(),
            '$symbol${d.amount.toStringAsFixed(2)}',
            '${d.percentage.toStringAsFixed(1)}%',
          ]).toList(),
        ),
      ],
    );
  }
}
