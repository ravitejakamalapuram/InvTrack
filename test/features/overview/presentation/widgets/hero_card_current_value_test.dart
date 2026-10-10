// A10 (#754, ANLY-01): with current values the hero shows a real portfolio
// XIRR. While any value is estimated it is the "Expected XIRR", shown next
// to the "Realised XIRR" of closed investments.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
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
  double textScale = 1,
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
        // Scale the text on top of the real MediaQuery; never replace it.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        // The overview screen puts the card in a scrolling list, so its
        // height is unbounded there too.
        home: Scaffold(
          body: SingleChildScrollView(
            child:
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
    ),
  );
  await tester.pumpAndSettle();
}

/// A phone as narrow as the smallest supported width.
void _narrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// An open portfolio with no current value: [returned] paid back so far.
InvestmentStats _awaiting({
  required double returned,
  double invested = 500000,
}) => InvestmentStats(
  totalInvested: invested,
  totalReturned: returned,
  netCashFlow: returned - invested,
  absoluteReturn: (returned - invested) / invested * 100,
  moic: returned / invested,
  xirr: null,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: returned == 0 ? 1 : 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2025, 1, 1),
  missingValueCount: 1,
);

Widget _card(InvestmentStats stats) => HeroCardContent(
  globalStats: stats,
  openStats: stats,
  closedStats: _closed,
  currencyFormat: _inr,
  showRealizedOnly: false,
);

/// The net cash-flow figure of the hero card (not the out/in amounts).
final _netAmount = find.byKey(const ValueKey('hero-net-cash-flow'));

/// The semantics label of the node for [finder] and of every node below it.
String _semanticsLabels(WidgetTester tester, Finder finder) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    labels.add(node.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(finder));
  return labels.join(' | ');
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

  testWidgets('awaiting current value keeps the amount above the status '
      'at 320dp and 1.8x text', (tester) async {
    _narrowPhone(tester);

    await _pump(
      tester,
      textScale: 1.8,
      card: _card(_awaiting(returned: 10000)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Awaiting current value'), findsOneWidget);
    // -4,90,000 is shown in lakh, still under the rupee symbol.
    expect(find.text('-₹4.9 L'), findsOneWidget);
    expect(_netAmount, findsOneWidget);
    expect(
      tester.getRect(_netAmount).bottom,
      lessThan(tester.getRect(find.text('Awaiting current value')).top),
    );
    // No fake loss next to an open investment without a value.
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('awaiting first payout keeps the amount above the status '
      'at 320dp and 1.8x text', (tester) async {
    _narrowPhone(tester);

    await _pump(tester, textScale: 1.8, card: _card(_awaiting(returned: 0)));

    expect(tester.takeException(), isNull);
    expect(find.text('Awaiting first payout'), findsOneWidget);
    expect(find.text('Awaiting current value'), findsNothing);
    expect(find.text('-₹5 L'), findsOneWidget);
    expect(
      tester.getRect(_netAmount).bottom,
      lessThan(tester.getRect(find.text('Awaiting first payout')).top),
    );
    // XIRR is a dash, not 0% or -100%.
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('a valued portfolio keeps the return badge beside the amount', (
    tester,
  ) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    final amount = tester.getRect(_netAmount);
    final badge = tester.getRect(find.text('+5.0%'));
    expect(badge.left, greaterThanOrEqualTo(amount.right));
    // Same row: the badge overlaps the amount vertically, it is not below it.
    expect(badge.top, lessThan(amount.bottom));
    expect(find.text('Awaiting current value'), findsNothing);
    expect(find.text('Awaiting first payout'), findsNothing);
  });

  testWidgets('a large negative amount is shown in crore and read aloud as '
      'negative', (tester) async {
    final stats = InvestmentStats(
      totalInvested: 12345678,
      totalReturned: 0,
      netCashFlow: -12345678,
      absoluteReturn: 2.5,
      moic: 1.025,
      xirr: 0.05,
      cashFlowCount: 1,
      firstCashFlowDate: DateTime(2024, 1, 1),
      lastCashFlowDate: DateTime(2024, 1, 1),
      currentValue: 12654320,
      currentValueDate: DateTime(2026, 10, 2),
    );

    await _pump(tester, card: _card(stats));

    expect(tester.takeException(), isNull);
    expect(find.text('-₹1.23 Cr'), findsOneWidget);
    expect(
      _semanticsLabels(tester, find.byType(HeroCardContent)),
      contains('Net cash flow so far: negative 1.23 crore rupees'),
    );
  });

  testWidgets('privacy mode hides the net amount in text and semantics', (
    tester,
  ) async {
    _narrowPhone(tester);

    await _pump(
      tester,
      privacy: true,
      textScale: 1.8,
      card: _card(_awaiting(returned: 10000)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('-₹4.9 L'), findsNothing);
    expect(
      find.descendant(of: _netAmount, matching: find.text('•••••')),
      findsOneWidget,
    );
    final labels = _semanticsLabels(tester, find.byType(HeroCardContent));
    expect(labels, contains('Net cash flow so far: Hidden amount'));
    expect(labels, contains('Return: Awaiting current value'));
    expect(labels, isNot(contains('490000')));
    expect(labels, isNot(contains('lakh')));
    expect(labels, isNot(contains('rupees')));
  });

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
