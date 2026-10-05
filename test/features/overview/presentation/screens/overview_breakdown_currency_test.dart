/// A18 / UX-08: the Net Position Breakdown read every amount as rupees and
/// showed '₹' on long-press, whatever the base currency.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

InvestmentStats _stats(double invested, double returned) => InvestmentStats(
  totalInvested: invested,
  totalReturned: returned,
  netCashFlow: returned - invested,
  absoluteReturn: 0,
  moic: 0,
  xirr: 0,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2025, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 1),
);

void main() {
  testWidgets('a USD user hears the breakdown amounts in dollars', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
    final prefs = await SharedPreferences.getInstance();
    final open = _stats(1500000, 0);
    final closed = _stats(10000, 12500);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          currencyCodeProvider.overrideWith((ref) => 'USD'),
          currencySymbolProvider.overrideWith((ref) => r'$'),
          currencyLocaleProvider.overrideWith((ref) => 'en_US'),
          allInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
          allCashFlowsStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          multiCurrencyGlobalStatsProvider.overrideWith(
            (ref) async => _stats(1510000, 12500),
          ),
          multiCurrencyOpenStatsProvider.overrideWith((ref) async => open),
          multiCurrencyClosedStatsProvider.overrideWith((ref) async => closed),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OverviewScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.scrollUntilVisible(
      find.text('Open Investments'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    final breakdown = find.ancestor(
      of: find.text('Open Investments'),
      matching: find.byType(Column),
    );
    final openAmount = find.descendant(
      of: breakdown.first,
      matching: find.byType(CompactAmountText),
    );

    expect(tester.getSemantics(openAmount).label, 'negative 1,500,000 dollars');
    expect(find.bySemanticsLabel(RegExp('rupees')), findsNothing);
  });
}
