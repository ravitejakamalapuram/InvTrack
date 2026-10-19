// A122 (#896): a goal that fails to load says so in the user's language and
// offers Retry, instead of vanishing or showing hard-coded English.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goal_details_screen.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_card.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goals_dashboard_card.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

GoalProgress _progress() => GoalProgress(
  goal: _goal,
  currentAmount: 200000,
  targetAmount: 1000000,
  progressPercent: 20,
  monthlyVelocity: 0,
  monthlyIncome: 0,
  status: GoalStatus.onTrack,
  currentMilestone: GoalMilestone.start,
  achievedMilestones: const [],
  linkedInvestmentCount: 1,
  calculatedAt: DateTime(2026, 10, 4),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  List<Override> overrides,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('dashboard card shows an error with Retry, then the goals', (
    tester,
  ) async {
    var calls = 0;
    await _pump(tester, const GoalsDashboardCard(), [
      multiCurrencyGoalsSummaryProvider.overrideWith((ref) async {
        if (calls++ == 0) throw Exception('offline');
        return GoalsSummary(
          totalGoals: 0,
          achievedGoals: 0,
          onTrackGoals: 0,
          behindGoals: 0,
          averageProgress: 0,
          closestToCompletion: null,
          activeGoals: const [],
          completedGoals: const [],
        );
      }),
    ]);

    expect(find.text(l10n.goalsLoadError), findsOneWidget);
    final retry = find.text(l10n.retry);
    expect(retry, findsOneWidget);
    expect(
      tester.getSemantics(retry),
      containsSemantics(isButton: true, hasTapAction: true),
    );

    await tester.tap(retry);
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.goalsLoadError), findsNothing);
    expect(calls, 2);
  });

  testWidgets('goal card shows the localised error, not English literals', (
    tester,
  ) async {
    await _pump(tester, GoalCard(goal: _goal, onTap: () {}), [
      multiCurrencyGoalProgressProvider(
        _goal.id,
      ).overrideWith((ref) async => throw Exception('rate')),
    ]);

    expect(find.text('Error loading progress'), findsNothing);
    expect(find.text(l10n.goalProgressLoadError), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
  });

  testWidgets('goal details shows the error with Retry that reloads', (
    tester,
  ) async {
    var calls = 0;
    await _pump(tester, GoalDetailsScreen(goalId: _goal.id), [
      watchGoalByIdProvider(_goal.id).overrideWith((ref) {
        if (calls++ == 0) return Stream<GoalEntity?>.error(Exception('x'));
        return Stream.value(_goal);
      }),
      multiCurrencyGoalProgressProvider(
        _goal.id,
      ).overrideWith((ref) async => _progress()),
      goalLinkedInvestmentsProvider(
        _goal.id,
      ).overrideWith((ref) async => const []),
    ]);

    expect(find.text('Failed to load goal'), findsNothing);
    expect(find.text(l10n.goalLoadError), findsOneWidget);
    final retry = find.text(l10n.retry);
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.goalLoadError), findsNothing);
    expect(calls, 2);
  });
}
