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

void main() {
  group('GoalCard Multi-Currency Tests', () {
    final testGoal = GoalEntity(
      id: 'goal_1',
      name: 'Retirement Fund',
      type: GoalType.targetAmount,
      targetAmount: 1000000,
      currency: 'USD',
      trackingMode: GoalTrackingMode.all,
      icon: 'savings',
      colorValue: Colors.blue.value,
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

    testWidgets('displays goal progress message with correct currency symbol',
        (tester) async {
      // Mock SharedPreferences for privacy mode
      SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currencySymbolProvider.overrideWith((ref) => '\$'),
            currencyLocaleProvider.overrideWith((ref) => 'en_US'),
            // Override the multi-currency provider that GoalCard actually uses
            multiCurrencyGoalProgressProvider(testGoal.id).overrideWith(
              (ref) => Future.value(testProgress),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: GoalCard(
                goal: testGoal,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify progress message shows USD symbol
      expect(find.textContaining('\$250K of \$1M'), findsOneWidget);
    });

    testWidgets('shows progress with locale-aware formatting (Indian locale)',
        (tester) async {
      // Mock SharedPreferences for privacy mode
      SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currencySymbolProvider.overrideWith((ref) => '₹'),
            currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
            multiCurrencyGoalProgressProvider(testGoal.id).overrideWith(
              (ref) => Future.value(testProgress),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: GoalCard(
                goal: testGoal,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify progress message shows Indian notation (L for lakhs)
      expect(find.textContaining('₹2.5L of ₹10L'), findsOneWidget);
    });

    testWidgets('shows progress with locale-aware formatting (Western locale)',
        (tester) async {
      // Mock SharedPreferences for privacy mode
      SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currencySymbolProvider.overrideWith((ref) => '€'),
            currencyLocaleProvider.overrideWith((ref) => 'de_DE'),
            multiCurrencyGoalProgressProvider(testGoal.id).overrideWith(
              (ref) => Future.value(testProgress),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: GoalCard(
                goal: testGoal,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widget renders successfully with German locale
      // The GoalCard should render without errors
      expect(find.byType(GoalCard), findsOneWidget);

      // Verify the goal name is displayed
      expect(find.text('Retirement Fund'), findsOneWidget);
    });

    testWidgets('shows correct progress percentage', (tester) async {
      // Mock SharedPreferences for privacy mode
      SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currencySymbolProvider.overrideWith((ref) => '\$'),
            currencyLocaleProvider.overrideWith((ref) => 'en_US'),
            multiCurrencyGoalProgressProvider(testGoal.id).overrideWith(
              (ref) => Future.value(testProgress),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: GoalCard(
                goal: testGoal,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify progress percentage is shown
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('handles income goals with monthly amounts', (tester) async {
      final incomeGoal = testGoal.copyWith(
        type: GoalType.incomeTarget,
        targetMonthlyIncome: 10000,
      );

      final incomeProgress = GoalProgress(
        goal: incomeGoal,
        currentAmount: 0,
        progressPercent: 25,
        monthlyVelocity: 0,
        monthlyIncome: 2500,
        status: GoalStatus.onTrack,
        currentMilestone: GoalMilestone.quarter,
        achievedMilestones: [GoalMilestone.start, GoalMilestone.quarter],
        linkedInvestmentCount: 3,
        calculatedAt: DateTime.now(),
      );

      // Mock SharedPreferences for privacy mode
      SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currencySymbolProvider.overrideWith((ref) => '\$'),
            currencyLocaleProvider.overrideWith((ref) => 'en_US'),
            multiCurrencyGoalProgressProvider(incomeGoal.id).overrideWith(
              (ref) => Future.value(incomeProgress),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: GoalCard(
                goal: incomeGoal,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify monthly income format
      expect(find.textContaining('\$2.5K/mo of \$10K/mo'), findsOneWidget);
    });
  });
}

