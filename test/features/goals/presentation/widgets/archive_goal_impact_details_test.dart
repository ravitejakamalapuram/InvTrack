// A17 / GAP1-02: the archive dialog lists the goals whose progress changes.
// Percentages are hidden in privacy mode, like the goal rings.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/archive_goal_impact_details.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

class _PrivacyOn extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

GoalEntity _goal(String name) => GoalEntity(
  id: name,
  name: name,
  type: GoalType.targetAmount,
  targetAmount: 150000,
  trackingMode: GoalTrackingMode.all,
  icon: '🎯',
  colorValue: 0xFF3B82F6,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  currency: 'INR',
);

GoalProgress _progress(GoalEntity goal, double current) => GoalProgress(
  goal: goal,
  currentAmount: current,
  targetAmount: 150000,
  progressPercent: current / 150000 * 100,
  monthlyVelocity: 0,
  monthlyIncome: 0,
  status: current > 0 ? GoalStatus.onTrack : GoalStatus.notStarted,
  currentMilestone: GoalMilestone.forPercentage(current / 150000 * 100),
  achievedMilestones: const [],
  linkedInvestmentCount: 1,
  calculatedAt: DateTime(2026, 10, 4),
);

GoalArchiveImpact _impact(String name, double before, double after) {
  final goal = _goal(name);
  return GoalArchiveImpact(
    goal: goal,
    before: _progress(goal, before),
    after: _progress(goal, after),
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<GoalArchiveImpact> impacts, {
  bool privacy = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(
          privacy ? _PrivacyOn.new : _PrivacyOff.new,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ArchiveGoalImpactDetails(impacts: impacts)),
      ),
    ),
  );
}

void main() {
  testWidgets('says which goals change and from what to what', (tester) async {
    await _pump(tester, [
      _impact('House', 114000, 0),
      _impact('Wealth', 61500, 20250),
    ]);

    expect(find.text('Goals that will change'), findsOneWidget);
    expect(find.text('House: 76% to 0%'), findsOneWidget);
    // 20250 / 150000 = 13.5%, shown rounded down like every goal screen.
    expect(find.text('Wealth: 41% to 13%'), findsOneWidget);
  });

  testWidgets('the rows are read out as the text on screen', (tester) async {
    await _pump(tester, [_impact('House', 114000, 0)]);

    expect(find.bySemanticsLabel('House: 76% to 0%'), findsOneWidget);
  });

  testWidgets('privacy mode keeps the goal names but hides the percentages', (
    tester,
  ) async {
    await _pump(tester, [_impact('House', 114000, 0)], privacy: true);

    expect(find.text('House: progress will change'), findsOneWidget);
    expect(find.textContaining('76'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('76')), findsNothing);
  });

  testWidgets('shows nothing without affected goals', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Goals that will change'), findsNothing);
  });
}
