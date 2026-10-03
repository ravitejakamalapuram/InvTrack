import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
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
  InvestmentStatus status = InvestmentStatus.open,
  double? expectedRate,
  int? tenureMonths,
  CompoundingFrequency? compounding,
  InterestPayoutMode? payoutMode,
}) {
  return InvestmentEntity(
    id: 'fd-1',
    name: 'Cumulative FD',
    type: InvestmentType.fixedDeposit,
    status: status,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    startDate: DateTime(2026, 1, 1),
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
}
