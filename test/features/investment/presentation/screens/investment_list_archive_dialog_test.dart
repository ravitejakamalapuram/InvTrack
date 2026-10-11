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

/// Archives succeed or fail as told; `archived` and `restored` record the ids.
class _FakeInvestmentNotifier extends InvestmentNotifier {
  _FakeInvestmentNotifier({this.fails = false});

  final bool fails;
  final archived = <String>[];
  final restored = <String>[];

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  Future<void> archiveInvestment(String id) async {
    if (fails) throw Exception('offline');
    archived.add(id);
  }

  @override
  Future<void> unarchiveInvestment(String id) async {
    if (fails) throw Exception('offline');
    restored.add(id);
  }
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(InvestmentListScreen)));

Future<void> _pumpList(
  WidgetTester tester, {
  InvestmentEntity? investment,
  _FakeInvestmentNotifier? notifier,
}) async {
  final shown = investment ?? _investment;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (notifier != null)
          investmentNotifierProvider.overrideWith(() => notifier),
        allInvestmentsProvider.overrideWith((ref) => Stream.value([shown])),
        archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
        filteredInvestmentsProvider.overrideWith(
          (ref) => AsyncValue.data([shown]),
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
  testWidgets('confirming the swipe archives it and says so', (tester) async {
    final notifier = _FakeInvestmentNotifier();
    await _pumpList(tester, notifier: notifier);

    await tester.drag(find.text('Test Investment'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, _l10n(tester).archive));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(notifier.archived, ['inv-1']);
    expect(find.text(_l10n(tester).investmentArchived), findsOneWidget);
    expect(find.text('Investment archived'), findsOneWidget);
  });

  testWidgets('a failed swipe archive says it failed, from the ARB', (
    tester,
  ) async {
    final notifier = _FakeInvestmentNotifier(fails: true);
    await _pumpList(tester, notifier: notifier);

    await tester.drag(find.text('Test Investment'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, _l10n(tester).archive));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_l10n(tester).archiveInvestmentFailed), findsOneWidget);
    expect(find.text('Failed to archive investment'), findsOneWidget);
    expect(find.text('Investment archived'), findsNothing);
  });

  testWidgets('swiping an archived investment offers Unarchive and says it '
      'was restored', (tester) async {
    final notifier = _FakeInvestmentNotifier();
    await _pumpList(
      tester,
      investment: _investment.copyWith(isArchived: true),
      notifier: notifier,
    );

    await tester.drag(find.text('Test Investment'), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Unarchive Investment?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, _l10n(tester).unarchive));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(notifier.restored, ['inv-1']);
    expect(find.text(_l10n(tester).investmentRestored), findsOneWidget);
    expect(find.text('Investment restored'), findsOneWidget);
  });

  testWidgets('a failed unarchive says it failed, from the ARB', (
    tester,
  ) async {
    final notifier = _FakeInvestmentNotifier(fails: true);
    await _pumpList(
      tester,
      investment: _investment.copyWith(isArchived: true),
      notifier: notifier,
    );

    await tester.drag(find.text('Test Investment'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, _l10n(tester).unarchive));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_l10n(tester).unarchiveInvestmentFailed), findsOneWidget);
    expect(find.text('Failed to unarchive investment'), findsOneWidget);
  });
}
