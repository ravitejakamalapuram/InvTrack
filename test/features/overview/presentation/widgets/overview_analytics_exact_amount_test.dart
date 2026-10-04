// A13 / ANLY-12: the long-press "exact amount" on the Year over Year and
// Recently Closed cards uses the base-currency symbol and a single sign.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_analytics.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

Future<void> _pump(WidgetTester tester, Widget child, List overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWith((ref) => 'USD'),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final usdFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 0,
  );

  testWidgets('Year over Year: a loss reads -\$5,500.00, not --₹5,500.00', (
    tester,
  ) async {
    await _pump(tester, YoYComparisonCard(currencyFormat: usdFormat), [
      yoyComparisonProvider.overrideWithValue(
        AsyncValue.data(
          YoYComparison(
            thisYearNet: -5500,
            lastYearNet: 0,
            thisYearInvested: 5500,
            lastYearInvested: 0,
            thisYearReturned: 0,
            lastYearReturned: 0,
            periodStart: DateTime(2026, 4, 1),
            periodEnd: DateTime(2026, 10, 5),
            previousPeriodStart: DateTime(2025, 4, 1),
            previousPeriodEnd: DateTime(2025, 10, 5),
          ),
        ),
      ),
    ]);

    // Screen readers still hear the loss.
    expect(
      find.bySemanticsLabel(RegExp(r'negative 5,500(\.00)? dollars')),
      findsOneWidget,
    );

    // The card also shows the amount invested (\$5.5K, no sign); the net
    // cash flow is the signed one.
    await tester.longPress(find.text(r'-$5.5K'));
    await tester.pumpAndSettle();

    expect(find.text(r'-$5,500.00'), findsOneWidget);
    expect(find.textContaining('--'), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('Recently Closed: a loss reads -\$5,500.00 with no ₹', (
    tester,
  ) async {
    final investment = InvestmentEntity(
      id: 'closed',
      name: 'Closed loss',
      type: InvestmentType.stocks,
      status: InvestmentStatus.closed,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await _pump(tester, RecentlyClosedCard(currencyFormat: usdFormat), [
      recentlyClosedInvestmentsProvider.overrideWithValue(
        AsyncValue.data([
          InvestmentWithStats(
            investment: investment,
            stats: const InvestmentStats(
              totalInvested: 10000,
              totalReturned: 4500,
              netCashFlow: -5500,
              absoluteReturn: -55,
              moic: 0.45,
              xirr: -0.55,
              cashFlowCount: 2,
            ),
          ),
        ]),
      ),
    ]);

    // Screen readers still hear the loss.
    expect(
      find.bySemanticsLabel(RegExp(r'negative 5,500(\.00)? dollars')),
      findsOneWidget,
    );

    await tester.longPress(find.textContaining('5.5K'));
    await tester.pumpAndSettle();

    expect(find.text(r'-$5,500.00'), findsOneWidget);
    expect(find.textContaining('--'), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('Recently Closed: a break-even XIRR reads 0.0% IRR; an '
      'undefined one shows no IRR', (tester) async {
    InvestmentWithStats closed(String id, double? xirr) => InvestmentWithStats(
      investment: InvestmentEntity(
        id: id,
        name: 'Closed $id',
        type: InvestmentType.stocks,
        status: InvestmentStatus.closed,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      stats: InvestmentStats(
        totalInvested: 10000,
        totalReturned: 10000,
        netCashFlow: 0,
        absoluteReturn: 0,
        moic: 1,
        xirr: xirr,
        xirrMethod: xirr == null ? XirrMethod.undefined : XirrMethod.exact,
        cashFlowCount: 2,
      ),
    );
    await _pump(tester, RecentlyClosedCard(currencyFormat: usdFormat), [
      recentlyClosedInvestmentsProvider.overrideWithValue(
        AsyncValue.data([closed('even', 0), closed('unknown', null)]),
      ),
    ]);

    expect(find.text('0.0% IRR'), findsOneWidget);
  });
}
