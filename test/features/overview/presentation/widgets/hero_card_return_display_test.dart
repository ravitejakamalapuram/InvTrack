import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
}
