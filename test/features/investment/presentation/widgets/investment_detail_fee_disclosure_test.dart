// A15 (#760, CALC-07): the detail screen says that money out includes fees,
// and, when part of it was reinvested from earlier payouts, that MOIC and
// return % count that money once.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_stats_section.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.on);
  final bool on;

  @override
  bool build() => on;
}

const _feesNote = 'Money out includes fees.';
const _reinvestedNote =
    'Money out includes fees. Reinvested payouts count once in MOIC and '
    'return %.';

final _fd = InvestmentEntity(
  id: 'fd',
  name: 'Renewed FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.closed,
  createdAt: DateTime(2023),
  updatedAt: DateTime(2025),
  currency: 'INR',
);

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

/// Rs10L for a year, renewed for its maturity value of Rs10.75L.
final _rolloverStats = _module.calculateStats([
  _flow('1', CashFlowType.invest, 1000000, DateTime(2023, 1, 1)),
  _flow('2', CashFlowType.returnFlow, 1075000, DateTime(2024, 1, 1)),
  _flow('3', CashFlowType.invest, 1075000, DateTime(2024, 1, 1)),
  _flow('4', CashFlowType.returnFlow, 1155625, DateTime(2025, 1, 1)),
]);

/// Rs1L plus a Rs1,000 fee, Rs1.1L back a year later.
final _plainStats = _module.calculateStats([
  _flow('1', CashFlowType.invest, 100000, DateTime(2024, 1, 1)),
  _flow('2', CashFlowType.fee, 1000, DateTime(2024, 1, 1)),
  _flow('3', CashFlowType.returnFlow, 110000, DateTime(2025, 1, 1)),
]);

Future<void> _pump(
  WidgetTester tester,
  InvestmentStats stats, {
  bool privacy = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [privacyModeProvider.overrideWith(() => _Privacy(privacy))],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: InvestmentDetailStatsSection(
              stats: stats,
              investment: _fd,
              isDark: false,
              currencyFormat: NumberFormat.currency(
                locale: 'en_IN',
                symbol: '₹',
                decimalDigits: 0,
              ),
              isPrivacyMode: privacy,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('says that money out includes fees', (tester) async {
    await _pump(tester, _plainStats);

    expect(find.text(_feesNote), findsOneWidget);
    expect(find.bySemanticsLabel(_feesNote), findsOneWidget);
    expect(find.text(_reinvestedNote), findsNothing);
  });

  testWidgets('a renewed FD says reinvested payouts count once, and shows '
      'MOIC 1.16x rather than 1.08x', (tester) async {
    await _pump(tester, _rolloverStats);

    expect(find.text(_reinvestedNote), findsOneWidget);
    expect(find.bySemanticsLabel(_reinvestedNote), findsOneWidget);
    expect(find.text('1.16x'), findsOneWidget);
    expect(find.text('1.08x'), findsNothing);
    expect(find.text('+15.6%'), findsOneWidget);
  });

  testWidgets('the note has no amounts, so privacy mode still shows it', (
    tester,
  ) async {
    await _pump(tester, _rolloverStats, privacy: true);

    expect(find.text(_reinvestedNote), findsOneWidget);
  });
}
