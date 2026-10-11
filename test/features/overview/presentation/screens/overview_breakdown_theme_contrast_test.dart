// The Net Position Breakdown on the Overview paints the closed investments in
// the green for a gain and the red for a loss: the icon and the figure in the
// theme's colour, the tile behind them in a 10% tint of the brighter hue, so
// the figure keeps 4.5:1 on it. Colour is not the only carrier: the figure
// starts with + or -.
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/contrast.dart';
import '../../../../mocks/mock_analytics_service.dart';

// Demo figures only.
InvestmentStats _stats(double invested, double returned) => InvestmentStats(
  totalInvested: invested,
  totalReturned: returned,
  netCashFlow: returned - invested,
  absoluteReturn: 0,
  moic: 0,
  xirr: 0,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2025, 1, 1),
  lastCashFlowDate: DateTime(2026, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required InvestmentStats closed,
  required Brightness brightness,
}) async {
  SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
        allInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
        allCashFlowsStreamProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        multiCurrencyGlobalStatsProvider.overrideWith(
          (ref) async => _stats(1510000, 12500),
        ),
        multiCurrencyOpenStatsProvider.overrideWith(
          (ref) async => _stats(1500000, 0),
        ),
        multiCurrencyClosedStatsProvider.overrideWith((ref) async => closed),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OverviewScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.scrollUntilVisible(
    find.text('Closed (Realized)'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

/// The closed tile: the nearest Container around its label that has a fill.
Finder _closedTile() => find
    .ancestor(
      of: find.text('Closed (Realized)'),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color != null,
      ),
    )
    .first;

void main() {
  for (final (name, closed, sign, id, lightText, lightTint, darkText) in [
    (
      'a gain',
      _stats(10000, 12500),
      '+',
      'overview-breakdown-success-light@tint10',
      AppColors.successLight,
      AppColors.successTintLight,
      AppColors.successDark,
    ),
    (
      'a loss',
      _stats(10000, 8000),
      '-',
      'overview-breakdown-danger-light@tint10',
      AppColors.errorLight,
      AppColors.dangerTintLight,
      AppColors.errorDark,
    ),
  ]) {
    for (final isDark in [false, true]) {
      final theme = isDark ? 'dark' : 'light';
      final card = isDark ? AppColors.cardDark : AppColors.cardLight;
      final text = isDark ? darkText : lightText;

      testWidgets('closed $name in $theme: figure and icon read on the tile'
          '${isDark ? '' : ' ($id)'}', (tester) async {
        await _pump(
          tester,
          closed: closed,
          brightness: isDark ? Brightness.dark : Brightness.light,
        );

        final tile = _closedTile();
        final fill =
            ((tester.widget<Container>(tile)).decoration! as BoxDecoration)
                .color!;
        // Light: the tile is tinted with the brighter hue, the figure on it is
        // the deeper colour. Tinted with the figure's own colour, it would
        // fall under 4.5.
        final ground = composeOver(
          fill,
          isDark ? AppColors.cardDark : AppColors.cardLight,
        );
        expect(
          ground,
          composeOver(
            (isDark ? darkText : lightTint).withValues(alpha: 0.1),
            card,
          ),
        );

        final figure = tester.widget<CompactAmountText>(
          find.descendant(of: tile, matching: find.byType(CompactAmountText)),
        );
        expect(figure.style!.color, text);
        expect(figure.prefix, sign, reason: 'the figure starts with $sign');
        expect(
          contrastRatio(text, ground),
          greaterThanOrEqualTo(kMinText),
          reason: isDark ? 'overview-breakdown-dark' : id,
        );
        final icon = tester.widget<Icon>(
          find.descendant(of: tile, matching: find.byIcon(Icons.check_circle)),
        );
        expect(icon.color, text);
        expect(
          contrastRatio(icon.color!, ground),
          greaterThanOrEqualTo(kMinGraphic),
        );
      });
    }
  }
}
