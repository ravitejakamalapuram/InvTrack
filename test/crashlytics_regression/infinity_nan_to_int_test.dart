/// Regression tests for Crashlytics Infinity/NaN toInt crashes
///
/// Crashlytics Issues Fixed:
/// - d4131a2ceec52d1a8fb783a8e187559e
/// - f44a8b7d80af757a18f4b70b08dd7846
///
/// Bug: Unsupported operation: Infinity or NaN toInt
/// Root Cause: Division by zero or invalid calculations resulting in Infinity/NaN
/// Solution: Added _safeToInt() helper that checks isFinite before conversion
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_progress_ring.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_progress_ring.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Infinity/NaN toInt() Regression Tests', () {
    late SharedPreferences mockPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();
    });

    testWidgets('FireProgressRing handles Infinity progress without crashing',
        (tester) async {
      // Regression test for Crashlytics issue d4131a2ceec52d1a8fb783a8e187559e
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockPrefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FireProgressRing(
                progress: double.infinity, // This should NOT crash
                fireNumber: 1000000,
                currentValue: 500000,
                currencySymbol: '₹',
                status: FireProgressStatus.onTrack,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display 0% instead of crashing
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('FireProgressRing handles NaN progress without crashing',
        (tester) async {
      // Regression test for Crashlytics issue f44a8b7d80af757a18f4b70b08dd7846
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockPrefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FireProgressRing(
                progress: double.nan, // This should NOT crash
                fireNumber: 1000000,
                currentValue: 500000,
                currencySymbol: '₹',
                status: FireProgressStatus.onTrack,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display 0% instead of crashing
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('GoalProgressRing handles Infinity without crashing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalProgressRing(
              progress: double.infinity, // This should NOT crash
              color: Colors.blue,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display 0% instead of crashing
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('GoalProgressRingLarge handles NaN without crashing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalProgressRingLarge(
              progress: double.nan, // This should NOT crash
              color: Colors.green,
              currentAmount: '₹50,000',
              targetAmount: '₹1,00,000',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display 0% instead of crashing
      expect(find.text('0%'), findsOneWidget);
    });

    // Note: FireMilestoneCard test is covered by widget-level tests
    // The _safeToInt() helper is tested through FireProgressRing and GoalProgressRing
  });
}
