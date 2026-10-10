// A17 / GAP1-01, GAP1-02: the archive confirmation says what archiving does
// to the totals, goals and FIRE, and which goals change before the user
// confirms. The wording is the ticket's.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/archive_investment_confirm.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

const _disclosure =
    'Archived investments are hidden from your lists and reminders and are '
    'not counted in Overview totals, goals or FIRE.';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

final _fund = InvestmentEntity(
  id: 'fund',
  name: 'Index fund',
  type: InvestmentType.stocks,
  status: InvestmentStatus.open,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

GoalArchiveImpact _houseImpact() {
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
    status: current > 0 ? GoalStatus.onTrack : GoalStatus.notStarted,
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

/// Opens the confirmation from a button and records the answer.
Future<List<bool>> _open(
  WidgetTester tester, {
  required Future<List<GoalArchiveImpact>> Function() impacts,
  bool isArchived = false,
}) async {
  final answers = <bool>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        archiveGoalImpactProvider('fund').overrideWith((ref) => impacts()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async => answers.add(
                await confirmArchiveToggle(
                  context,
                  ref,
                  _fund.copyWith(isArchived: isArchived),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return answers;
}

void main() {
  testWidgets('archiving says it leaves totals, goals and FIRE', (
    tester,
  ) async {
    await _open(tester, impacts: () async => const []);

    expect(find.text('Archive Investment?'), findsOneWidget);
    expect(find.text(_disclosure), findsOneWidget);
    expect(find.text('Goals that will change'), findsNothing);
  });

  testWidgets('archiving lists the goals that change, before confirming', (
    tester,
  ) async {
    final answers = await _open(tester, impacts: () async => [_houseImpact()]);

    expect(find.text(_disclosure), findsOneWidget);
    expect(find.text('Goals that will change'), findsOneWidget);
    expect(find.text('House: 76% to 0%'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Archive'));
    await tester.pumpAndSettle();
    expect(answers, [true]);
  });

  testWidgets('cancelling answers false', (tester) async {
    final answers = await _open(tester, impacts: () async => const []);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(answers, [false]);
  });

  testWidgets('without goal numbers the disclosure is still shown', (
    tester,
  ) async {
    // The goal preview needs the converted snapshot; if it cannot load, the
    // user still gets the plain statement and can decide.
    await _open(
      tester,
      impacts: () => Future<List<GoalArchiveImpact>>.error(Exception('x')),
    );

    expect(find.text(_disclosure), findsOneWidget);
    expect(find.text('Goals that will change'), findsNothing);
  });

  testWidgets('unarchiving says the investment counts again', (tester) async {
    await _open(tester, impacts: () async => const [], isArchived: true);

    expect(find.text('Unarchive Investment?'), findsOneWidget);
    expect(
      find.text(
        'This restores the investment to your lists and counts it in '
        'Overview totals, goals and FIRE again.',
      ),
      findsOneWidget,
    );
  });
}
