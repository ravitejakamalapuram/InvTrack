// The hero card's headline is what the user has invested, never a cash-only
// net that is negative for every open holding. The realised scope keeps the
// net, because closed investments really are a profit or a loss.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

/// A new user: ₹5 L put into one FD, nothing back, no value entered.
final _fresh = InvestmentStats(
  totalInvested: 500000,
  totalReturned: 0,
  netCashFlow: -500000,
  absoluteReturn: 0,
  moic: 0,
  xirr: null,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2026, 10, 1),
  lastCashFlowDate: DateTime(2026, 10, 1),
  missingValueCount: 1,
);

/// An open FD with a value, plus a closed deal: ₹6L in, ₹1.12L back.
final _valued = InvestmentStats(
  totalInvested: 600000,
  totalReturned: 112000,
  netCashFlow: -488000,
  absoluteReturn: 4.966795,
  moic: 1.049668,
  xirr: 0.087328923,
  cashFlowCount: 3,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2026, 4, 1),
  currentValue: 517800,
  currentValueDate: DateTime(2026, 10, 2),
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
  WidgetTester tester,
  InvestmentStats stats, {
  bool realized = false,
  bool privacy = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(() => _Privacy(privacy)),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCardContent(
              globalStats: stats,
              openStats: stats,
              closedStats: _closed,
              currencyFormat: _inr,
              showRealizedOnly: realized,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _headline = find.byKey(const ValueKey('hero-headline-amount'));

void main() {
  testWidgets('a new user sees what they invested, not a negative', (
    tester,
  ) async {
    await _pump(tester, _fresh);

    expect(find.text('Invested'), findsOneWidget);
    expect(find.text('Net cash flow so far'), findsNothing);
    expect(
      find.descendant(of: _headline, matching: find.textContaining('₹5 L')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _headline, matching: find.textContaining('-')),
      findsNothing,
    );
  });

  testWidgets('shows the value now when a current value is known', (
    tester,
  ) async {
    await _pump(tester, _valued);
    expect(find.text('Value now'), findsOneWidget);

    await _pump(tester, _fresh);
    expect(find.text('Value now'), findsNothing);
  });

  testWidgets('the screen reader reads the invested headline', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _fresh);
    final labels = <String>[];
    void walk(SemanticsNode n) {
      labels.add(n.label);
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(tester.getSemantics(find.byType(HeroCardContent)));
    expect(labels.any((l) => l.startsWith('Invested:')), isTrue);
    handle.dispose();
  });

  testWidgets('privacy mode hides the invested amount', (tester) async {
    await _pump(tester, _fresh, privacy: true);
    expect(find.textContaining('₹5 L'), findsNothing);
  });

  testWidgets('the realised scope keeps the net profit', (tester) async {
    await _pump(tester, _valued, realized: true);
    expect(find.text('Realized Net Position'), findsOneWidget);
    expect(
      find.descendant(of: _headline, matching: find.textContaining('12,000')),
      findsOneWidget,
    );
  });
}
