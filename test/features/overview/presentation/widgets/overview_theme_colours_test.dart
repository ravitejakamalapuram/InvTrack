// The Overview paints the colours of the theme it is in. In dark, status text
// and icons use the dark values; a light value there is a shade too dim on the
// dark card, and the contrast PRs make it dimmer. In light nothing changes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
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
  for (final (brightness, success, neutral, error) in [
    (
      Brightness.light,
      AppColors.successLight,
      AppColors.neutral500Light,
      AppColors.errorLight,
    ),
    (
      Brightness.dark,
      AppColors.successDark,
      AppColors.neutral400Dark,
      AppColors.errorDark,
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
        final change = tester.widget<Text>(
          find.textContaining('Income +12.5%'),
        );
        expect(change.style!.color, success);
        if (brightness == Brightness.dark) {
          expect(
            contrastRatio(change.style!.color!, AppColors.cardDark),
            greaterThanOrEqualTo(kMinText),
          );
        }
      });
    });
  }
}
