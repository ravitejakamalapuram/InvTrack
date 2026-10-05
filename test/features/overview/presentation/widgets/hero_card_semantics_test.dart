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

class _PrivacyOn extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

/// A closed investment: ₹1,00,00,000 in, ₹99,94,999 net out, so the hero
/// shows a net position of -₹99.95 L (intl printed '-₹0.999Cr').
final _stats = InvestmentStats(
  totalInvested: 10000000,
  totalReturned: 5001,
  netCashFlow: -9994999,
  absoluteReturn: -99.95,
  moic: 0.0005,
  xirr: 0,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2025, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 1),
);

Future<void> _pump(WidgetTester tester, {required bool privacy}) async {
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
          body: HeroCardContent(
            globalStats: _stats,
            openStats: InvestmentStats.empty(),
            closedStats: _stats,
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
  testWidgets('shows and reads the net position in lakh', (tester) async {
    await _pump(tester, privacy: false);

    expect(find.text('-₹99.95 L'), findsOneWidget);
    expect(find.textContaining('0.999'), findsNothing);
    final label = tester.getSemantics(find.byType(HeroCardContent)).label;
    expect(label, contains('Net cash flow so far: negative 99.95 lakh rupees'));
  });

  testWidgets('privacy mode hides the amount from the screen reader too', (
    tester,
  ) async {
    await _pump(tester, privacy: true);

    expect(find.text('-₹99.95 L'), findsNothing);
    final label = tester.getSemantics(find.byType(HeroCardContent)).label;
    expect(label, contains('Net cash flow so far: Hidden amount'));
    expect(label, contains('Return: Hidden percentage'));
    expect(label, isNot(contains('lakh')));
    expect(label, isNot(contains('99')));
  });
}
