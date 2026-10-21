import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/reporting/metric_value.dart';
import 'package:inv_tracker/core/reporting/report_definition.dart';
import 'package:inv_tracker/core/reporting/report_period.dart';
import 'package:inv_tracker/core/reporting/report_result.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/reports/presentation/providers/period_report_provider.dart';
import 'package:inv_tracker/features/reports/presentation/screens/period_report_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.on);
  final bool on;
  @override
  bool build() => on;
}

ReportResult _result({double invested = 1250, bool withPrevious = true}) =>
    ReportResult(
      definitionId: 'monthly',
      period: ReportPeriod.month(2024, 3),
      baseCurrency: 'INR',
      generatedAt: DateTime(2024, 4, 1),
      totals: {
        ReportMetric.invested: Known(invested),
        ReportMetric.returned: const Known(200),
        ReportMetric.income: const Known(50),
        ReportMetric.fees: const Known(10),
        ReportMetric.netCashFlow: Known(240 - invested),
      },
      previous: withPrevious
          ? {
              ReportMetric.invested: const Known(1000),
              ReportMetric.returned: const Known(0),
              ReportMetric.income: const Known(0),
              ReportMetric.fees: const Known(0),
              ReportMetric.netCashFlow: const Known(-1000),
            }
          : null,
      breakdowns: {
        Breakdown.byInvestmentType: [
          BreakdownRow('fixedDeposit', {
            ReportMetric.netCashFlow: const Known(-1010),
          }),
        ],
        Breakdown.byCurrency: [
          BreakdownRow('INR', {ReportMetric.netCashFlow: const Known(-1010)}),
        ],
      },
      notes: const [
        ReportNote(ReportNoteKind.excludedFlows, 2),
        ReportNote(ReportNoteKind.archivedExcluded, 1),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  ReportResult result, {
  bool privacy = false,
  double width = 320,
  double scale = 1.8,
  bool screen = false,
}) async {
  tester.view.physicalSize = Size(width * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(() => _Privacy(privacy)),
        currencySymbolProvider.overrideWithValue('₹'),
        currencyLocaleProvider.overrideWithValue('en_IN'),
        periodReportProvider.overrideWith((ref, key) async => result),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen
            ? const PeriodReportScreen()
            : Scaffold(
                body: SingleChildScrollView(
                  child: PeriodReportView(result: result),
                ),
              ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows amounts, change and notes', (tester) async {
    await _pump(tester, _result(), scale: 1);
    expect(find.text('₹1,250.00'), findsOneWidget);
    expect(find.text('+25.0% vs previous period'), findsOneWidget);
    // previous returned is 0: no base, so a dash, never 0% or infinity.
    expect(find.text('— vs previous period'), findsNWidgets(3));
    expect(find.textContaining('2 entries are left out'), findsOneWidget);
    expect(
      find.textContaining('1 archived investment is not included'),
      findsOneWidget,
    );
    expect(find.text('Fixed Deposit'), findsOneWidget);
  });

  testWidgets('privacy mode shows no amount anywhere', (tester) async {
    await _pump(tester, _result(), privacy: true, scale: 1);
    expect(find.textContaining('1,250'), findsNothing);
    expect(find.textContaining('1,010'), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('no overflow at 320dp and 1.8x text', (tester) async {
    await _pump(tester, _result());
    expect(tester.takeException(), isNull);
  });

  testWidgets('the screen: no overflow at 320dp 1.8x, 48dp targets', (
    tester,
  ) async {
    await _pump(tester, _result(), screen: true);
    expect(tester.takeException(), isNull);
    for (final f in [
      find.byTooltip('Previous period'),
      find.byType(ChoiceChip).first,
    ]) {
      final size = tester.getSize(f);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('an empty period says so', (tester) async {
    final r = ReportResult(
      definitionId: 'weekly',
      period: ReportPeriod.week(DateTime(2024, 3, 12)),
      baseCurrency: 'INR',
      generatedAt: DateTime(2024, 3, 20),
      totals: {
        for (final m in [ReportMetric.invested, ReportMetric.netCashFlow])
          m: const Known(0),
      },
      breakdowns: const {},
      notes: const [],
    );
    await _pump(tester, r, scale: 1);
    expect(find.text('No activity in this period.'), findsOneWidget);
  });
}
