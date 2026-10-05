// A109: the US dollar question also lists goals, investments with no cash
// flows yet and investments only partly in US dollars. They start unticked,
// each says what would change, and the counts after Change and in Undo name
// goals when there are any. Investments-only lists keep the A04 wording.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/usd_tag_repair_dialog.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/usd_tag_repair_prompt.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';
import '../../../../mocks/mock_analytics_service.dart';

const _candidates = [
  UsdTagCandidate(
    id: 'inv-merged',
    name: 'Merged FD',
    isMerged: true,
    isArchived: false,
    cashFlowCount: 2,
    expectedPaymentCount: 1,
  ),
  UsdTagCandidate(
    id: 'partly:inv-mixed',
    name: 'Bond ladder',
    isMerged: false,
    isArchived: false,
    kind: UsdTagKind.partlyUsd,
    cashFlowCount: 2,
    usdCashFlowCount: 1,
  ),
  UsdTagCandidate(
    id: 'partly:inv-p2p',
    name: 'P2P loan',
    isMerged: false,
    isArchived: false,
    kind: UsdTagKind.partlyUsd,
    cashFlowCount: 1,
    usdCashFlowCount: 0,
    expectedPaymentCount: 1,
  ),
  UsdTagCandidate(
    id: 'empty:inv-empty',
    name: 'New FD',
    isMerged: false,
    isArchived: false,
    kind: UsdTagKind.noCashFlows,
    cashFlowCount: 0,
  ),
  UsdTagCandidate(
    id: 'goal:g2',
    name: 'Old car',
    isMerged: false,
    isArchived: true,
    kind: UsdTagKind.goal,
    cashFlowCount: 0,
  ),
];

const _extendedDetail =
    'Goals, investments with no cash flows yet and investments only partly '
    'in US dollars start unticked. Tick the ones that were in INR. Only what '
    'is in US dollars changes.';

void main() {
  bool? ticked(WidgetTester tester, String name) => tester
      .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, name))
      .value;

  group('UsdTagRepairDialog', () {
    Set<String>? result;

    Future<void> open(
      WidgetTester tester,
      List<UsdTagCandidate> candidates,
    ) async {
      result = null;
      // Tall enough to show the whole list without scrolling.
      tester.view
        ..physicalSize = const Size(800, 2000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showDialog<Set<String>>(
                context: context,
                builder: (_) =>
                    UsdTagRepairDialog(candidates: candidates, currency: 'INR'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists goals, payments, empty and partly US dollar '
        'investments unticked, saying what would change', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, _candidates);

      expect(
        find.text('Investments and goals recorded in US dollars'),
        findsOneWidget,
      );
      expect(
        find.text(
          'We found 5 investments and goals recorded in US dollars. Were '
          'these in ₹ (INR)?',
        ),
        findsOneWidget,
      );
      expect(find.text(_extendedDetail), findsOneWidget);
      expect(find.text('2 cash flows · 1 expected payment · Merged'), findsOne);
      expect(find.text('Partly in US dollars · 1 of 2 cash flows'), findsOne);
      expect(
        find.text('Partly in US dollars · 1 expected payment'),
        findsOneWidget,
      );
      expect(find.text('No cash flows yet'), findsOneWidget);
      expect(find.text('Goal · Archived'), findsOneWidget);

      expect(ticked(tester, 'Merged FD'), isTrue);
      expect(ticked(tester, 'Bond ladder'), isFalse);
      expect(ticked(tester, 'P2P loan'), isFalse);
      expect(ticked(tester, 'New FD'), isFalse);
      expect(ticked(tester, 'Old car'), isFalse);

      // A screen reader hears the name, what would change and the tick.
      expect(
        tester.getSemantics(find.widgetWithText(CheckboxListTile, 'Old car')),
        containsSemantics(
          label: 'Old car\nGoal · Archived',
          hasCheckedState: true,
          isChecked: false,
        ),
      );
      expect(
        tester.getSemantics(
          find.widgetWithText(CheckboxListTile, 'Bond ladder'),
        ),
        containsSemantics(
          label: 'Bond ladder\nPartly in US dollars · 1 of 2 cash flows',
          hasCheckedState: true,
          isChecked: false,
        ),
      );
      // Names and counts only: no amount for privacy mode to hide.
      expect(find.textContaining(RegExp(r'\d{3}')), findsNothing);
      semantics.dispose();
    });

    testWidgets('Change returns what the user ticked', (tester) async {
      await open(tester, _candidates);

      await tester.tap(find.text('Old car'));
      await tester.pump();
      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(result, {'inv-merged', 'goal:g2'});
    });

    testWidgets('a list of investments only keeps the A04 title and message, '
        'with the unticked note when one is only partly in US '
        'dollars', (tester) async {
      await open(tester, _candidates.sublist(0, 2));

      expect(find.text('Investments recorded in US dollars'), findsOneWidget);
      expect(
        find.text(
          'We found 2 investments recorded in US dollars. Were these in ₹ '
          '(INR)?',
        ),
        findsOneWidget,
      );
      expect(find.text(_extendedDetail), findsOneWidget);
    });

    testWidgets('all US dollar investments only: no unticked note', (
      tester,
    ) async {
      await open(tester, _candidates.sublist(0, 1));

      expect(find.text(_extendedDetail), findsNothing);
    });
  });

  group('with a goal in US dollars', () {
    late FakeLegacyCurrencyFirestore firestore;
    late SharedPreferences prefs;
    late FakeAnalyticsService analytics;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      analytics = FakeAnalyticsService();
      firestore = FakeLegacyCurrencyFirestore()
        ..put('goals', 'g1', {
          'name': 'House',
          'targetAmount': 500000.0,
          'currency': 'USD',
        });
    });

    UsdTagRepairService service() => UsdTagRepairService(
      firestore: firestore,
      userId: firestore.uid,
      prefs: prefs,
    );

    String? goalCurrency() =>
        firestore.stored('goals', 'g1')!['currency'] as String?;

    Widget app(Widget home) => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        securityProvider.overrideWith(_Unlocked.new),
        analyticsServiceProvider.overrideWithValue(analytics),
        usdTagRepairServiceProvider.overrideWithValue(service()),
        legacyCurrencyBackfillServiceProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );

    testWidgets('the question names the goal, Change says a goal changed, '
        'and Undo puts US dollars back', (tester) async {
      await tester.pumpWidget(
        app(const UsdTagRepairInitializer(child: SizedBox())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('We found 1 goal recorded in US dollars. Was it in ₹ (INR)?'),
        findsOneWidget,
      );
      expect(find.text('Goal'), findsOneWidget);
      expect(ticked(tester, 'House'), isFalse);

      await tester.tap(find.text('House'));
      await tester.pump();
      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(goalCurrency(), 'INR');
      expect(firestore.stored('goals', 'g1')!['targetAmount'], 500000.00);
      expect(find.text('1 goal changed to INR.'), findsOneWidget);
      expect(analytics.loggedEvents.last.parameters, {
        'action': 'fixed',
        'flagged': 1,
        'fixed': 1,
      });

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(goalCurrency(), 'USD');
      expect(find.text('The US dollar fix was undone.'), findsOneWidget);
    });

    testWidgets('Change when the goal was already fixed elsewhere says '
        'nothing changed', (tester) async {
      await tester.pumpWidget(
        app(const UsdTagRepairInitializer(child: SizedBox())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('House'));
      await tester.pump();
      firestore.stored('goals', 'g1')!['currency'] = 'INR';

      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nothing needed changing. These are no longer recorded in US '
          'dollars.',
        ),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('the Undo item in Data & Account names goals', (tester) async {
      firestore
        ..put('investments', 'inv-empty', {'name': 'New FD', 'currency': 'USD'})
        ..put('goals', 'g3', {
          'name': 'Wedding',
          'targetAmount': 800000.0,
          'currency': 'USD',
        });
      await service().repair({'goal:g1', 'goal:g3', 'empty:inv-empty'}, 'INR');
      await tester.pumpWidget(app(const UsdTagRepairUndoTile()));

      expect(
        find.text('Show 3 investments and goals in US dollars again'),
        findsOneWidget,
      );
      await tester.tap(find.text('Undo the US dollar fix'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '3 investments and goals will be shown in US dollars again. Their '
          'amounts do not change.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(goalCurrency(), 'USD');
      expect(firestore.stored('goals', 'g3')!['currency'], 'USD');
      expect(firestore.stored('investments', 'inv-empty')!['currency'], 'USD');
    });
  });
}

class _Unlocked extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState(hasPin: false, isLocked: false);
}
