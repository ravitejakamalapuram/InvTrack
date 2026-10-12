// The Overview paints the colours of the theme it is in. In dark, status text
// and icons use the dark values; a light value there is a shade too dim on the
// dark card. In light the green and red are the deeper values that read on
// white, and anything tinted with them (the MOIC tile, the income pill) is
// tinted with the brighter hue, so the pale fills keep their look.
//
// The Cash In and Out chart is the one place that paints fills, not text: its
// bars and the legend swatches under them are one colour per series, so a
// colour PR that changes the swatch has to change the bar with it. In light
// the bars are solid: 70% of the deeper green is 3.07:1 on the card, and a
// tint of it is not allowed (the tints are made of the brighter hue).
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_analytics.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_quick_stats.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/contrast.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Brightness brightness, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        ...overrides,
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Demo figures only: Rs1,00,000 in, Rs1,25,000 back.
final _closed = InvestmentStats(
  totalInvested: 100000,
  totalReturned: 125000,
  netCashFlow: 25000,
  absoluteReturn: 25,
  moic: 1.25,
  xirr: 0.118,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2024, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 1),
);

CashFlowEntity _income(double amount, DateTime date) => CashFlowEntity(
  id: 'income-${date.toIso8601String()}',
  investmentId: 'inv',
  type: CashFlowType.income,
  amount: amount,
  currency: 'INR',
  date: date,
  createdAt: date,
);

// Rs10,00,000 in an open FD with no payout yet.
final _awaiting = InvestmentStats(
  totalInvested: 1000000,
  totalReturned: 0,
  netCashFlow: -1000000,
  absoluteReturn: -100,
  moic: 0,
  xirr: null,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 1,
  firstCashFlowDate: DateTime(2026, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 1),
);

void main() {
  for (final (
        brightness,
        success,
        neutral,
        error,
        successTint,
        cardGround,
        cashOutId,
        cashInId,
      )
      in [
        (
          Brightness.light,
          AppColors.successLight,
          AppColors.neutral500Light,
          AppColors.errorLight,
          AppColors.successTintLight,
          AppColors.cardLight,
          'overview-cash-out-bar-light@card',
          'overview-cash-in-bar-light@card',
        ),
        (
          Brightness.dark,
          AppColors.successDark,
          AppColors.neutral400Dark,
          AppColors.errorDark,
          AppColors.successDark,
          AppColors.cardDark,
          'overview-cash-out-bar-dark@card',
          'overview-cash-in-bar-dark@card',
        ),
      ]) {
    group('in $brightness', () {
      testWidgets('the MOIC tile icon is the success colour', (tester) async {
        await _pump(
          tester,
          OverviewQuickStats(
            stats: _closed,
            openStats: InvestmentStats.empty(),
          ),
          brightness,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.trending_up)).color,
          success,
        );
      });

      testWidgets('the MOIC tile disc is tinted with the brighter hue', (
        tester,
      ) async {
        await _pump(
          tester,
          OverviewQuickStats(
            stats: _closed,
            openStats: InvestmentStats.empty(),
          ),
          brightness,
        );
        final disc = tester.widget<Container>(
          find
              .ancestor(
                of: find.byIcon(Icons.trending_up),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Container &&
                      w.decoration is BoxDecoration &&
                      (w.decoration! as BoxDecoration).color != null,
                ),
              )
              .first,
        );
        expect(
          (disc.decoration! as BoxDecoration).color,
          successTint.withValues(alpha: 0.1),
        );
      });

      testWidgets('an awaiting MOIC tile icon is the muted grey', (
        tester,
      ) async {
        await _pump(
          tester,
          OverviewQuickStats(stats: _awaiting, openStats: _awaiting),
          brightness,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.trending_up)).color,
          neutral,
        );
      });

      testWidgets('the load-error icon is the error colour', (tester) async {
        await _pump(tester, OverviewLoadErrorState(onRetry: () {}), brightness);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.cloud_off_rounded)).color,
          error,
        );
      });

      testWidgets('a rise in income is the success colour', (tester) async {
        await _pump(
          tester,
          YoYComparisonCard(
            currencyFormat: NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: 0,
            ),
          ),
          brightness,
          overrides: [
            currencyCodeProvider.overrideWith((ref) => 'INR'),
            convertedCashFlowsProvider.overrideWithValue(
              AsyncValue.data([
                _income(8000, DateTime(2025, 8, 1)),
                _income(9000, DateTime(2026, 8, 1)),
              ]),
            ),
            valuationDateProvider.overrideWithValue(DateTime(2026, 10, 4)),
          ],
        );
        final label = find.textContaining('Income +12.5%');
        final change = tester.widget<Text>(label);
        expect(change.style!.color, success);
        // The pill is tinted with the brighter hue; the label on it reads 4.5.
        final pill = tester.widget<Container>(
          find
              .ancestor(
                of: label,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Container &&
                      w.decoration is BoxDecoration &&
                      (w.decoration! as BoxDecoration).color != null,
                ),
              )
              .first,
        );
        final fill = (pill.decoration! as BoxDecoration).color!;
        expect(fill, successTint.withValues(alpha: 0.1));
        expect(
          contrastRatio(change.style!.color!, composeOver(fill, cardGround)),
          greaterThanOrEqualTo(kMinText),
          reason: brightness == Brightness.dark
              ? 'income pill in dark'
              : 'yoy-pill-success-light@tint10',
        );
        // Colour is not the only carrier: the label has the sign and the icon
        // points up.
        expect(find.byIcon(Icons.trending_up), findsWidgets);
      });

      testWidgets(
        'the Cash Out and Cash In bars and swatches follow the theme',
        (tester) async {
          await _pump(
            tester,
            MonthlyCashFlowTrend(
              currencyFormat: NumberFormat.currency(
                locale: 'en_IN',
                symbol: '₹',
                decimalDigits: 0,
              ),
            ),
            brightness,
            overrides: [
              monthlyCashFlowTrendProvider.overrideWithValue(
                AsyncValue.data([
                  MonthlyCashFlowData(
                    month: DateTime(2026, 9, 1),
                    inflows: 8000,
                    outflows: 5000,
                  ),
                ]),
              ),
            ],
          );
          List<Color> fills(bool Function(Container) isIt) => [
            for (final w in tester.widgetList<Container>(
              find.byType(Container),
            ))
              if (isIt(w)) (w.decoration! as BoxDecoration).color!,
          ];
          // Outflows first, then inflows; the legend lists Cash Out, Cash In.
          final bars = fills(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration! as BoxDecoration).borderRadius ==
                    const BorderRadius.vertical(top: Radius.circular(4)),
          );
          final swatches = fills(
            (c) =>
                c.decoration is BoxDecoration &&
                c.constraints == BoxConstraints.tightFor(width: 12, height: 12),
          );
          // Dark bars are 70% of the dark colour; light bars are solid.
          final alpha = brightness == Brightness.dark ? 0.7 : 1.0;
          expect(bars, [
            error.withValues(alpha: alpha),
            success.withValues(alpha: alpha),
          ]);
          expect(swatches, [error, success]);
          // A data graphic needs 3:1 against the card it is drawn on, in both
          // themes; the swatch is the bar's colour without the alpha.
          for (final (id, fill) in [
            (cashOutId, bars[0]),
            (cashInId, bars[1]),
            (cashOutId, swatches[0]),
            (cashInId, swatches[1]),
          ]) {
            expect(
              contrastRatio(fill, cardGround),
              greaterThanOrEqualTo(kMinGraphic),
              reason: id,
            );
          }
        },
      );
    });
  }
}
