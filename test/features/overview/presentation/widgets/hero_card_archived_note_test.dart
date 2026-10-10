// A17 / GAP1-01: archived investments are left out of the Overview totals on
// purpose (decision 2026-10-02). The hero says so with a footnote, so the
// numbers are never read as "everything you ever invested".
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

class _PrivacyOn extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

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

final InvestmentStats _stats = FinancialCalculatorModule().calculateStats([
  _flow('1', CashFlowType.invest, 100000, DateTime(2024, 4, 1)),
  _flow('2', CashFlowType.income, 7000, DateTime(2025, 4, 1)),
  _flow('3', CashFlowType.income, 7000, DateTime(2026, 4, 1)),
  _flow('4', CashFlowType.returnFlow, 100000, DateTime(2026, 4, 1)),
]);

Future<void> _pumpHero(
  WidgetTester tester, {
  int archivedCount = 0,
  bool showRealizedOnly = false,
  bool privacy = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(
          privacy ? _PrivacyOn.new : _PrivacyOff.new,
        ),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
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
              showRealizedOnly: showRealizedOnly,
              archivedCount: archivedCount,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('says how many archived investments the totals leave out', (
    tester,
  ) async {
    await _pumpHero(tester, archivedCount: 3);

    expect(find.text('Excludes 3 archived investments'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Excludes 3 archived investments')),
      findsWidgets,
    );
  });

  testWidgets('uses the singular for one archived investment', (tester) async {
    await _pumpHero(tester, archivedCount: 1);

    expect(find.text('Excludes 1 archived investment'), findsOneWidget);
  });

  testWidgets('shows no footnote when nothing is archived', (tester) async {
    await _pumpHero(tester);

    expect(find.textContaining('archived'), findsNothing);
  });

  testWidgets('the realized-only view leaves archived ones out too', (
    tester,
  ) async {
    await _pumpHero(tester, archivedCount: 2, showRealizedOnly: true);

    expect(find.text('Excludes 2 archived investments'), findsOneWidget);
  });

  testWidgets('a count is not an amount: privacy mode keeps the footnote', (
    tester,
  ) async {
    await _pumpHero(tester, archivedCount: 2, privacy: true);

    expect(find.text('Excludes 2 archived investments'), findsOneWidget);
  });
}
