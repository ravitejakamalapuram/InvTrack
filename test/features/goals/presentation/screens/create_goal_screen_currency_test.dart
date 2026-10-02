import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/screens/create_goal_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('editing an INR goal with a USD base shows the ₹ prefix', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final inrGoal = GoalEntity(
      id: 'goal-1',
      name: 'House',
      type: GoalType.targetAmount,
      targetAmount: 5000000,
      trackingMode: GoalTrackingMode.all,
      icon: '🏠',
      colorValue: 0xFF4CAF50,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      currency: 'INR',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [currencyCodeProvider.overrideWithValue('USD')],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CreateGoalScreen(goalToEdit: inrGoal),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = tester
        .widgetList<AppTextField>(find.byType(AppTextField))
        .firstWhere((f) => f.label == 'Target Amount');
    // The target is entered in the goal's currency, not the base currency
    expect(target.prefixText, '₹');
  });
}
