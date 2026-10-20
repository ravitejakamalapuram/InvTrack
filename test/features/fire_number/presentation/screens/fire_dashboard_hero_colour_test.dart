// The FIRE hero card is a purple gradient in both themes, so the status badge
// and the progress ring on it are judged against purple, not against the card
// or the page. In light the green text colour got deeper (it reads on white),
// and on purple that would be 1.0:1: invisible. The hero keeps the bright
// green it always had, 2.1:1 to 2.4:1, which is still under 4.5 and is
// recorded as a follow-up for the hero tier; this PR must not make it worse.
//
// The insight card below the hero is on the page, not on purple: its fill and
// the disc behind its icon are tints of the brighter green, and the icon is the
// deeper green. Colour is not the only carrier: the header says "You're ahead
// of schedule!".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_calculation_service.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_dashboard_screen.dart';
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
  FireCalculationResult result,
  Brightness brightness,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
        fireSettingsProvider.overrideWith((ref) => Stream.value(_settings)),
        fireCalculationProvider.overrideWithValue(AsyncValue.data(result)),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FireDashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // 36.6 lakh saved with 60,000 a month: ahead of schedule.
  final ahead = _calculate(corpus: 3660000, savings: 60000);

  test('the scenario is the status the tests name', () {
    expect(ahead.status, FireProgressStatus.ahead);
  });

  testWidgets('in light the badge on the hero keeps the green it always had', (
    tester,
  ) async {
    await _pump(tester, ahead, Brightness.light);

    final label = find.text('Ahead of Schedule');
    expect(label, findsOneWidget, reason: 'the status is written out');
    final color = tester.widget<Text>(label).style!.color!;
    // The shipped green, #10b981, not the deeper text colour.
    expect(color, const Color(0xFF10B981));
    expect(color, AppColors.successTintLight);
    // Why it must stay: the deeper text green, #007a54, on each light stop.
    for (final stop in AppColors.heroGradient.colors) {
      expect(
        contrastRatio(const Color(0xFF007A54), stop),
        lessThan(1.2),
        reason: 'on ${stop.toARGB32()}',
      );
      expect(
        contrastRatio(color, stop),
        greaterThan(2.0),
        reason: 'the shipped green on ${stop.toARGB32()}',
      );
    }
  });

  testWidgets('in dark the badge on the hero is the dark green', (
    tester,
  ) async {
    await _pump(tester, ahead, Brightness.dark);

    final color = tester
        .widget<Text>(find.text('Ahead of Schedule'))
        .style!
        .color!;
    expect(color, AppColors.successDark);
    for (final stop in AppColors.heroGradientDark.colors) {
      expect(
        contrastRatio(color, stop),
        greaterThanOrEqualTo(kMinText),
        reason: 'on ${stop.toARGB32()}',
      );
    }
  });

  testWidgets('in light the insight card is a tint of the brighter green and '
      'its icon the deeper one (fire-insight-disc-light@tint20)', (
    tester,
  ) async {
    await _pump(tester, ahead, Brightness.light);

    expect(find.text("You're ahead!"), findsOneWidget);
    final icon = find.byIcon(Icons.check_circle_outline);
    expect(icon, findsOneWidget);
    expect(tester.widget<Icon>(icon).color, AppColors.successLight);

    final card = tester.widget<GlassCard>(
      find.ancestor(of: icon, matching: find.byType(GlassCard)).first,
    );
    final cardFill = composeOver(card.backgroundColor!, AppColors.cardLight);
    expect(
      cardFill,
      composeOver(
        AppColors.successTintLight.withValues(alpha: 0.08),
        AppColors.cardLight,
      ),
    );
    Color? discFill;
    for (final element
        in find
            .ancestor(of: icon, matching: find.byType(Container))
            .evaluate()) {
      final decoration = (element.widget as Container).decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        discFill = composeOver(decoration.color!, cardFill);
        break;
      }
    }
    expect(
      discFill,
      composeOver(AppColors.successTintLight.withValues(alpha: 0.2), cardFill),
    );
    expect(
      contrastRatio(AppColors.successLight, discFill!),
      greaterThanOrEqualTo(kMinGraphic),
      reason: 'fire-insight-disc-light@tint20',
    );
  });

  // 14 lakh saved and nothing added: behind. The icons beside text are the
  // deeper amber and blue in light; the milestone's ring is a fill and keeps
  // the bright amber.
  final behind = _calculate(corpus: 1402551.73, savings: 0);

  test('the behind scenario is the status the test names', () {
    expect(behind.status, FireProgressStatus.behind);
    expect(behind.nextMilestone, isNotNull);
  });

  testWidgets('in light the icons beside text are the deeper blue and amber, '
      'the ring keeps the bright amber', (tester) async {
    await _pump(tester, behind, Brightness.light);

    Color icon(IconData data) => tester.widget<Icon>(find.byIcon(data)).color!;

    expect(icon(Icons.calendar_today_outlined), AppColors.accentTextLight);
    expect(icon(Icons.savings_outlined), AppColors.warningTextLight);
    // The projected date's icon follows the status; the banner's too.
    expect(icon(Icons.flag_outlined), AppColors.warningTextLight);
    expect(icon(Icons.lightbulb_outline), AppColors.warningTextLight);
    expect(icon(Icons.emoji_events_outlined), AppColors.warningTextLight);
    for (final data in [
      Icons.calendar_today_outlined,
      Icons.savings_outlined,
      Icons.flag_outlined,
      Icons.emoji_events_outlined,
    ]) {
      expect(
        contrastRatio(icon(data), AppColors.cardLight),
        greaterThanOrEqualTo(kMinGraphic),
        reason: '$data on the card',
      );
    }
    expect(
      contrastRatio(
        icon(Icons.emoji_events_outlined),
        AppColors.neutral100Light,
      ),
      greaterThanOrEqualTo(kMinGraphic),
      reason: 'the trophy sits on neutral100',
    );
    // Colour is not the only carrier: the banner says where the plan stands.
    expect(find.text('Behind Schedule'), findsWidgets);
    // The ring is a fill.
    final ring = tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .where((i) => i.strokeWidth == 4)
        .single;
    expect(ring.valueColor!.value, AppColors.warningLight);
  });

  testWidgets('in dark the same icons use the dark values', (tester) async {
    await _pump(tester, behind, Brightness.dark);

    Color icon(IconData data) => tester.widget<Icon>(find.byIcon(data)).color!;

    expect(icon(Icons.calendar_today_outlined), AppColors.accentDark);
    expect(icon(Icons.savings_outlined), AppColors.warningDark);
    expect(icon(Icons.flag_outlined), AppColors.warningDark);
    expect(icon(Icons.emoji_events_outlined), AppColors.warningDark);
  });
}
