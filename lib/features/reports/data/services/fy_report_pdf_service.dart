/// Tax-Year (FY) report as an A4 PDF.
///
/// Two pure steps so the figures can be tested without a PDF parser:
/// [buildFyPdfContent] turns an [FYReport] into the exact strings printed,
/// and [renderFyReportPdf] lays those strings out on A4. [FyReportPdfService]
/// adds the font loading, the off-UI-isolate render and the share sheet.
///
/// Money rules: every amount is in the base currency the report was built
/// in; capital gains are never printed as a number because the cash-flow
/// model cannot prove a sale; a missing XIRR is an em dash, never 0%.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// One label and the text printed beside it.
class FyPdfRow {
  final String label;
  final String value;

  /// False when [value] is an explanation rather than a money amount.
  final bool isAmount;

  const FyPdfRow(this.label, this.value, {this.isAmount = true});
}

/// One printed line of the monthly table.
class FyPdfMonthRow {
  final String month;
  final String invested;
  final String incomeAndReturns;
  final String net;

  const FyPdfMonthRow({
    required this.month,
    required this.invested,
    required this.incomeAndReturns,
    required this.net,
  });
}

/// Every string on the page, already formatted.
class FyPdfContent {
  final String title;
  final String subtitle;
  final String generatedLine;
  final String amountsNote;
  final String incomeHeading;
  final List<String> incomeHeaders;
  final List<FyPdfRow> incomeRows;
  final String cashFlowHeading;
  final List<FyPdfRow> tiles;
  final String netCashFlowLabel;
  final String netCashFlowValue;
  final String xirrLabel;
  final String xirrValue;
  final String monthHeading;
  final List<String> monthHeaders;
  final List<FyPdfMonthRow> monthRows;
  final String disclaimer;

  const FyPdfContent({
    required this.title,
    required this.subtitle,
    required this.generatedLine,
    required this.amountsNote,
    required this.incomeHeading,
    required this.incomeHeaders,
    required this.incomeRows,
    required this.cashFlowHeading,
    required this.tiles,
    required this.netCashFlowLabel,
    required this.netCashFlowValue,
    required this.xirrLabel,
    required this.xirrValue,
    required this.monthHeading,
    required this.monthHeaders,
    required this.monthRows,
    required this.disclaimer,
  });
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

// Fixed English abbreviations, like MonthlyFYData.monthName, so no locale
// data has to be loaded before printing.
String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Formats the report for print. Pure: no I/O, no clock.
FyPdfContent buildFyPdfContent({
  required FYReport report,
  required AppLocalizations l10n,
  required String baseCurrency,
  required DateTime generatedAt,
}) {
  final symbol = getCurrencySymbol(baseCurrency);
  final locale = getCurrencyLocale(baseCurrency);

  String money(double v) => formatCurrency(v, symbol, locale);
  // Sign goes before the symbol; zero carries none.
  String signed(double v) {
    final text = money(v.abs());
    if (v > 0) return '+$text';
    if (v < 0) return '-$text';
    return text;
  }

  final xirr = report.xirr;
  return FyPdfContent(
    title: l10n.fyPdfTitle,
    subtitle: l10n.fyPdfFinancialYear(
      report.fyLabel,
      _day(report.fyStart),
      _day(report.fyEnd),
    ),
    generatedLine: l10n.fyPdfGenerated(_day(generatedAt)),
    amountsNote: l10n.fyPdfAmountsIn(symbol, baseCurrency),
    incomeHeading: l10n.fyPdfIncomeHeading,
    incomeHeaders: [l10n.fyPdfColType, l10n.fyPdfColAmount],
    incomeRows: [
      FyPdfRow(l10n.fyPdfInterestIncome, money(report.interestIncome)),
      FyPdfRow(l10n.fyPdfDividendIncome, money(report.dividendIncome)),
      // The cash-flow model cannot prove a sale, so gains are never a number.
      FyPdfRow(
        l10n.fyPdfCapitalGains,
        l10n.fyPdfCapitalGainsNotCalculated,
        isAmount: false,
      ),
    ],
    cashFlowHeading: l10n.fyPdfCashFlowHeading,
    tiles: [
      FyPdfRow(l10n.fyPdfInvested, money(report.totalInvested)),
      FyPdfRow(l10n.fyPdfReturned, money(report.totalReturns)),
      FyPdfRow(l10n.fyPdfIncome, money(report.totalIncome)),
      FyPdfRow(l10n.fyPdfFees, money(report.totalFees)),
    ],
    netCashFlowLabel: l10n.fyPdfNetCashFlow,
    netCashFlowValue: signed(report.netCashFlow),
    xirrLabel: l10n.fyPdfXirrForYear,
    // XIRR is a fraction (0.114); undefined is a dash, never 0%.
    xirrValue: xirr == null ? '—' : '${(xirr * 100).toStringAsFixed(1)}%',
    monthHeading: l10n.fyPdfByMonth,
    monthHeaders: [
      l10n.fyPdfColMonth,
      l10n.fyPdfColInvested,
      l10n.fyPdfColIncomeReturns,
      l10n.fyPdfColNet,
    ],
    monthRows: [
      for (final m in report.monthlyBreakdown)
        FyPdfMonthRow(
          month: '${m.monthName} ${m.year}',
          invested: money(m.invested),
          incomeAndReturns: money(m.income + m.returns),
          net: signed(m.net),
        ),
    ],
    disclaimer: l10n.fyPdfDisclaimer,
  );
}

/// TTF bytes for the four faces the design uses. Bytes (not fonts) so they
/// can cross into a background isolate.
class FyPdfFontBytes {
  final Uint8List body;
  final Uint8List bodyStrong;
  final Uint8List heading;
  final Uint8List display;

  const FyPdfFontBytes({
    required this.body,
    required this.bodyStrong,
    required this.heading,
    required this.display,
  });
}

const _ink = PdfColor.fromInt(0xFF1C1917);
const _muted = PdfColor.fromInt(0xFF57534E);
const _accent = PdfColor.fromInt(0xFF5B4CDB);
const _accentText = PdfColor.fromInt(0xFF4338CA);
const _ruleStrong = PdfColor.fromInt(0xFFD6D3D1);
const _rule = PdfColor.fromInt(0xFFE7E5E4);

pw.Font _ttf(Uint8List b) => pw.Font.ttf(ByteData.sublistView(b));

/// Lays [c] out on A4. Pure apart from the PDF it returns, so it can run in
/// a background isolate.
Future<Uint8List> renderFyReportPdf(
  FyPdfContent c,
  FyPdfFontBytes fonts,
) async {
  final body = _ttf(fonts.body);
  final strong = _ttf(fonts.bodyStrong);
  final heading = _ttf(fonts.heading);
  final display = _ttf(fonts.display);

  pw.TextStyle text(double size, {pw.Font? font, PdfColor color = _ink}) =>
      pw.TextStyle(font: font ?? body, fontSize: size, color: color);

  pw.Widget h2(String s) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(s, style: text(12, font: heading)),
  );

  pw.Widget cell(
    String s,
    pw.TextStyle style, {
    bool right = false,
    double v = 9,
    PdfColor? line,
    bool head = false,
  }) => pw.Container(
    padding: pw.EdgeInsets.symmetric(vertical: v),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(
          color: line ?? (head ? _ruleStrong : _rule),
          width: 0.75,
        ),
      ),
    ),
    alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    child: pw.Text(s, style: style),
  );

  pw.Widget incomeTable() => pw.Table(
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(3),
    },
    children: [
      pw.TableRow(
        children: [
          cell(
            c.incomeHeaders[0],
            text(9, font: strong, color: _muted),
            v: 6,
            head: true,
          ),
          cell(
            c.incomeHeaders[1],
            text(9, font: strong, color: _muted),
            right: true,
            v: 6,
            head: true,
          ),
        ],
      ),
      for (final r in c.incomeRows)
        pw.TableRow(
          children: [
            cell(r.label, text(10.5), v: 9),
            cell(
              r.value,
              r.isAmount
                  ? text(10.5, font: heading)
                  : text(10.5, color: _muted),
              right: true,
              v: 9,
            ),
          ],
        ),
    ],
  );

  pw.Widget tile(FyPdfRow t) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _rule, width: 0.75),
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(t.label, style: text(9, color: _muted)),
          pw.SizedBox(height: 2),
          pw.Text(t.value, style: text(10.5, font: heading)),
        ],
      ),
    ),
  );

  pw.Widget cashFlow() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        children: [
          for (var i = 0; i < c.tiles.length; i++) ...[
            if (i > 0) pw.SizedBox(width: 9),
            tile(c.tiles[i]),
          ],
        ],
      ),
      pw.SizedBox(height: 9),
      pw.RichText(
        text: pw.TextSpan(
          style: text(10.5),
          children: [
            pw.TextSpan(text: '${c.netCashFlowLabel} '),
            pw.TextSpan(
              text: c.netCashFlowValue,
              style: text(10.5, font: heading),
            ),
            pw.TextSpan(text: ' · ${c.xirrLabel} '),
            pw.TextSpan(
              text: c.xirrValue,
              style: text(10.5, font: heading),
            ),
          ],
        ),
      ),
    ],
  );

  pw.Widget monthTable() => pw.Table(
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(2),
      2: const pw.FlexColumnWidth(2.5),
      3: const pw.FlexColumnWidth(2),
    },
    children: [
      pw.TableRow(
        children: [
          for (var i = 0; i < c.monthHeaders.length; i++)
            cell(
              c.monthHeaders[i],
              text(9, font: strong, color: _muted),
              right: i > 0,
              v: 5,
              head: true,
            ),
        ],
      ),
      for (final m in c.monthRows)
        pw.TableRow(
          children: [
            cell(m.month, text(9.75), v: 6),
            cell(m.invested, text(9.75), right: true, v: 6),
            cell(m.incomeAndReturns, text(9.75), right: true, v: 6),
            cell(m.net, text(9.75), right: true, v: 6),
          ],
        ),
    ],
  );

  final doc = pw.Document(title: c.title, creator: 'InvTrack');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 36),
      footer: (_) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.only(top: 9),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _rule, width: 0.75)),
        ),
        child: pw.Text(
          c.disclaimer,
          style: text(8.25, color: _muted).copyWith(lineSpacing: 2),
        ),
      ),
      build: (_) => [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _accent, width: 1.5),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INVTRACK',
                      style: text(9, font: strong, color: _accentText),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(c.title, style: text(22.5, font: display)),
                    pw.SizedBox(height: 2),
                    pw.Text(c.subtitle, style: text(10.5, color: _muted)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(c.generatedLine, style: text(9, color: _muted)),
                  pw.Text(c.amountsNote, style: text(9, color: _muted)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 21),
        h2(c.incomeHeading),
        incomeTable(),
        pw.SizedBox(height: 21),
        h2(c.cashFlowHeading),
        cashFlow(),
        pw.SizedBox(height: 21),
        h2(c.monthHeading),
        monthTable(),
      ],
    ),
  );
  return doc.save();
}

/// Builds the PDF off the UI isolate and opens the system share sheet.
class FyReportPdfService {
  const FyReportPdfService();

  Future<void> share({
    required FYReport report,
    required AppLocalizations l10n,
    required String baseCurrency,
  }) async {
    final content = buildFyPdfContent(
      report: report,
      l10n: l10n,
      baseCurrency: baseCurrency,
      generatedAt: DateTime.now(),
    );
    final fonts = await _loadFonts();
    final bytes = await Isolate.run(() => renderFyReportPdf(content, fonts));

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/invtrack_tax_year_${report.fyLabel}.pdf';
    await File(path).writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/pdf')],
        subject: '${l10n.fyPdfTitle} ${report.fyLabel}',
      ),
    );
  }

  Future<FyPdfFontBytes> _loadFonts() async {
    Future<Uint8List> load(String f) async =>
        (await rootBundle.load('assets/fonts/$f')).buffer.asUint8List();
    return FyPdfFontBytes(
      body: await load('Inter-Regular.ttf'),
      bodyStrong: await load('Inter-SemiBold.ttf'),
      heading: await load('PlusJakartaSans-Bold.ttf'),
      display: await load('PlusJakartaSans-ExtraBold.ttf'),
    );
  }
}
