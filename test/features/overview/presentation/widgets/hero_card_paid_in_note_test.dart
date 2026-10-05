// A15 (#760, CALC-07): the Overview return % is measured on paid-in
// capital, so when payouts were reinvested the hero says why the badge does
// not equal net / money out.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

const _reinvestedNote =
    'Money out includes fees. Reinvested payouts count once in MOIC and '
    'return %.';

CashFlowEntity _flow(String id, CashFlowType type, double amount, DateTime d) =>
    CashFlowEntity(
      id: id,
      investmentId: 'fd',
      date: d,
      type: type,
      amount: amount,
      createdAt: d,
      currency: 'INR',
    );

final _module = FinancialCalculatorModule();

Future<void> _pumpHero(WidgetTester tester, InvestmentStats stats) async {
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
            globalStats: stats,
            openStats: InvestmentStats.empty(),
            closedStats: stats,
            currencyFormat: NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: 0,
            ),
            showRealizedOnly: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a renewed FD explains the +15.6% badge next to gross money '
      'out', (tester) async {
    // Rs10L for a year, renewed for its maturity value of Rs10.75L.
    final stats = _module.calculateStats([
      _flow('1', CashFlowType.invest, 1000000, DateTime(2023, 1, 1)),
      _flow('2', CashFlowType.returnFlow, 1075000, DateTime(2024, 1, 1)),
      _flow('3', CashFlowType.invest, 1075000, DateTime(2024, 1, 1)),
      _flow('4', CashFlowType.returnFlow, 1155625, DateTime(2025, 1, 1)),
    ]);

    await _pumpHero(tester, stats);

    expect(find.text('+15.6%'), findsOneWidget);
    expect(find.text(_reinvestedNote), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Reinvested payouts')), findsWidgets);
  });

  testWidgets('with nothing reinvested the hero shows no note', (tester) async {
    final stats = _module.calculateStats([
      _flow('1', CashFlowType.invest, 100000, DateTime(2024, 1, 1)),
      _flow('2', CashFlowType.returnFlow, 110000, DateTime(2025, 1, 1)),
    ]);

    await _pumpHero(tester, stats);

    expect(find.text('+10.0%'), findsOneWidget);
    expect(find.text(_reinvestedNote), findsNothing);
  });
}
