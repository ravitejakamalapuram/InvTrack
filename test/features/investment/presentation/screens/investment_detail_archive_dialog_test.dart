// A17: archiving from the investment detail screen shows the same
// confirmation as the list swipe (what it does to Overview totals, goals and
// FIRE, and which goals change), and its messages come from the ARB file.
// Before, the detail screen had its own inline dialog that only said the item
// would be hidden, and nothing tested it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_currency_conversion_service.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
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

final _fund = InvestmentEntity(
  id: 'inv-1',
  name: 'Index fund',
  type: InvestmentType.stocks,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
);

final _flows = [
  CashFlowEntity(
    id: 'cf-1',
    investmentId: 'inv-1',
    type: CashFlowType.invest,
    amount: 100000,
    currency: 'INR',
    date: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  ),
];

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

const _disclosure =
    'Archived investments are hidden from your lists and reminders and are '
    'not counted in Overview totals, goals or FIRE.';

/// Opens the detail screen from a launcher, so that going back is possible.
Future<void> _pump(
  WidgetTester tester, {
  required _FakeInvestmentNotifier notifier,
  bool archived = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final investment = _fund.copyWith(isArchived: archived);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(
          MockCurrencyConversionService(),
        ),
        investmentNotifierProvider.overrideWith(() => notifier),
        cashFlowsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value(_flows)),
        archivedCashFlowsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value(_flows)),
        expectedCashFlowsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value([])),
        documentsByInvestmentProvider(
          'inv-1',
        ).overrideWith((ref) => Stream.value([])),
        archiveGoalImpactProvider(
          'inv-1',
        ).overrideWith((ref) async => [_impact()]),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      InvestmentDetailScreen(investment: investment),
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
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

/// More options > the archive entry, which opens the confirmation.
Future<void> _openArchiveDialog(WidgetTester tester, String entry) async {
  await tester.tap(find.byTooltip(_l10n(tester).tooltipMoreOptions));
  await tester.pumpAndSettle();
  await tester.tap(find.text(entry));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('archive: the dialog states the exclusion and lists the goals '
      'that change', (tester) async {
    await _pump(tester, notifier: _FakeInvestmentNotifier());

    await _openArchiveDialog(tester, 'Archive Investment');

    expect(find.text('Archive Investment?'), findsOneWidget);
    expect(find.text(_disclosure), findsOneWidget);
    expect(find.text('Goals that will change'), findsOneWidget);
    expect(find.text('House: 76% to 0%'), findsOneWidget);
    // The old inline dialog only said the item would be hidden.
    expect(find.textContaining('will hide the investment'), findsNothing);
  });

  testWidgets('archive: confirming archives it, says so and goes back', (
    tester,
  ) async {
    final notifier = _FakeInvestmentNotifier();
    await _pump(tester, notifier: notifier);

    await _openArchiveDialog(tester, 'Archive Investment');
    await tester.tap(find.widgetWithText(TextButton, _l10n(tester).archive));
    await tester.pumpAndSettle();

    expect(notifier.archived, ['inv-1']);
    expect(find.text(_l10n(tester).investmentArchived), findsOneWidget);
    // Back on the launcher.
    expect(find.byType(InvestmentDetailScreen), findsNothing);
  });

  testWidgets('archive: cancelling archives nothing', (tester) async {
    final notifier = _FakeInvestmentNotifier();
    await _pump(tester, notifier: notifier);

    await _openArchiveDialog(tester, 'Archive Investment');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(notifier.archived, isEmpty);
    expect(find.byType(InvestmentDetailScreen), findsOneWidget);
  });

  testWidgets('archive: a failure says so and stays on the screen', (
    tester,
  ) async {
    final notifier = _FakeInvestmentNotifier(fails: true);
    await _pump(tester, notifier: notifier);

    await _openArchiveDialog(tester, 'Archive Investment');
    await tester.tap(find.widgetWithText(TextButton, _l10n(tester).archive));
    await tester.pumpAndSettle();

    expect(find.text(_l10n(tester).archiveInvestmentFailed), findsOneWidget);
    expect(find.text('Failed to archive investment'), findsOneWidget);
    expect(find.byType(InvestmentDetailScreen), findsOneWidget);
  });

  testWidgets('unarchive: the dialog says what counts again, and restoring '
      'says so', (tester) async {
    final notifier = _FakeInvestmentNotifier();
    await _pump(tester, notifier: notifier, archived: true);

    await _openArchiveDialog(tester, 'Unarchive Investment');

    expect(find.text('Unarchive Investment?'), findsOneWidget);
    expect(
      find.text(
        'This restores the investment to your lists and counts it in '
        'Overview totals again. Goals and FIRE count it only while it is '
        'open.',
      ),
      findsOneWidget,
    );
    // Nothing is lost by restoring, so there is no goal list.
    expect(find.text('Goals that will change'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, _l10n(tester).unarchive));
    await tester.pumpAndSettle();

    expect(notifier.restored, ['inv-1']);
    expect(find.text(_l10n(tester).investmentRestored), findsOneWidget);
    // Unarchiving stays on the screen.
    expect(find.byType(InvestmentDetailScreen), findsOneWidget);
  });

  testWidgets('unarchive: a failure says so, from the ARB', (tester) async {
    final notifier = _FakeInvestmentNotifier(fails: true);
    await _pump(tester, notifier: notifier, archived: true);

    await _openArchiveDialog(tester, 'Unarchive Investment');
    await tester.tap(find.widgetWithText(TextButton, _l10n(tester).unarchive));
    await tester.pumpAndSettle();

    expect(find.text(_l10n(tester).unarchiveInvestmentFailed), findsOneWidget);
    expect(find.text('Failed to unarchive investment'), findsOneWidget);
  });
}
