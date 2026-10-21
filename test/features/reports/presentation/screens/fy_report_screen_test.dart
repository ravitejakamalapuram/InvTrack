// #800: the Tax-Year (FY) report screen. An undefined XIRR reads as an em dash
// with a hint (never 0%), capital gains read "Not calculated", privacy mode
// hides every amount, and the screen survives 320dp at 1.8x text.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:inv_tracker/features/reports/presentation/screens/fy_report_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.on);
  final bool on;

  @override
  bool build() => on;
}

InvestmentEntity _inv(String name) => InvestmentEntity(
  id: name,
  name: name,
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2025, 4, 1),
  updatedAt: DateTime(2025, 4, 1),
  currency: 'INR',
);

FYReport _report({double? xirr = 0.114, double endValue = 1840000}) => FYReport(
  fyStart: DateTime(2025, 4, 1),
  fyEnd: DateTime(2026, 3, 31, 23, 59, 59),
  fyLabel: '2025-26',
  totalInvested: 650000,
  totalReturns: 410000,
  totalIncome: 492000,
  totalFees: 13600,
  netCashFlow: 238400,
  xirr: xirr,
  monthlyBreakdown: [
    for (final m in [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3])
      MonthlyFYData(
        month: m,
        year: m >= 4 ? 2025 : 2026,
        invested: 0,
        returns: 0,
        income: m == 1 ? 46200 : 20000,
        fees: 0,
      ),
  ],
  topPerformersByReturns: [
    InvestmentWithReturns(
      investment: _inv('Fixed deposit, Bank A'),
      absoluteReturns: 32400,
      xirr: 0.081,
      percentageGain: 8,
    ),
    InvestmentWithReturns(
      investment: _inv('P2P lending, Platform B'),
      absoluteReturns: 21900,
      xirr: null,
      percentageGain: 6,
    ),
  ],
  topPerformersByXIRR: const [],
  portfolioValueAtStart: 1500000,
  portfolioValueAtEnd: endValue,
  shortTermCapitalGains: 0,
  longTermCapitalGains: 0,
  dividendIncome: 71000,
  interestIncome: 421000,
);

Future<void> _pump(
  WidgetTester tester,
  FYReport report, {
  bool privacy = false,
  double scale = 1.0,
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWithValue('INR'),
        privacyModeProvider.overrideWith(() => _Privacy(privacy)),
        fyReportProvider.overrideWith((ref, year) async => report),
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
        home: const FyReportScreen(initialFyYear: 2025),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the hero, tiles, tax card, performers and disclaimer', (
    tester,
  ) async {
    await _pump(tester, _report());

    expect(find.text('Tax-Year Report'), findsOneWidget);
    expect(find.text('FY 2025-26'), findsOneWidget);
    expect(find.textContaining('2,38,400'), findsOneWidget);
    expect(find.text('11.4%'), findsOneWidget);
    expect(find.textContaining('6,50,000'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('not tax advice'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('For your tax filing'), findsOneWidget);
    expect(find.textContaining('4,21,000'), findsOneWidget);
    expect(find.text('Fixed deposit, Bank A'), findsOneWidget);
    expect(find.textContaining('It is not tax advice'), findsOneWidget);
  });

  testWidgets('null XIRR is an em dash with a hint, never 0%', (tester) async {
    await _pump(tester, _report(xirr: null));

    expect(find.text('—'), findsWidgets);
    expect(
      find.textContaining('Add a current value to calculate'),
      findsOneWidget,
    );
    expect(find.textContaining('0%'), findsNothing);
    expect(find.textContaining('0.0%'), findsNothing);
  });

  testWidgets('capital gains read Not calculated, not an amount', (
    tester,
  ) async {
    await _pump(tester, _report());
    await tester.scrollUntilVisible(
      find.text('Not calculated'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Not calculated'), findsOneWidget);
  });

  testWidgets('privacy mode hides every amount', (tester) async {
    await _pump(tester, _report(), privacy: true);
    await tester.scrollUntilVisible(
      find.textContaining('not tax advice'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    for (final amount in [
      '2,38,400',
      '6,50,000',
      '4,10,000',
      '4,92,000',
      '13,600',
      '4,21,000',
      '71,000',
      '32,400',
      '46,200',
    ]) {
      expect(
        find.textContaining(amount, skipOffstage: false),
        findsNothing,
        reason: '$amount must be masked',
      );
    }
  });

  testWidgets('no overflow at 320dp and 1.8x text; targets are 48dp', (
    tester,
  ) async {
    await _pump(tester, _report(), scale: 1.8, size: const Size(320, 700));
    expect(tester.takeException(), isNull);

    for (final chip in ['FY 2025-26']) {
      expect(
        tester
            .getSize(
              find
                  .ancestor(of: find.text(chip), matching: find.byType(InkWell))
                  .first,
            )
            .height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(
      tester.getSize(find.byTooltip('Hide amounts')).shortestSide,
      greaterThanOrEqualTo(48),
    );
  });
}
