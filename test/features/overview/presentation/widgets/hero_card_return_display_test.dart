import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/mock_analytics_service.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

class _PrivacyOn extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

Future<void> _pumpHero(
  WidgetTester tester, {
  required InvestmentStats global,
  required InvestmentStats open,
  required InvestmentStats closed,
  required bool realizedOnly,
  bool privacy = false,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(
          privacy ? _PrivacyOn.new : _PrivacyOff.new,
        ),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        // The hero reports xirr_viewed when it shows a real XIRR.
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: HeroCardContent(
            globalStats: global,
            openStats: open,
            closedStats: closed,
            currencyFormat: _inr,
            showRealizedOnly: realizedOnly,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'open investment with only an INVEST flow shows Awaiting first payout '
    'and XIRR dash, never -100% or 0.0%',
    (tester) async {
      // UX-03: one cumulative FD of Rs1,00,000, nothing received yet.
      final investOnly = InvestmentStats(
        totalInvested: 100000,
        totalReturned: 0,
        netCashFlow: -100000,
        absoluteReturn: -100,
        moic: 0,
        xirr: 0,
        xirrMethod: XirrMethod.undefined,
        cashFlowCount: 1,
        firstCashFlowDate: DateTime(2026, 1, 1),
        lastCashFlowDate: DateTime(2026, 1, 1),
      );

      await _pumpHero(
        tester,
        global: investOnly,
        open: investOnly,
        closed: InvestmentStats.empty(),
        realizedOnly: false,
      );

      expect(find.text('Net cash flow so far'), findsOneWidget);
      expect(find.text('Awaiting first payout'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(
        find.text('Add a payout or current value to calculate'),
        findsOneWidget,
      );
      expect(find.text('-100.0%'), findsNothing);
      expect(find.text('0.0%'), findsNothing);
      final semantics = tester.getSemantics(find.byType(HeroCardContent));
      expect(semantics.label, contains('Awaiting first payout'));
      expect(semantics.label, isNot(contains('100 percent')));
    },
  );

  testWidgets('realized view labels an approximate XIRR approx.', (
    tester,
  ) async {
    final closed = InvestmentStats(
      totalInvested: 100000,
      totalReturned: 50000,
      netCashFlow: -50000,
      absoluteReturn: -50,
      moic: 0.5,
      xirr: -0.5258,
      xirrMethod: XirrMethod.approximate,
      cashFlowCount: 3,
      firstCashFlowDate: DateTime(2023, 1, 1),
      lastCashFlowDate: DateTime(2025, 1, 1),
    );

    await _pumpHero(
      tester,
      global: closed,
      open: InvestmentStats.empty(),
      closed: closed,
      realizedOnly: true,
    );

    expect(find.text('-52.6% approx.'), findsOneWidget);
    // Closed investments keep their real return badge.
    expect(find.text('-50.0%'), findsOneWidget);
  });

  // #954: open holdings that returned their cost and have no current value
  // keep their return, labelled "so far".
  InvestmentStats paidBack({int cashOnly = 1, int missing = 0}) =>
      InvestmentStats(
        totalInvested: 1000000,
        totalReturned: 1114000,
        netCashFlow: 114000,
        absoluteReturn: 11.4,
        moic: 1.114,
        xirr: 0.114,
        cashFlowCount: 2,
        firstCashFlowDate: DateTime(2025, 10, 10),
        lastCashFlowDate: DateTime(2026, 10, 10),
        cashOnlyCount: cashOnly,
        missingValueCount: missing,
      );

  testWidgets('shows the return badge, XIRR and screen reader text so far', (
    tester,
  ) async {
    final stats = paidBack();
    await _pumpHero(
      tester,
      global: stats,
      open: stats,
      closed: InvestmentStats.empty(),
      realizedOnly: false,
    );

    expect(find.text('+11.4% so far'), findsOneWidget);
    expect(find.text('XIRR so far'), findsOneWidget);
    expect(find.text('11.4%'), findsOneWidget);
    expect(find.text('XIRR'), findsNothing);
    final label = tester.getSemantics(find.byType(HeroCardContent)).label;
    expect(
      label,
      contains(
        'Return: positive 11.4 percent so far. '
        'Counts money received only, not any value still held.',
      ),
    );
  });

  testWidgets('privacy mode keeps the label but reads no figure', (
    tester,
  ) async {
    final stats = paidBack();
    await _pumpHero(
      tester,
      global: stats,
      open: stats,
      closed: InvestmentStats.empty(),
      realizedOnly: false,
      privacy: true,
    );

    expect(find.text('XIRR so far'), findsOneWidget);
    final label = tester.getSemantics(find.byType(HeroCardContent)).label;
    expect(
      label,
      contains(
        'Return: Hidden percentage so far. '
        'Counts money received only, not any value still held.',
      ),
    );
    expect(label, isNot(contains('11.4')));

    // What a sighted user sees: the net amount is drawn behind the blur and
    // the return badge, which stays in the tree, is faded out.
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('hero-net-cash-flow')),
        matching: find.byType(ImageFiltered),
      ),
      findsOneWidget,
    );
    final badgeOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.text('+11.4% so far'),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(badgeOpacity.opacity, 0.0);
  });

  testWidgets('a holding that still awaits a value wins over so far', (
    tester,
  ) async {
    final stats = paidBack(missing: 1);
    await _pumpHero(
      tester,
      global: stats,
      open: stats,
      closed: InvestmentStats.empty(),
      realizedOnly: false,
    );

    expect(find.text('Awaiting current value'), findsOneWidget);
    expect(find.text('XIRR so far'), findsNothing);
    expect(find.textContaining('% so far'), findsNothing);
  });

  testWidgets('the realized view is final and never so far', (tester) async {
    final stats = paidBack();
    await _pumpHero(
      tester,
      global: stats,
      open: stats,
      closed: stats,
      realizedOnly: true,
    );

    expect(find.text('XIRR'), findsOneWidget);
    expect(find.text('+11.4%'), findsOneWidget);
    expect(find.text('XIRR so far'), findsNothing);
    expect(find.textContaining('% so far'), findsNothing);
  });

  testWidgets('the so-far badge moves below a crore amount instead of '
      'squeezing it, at 320dp and 1.8x text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stats = InvestmentStats(
      totalInvested: 10000000,
      totalReturned: 22345678,
      netCashFlow: 12345678,
      absoluteReturn: 123.45678,
      moic: 2.2345678,
      xirr: 0.05,
      cashFlowCount: 2,
      firstCashFlowDate: DateTime(2024, 1, 1),
      lastCashFlowDate: DateTime(2025, 1, 1),
      cashOnlyCount: 1,
    );
    await _pumpHero(
      tester,
      global: stats,
      open: stats,
      closed: InvestmentStats.empty(),
      realizedOnly: false,
      textScale: 1.8,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('₹1.23 Cr'), findsOneWidget);
    final badge = find.text('+123.5% so far');
    expect(badge, findsOneWidget);
    final amount = tester.getRect(
      find.byKey(const ValueKey('hero-net-cash-flow')),
    );
    expect(tester.getRect(badge).top, greaterThanOrEqualTo(amount.bottom));
  });
}
