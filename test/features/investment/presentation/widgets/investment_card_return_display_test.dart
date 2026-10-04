import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required InvestmentEntity investment,
  required InvestmentStats stats,
  required XirrResult xirr,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (investment.isArchived) ...[
          archivedInvestmentBasicStatsProvider(
            investment.id,
          ).overrideWith((ref) => AsyncValue.data(stats)),
          archivedInvestmentXirrProvider(
            investment.id,
          ).overrideWith((ref) => Future.value(xirr)),
        ] else ...[
          investmentBasicStatsProvider(
            investment.id,
          ).overrideWith((ref) => AsyncValue.data(stats)),
          investmentXirrProvider(
            investment.id,
          ).overrideWith((ref) => Future.value(xirr)),
        ],
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyFormatProvider.overrideWith(
          (ref) => NumberFormat.currency(
            locale: 'en_IN',
            symbol: '₹',
            decimalDigits: 0,
          ),
        ),
        currencyCodeProvider.overrideWith((ref) => 'USD'),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InvestmentCard(
            investment: investment,
            isSelectionMode: false,
            isSelected: false,
            onTap: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

InvestmentEntity _investment(
  InvestmentStatus status, {
  bool isArchived = false,
}) => InvestmentEntity(
  id: 'inv-1',
  name: 'Cumulative FD',
  type: InvestmentType.fixedDeposit,
  status: status,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
  isArchived: isArchived,
);

void main() {
  testWidgets(
    'open investment with only an INVEST flow shows Awaiting first payout',
    (tester) async {
      // Basic stats (no XIRR) for a single INVEST of Rs1,00,000, and the XIRR
      // the bulk provider returns for it (undefined: a single cash flow).
      final stats = InvestmentStats(
        totalInvested: 100000,
        totalReturned: 0,
        netCashFlow: -100000,
        absoluteReturn: -100,
        moic: 0,
        xirr: 0,
        cashFlowCount: 1,
        firstCashFlowDate: DateTime(2026, 1, 1),
        lastCashFlowDate: DateTime(2026, 1, 1),
      );

      await _pumpCard(
        tester,
        investment: _investment(InvestmentStatus.open),
        stats: stats,
        xirr: const XirrResult.undefined(XirrUndefinedReason.insufficientFlows),
      );

      expect(find.text('Awaiting first payout'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      final label = tester.getSemantics(find.byType(GlassCard)).label;
      expect(label, contains('Awaiting first payout'));
      expect(label, isNot(contains('percent')));
    },
  );

  testWidgets('open FD with payouts does not show a negative IRR', (
    tester,
  ) async {
    // ANLY-01: Rs10L FD, three quarterly payouts of Rs17,500; the flows alone
    // give about -99.3% XIRR.
    final stats = InvestmentStats(
      totalInvested: 1000000,
      totalReturned: 52500,
      netCashFlow: -947500,
      absoluteReturn: -94.75,
      moic: 0.0525,
      xirr: 0,
      cashFlowCount: 4,
      firstCashFlowDate: DateTime(2026, 1, 1),
      lastCashFlowDate: DateTime(2026, 10, 1),
    );

    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.open),
      stats: stats,
      xirr: const XirrResult.exact(-0.9932),
    );

    expect(find.text('Awaiting current value'), findsOneWidget);
    expect(find.textContaining('-99'), findsNothing);
  });

  testWidgets('3-day holding shows +2.0% in 3 days instead of an annual rate', (
    tester,
  ) async {
    final stats = InvestmentStats(
      totalInvested: 100000,
      totalReturned: 102000,
      netCashFlow: 2000,
      absoluteReturn: 2.0,
      moic: 1.02,
      xirr: 0,
      cashFlowCount: 2,
      firstCashFlowDate: DateTime(2026, 1, 1),
      lastCashFlowDate: DateTime(2026, 1, 4),
    );

    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.closed),
      stats: stats,
      xirr: const XirrResult.approximate(10.126388779444367),
    );

    expect(find.text('+2.0% in 3 days'), findsOneWidget);
  });

  // Two years from -Rs1,00,000 to Rs22,500 back, with the rate taken from the
  // timing-blind fallback rather than a solved root.
  final approxStats = InvestmentStats(
    totalInvested: 100000,
    totalReturned: 22500,
    netCashFlow: -77500,
    absoluteReturn: -77.5,
    moic: 0.225,
    xirr: 0,
    xirrMethod: XirrMethod.undefined,
    cashFlowCount: 2,
    firstCashFlowDate: DateTime(2024, 1, 1),
    lastCashFlowDate: DateTime(2026, 1, 1),
  );

  testWidgets('approximate XIRR is labelled approx. on the card', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.closed),
      stats: approxStats,
      xirr: const XirrResult.approximate(-0.526),
    );

    expect(find.text('-52.6% approx. IRR'), findsOneWidget);
    final label = tester.getSemantics(find.byType(GlassCard)).label;
    expect(label, contains('Returns: approximately'));
  });

  testWidgets('approximate XIRR is labelled approx. on an archived card', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.closed, isArchived: true),
      stats: approxStats,
      xirr: const XirrResult.approximate(-0.526),
    );

    expect(find.text('-52.6% approx. IRR'), findsOneWidget);
  });

  testWidgets('exact XIRR has no approx. label', (tester) async {
    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.closed),
      stats: approxStats,
      xirr: const XirrResult.exact(-0.526),
    );

    expect(find.text('-52.6% IRR'), findsOneWidget);
    expect(find.textContaining('approx'), findsNothing);
  });

  testWidgets('closed investment with a single INVEST flow is not "in under a '
      'day"', (tester) async {
    final stats = InvestmentStats(
      totalInvested: 100000,
      totalReturned: 0,
      netCashFlow: -100000,
      absoluteReturn: -100,
      moic: 0,
      xirr: 0,
      xirrMethod: XirrMethod.undefined,
      cashFlowCount: 1,
      firstCashFlowDate: DateTime(2023, 1, 1),
      lastCashFlowDate: DateTime(2023, 1, 1),
    );

    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.closed),
      stats: stats,
      xirr: const XirrResult.undefined(XirrUndefinedReason.insufficientFlows),
    );

    expect(find.textContaining('under a day'), findsNothing);
    expect(find.textContaining('IRR'), findsNothing);
  });
}
