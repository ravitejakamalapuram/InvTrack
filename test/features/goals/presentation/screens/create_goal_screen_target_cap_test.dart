// Follow-up to #996: the goal form refuses a target amount of 16 digits or
// more, also one that rounds up to 16 digits in the goal's currency, with the
// same message the cash-flow amount field shows, and saves nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/screens/create_goal_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../data/repositories/mock_goal_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

const _tooLargeText = 'That amount is too large';

final _house = GoalEntity(
  id: 'goal-1',
  name: 'House',
  type: GoalType.targetAmount,
  targetAmount: 500000,
  trackingMode: GoalTrackingMode.all,
  icon: '🏠',
  colorValue: 0xFF4CAF50,
  createdAt: DateTime(2026, 1, 15),
  updatedAt: DateTime(2026, 1, 15),
  currency: 'JPY',
);

Finder _editableWithText(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

void main() {
  late FakeGoalRepository repository;

  setUp(() => repository = FakeGoalRepository());

  /// Opens the edit form for [_house] (a JPY goal), types [target] as the
  /// target amount and taps save.
  Future<void> typeAndSave(WidgetTester tester, String target) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    repository.seed(goals: [_house]);

    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Goals')),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => CreateGoalScreen(goalToEdit: _house),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyCodeProvider.overrideWithValue('INR'),
          goalRepositoryProvider.overrideWithValue(repository),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_editableWithText('500000'), target);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
  }

  for (final bad in ['1000000000000000', '999999999999999.5']) {
    testWidgets('$bad is refused with the amount message, nothing saved', (
      tester,
    ) async {
      await typeAndSave(tester, bad);

      expect(find.text(_tooLargeText), findsOneWidget);
      expect(find.text('Goals'), findsNothing, reason: 'the form stays open');
      expect(repository.goals.single.targetAmount, 500000);
    });
  }

  testWidgets('the largest 15-digit amount is saved', (tester) async {
    await typeAndSave(tester, '999999999999999');

    expect(find.text(_tooLargeText), findsNothing);
    expect(find.text('Goals'), findsOneWidget, reason: 'the form saved');
    expect(repository.goals.single.targetAmount, 999999999999999.0);
  });
}
