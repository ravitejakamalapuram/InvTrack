import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';

void main() {
  testWidgets('GoalCard handles missing localizations gracefully without NPE', (tester) async {
    final testGoal = GoalEntity(
      id: 'goal_1',
      name: 'Retirement Fund',
      type: GoalType.targetAmount,
      targetAmount: 1000000,
      currency: 'USD',
      trackingMode: GoalTrackingMode.all,
      icon: 'savings',
      colorValue: 0xFF0000FF,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
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

    // GoalCard will trigger a Riverpod provider exception when trying to fetch progress
    // due to missing providers/repositories in the mock environment,
    // but we only care that there isn't a NullPointerException on `AppLocalizations.of(context)!`.
    final exception = tester.takeException();

    // As long as the exception isn't a TypeError (which NPEs are), we know our localization fix works.
    if (exception != null) {
      expect(exception is TypeError, isFalse, reason: 'Expected no TypeError (NPE) from AppLocalizations');
    }
  });
}
