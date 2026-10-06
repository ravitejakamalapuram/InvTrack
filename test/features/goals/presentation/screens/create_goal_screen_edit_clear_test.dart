// A116 (#890): editing a goal must be able to clear its target date and its
// monthly income target. The form pre-fills both, so a null it saves is one
// the user cleared, and it must stay cleared after a restart.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/data/models/goal_model.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/screens/create_goal_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../data/repositories/mock_goal_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

final _house = GoalEntity(
  id: 'goal-1',
  name: 'House',
  type: GoalType.targetAmount,
  targetAmount: 500000.00,
  targetDate: DateTime(2030, 3, 31),
  trackingMode: GoalTrackingMode.selected,
  linkedInvestmentIds: const ['inv-1', 'inv-2'],
  icon: '🏠',
  colorValue: 0xFF4CAF50,
  createdAt: DateTime(2026, 1, 15),
  updatedAt: DateTime(2026, 1, 15),
  currency: 'INR',
);

final _income = GoalEntity(
  id: 'goal-2',
  name: 'Rent cover',
  type: GoalType.incomeTarget,
  targetAmount: 0,
  targetMonthlyIncome: 20000,
  trackingMode: GoalTrackingMode.all,
  icon: '💰',
  colorValue: 0xFF4CAF50,
  createdAt: DateTime(2026, 1, 15),
  updatedAt: DateTime(2026, 1, 15),
  currency: 'INR',
);

Finder _editableWithText(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

/// The goal as the app reads it back after a restart: written with
/// [GoalModel.toFirestore] and read with [GoalModel.fromFirestore].
GoalEntity _afterRestart(GoalEntity goal) => GoalModel.fromFirestore(
  {
    ...GoalModel.toFirestore(goal),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 5)),
  },
  goal.id,
  baseCurrency: 'INR',
);

void main() {
  late FakeGoalRepository repository;

  setUp(() => repository = FakeGoalRepository());

  /// Opens the edit form for [goal], runs [edit], saves, and returns the
  /// stored goal.
  Future<GoalEntity> editAndSave(
    WidgetTester tester,
    GoalEntity goal,
    Future<void> Function() edit,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    goal.isArchived
        ? repository.seed(archivedGoals: [goal])
        : repository.seed(goals: [goal]);

    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Goals')),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => CreateGoalScreen(goalToEdit: goal),
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

    await edit();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Goals'), findsOneWidget, reason: 'the form saved');
    return goal.isArchived
        ? repository.archivedGoals.single
        : repository.goals.single;
  }

  testWidgets('clearing the target date saves no date', (tester) async {
    final stored = await editAndSave(tester, _house, () async {
      await tester.tap(find.byTooltip('Clear target date'));
      await tester.pumpAndSettle();
    });

    expect(stored.targetDate, isNull);
    expect(_afterRestart(stored).targetDate, isNull);
    expect(stored.targetAmount, 500000.00);
  });

  testWidgets('emptying the monthly income target saves none', (tester) async {
    final stored = await editAndSave(tester, _income, () async {
      await tester.enterText(_editableWithText('20000'), '');
      await tester.pumpAndSettle();
    });

    expect(stored.targetMonthlyIncome, isNull);
    expect(_afterRestart(stored).targetMonthlyIncome, isNull);
  });

  testWidgets('control: renaming keeps every other field', (tester) async {
    final stored = await editAndSave(tester, _house, () async {
      await tester.enterText(_editableWithText('House'), 'Home');
      await tester.pumpAndSettle();
    });

    expect(stored.id, 'goal-1');
    expect(stored.name, 'Home');
    expect(stored.type, GoalType.targetAmount);
    expect(stored.targetAmount, 500000.00);
    expect(stored.targetMonthlyIncome, isNull);
    expect(stored.targetDate, equals(DateTime(2030, 3, 31)));
    expect(stored.trackingMode, GoalTrackingMode.selected);
    expect(stored.linkedInvestmentIds, equals(['inv-1', 'inv-2']));
    expect(stored.linkedTypes, isEmpty);
    expect(stored.icon, '🏠');
    expect(stored.colorValue, 0xFF4CAF50);
    expect(stored.isArchived, isFalse);
    expect(stored.createdAt, equals(DateTime(2026, 1, 15)));
    expect(stored.updatedAt.isAfter(DateTime(2026, 1, 15)), isTrue);
    expect(stored.currency, 'INR');
    expect(_afterRestart(stored).targetDate, equals(DateTime(2030, 3, 31)));
  });

  testWidgets('control: editing an archived goal keeps it archived', (
    tester,
  ) async {
    final stored = await editAndSave(
      tester,
      _house.copyWith(isArchived: true),
      () async {
        await tester.enterText(_editableWithText('House'), 'Home');
        await tester.pumpAndSettle();
      },
    );

    // The edit reached the archived store, not the active one.
    expect(stored.name, 'Home');
    expect(stored.isArchived, isTrue);
    expect(repository.goals, isEmpty);
  });
}
