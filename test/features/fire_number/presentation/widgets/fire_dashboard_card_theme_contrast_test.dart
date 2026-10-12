// The FIRE card on Overview and its load-error card paint the status colour of
// the theme they are in. In dark the light status colours (emerald, amber) lose
// their contrast on the dark card as soon as the light values deepen, so the
// dark card reads the dark values.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_calculation_service.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_dashboard_card.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_load_error_card.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_stats_card.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/contrast.dart';

final _asOf = DateTime(2026, 10, 2);

final _settings = FireSettingsEntity(
  id: 'fire',
  monthlyExpenses: 50000,
  birthYear: 1998,
  targetFireAge: 50,
  isSetupComplete: true,
  currency: 'INR',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

FireCalculationResult _calculate({
  required double corpus,
  required double savings,
}) => FireCalculationService().calculate(
  settings: _settings,
  currentPortfolioValue: corpus,
  currentMonthlySavings: savings,
  asOf: _asOf,
  inputs: FireInputsSummary(
    investmentsValue: corpus,
    principalWithoutValue: 0,
    otherAssets: 0,
    savingsSource: MonthlySavingsSource.history,
  ),
);

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  Widget home, {
  FireCalculationResult? result,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
        fireSettingsProvider.overrideWith((ref) => Stream.value(_settings)),
        if (result != null)
          fireCalculationProvider.overrideWithValue(AsyncValue.data(result)),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _fireIcon(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(Icons.local_fire_department)).color!;

Color _text(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

/// The tint behind [text]: the fill of the nearest Container around it that
/// has one, over [ground], the way it is painted.
Color _tintBehind(WidgetTester tester, String text, Color ground) {
  for (final element
      in find
          .ancestor(of: find.text(text), matching: find.byType(Container))
          .evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return composeOver(decoration.color!, ground);
    }
  }
  throw StateError('No filled Container around the text.');
}

/// The fill behind the 24px icon [icon]: the nearest Container around it that
/// has one, over [ground], the way it is painted.
Color _discBehind(WidgetTester tester, IconData icon, Color ground) {
  for (final element
      in find
          .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
          .evaluate()) {
    final decoration = (element.widget as Container).decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return composeOver(decoration.color!, ground);
    }
  }
  throw StateError('No filled Container around the icon.');
}

Color _barFill(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .valueColor!
    .value!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // 36.6 lakh saved with 60,000 a month: ahead of schedule.
  final ahead = _calculate(corpus: 3660000, savings: 60000);
  // 14 lakh saved and nothing added: behind.
  final behind = _calculate(corpus: 1402551.73, savings: 0);

  // 14 lakh saved and 30,000 a month: reaches FIRE by the target age, not
  // sooner.
  final onTrack = _calculate(corpus: 1402551.73, savings: 30000);

  test('the scenarios are the statuses the tests name', () {
    expect(ahead.status, FireProgressStatus.ahead);
    expect(behind.status, FireProgressStatus.behind);
    expect(onTrack.status, FireProgressStatus.onTrack);
  });

  group('FIRE card, ahead of schedule', () {
    testWidgets('in dark: icon, label, bar and percentage use the dark green', (
      tester,
    ) async {
      await _pump(
        tester,
        AppTheme.darkTheme,
        const FireDashboardCard(),
        result: ahead,
      );

      expect(_fireIcon(tester), AppColors.successDark);
      expect(_text(tester, 'Ahead of Schedule'), AppColors.successDark);
      expect(_barFill(tester), AppColors.successDark);
      expect(
        contrastRatio(_text(tester, 'Ahead of Schedule'), AppColors.cardDark),
        greaterThanOrEqualTo(kMinText),
      );
    });

    testWidgets('in light: unchanged, the light green', (tester) async {
      await _pump(
        tester,
        AppTheme.lightTheme,
        const FireDashboardCard(),
        result: ahead,
      );

      expect(_fireIcon(tester), AppColors.successLight);
      expect(_text(tester, 'Ahead of Schedule'), AppColors.successLight);
      expect(_barFill(tester), AppColors.successLight);
    });

    testWidgets(
      'fire-status-ahead-light@tint15: the status chip reaches 4.5 and says it in words',
      (tester) async {
        await _pump(
          tester,
          AppTheme.lightTheme,
          const FireDashboardCard(),
          result: ahead,
        );

        // Colour is not the only carrier: the status is written out.
        final label = _text(tester, 'Ahead of Schedule');
        // The chip is tinted with the old, brighter green. Tinted with the
        // deeper text colour it would be 4.34, under 4.5.
        final tint = _tintBehind(
          tester,
          'Ahead of Schedule',
          AppColors.cardLight,
        );
        expect(
          tint,
          composeOver(
            AppColors.successTintLight.withValues(alpha: 0.15),
            AppColors.cardLight,
          ),
        );
        expect(
          contrastRatio(label, tint),
          greaterThanOrEqualTo(kMinText),
          reason: 'fire-status-ahead-light@tint15',
        );
        expect(
          contrastRatio(_barFill(tester), AppColors.cardLight),
          greaterThanOrEqualTo(kMinGraphic),
          reason: 'the progress bar is a graphic: 3:1',
        );
      },
    );
  });

  group('FIRE card, behind', () {
    testWidgets('in dark: the label is the dark amber and still says Behind', (
      tester,
    ) async {
      await _pump(
        tester,
        AppTheme.darkTheme,
        const FireDashboardCard(),
        result: behind,
      );

      // Colour is not the only carrier: the status is written out.
      expect(_text(tester, 'Behind Schedule'), AppColors.warningDark);
      expect(_fireIcon(tester), AppColors.warningDark);
      expect(_barFill(tester), AppColors.warningDark);
    });

    // In light the icon, the label and the percentage are the deeper amber;
    // the chip is tinted, and the bar filled, with the bright amber.
    for (final (name, result, label, text, bright, id) in [
      (
        'behind',
        behind,
        'Behind Schedule',
        AppColors.warningTextLight,
        AppColors.warningLight,
        'fire-status-behind-light@tint15',
      ),
      (
        'on track',
        onTrack,
        'On Track',
        AppColors.accentTextLight,
        AppColors.accentLight,
        'fire-status-on-track-light@tint15',
      ),
    ]) {
      testWidgets('$name in light: the label reads on its tint ($id)', (
        tester,
      ) async {
        await _pump(
          tester,
          AppTheme.lightTheme,
          const FireDashboardCard(),
          result: result,
        );

        // Colour is not the only carrier: the status is written out.
        expect(_text(tester, label), text);
        expect(_fireIcon(tester), text);
        final tint = _tintBehind(tester, label, AppColors.cardLight);
        expect(
          tint,
          composeOver(bright.withValues(alpha: 0.15), AppColors.cardLight),
        );
        expect(
          contrastRatio(_text(tester, label), tint),
          greaterThanOrEqualTo(kMinText),
          reason: id,
        );
        expect(
          contrastRatio(_fireIcon(tester), AppColors.cardLight),
          greaterThanOrEqualTo(kMinGraphic),
        );
        // The bar is a fill and keeps the bright hue.
        expect(_barFill(tester), bright);
      });
    }
  });

  group('FIRE stats card', () {
    // The icons of the FIRE number and the Barista FIRE number: the deeper
    // blue and amber on a 15% tint of the bright hue.
    for (final (theme, fire, barista) in [
      (
        AppTheme.lightTheme,
        AppColors.accentTextLight,
        AppColors.warningTextLight,
      ),
      (AppTheme.darkTheme, AppColors.accentDark, AppColors.warningDark),
    ]) {
      final isLight = theme.brightness == Brightness.light;
      testWidgets('in ${isLight ? 'light' : 'dark'}: the icons read on their '
          'discs', (tester) async {
        await _pump(
          tester,
          theme,
          FireStatsCard(calculation: behind, currencySymbol: '₹'),
        );

        expect(
          tester.widget<Icon>(find.byIcon(Icons.local_fire_department)).color,
          fire,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.coffee_outlined)).color,
          barista,
        );
        final card = isLight ? AppColors.cardLight : AppColors.cardDark;
        final brightFire = isLight
            ? AppColors.accentLight
            : AppColors.accentDark;
        final brightBarista = isLight
            ? AppColors.warningLight
            : AppColors.warningDark;
        final fireDisc = _discBehind(tester, Icons.local_fire_department, card);
        final baristaDisc = _discBehind(tester, Icons.coffee_outlined, card);
        expect(fireDisc, composeOver(brightFire.withValues(alpha: 0.15), card));
        expect(
          baristaDisc,
          composeOver(brightBarista.withValues(alpha: 0.15), card),
        );
        expect(
          contrastRatio(fire, fireDisc),
          greaterThanOrEqualTo(kMinGraphic),
          reason: isLight ? 'fire-stats-icon-fire-light@tint15' : 'dark',
        );
        expect(
          contrastRatio(barista, baristaDisc),
          greaterThanOrEqualTo(kMinGraphic),
          reason: isLight ? 'fire-stats-icon-barista-light@tint15' : 'dark',
        );
      });
    }
  });

  group('FIRE load-error card', () {
    testWidgets('in dark: the cloud icon is the dark red', (tester) async {
      await _pump(
        tester,
        AppTheme.darkTheme,
        FireLoadErrorCard(onRetry: () {}),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off_rounded));
      expect(icon.color, AppColors.errorDark);
      expect(
        contrastRatio(icon.color!, AppColors.cardDark),
        greaterThanOrEqualTo(kMinGraphic),
      );
    });

    testWidgets('in light: unchanged, the light red', (tester) async {
      await _pump(
        tester,
        AppTheme.lightTheme,
        FireLoadErrorCard(onRetry: () {}),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off_rounded));
      expect(icon.color, AppColors.errorLight);
    });
  });
}
