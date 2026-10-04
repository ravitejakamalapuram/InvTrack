// A12 (#756): the goal details screen shows what the goal needs each month,
// the investments it tracks (archived ones too, labelled as not counted,
// money rule 9), and how many other goals count the same investments.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goal_details_screen.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_carousel_card.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _goal = GoalEntity(
  id: 'house',
  name: 'House',
  type: GoalType.targetDate,
  targetAmount: 1000000,
  targetDate: DateTime(2029, 10, 4),
  trackingMode: GoalTrackingMode.selected,
  linkedInvestmentIds: const ['fd', 'old'],
  icon: '🏠',
  colorValue: 0xFF3B82F6,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  currency: 'INR',
);

InvestmentEntity _inv(String id, String name, {bool isArchived = false}) =>
    InvestmentEntity(
      id: id,
      name: name,
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currency: 'INR',
      isArchived: isArchived,
    );

GoalProgress _progress({double percent = 20, int otherGoals = 1}) =>
    GoalProgress(
      goal: _goal,
      currentAmount: 200000,
      targetAmount: 1000000,
      progressPercent: percent,
      monthlyVelocity: 0,
      monthlyIncome: 0,
      requiredMonthly: 18402.43,
      otherGoalsCount: otherGoals,
      status: GoalStatus.behind,
      currentMilestone: GoalMilestone.start,
      achievedMilestones: const [],
      linkedInvestmentCount: 1,
      calculatedAt: DateTime(2026, 10, 4),
    );

Future<void> _pump(
  WidgetTester tester, {
  bool privacy = false,
  List<LinkedGoalInvestment>? linked,
  int otherGoals = 1,
}) async {
  SharedPreferences.setMockInitialValues({'privacy_mode_enabled': privacy});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
        watchGoalByIdProvider(
          _goal.id,
        ).overrideWith((ref) => Stream.value(_goal)),
        multiCurrencyGoalProgressProvider(
          _goal.id,
        ).overrideWith((ref) async => _progress(otherGoals: otherGoals)),
        goalLinkedInvestmentsProvider(_goal.id).overrideWith(
          (ref) async =>
              linked ??
              [
                LinkedGoalInvestment(
                  investment: _inv('fd', 'HDFC FD'),
                  isArchived: false,
                  isCounted: true,
                ),
                LinkedGoalInvestment(
                  investment: _inv('old', 'Old SBI FD', isArchived: true),
                  isArchived: true,
                  isCounted: false,
                ),
              ],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GoalDetailsScreen(goalId: _goal.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the monthly amount needed and the rate it assumes', (
    tester,
  ) async {
    await _pump(tester);

    await tester.scrollUntilVisible(find.text('Required per month'), 200);
    expect(find.text('Required per month'), findsOneWidget);
    expect(find.text('Assumes 8% growth a year'), findsOneWidget);
    expect(find.textContaining('18'), findsWidgets);
  });

  testWidgets('hides the monthly amount in privacy mode', (tester) async {
    await _pump(tester, privacy: true);

    await tester.scrollUntilVisible(find.text('Required per month'), 200);
    expect(find.textContaining('18,402'), findsNothing);
    expect(find.textContaining('18.4'), findsNothing);
  });

  testWidgets('says how many other goals count the same investments', (
    tester,
  ) async {
    await _pump(tester, otherGoals: 2);

    expect(find.text('Also counted in 2 other goals'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Also counted in 2 other goals'),
      findsOneWidget,
    );
  });

  testWidgets('shows no shared-goal chip when no other goal counts them', (
    tester,
  ) async {
    await _pump(tester, otherGoals: 0);

    expect(find.textContaining('Also counted in'), findsNothing);
  });

  testWidgets('lists linked investments and marks archived ones', (
    tester,
  ) async {
    await _pump(tester);

    await tester.scrollUntilVisible(find.text('Old SBI FD'), 200);
    expect(find.text('Linked investments'), findsOneWidget);
    expect(find.text('HDFC FD'), findsOneWidget);
    expect(find.text('Old SBI FD'), findsOneWidget);
    expect(find.text('Archived · not counted'), findsOneWidget);
    expect(
      find.text('Archived investments are not counted in goal progress.'),
      findsOneWidget,
    );
  });

  testWidgets('says when no investment is linked', (tester) async {
    await _pump(tester, linked: const []);

    await tester.scrollUntilVisible(find.text('Linked investments'), 200);
    expect(find.text('No investments linked yet'), findsOneWidget);
    expect(
      find.text('Archived investments are not counted in goal progress.'),
      findsNothing,
    );
  });

  testWidgets('the carousel shows 99.6% as 99%, like the ring', (tester) async {
    SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GoalCarouselCard(progress: _progress(percent: 99.6)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('99%'), findsOneWidget);
    expect(find.text('100%'), findsNothing);
  });
}
