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

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget body) async {
  SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
      // The pill is the light green at 15% over the card.
      final pill = composeOver(
        AppColors.successLight.withValues(alpha: 0.15),
        AppColors.cardDark,
      );
      expect(contrastRatio(label, pill), greaterThanOrEqualTo(kMinText));
    });

    testWidgets('in light: unchanged, the light green', (tester) async {
      await _pump(
        tester,
        AppTheme.lightTheme,
        GoalCarouselCard(progress: _achieved()),
      );

      expect(_color(tester, 'Completed'), AppColors.successLight);
    });
  });
}
