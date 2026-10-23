// A14 / #759: when a total used a cached or last-known exchange rate over 24
// hours old, the hero card carries a small marker saying so. It shows nothing
// otherwise, and never changes a figure.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/mock_analytics_service.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

final InvestmentStats _stats = FinancialCalculatorModule().calculateStats([
  CashFlowEntity(
    id: '1',
    investmentId: 'fd',
    date: DateTime(2024, 4, 1),
    type: CashFlowType.invest,
    amount: 100000,
    createdAt: DateTime(2024, 4, 1),
    currency: 'INR',
  ),
]);

Future<void> _pumpHero(WidgetTester tester, {required bool approximate}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCardContent(
              globalStats: _stats,
              openStats: InvestmentStats.empty(),
              closedStats: _stats,
              currencyFormat: NumberFormat.currency(
                locale: 'en_IN',
                symbol: '₹',
                decimalDigits: 0,
              ),
              showRealizedOnly: false,
              isApproximate: approximate,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const note = 'Some amounts use older exchange rates';

  testWidgets('shows the approximate marker when a rate was approximate', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpHero(tester, approximate: true);

    expect(find.byTooltip(note), findsOneWidget);
    expect(
      find.descendant(
        of: find.byTooltip(note),
        matching: find.byIcon(Icons.info_outline),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(note)), findsWidgets);
    handle.dispose();
  });

  testWidgets('shows no marker when every rate was fresh', (tester) async {
    await _pumpHero(tester, approximate: false);

    expect(find.byTooltip(note), findsNothing);
  });
}
