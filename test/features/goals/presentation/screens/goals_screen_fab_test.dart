// A67 (#802): the goals list FAB is typed to GoalEntity (was List<dynamic>);
// it must still show for active goals and hide when nothing is visible.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goals_screen.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoalEntity _goal({bool archived = false}) => GoalEntity(
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
  isArchived: archived,
);

Future<void> _pump(WidgetTester tester, List<GoalEntity> active) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeGoalsProvider.overrideWith((ref) => Stream.value(active)),
        archivedGoalsProvider.overrideWith(
          (ref) => Stream.value(const <GoalEntity>[]),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GoalsScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('GoalsScreen FAB', () {
    testWidgets('FAB shows when there is an active goal', (tester) async {
      await _pump(tester, [_goal()]);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('FAB is hidden when no goal is visible', (tester) async {
      await _pump(tester, [_goal(archived: true)]);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}
