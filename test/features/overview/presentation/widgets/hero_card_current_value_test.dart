// A10 (#754, ANLY-01): with current values the hero shows a real portfolio
// XIRR. While any value is estimated it is the "Expected XIRR", shown next
// to the "Realised XIRR" of closed investments.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.value);
  final bool value;
  @override
  bool build() => value;
}

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// CALC-01 S4: closed P2P plus an open ₹5L FD valued at 5,17,800.77.
final _global = InvestmentStats(
  totalInvested: 600000,
  totalReturned: 112000,
  netCashFlow: -488000,
  absoluteReturn: 4.966795,
  moic: 1.049668,
  xirr: 0.087328923,
  cashFlowCount: 3,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2026, 4, 1),
  currentValue: 517800.77,
  currentValueDate: DateTime(2026, 10, 2),
  currentValueIsEstimate: true,
  currentValueRate: 7,
);

final _open = InvestmentStats(
  totalInvested: 500000,
  totalReturned: 0,
  netCashFlow: -500000,
  absoluteReturn: 3.560154,
  moic: 1.035602,
  xirr: 0.071859,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2026, 4, 1),
  lastCashFlowDate: DateTime(2026, 4, 1),
  currentValue: 517800.77,
  currentValueDate: DateTime(2026, 10, 2),
  currentValueIsEstimate: true,
  currentValueRate: 7,
);

final _closed = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 112000,
  netCashFlow: 12000,
  absoluteReturn: 12,
  moic: 1.12,
  xirr: 0.119653256,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2025, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  bool privacy = false,
  Widget? card,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(() => _Privacy(privacy)),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body:
              card ??
              HeroCardContent(
                globalStats: _global,
                openStats: _open,
                closedStats: _closed,
                currencyFormat: _inr,
                showRealizedOnly: false,
              ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _toggleCard(AsyncValue<InvestmentStats> closed) => HeroCardWithToggle(
  globalStats: AsyncData(_global),
  openStats: AsyncData(_open),
  closedStats: closed,
  currencyFormat: _inr,
  errorBuilder: (e) => Text(e),
);

void main() {
  testWidgets('shows Expected and Realised XIRR side by side', (tester) async {
    await _pump(tester);

    expect(find.text('Expected XIRR'), findsOneWidget);
    expect(find.text('8.7%'), findsOneWidget);
    expect(find.text('Realised XIRR'), findsOneWidget);
    expect(find.text('12.0%'), findsOneWidget);
    // The return badge includes the current value: +5.0%, not -81%.
    expect(find.text('+5.0%'), findsOneWidget);
    expect(find.text('Awaiting first payout'), findsNothing);
    expect(find.text('Based on 7% p.a.'), findsOneWidget);
  });

  testWidgets('fits a 360dp-wide phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Realised XIRR'), findsOneWidget);
  });

  testWidgets(
    'keeps net cash flow above awaiting-current-value status on narrow large-text layouts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const awaiting = InvestmentStats(
        totalInvested: 500000,
        totalReturned: 10000,
        netCashFlow: -490000,
        absoluteReturn: -98,
        moic: 0.02,
        xirr: null,
        xirrMethod: XirrMethod.undefined,
        cashFlowCount: 2,
        firstCashFlowDate: DateTime(2024, 1, 1),
        lastCashFlowDate: DateTime(2025, 1, 1),
        missingValueCount: 1,
      );

      await _pump(
        tester,
        card: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: const HeroCardContent(
            globalStats: awaiting,
            openStats: awaiting,
            closedStats: _closed,
            currencyFormat: _inr,
            showRealizedOnly: false,
          ),
        ),
      );

      expect(find.text('Awaiting current value'), findsOneWidget);
      expect(find.byType(CompactAmountText), findsOneWidget);
      expect(
        tester.getRect(find.byType(CompactAmountText)).bottom,
        lessThan(tester.getRect(find.text('Awaiting current value')).top),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('privacy mode hides both XIRRs', (tester) async {
    await _pump(tester, privacy: true);

    expect(find.text('Expected XIRR'), findsOneWidget);
    expect(find.text('Realised XIRR'), findsOneWidget);
    expect(find.text('8.7%'), findsNothing);
    expect(find.text('12.0%'), findsNothing);
  });

  // The expected XIRR must never pass as the realised one.
  testWidgets('no Realised XIRR while closed stats load', (tester) async {
    await _pump(
      tester,
      card: _toggleCard(const AsyncLoading<InvestmentStats>()),
    );

    expect(find.text('Expected XIRR'), findsOneWidget);
    expect(find.text('8.7%'), findsOneWidget);
    expect(find.text('Realised XIRR'), findsNothing);
  });

  testWidgets('no Realised XIRR when closed stats fail', (tester) async {
    await _pump(
      tester,
      card: _toggleCard(
        AsyncError<InvestmentStats>(Exception('x'), StackTrace.empty),
      ),
    );

    expect(find.text('Expected XIRR'), findsOneWidget);
    expect(find.text('Realised XIRR'), findsNothing);
  });

  testWidgets('Realised XIRR once closed stats load', (tester) async {
    await _pump(tester, card: _toggleCard(AsyncData(_closed)));

    expect(find.text('Realised XIRR'), findsOneWidget);
    expect(find.text('12.0%'), findsOneWidget);
  });
}
