// Goal cards paint the status colours of the theme they are in. In dark the
// light green and red lose their contrast on the dark card once the light
// values deepen, so the cards read the dark values there.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_carousel_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goals_dashboard_card.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/contrast.dart';

final _goal = GoalEntity(
  id: 'house',
  name: 'House',
  type: GoalType.targetAmount,
  targetAmount: 1000000,
  trackingMode: GoalTrackingMode.all,
  icon: '🏠',
  colorValue: 0xFF3B82F6,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  currency: 'INR',
);

GoalProgress _achieved() => GoalProgress(
  goal: _goal,
  currentAmount: 1000000,
  targetAmount: 1000000,
  progressPercent: 100,
  monthlyVelocity: 0,
  monthlyIncome: 0,
  status: GoalStatus.achieved,
  currentMilestone: GoalMilestone.complete,
  achievedMilestones: const [],
  linkedInvestmentCount: 1,
  calculatedAt: DateTime(2026, 10, 4),
);

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  Widget body, {
  GoalsSummary? summary,
}) async {
  SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (summary != null)
          multiCurrencyGoalsSummaryProvider.overrideWith(
            (ref) => Future.value(summary),
          ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
        multiCurrencyGoalProgressProvider(_goal.id).overrideWith(
          (ref) => Future<GoalProgress>.error(Exception('offline')),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: body),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _color(WidgetTester tester, String text) =>
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('the goal card that could not load its progress', () {
    const message = 'Error loading progress';

    testWidgets('in dark: the message is the dark red', (tester) async {
      await _pump(
        tester,
        AppTheme.darkTheme,
        GoalCard(goal: _goal, onTap: () {}),
      );

      expect(_color(tester, message), AppColors.errorDark);
      expect(
        contrastRatio(_color(tester, message), AppColors.cardDark),
        greaterThanOrEqualTo(kMinText),
      );
    });

    testWidgets('in light: unchanged, the light red', (tester) async {
      await _pump(
        tester,
        AppTheme.lightTheme,
        GoalCard(goal: _goal, onTap: () {}),
      );

      expect(_color(tester, message), AppColors.errorLight);
    });
  });

  group('the carousel card of a completed goal', () {
    testWidgets('in dark: Completed is the dark green, readable on its tint', (
      tester,
    ) async {
      await _pump(
        tester,
        AppTheme.darkTheme,
        GoalCarouselCard(progress: _achieved()),
      );

      final label = _color(tester, 'Completed');
      expect(label, AppColors.successDark);
      // The pill's own fill, read from the widget, over the card.
      final pillBox = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Completed'),
              matching: find.byType(Container),
            )
            .first,
      );
      final pillFill = (pillBox.decoration! as BoxDecoration).color!;
      expect(pillFill.a, lessThan(1), reason: 'a tint, not the label ground');
      final pill = composeOver(pillFill, AppColors.cardDark);
      expect(contrastRatio(label, pill), greaterThanOrEqualTo(kMinText));
    });

    testWidgets(
      'goal-completed-light@tint15: Completed is the light green, readable on its tint',
      (tester) async {
        await _pump(
          tester,
          AppTheme.lightTheme,
          GoalCarouselCard(progress: _achieved()),
        );

        final label = _color(tester, 'Completed');
        expect(label, AppColors.successLight);
        // The pill is tinted with the old, brighter green. Tinted with the
        // deeper text colour it would be 4.34, under 4.5.
        final pill = _tintBehind(tester, 'Completed', AppColors.cardLight);
        expect(
          pill,
          composeOver(
            AppColors.successTintLight.withValues(alpha: 0.15),
            AppColors.cardLight,
          ),
        );
        expect(
          contrastRatio(label, pill),
          greaterThanOrEqualTo(kMinText),
          reason: 'goal-completed-light@tint15',
        );
      },
    );
  });

  group('the goals card on the Overview', () {
    final summary = GoalsSummary(
      totalGoals: 2,
      achievedGoals: 1,
      onTrackGoals: 1,
      behindGoals: 0,
      averageProgress: 80,
      completedGoals: [_achieved()],
    );

    testWidgets(
      'goals-achieved-light@tint10: the count is the light green, readable on the page',
      (tester) async {
        await _pump(
          tester,
          AppTheme.lightTheme,
          const GoalsDashboardCard(),
          summary: summary,
        );

        // The count says it in words and digits; colour is not the carrier.
        const text = '1/2 achieved';
        final label = _color(tester, text);
        expect(label, AppColors.successLight);
        // The chip sits in the section header, on the page itself.
        final chip = _tintBehind(tester, text, AppColors.backgroundLight);
        expect(
          chip,
          composeOver(
            AppColors.successTintLight.withValues(alpha: 0.1),
            AppColors.backgroundLight,
          ),
        );
        expect(
          contrastRatio(label, chip),
          greaterThanOrEqualTo(kMinText),
          reason: 'goals-achieved-light@tint10',
        );
      },
    );

    testWidgets('in dark: the count is the dark green', (tester) async {
      await _pump(
        tester,
        AppTheme.darkTheme,
        const GoalsDashboardCard(),
        summary: summary,
      );

      const text = '1/2 achieved';
      expect(_color(tester, text), AppColors.successDark);
      expect(
        contrastRatio(
          _color(tester, text),
          _tintBehind(tester, text, AppColors.backgroundDark),
        ),
        greaterThanOrEqualTo(kMinText),
      );
    });
  });
}
