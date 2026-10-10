// A17: swiping an investment to archive it says what archiving does to the
// Overview totals, goals and FIRE, and which goals change, before the user
// confirms (the old dialog only said the item would be hidden).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _investment = InvestmentEntity(
  id: 'inv-1',
  name: 'Test Investment',
  type: InvestmentType.stocks,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

GoalArchiveImpact _impact() {
  final goal = GoalEntity(
    id: 'house',
    name: 'House',
    type: GoalType.targetAmount,
    targetAmount: 150000,
    trackingMode: GoalTrackingMode.all,
    icon: '🏠',
    colorValue: 0xFF3B82F6,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    currency: 'INR',
  );
  GoalProgress progress(double current) => GoalProgress(
    goal: goal,
    currentAmount: current,
    targetAmount: 150000,
    progressPercent: current / 150000 * 100,
    monthlyVelocity: 0,
    monthlyIncome: 0,
    status: GoalStatus.onTrack,
    currentMilestone: GoalMilestone.forPercentage(current / 150000 * 100),
    achievedMilestones: const [],
    linkedInvestmentCount: 1,
    calculatedAt: DateTime(2026, 10, 4),
  );
  return GoalArchiveImpact(
    goal: goal,
    before: progress(114000),
    after: progress(0),
  );
}

Future<void> _pumpList(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allInvestmentsProvider.overrideWith(
          (ref) => Stream.value([_investment]),
        ),
        archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
        filteredInvestmentsProvider.overrideWith(
          (ref) => AsyncValue.data([_investment]),
        ),
        investmentCountsProvider.overrideWithValue((
          all: 1,
          open: 1,
          closed: 0,
          archived: 0,
        )),
        archiveGoalImpactProvider(
          'inv-1',
        ).overrideWith((ref) async => [_impact()]),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvestmentListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the swipe dialog states the exclusion and lists the goals', (
    tester,
  ) async {
    await _pumpList(tester);

    await tester.drag(find.text('Test Investment'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Archive Investment?'), findsOneWidget);
    expect(
      find.text(
        'Archived investments are hidden from your lists and reminders and '
        'are not counted in Overview totals, goals or FIRE.',
      ),
      findsOneWidget,
    );
    expect(find.text('Goals that will change'), findsOneWidget);
    expect(find.text('House: 76% to 0%'), findsOneWidget);
    // The old wording only said the item would be hidden.
    expect(
      find.textContaining('will be hidden from your active'),
      findsNothing,
    );
  });
}
