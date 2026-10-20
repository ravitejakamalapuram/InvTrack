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

class _PrivacyOn extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required InvestmentEntity investment,
  required InvestmentStats stats,
  required XirrResult xirr,
  bool privacy = false,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (investment.isArchived) ...[
          // Archived cards read the converted archived stats, XIRR included.
          multiCurrencyArchivedInvestmentStatsProvider(investment.id)
              .overrideWith(
                (ref) async => stats.copyWith(
                  xirr: xirr.value,
                  xirrMethod: xirr.method,
                ),
              ),
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
        privacyModeProvider.overrideWith(
          privacy ? _PrivacyOn.new : _PrivacyOff.new,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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

  // A10 (#754): an XIRR that uses an estimated current value is labelled
  // "Expected XIRR" with its basis until the user confirms the value.
  InvestmentStats valuedStats({required bool isEstimate}) => InvestmentStats(
    totalInvested: 100000,
    totalReturned: 0,
    netCashFlow: -100000,
    absoluteReturn: 7.185903,
    moic: 1.07185903,
    xirr: 0,
    cashFlowCount: 1,
    firstCashFlowDate: DateTime(2025, 10, 2),
    lastCashFlowDate: DateTime(2025, 10, 2),
    currentValue: 107185.90,
    currentValueDate: DateTime(2026, 10, 2),
    currentValueIsEstimate: isEstimate,
    currentValueRate: isEstimate ? 7 : null,
  );

  testWidgets('estimated XIRR is labelled Expected XIRR on the card', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.open),
      stats: valuedStats(isEstimate: true),
      xirr: const XirrResult.exact(0.07185903),
    );

    expect(find.text('+7.2% Expected XIRR'), findsOneWidget);
    expect(find.text('+7.2% IRR'), findsNothing);
    final label = tester.getSemantics(find.byType(GlassCard)).label;
    expect(
      label,
      contains('Returns: expected positive 7.2 percent, Based on 7% p.a.'),
    );
  });

  testWidgets('a confirmed current value keeps the plain IRR label', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.open),
      stats: valuedStats(isEstimate: false),
      xirr: const XirrResult.exact(0.07185903),
    );

    expect(find.text('+7.2% IRR'), findsOneWidget);
    expect(find.textContaining('Expected'), findsNothing);
    final label = tester.getSemantics(find.byType(GlassCard)).label;
    expect(label, contains('Returns: positive 7.2 percent'));
    expect(label, isNot(contains('expected')));
  });

  // #954: an open investment that has returned its cost and has no current
  // value keeps its IRR, labelled "so far", on the card and for screen readers.
  InvestmentStats paidBackStats({int cashOnly = 0}) => InvestmentStats(
    totalInvested: 100000,
    totalReturned: 110000,
    netCashFlow: 10000,
    absoluteReturn: 10,
    moic: 1.1,
    xirr: 0,
    cashFlowCount: 2,
    firstCashFlowDate: DateTime(2023, 1, 1),
    lastCashFlowDate: DateTime(2024, 1, 1),
    cashOnlyCount: cashOnly,
  );

  testWidgets('a paid-back open investment shows its IRR so far', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.open),
      stats: paidBackStats(cashOnly: 1),
      xirr: const XirrResult.exact(0.049),
    );

    expect(find.text('+4.9% IRR so far'), findsOneWidget);
    expect(find.text('+4.9% IRR'), findsNothing);
    final label = tester.getSemantics(find.byType(GlassCard)).label;
    expect(
      label,
      contains(
        'Returns: positive 4.9 percent so far. '
        'Counts money received only, not any value still held.',
      ),
    );
  });

  testWidgets('privacy mode keeps the so-far note but not the figure', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.open),
      stats: paidBackStats(cashOnly: 1),
      xirr: const XirrResult.exact(0.049),
      privacy: true,
    );

    final label = tester.getSemantics(find.byType(GlassCard)).label;
    expect(
      label,
      contains(
        'Returns: Hidden percentage so far. '
        'Counts money received only, not any value still held.',
      ),
    );
    expect(label, isNot(contains('4.9')));
    expect(label, isNot(contains('110')));
    // No amount is drawn (with privacy off the card shows "+₹10,000" and
    // "₹1 L"), and the pill, still in the tree, is invisible.
    expect(find.textContaining('₹'), findsNothing);
    final pillOpacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(GlassCard),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(pillOpacity.opacity, 0.0);
  });

  testWidgets('a short so-far holding says so on the pill', (tester) async {
    final stats = InvestmentStats(
      totalInvested: 100000,
      totalReturned: 100500,
      netCashFlow: 500,
      absoluteReturn: 0.5,
      moic: 1.005,
      xirr: 0,
      cashFlowCount: 2,
      firstCashFlowDate: DateTime(2026, 9, 1),
      lastCashFlowDate: DateTime(2026, 9, 21),
      cashOnlyCount: 1,
    );
    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.open),
      stats: stats,
      xirr: const XirrResult.approximate(0.09),
    );

    expect(find.text('+0.5% in 20 days so far'), findsOneWidget);
    final label = tester.getSemantics(find.byType(GlassCard)).label;
    expect(label, contains('Returns: positive 0.5 percent so far. Counts'));
  });

  // The longest so-far pill must not overflow on a small phone, or with large
  // text. (The card's bottom strip already overflows at 320dp and 1.3x text,
  // with or without a pill, so that size is checked for the pill's own box.)
  for (final (width, scale) in [(320.0, 1.0), (360.0, 1.3)]) {
    testWidgets('the so-far pill fits ${width}dp at ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpCard(
        tester,
        investment: _investment(InvestmentStatus.open),
        stats: paidBackStats(cashOnly: 1),
        xirr: const XirrResult.approximate(0.049),
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('+4.9% approx. IRR so far'), findsOneWidget);
    });
  }

  testWidgets('the so-far pill stays inside the card at 320dp and 1.3x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.open),
      stats: paidBackStats(cashOnly: 1),
      xirr: const XirrResult.approximate(0.049),
      textScale: 1.3,
    );
    // Only the bottom strip overflows (before and after this change).
    tester.takeException();

    final pill = tester.getRect(find.text('+4.9% approx. IRR so far'));
    final card = tester.getRect(find.byType(GlassCard));
    expect(pill.left, greaterThanOrEqualTo(card.left));
    expect(pill.right, lessThanOrEqualTo(card.right));
  });

  testWidgets('a closed card keeps the plain IRR', (tester) async {
    await _pumpCard(
      tester,
      investment: _investment(InvestmentStatus.closed),
      stats: paidBackStats(cashOnly: 1),
      xirr: const XirrResult.exact(0.049),
    );
    expect(find.text('+4.9% IRR'), findsOneWidget);
    expect(find.textContaining('so far'), findsNothing);
    final label = tester.getSemantics(find.byType(GlassCard)).label;
    expect(label, isNot(contains('so far')));
  });
}
