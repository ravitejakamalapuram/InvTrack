import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';

void main() {
  testWidgets('GoalCard handles missing AppLocalizations gracefully (test-crash-1)', (tester) async {
    final testGoal = GoalEntity(
      id: 'goal_1',
      name: 'Retirement Fund',
      type: GoalType.targetAmount,
      targetAmount: 1000000,
      currency: 'USD',
      trackingMode: GoalTrackingMode.all,
      icon: 'savings',
      colorValue: 0xFF2196F3,
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
      achievedMilestones: [GoalMilestone.start, GoalMilestone.quarter],
      linkedInvestmentCount: 3,
      calculatedAt: DateTime.now(),
    );

    SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
    final prefs = await SharedPreferences.getInstance();

    // Pump widget WITHOUT localizations delegates
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currencySymbolProvider.overrideWith((ref) => '\$'),
          currencyLocaleProvider.overrideWith((ref) => 'en_US'),
          multiCurrencyGoalProgressProvider(
            testGoal.id,
          ).overrideWith((ref) => Future.value(testProgress)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: GoalCard(goal: testGoal, onTap: () {}),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Test should pass without NullPointerException, and widget should be successfully mounted
    expect(find.byType(GoalCard), findsOneWidget);

    // In missing locale, the name of the goal should still be visible
    expect(find.text('Retirement Fund'), findsOneWidget);
  });
}
