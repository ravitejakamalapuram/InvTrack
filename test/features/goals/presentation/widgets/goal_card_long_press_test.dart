import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final testGoal = GoalEntity(
    id: 'goal_1',
    name: 'Retirement Fund',
    type: GoalType.targetAmount,
    targetAmount: 1000000,
    currency: 'USD',
    trackingMode: GoalTrackingMode.all,
    icon: 'savings',
    colorValue: (Colors.blue.a.toInt() << 24) | (Colors.blue.r.toInt() << 16) | (Colors.blue.g.toInt() << 8) | Colors.blue.b.toInt(),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );

  final testProgress = GoalProgress(
    goal: testGoal,
    currentAmount: 250000,
    progressPercent: 25,
    monthlyVelocity: 5000,
    monthlyIncome: 0,
    status: GoalStatus.onTrack,
    currentMilestone: GoalMilestone.quarter,
    achievedMilestones: const [GoalMilestone.start, GoalMilestone.quarter],
    linkedInvestmentCount: 3,
    calculatedAt: DateTime.now(),
  );

  testWidgets('long press triggers callback without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
    final prefs = await SharedPreferences.getInstance();

    bool longPressed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currencySymbolProvider.overrideWith((ref) => '\$'),
          currencyLocaleProvider.overrideWith((ref) => 'en_US'),
          multiCurrencyGoalProgressProvider(testGoal.id).overrideWith((ref) => Future.value(testProgress)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GoalCard(
              goal: testGoal,
              onTap: () {},
              onLongPress: () { longPressed = true; },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.longPress(find.byType(GoalCard));
    expect(longPressed, isTrue);
  });
}
