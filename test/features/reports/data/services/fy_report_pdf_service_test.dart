import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_pdf_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

FYReport _report({double? xirr = 0.114, List<MonthlyFYData>? months}) =>
    FYReport(
      fyStart: DateTime(2025, 4, 1),
      fyEnd: DateTime(2026, 3, 31),
      fyLabel: '2025-26',
      totalInvested: 650000,
      totalReturns: 410000,
      totalIncome: 492000,
      totalFees: 13600,
      netCashFlow: 238400,
      xirr: xirr,
      monthlyBreakdown:
          months ??
          const [
            MonthlyFYData(
              month: 4,
              year: 2025,
              invested: 50000,
              returns: 12400,
              income: 50000,
              fees: 0,
            ),
            MonthlyFYData(
              month: 5,
              year: 2025,
              invested: 0,
              returns: 0,
              income: 18000,
              fees: 0,
            ),
          ],
      topPerformersByReturns: const [],
      topPerformersByXIRR: const [],
      portfolioValueAtStart: 0,
      portfolioValueAtEnd: 0,
      shortTermCapitalGains: 0,
      longTermCapitalGains: 0,
      dividendIncome: 71000,
      interestIncome: 421000,
    );

FyPdfContent _content(FYReport r, {String currency = 'INR'}) =>
    buildFyPdfContent(
      report: r,
      l10n: AppLocalizationsEn(),
      baseCurrency: currency,
      generatedAt: DateTime(2026, 10, 21),
    );

void main() {
  group('buildFyPdfContent', () {
    test('header carries title, FY range, date and base currency note', () {
      final c = _content(_report());
      expect(c.title, 'Tax-Year Report');
      expect(c.subtitle, 'Financial year 2025-26 (1 Apr 2025 to 31 Mar 2026)');
      expect(c.generatedLine, 'Generated 21 Oct 2026');
      expect(c.amountsNote, 'All amounts in ₹ (INR)');
    });

    test('income table lists interest, dividend and no computed gains', () {
      final c = _content(_report());
      expect(c.incomeRows.map((r) => r.label), [
        'Interest income',
        'Dividend income',
        'Capital gains',
      ]);
      expect(c.incomeRows[0].value, '₹4,21,000');
      expect(c.incomeRows[1].value, '₹71,000');
      expect(
        c.incomeRows[2].value,
        'Not calculated (needs sale proceeds and cost)',
      );
      expect(c.incomeRows[2].isAmount, isFalse);
    });

    test(
      'capital gains stay "not calculated" even if the entity has values',
      () {
        final r = _report();
        final withGains = FYReport(
          fyStart: r.fyStart,
          fyEnd: r.fyEnd,
          fyLabel: r.fyLabel,
          totalInvested: r.totalInvested,
          totalReturns: r.totalReturns,
          totalIncome: r.totalIncome,
          totalFees: r.totalFees,
          netCashFlow: r.netCashFlow,
          xirr: r.xirr,
          monthlyBreakdown: r.monthlyBreakdown,
          topPerformersByReturns: const [],
          topPerformersByXIRR: const [],
          portfolioValueAtStart: 0,
          portfolioValueAtEnd: 0,
          shortTermCapitalGains: 999,
          longTermCapitalGains: 1,
          dividendIncome: 1,
          interestIncome: 2,
        );
        expect(_content(withGains).incomeRows[2].isAmount, isFalse);
      },
    );

    test('cash flow tiles and net line use Indian grouping', () {
      final c = _content(_report());
      expect(c.tiles.map((t) => '${t.label}=${t.value}'), [
        'Invested=₹6,50,000',
        'Returned=₹4,10,000',
        'Income=₹4,92,000',
        'Fees=₹13,600',
      ]);
      expect(c.netCashFlowLabel, 'Net cash flow');
      expect(c.netCashFlowValue, '+₹2,38,400');
      expect(c.xirrLabel, 'XIRR for the year');
      expect(c.xirrValue, '11.4%');
    });

    test('negative net cash flow keeps its sign before the symbol', () {
      final r = _report();
      final neg = FYReport(
        fyStart: r.fyStart,
        fyEnd: r.fyEnd,
        fyLabel: r.fyLabel,
        totalInvested: 100,
        totalReturns: 0,
        totalIncome: 0,
        totalFees: 0,
        netCashFlow: -100,
        xirr: -0.052,
        monthlyBreakdown: const [],
        topPerformersByReturns: const [],
        topPerformersByXIRR: const [],
        portfolioValueAtStart: 0,
        portfolioValueAtEnd: 0,
        shortTermCapitalGains: 0,
        longTermCapitalGains: 0,
        dividendIncome: 0,
        interestIncome: 0,
      );
      final c = _content(neg);
      expect(c.netCashFlowValue, '-₹100');
      expect(c.xirrValue, '-5.2%');
    });

    test('null XIRR is an em dash, never 0%', () {
      expect(_content(_report(xirr: null)).xirrValue, '—');
    });

    test('zero net is shown without a sign', () {
      final c = _content(
        _report(
          months: const [
            MonthlyFYData(
              month: 6,
              year: 2025,
              invested: 5,
              returns: 5,
              income: 0,
              fees: 0,
            ),
          ],
        ),
      );
      expect(c.monthRows.single.net, '₹0');
    });

    test('monthly table: invested, income plus returns, signed net', () {
      final c = _content(_report());
      expect(c.monthHeaders, [
        'Month',
        'Invested',
        'Income and returns',
        'Net',
      ]);
      final apr = c.monthRows[0];
      expect(apr.month, 'Apr 2025');
      expect(apr.invested, '₹50,000');
      expect(apr.incomeAndReturns, '₹62,400');
      expect(apr.net, '+₹12,400');
      expect(c.monthRows[1].invested, '₹0');
      expect(c.monthRows[1].net, '+₹18,000');
    });

    test('footer is the not-tax-advice disclaimer', () {
      final c = _content(_report());
      expect(c.disclaimer, contains('It is not tax advice.'));
    });

    test('non-INR base currency uses its own symbol and locale', () {
      final c = _content(_report(), currency: 'USD');
      expect(c.amountsNote, 'All amounts in \$ (USD)');
      expect(c.incomeRows[0].value, '\$421,000');
    });
  });

  group('renderFyReportPdf', () {
    Uint8List font(String f) => File('assets/fonts/$f').readAsBytesSync();

    test('produces a non-empty single-page-or-more PDF document', () async {
      final bytes = await renderFyReportPdf(
        _content(_report()),
        FyPdfFontBytes(
          body: font('Inter-Regular.ttf'),
          bodyStrong: font('Inter-SemiBold.ttf'),
          heading: font('PlusJakartaSans-Bold.ttf'),
          display: font('PlusJakartaSans-ExtraBold.ttf'),
        ),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    });

    test('a 12-month report renders', () async {
      final months = [
        for (var i = 0; i < 12; i++)
          MonthlyFYData(
            month: ((3 + i) % 12) + 1,
            year: i < 9 ? 2025 : 2026,
            invested: 1000.0 * i,
            returns: 0,
            income: 500,
            fees: 1,
          ),
      ];
      final bytes = await renderFyReportPdf(
        _content(_report(months: months)),
        FyPdfFontBytes(
          body: font('Inter-Regular.ttf'),
          bodyStrong: font('Inter-SemiBold.ttf'),
          heading: font('PlusJakartaSans-Bold.ttf'),
          display: font('PlusJakartaSans-ExtraBold.ttf'),
        ),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
