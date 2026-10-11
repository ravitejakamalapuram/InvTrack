import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_stats_section.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

class _PrivacyOn extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

InvestmentEntity _investment({
  InvestmentType type = InvestmentType.fixedDeposit,
  InvestmentStatus status = InvestmentStatus.open,
  bool isArchived = false,
  double? currentValue,
  double? expectedRate,
  int? tenureMonths,
  CompoundingFrequency? compounding,
  InterestPayoutMode? payoutMode,
  DateTime? maturityDate,
}) {
  return InvestmentEntity(
    id: 'fd-1',
    name: 'Cumulative FD',
    type: type,
    status: status,
    isArchived: isArchived,
    currentValue: currentValue,
    currentValueDate: currentValue == null ? null : DateTime(2026, 10, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    startDate: DateTime(2026, 1, 1),
    maturityDate: maturityDate,
    expectedRate: expectedRate,
    tenureMonths: tenureMonths,
    compoundingFrequency: compounding,
    interestPayoutMode: payoutMode,
    currency: 'INR',
  );
}

/// What calculateStats returns today for a single INVEST of Rs1,00,000.
final _investOnlyStats = InvestmentStats(
  totalInvested: 100000,
  principal: 100000,
  totalReturned: 0,
  netCashFlow: -100000,
  absoluteReturn: -100,
  moic: 0,
  xirr: 0,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2026, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required InvestmentEntity investment,
  required InvestmentStats stats,
  bool privacy = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        privacyModeProvider.overrideWith(
          privacy ? _PrivacyOn.new : _PrivacyOff.new,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: InvestmentDetailStatsSection(
              stats: stats,
              investment: investment,
              isDark: false,
              currencyFormat: _inr,
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
  group(
    'InvestmentDetailStatsSection for an open investment with no payout',
    () {
      testWidgets(
        'shows Awaiting first payout and dashes, never -100% or 0.0%',
        (tester) async {
          await _pump(
            tester,
            investment: _investment(),
            stats: _investOnlyStats,
          );

          expect(find.text('Awaiting first payout'), findsOneWidget);
          expect(find.text('Net cash flow so far'), findsOneWidget);
          // XIRR and MOIC both show a dash instead of 0.0% / 0.00x.
          expect(find.text('—'), findsNWidgets(2));
          expect(
            find.text('Add a payout or current value to calculate'),
            findsOneWidget,
          );
          expect(find.textContaining('-100'), findsNothing);
          expect(find.text('0.0%'), findsNothing);
          expect(find.text('0.00x'), findsNothing);
        },
      );

      testWidgets(
        'shows the projected maturity value when rate and tenure are known',
        (tester) async {
          // UX-03: Rs1,00,000 at 7% compounded quarterly for 3 years.
          // 100000 * 1.0175^12 = 1,23,143.93; effective rate 7.186% p.a.
          await _pump(
            tester,
            investment: _investment(
              expectedRate: 7,
              tenureMonths: 36,
              compounding: CompoundingFrequency.quarterly,
              payoutMode: InterestPayoutMode.cumulative,
            ),
            stats: _investOnlyStats,
          );

          expect(
            find.text('Projected at maturity ₹1,23,144 (7.19% p.a.)'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'A72: a fee is not compounded as principal (Rs1,23,144, not Rs1,23,760)',
        (tester) async {
          // INVEST Rs1,00,000 + FEE Rs500, 7% quarterly, 36 months:
          // 100000 * 1.0175^12 = 1,23,143.93 (100500 would give 1,23,759.65).
          CashFlowEntity flow(String id, CashFlowType type, double amount) =>
              CashFlowEntity(
                id: id,
                investmentId: 'fd-1',
                date: DateTime(2026, 1, 1),
                type: type,
                amount: amount,
                currency: 'INR',
                createdAt: DateTime(2026, 1, 1),
              );
          final stats = FinancialCalculatorModule().calculateStats([
            flow('1', CashFlowType.invest, 100000),
            flow('2', CashFlowType.fee, 500),
          ]);

          await _pump(
            tester,
            investment: _investment(
              expectedRate: 7,
              tenureMonths: 36,
              compounding: CompoundingFrequency.quarterly,
              payoutMode: InterestPayoutMode.cumulative,
            ),
            stats: stats,
          );

          expect(
            find.text('Projected at maturity ₹1,23,144 (7.19% p.a.)'),
            findsOneWidget,
          );
          expect(find.textContaining('1,23,760'), findsNothing);
        },
      );

      testWidgets(
        'A16: an FD with no compounding chosen is projected quarterly',
        (tester) async {
          // Rs1,00,000 at 7% for 5 years: 100000 * 1.0175^20 = 1,41,477.82
          // (annual compounding would show 1,40,255).
          await _pump(
            tester,
            investment: _investment(
              expectedRate: 7,
              tenureMonths: 60,
              payoutMode: InterestPayoutMode.cumulative,
            ),
            stats: _investOnlyStats,
          );

          expect(
            find.text('Projected at maturity ₹1,41,478 (7.19% p.a.)'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'A16: a 444-day FD set by its maturity date is projected in days',
        (tester) async {
          // 1 Jan 2026 to 21 Mar 2027 is 444 days: 4 quarters, then 79 days
          // simple: 100000 * 1.0175^4 * (1 + 0.07 * 79 / 365) = 1,08,809.84.
          await _pump(
            tester,
            investment: _investment(
              expectedRate: 7,
              compounding: CompoundingFrequency.quarterly,
              payoutMode: InterestPayoutMode.cumulative,
              maturityDate: DateTime(2027, 3, 21),
            ),
            stats: _investOnlyStats,
          );

          expect(
            find.text('Projected at maturity ₹1,08,810 (7.19% p.a.)'),
            findsOneWidget,
          );
        },
      );

      testWidgets('does not project a compounded value for periodic payouts', (
        tester,
      ) async {
        await _pump(
          tester,
          investment: _investment(
            expectedRate: 7,
            tenureMonths: 36,
            compounding: CompoundingFrequency.quarterly,
            payoutMode: InterestPayoutMode.periodic,
          ),
          stats: _investOnlyStats,
        );

        expect(find.textContaining('Projected at maturity'), findsNothing);
      });

      testWidgets('hides the projected amount in privacy mode', (tester) async {
        await _pump(
          tester,
          investment: _investment(
            expectedRate: 7,
            tenureMonths: 36,
            compounding: CompoundingFrequency.quarterly,
            payoutMode: InterestPayoutMode.cumulative,
          ),
          stats: _investOnlyStats,
          privacy: true,
        );

        expect(find.textContaining('1,23,144'), findsNothing);
        expect(find.textContaining('Projected at maturity'), findsNothing);
      });
    },
  );

  group('InvestmentDetailStatsSection return figures', () {
    testWidgets('3-day holding shows +2.0% in 3 days as the primary figure', (
      tester,
    ) async {
      final stats = InvestmentStats(
        totalInvested: 100000,
        totalReturned: 102000,
        netCashFlow: 2000,
        absoluteReturn: 2.0,
        moic: 1.02,
        xirr: 10.126388779444367,
        xirrMethod: XirrMethod.approximate,
        cashFlowCount: 2,
        firstCashFlowDate: DateTime(2026, 1, 1),
        lastCashFlowDate: DateTime(2026, 1, 4),
      );

      await _pump(
        tester,
        investment: _investment(status: InvestmentStatus.closed),
        stats: stats,
      );

      expect(find.text('+2.0% in 3 days'), findsOneWidget);
      expect(find.text('annualised >1000%'), findsOneWidget);
      expect(find.text('0.0%'), findsNothing);
    });

    testWidgets('approximate XIRR is labelled approx.', (tester) async {
      final stats = InvestmentStats(
        totalInvested: 100000,
        totalReturned: 50000,
        netCashFlow: -50000,
        absoluteReturn: -50,
        moic: 0.5,
        xirr: -0.5258,
        xirrMethod: XirrMethod.approximate,
        cashFlowCount: 3,
        firstCashFlowDate: DateTime(2023, 1, 1),
        lastCashFlowDate: DateTime(2025, 1, 1),
      );

      await _pump(
        tester,
        investment: _investment(status: InvestmentStatus.closed),
        stats: stats,
      );

      expect(find.text('-52.6% approx.'), findsOneWidget);
    });

    testWidgets('XIRR above 1000% renders >1000% instead of 0.0%', (
      tester,
    ) async {
      final stats = InvestmentStats(
        totalInvested: 100000,
        totalReturned: 1300000,
        netCashFlow: 1200000,
        absoluteReturn: 1200,
        moic: 13,
        xirr: 12.0,
        cashFlowCount: 2,
        firstCashFlowDate: DateTime(2025, 1, 1),
        lastCashFlowDate: DateTime(2026, 1, 1),
      );

      await _pump(
        tester,
        investment: _investment(status: InvestmentStatus.closed),
        stats: stats,
      );

      expect(find.text('>1000%'), findsOneWidget);
      expect(find.text('0.0%'), findsNothing);
    });

    testWidgets('closed investment that returned nothing still shows -100%', (
      tester,
    ) async {
      final stats = InvestmentStats(
        totalInvested: 100000,
        totalReturned: 0,
        netCashFlow: -100000,
        absoluteReturn: -100,
        moic: 0,
        xirr: -1.0,
        xirrMethod: XirrMethod.approximate,
        cashFlowCount: 2,
        firstCashFlowDate: DateTime(2023, 1, 1),
        lastCashFlowDate: DateTime(2024, 1, 1),
      );

      await _pump(
        tester,
        investment: _investment(status: InvestmentStatus.closed),
        stats: stats,
      );

      expect(find.text('-100.0%'), findsOneWidget);
      expect(find.text('Awaiting first payout'), findsNothing);
    });
  });

  // #954 (owner decision, option 1): the Bhive RBF screenshot of #942. Rs10 L
  // in, Rs11.14 L back after a year, no current value: the figures are
  // cash-only minimums, so they say "so far", and the page hints that a fully
  // paid back investment can be closed.
  group('InvestmentDetailStatsSection returns that are so far (#954)', () {
    final flows = [
      CashFlowEntity(
        id: 'in',
        investmentId: 'fd-1',
        date: DateTime(2025, 10, 10),
        type: CashFlowType.invest,
        amount: 1000000,
        currency: 'INR',
        createdAt: DateTime(2025, 10, 10),
      ),
      CashFlowEntity(
        id: 'out',
        investmentId: 'fd-1',
        date: DateTime(2026, 10, 10),
        type: CashFlowType.returnFlow,
        amount: 1114000,
        currency: 'INR',
        createdAt: DateTime(2026, 10, 10),
      ),
    ];

    /// The stats the app builds: terminal values first, then the one stats
    /// implementation.
    InvestmentStats statsOf(
      InvestmentEntity investment, [
      List<CashFlowEntity>? from,
    ]) {
      final cashFlows = from ?? flows;
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [investment],
        cashFlows: cashFlows,
        asOf: DateTime(2026, 10, 11),
      );
      return FinancialCalculatorModule().calculateStats(
        cashFlows,
        terminalValues: terminal,
      );
    }

    // Rs1,00,000 in, Rs1,02,000 back 3 days later: a short holding that has
    // returned its cost, so its figures are so far and carry subtitles.
    final shortFlows = [
      CashFlowEntity(
        id: 'in',
        investmentId: 'fd-1',
        date: DateTime(2026, 10, 1),
        type: CashFlowType.invest,
        amount: 100000,
        currency: 'INR',
        createdAt: DateTime(2026, 10, 1),
      ),
      CashFlowEntity(
        id: 'out',
        investmentId: 'fd-1',
        date: DateTime(2026, 10, 4),
        type: CashFlowType.returnFlow,
        amount: 102000,
        currency: 'INR',
        createdAt: DateTime(2026, 10, 4),
      ),
    ];

    const soFarNote =
        'so far. Counts money received only, not any value still held.';

    testWidgets('label the XIRR, MOIC and return badge, and hint at closing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final investment = _investment(type: InvestmentType.gold);
      await _pump(tester, investment: investment, stats: statsOf(investment));

      expect(find.text('No current value yet'), findsOneWidget);
      expect(find.text('XIRR so far'), findsOneWidget);
      expect(find.text('+11.4%'), findsOneWidget);
      expect(find.text('MOIC so far'), findsOneWidget);
      expect(find.text('1.11x'), findsOneWidget);
      expect(find.text('+11.4% so far'), findsOneWidget);
      expect(find.text('Fully paid back? Mark it closed'), findsOneWidget);
      expect(find.text('XIRR'), findsNothing);
      expect(find.text('MOIC'), findsNothing);
      expect(find.bySemanticsLabel('XIRR: +11.4% $soFarNote'), findsOneWidget);
      // The visible "1.0y" under the MOIC is read too, before the qualifier.
      expect(
        find.bySemanticsLabel('MOIC: 1.11x, 1.0y $soFarNote'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('keep privacy mode: no figure as text or in semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final investment = _investment(type: InvestmentType.gold);
      await _pump(
        tester,
        investment: investment,
        stats: statsOf(investment),
        privacy: true,
      );

      // The labels and the hint hold no amount, so they stay.
      expect(find.text('XIRR so far'), findsOneWidget);
      expect(find.text('MOIC so far'), findsOneWidget);
      expect(find.text('Fully paid back? Mark it closed'), findsOneWidget);
      expect(find.textContaining('11.4'), findsNothing);
      expect(find.textContaining('1.11'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'11\.4|1\.11|1,114|11\.14')),
        findsNothing,
      );
      // A hidden percentage is announced as one, like the list card and the
      // Overview hero do; the multiple keeps the neutral hidden string.
      expect(
        find.bySemanticsLabel('XIRR: Hidden percentage $soFarNote'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('MOIC: Hidden amount, 1.0y $soFarNote'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('read the subtitle under the return and the MOIC', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final investment = _investment(type: InvestmentType.gold);
      await _pump(
        tester,
        investment: investment,
        stats: statsOf(investment, shortFlows),
      );

      // What is on screen under the figures is part of what is announced.
      expect(find.text('annualised >1000%'), findsOneWidget);
      expect(find.text('<1mo'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Return: +2.0% in 3 days, annualised >1000% $soFarNote',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('MOIC: 1.02x, <1mo $soFarNote'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('hide the short holding return and its subtitle in privacy', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final investment = _investment(type: InvestmentType.gold);
      await _pump(
        tester,
        investment: investment,
        stats: statsOf(investment, shortFlows),
        privacy: true,
      );

      // The annualised hint is a return figure: not shown, not read.
      expect(find.textContaining('annualised'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'2\.0|1\.02|102|1000|annualised')),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel('Return: Hidden percentage $soFarNote'),
        findsOneWidget,
      );
      // The holding period is not an amount, so it stays.
      expect(
        find.bySemanticsLabel('MOIC: Hidden amount, <1mo $soFarNote'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('are not labelled on a closed investment', (tester) async {
      final investment = _investment(
        type: InvestmentType.gold,
        status: InvestmentStatus.closed,
      );
      await _pump(tester, investment: investment, stats: statsOf(investment));

      expect(find.text('XIRR'), findsOneWidget);
      expect(find.text('MOIC'), findsOneWidget);
      expect(find.text('+11.4%'), findsNWidgets(2));
      expect(find.text('XIRR so far'), findsNothing);
      expect(find.text('MOIC so far'), findsNothing);
      expect(find.textContaining('% so far'), findsNothing);
      expect(find.text('Fully paid back? Mark it closed'), findsNothing);
    });

    testWidgets('are not labelled while a holding still awaits a value', (
      tester,
    ) async {
      final investment = _investment(type: InvestmentType.gold);
      final stats = statsOf(investment).copyWith(missingValueCount: 1);
      await _pump(tester, investment: investment, stats: stats);

      expect(find.text('Awaiting current value'), findsOneWidget);
      expect(find.text('XIRR so far'), findsNothing);
      expect(find.text('MOIC so far'), findsNothing);
      expect(find.textContaining('% so far'), findsNothing);
      expect(find.text('Fully paid back? Mark it closed'), findsNothing);
    });

    testWidgets('are not labelled once the investment has a value', (
      tester,
    ) async {
      final investment = _investment(
        type: InvestmentType.gold,
        currentValue: 50000,
      );
      await _pump(tester, investment: investment, stats: statsOf(investment));

      expect(find.text('XIRR'), findsOneWidget);
      expect(find.text('Fully paid back? Mark it closed'), findsNothing);
      expect(find.text('XIRR so far'), findsNothing);
      expect(find.text('MOIC so far'), findsNothing);
      expect(find.textContaining('% so far'), findsNothing);
    });

    testWidgets('keep the label but drop the hint when archived', (
      tester,
    ) async {
      // An archived investment cannot be closed from here.
      final investment = _investment(
        type: InvestmentType.gold,
        isArchived: true,
      );
      await _pump(tester, investment: investment, stats: statsOf(investment));

      expect(find.text('XIRR so far'), findsOneWidget);
      expect(find.text('Fully paid back? Mark it closed'), findsNothing);
    });

    testWidgets('fit a 320dp screen at 1.3x text without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final investment = _investment(type: InvestmentType.gold);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyCodeProvider.overrideWith((ref) => 'INR'),
            privacyModeProvider.overrideWith(_PrivacyOff.new),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: InvestmentDetailStatsSection(
                  stats: statsOf(investment),
                  investment: investment,
                  isDark: false,
                  currencyFormat: _inr,
                  isPrivacyMode: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fully paid back? Mark it closed'), findsOneWidget);
    });
  });
}
