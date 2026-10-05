// A109 review: the US dollar question and its follow-ups name what is
// really there. A list of goals only no longer says "investments and
// goals", and a partly US dollar investment says when its own currency
// changes.
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

UsdTagCandidate _goal(String id, String name) => UsdTagCandidate(
  id: 'goal:$id',
  name: name,
  isMerged: false,
  isArchived: false,
  kind: UsdTagKind.goal,
  cashFlowCount: 0,
);

void main() {
  group('UsdTagRepairDialog', () {
    Future<void> open(
      WidgetTester tester,
      List<UsdTagCandidate> candidates,
    ) async {
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
              onPressed: () => showDialog<Set<String>>(
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

    testWidgets('goals only: the title and message name goals, not '
        'investments', (tester) async {
      await open(tester, [_goal('g1', 'House'), _goal('g2', 'Wedding')]);

      expect(find.text('Goals recorded in US dollars'), findsOneWidget);
      expect(
        find.text(
          'We found 2 goals recorded in US dollars. Were these in ₹ (INR)?',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('investments and goals'), findsNothing);
    });

    testWidgets('investments and goals together keep the mixed wording', (
      tester,
    ) async {
      await open(tester, [
        const UsdTagCandidate(
          id: 'inv-1',
          name: 'FD',
          isMerged: false,
          isArchived: false,
          cashFlowCount: 1,
        ),
        _goal('g1', 'House'),
      ]);

      expect(
        find.text('Investments and goals recorded in US dollars'),
        findsOneWidget,
      );
      expect(
        find.text(
          'We found 2 investments and goals recorded in US dollars. Were '
          'these in ₹ (INR)?',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a partly US dollar investment in US dollars itself says '
        'that its currency changes', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, const [
        UsdTagCandidate(
          id: 'partly:inv-own',
          name: 'Bond ladder',
          isMerged: false,
          isArchived: false,
          kind: UsdTagKind.partlyUsd,
          cashFlowCount: 2,
          usdCashFlowCount: 1,
          investmentTagged: true,
        ),
        UsdTagCandidate(
          id: 'partly:inv-only',
          name: 'Chit',
          isMerged: false,
          isArchived: false,
          kind: UsdTagKind.partlyUsd,
          cashFlowCount: 1,
          usdCashFlowCount: 0,
          investmentTagged: true,
        ),
        UsdTagCandidate(
          id: 'partly:inv-flows',
          name: 'P2P',
          isMerged: false,
          isArchived: false,
          kind: UsdTagKind.partlyUsd,
          cashFlowCount: 2,
          usdCashFlowCount: 1,
        ),
      ]);

      expect(
        find.text(
          "Partly in US dollars · The investment's currency · 1 of 2 cash "
          'flows',
        ),
        findsOneWidget,
      );
      expect(
        find.text("Partly in US dollars · The investment's currency"),
        findsOneWidget,
      );
      expect(
        find.text('Partly in US dollars · 1 of 2 cash flows'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.widgetWithText(CheckboxListTile, 'Chit')),
        containsSemantics(
          label: "Chit\nPartly in US dollars · The investment's currency",
          hasCheckedState: true,
          isChecked: false,
        ),
      );
      semantics.dispose();
    });
  });

  group('two goals in US dollars', () {
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
        })
        ..put('goals', 'g2', {
          'name': 'Wedding',
          'targetAmount': 800000.0,
          'currency': 'USD',
        });
    });

    UsdTagRepairService service() => UsdTagRepairService(
      firestore: firestore,
      userId: firestore.uid,
      prefs: prefs,
    );

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

    testWidgets('Change says 2 goals changed', (tester) async {
      await tester.pumpWidget(
        app(const UsdTagRepairInitializer(child: SizedBox())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('House'));
      await tester.tap(find.text('Wedding'));
      await tester.pump();
      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(find.text('2 goals changed to INR.'), findsOneWidget);
    });

    testWidgets('the Undo item and its confirmation say 2 goals', (
      tester,
    ) async {
      await service().repair({'goal:g1', 'goal:g2'}, 'INR');
      await tester.pumpWidget(app(const UsdTagRepairUndoTile()));

      expect(find.text('Show 2 goals in US dollars again'), findsOneWidget);
      await tester.tap(find.text('Undo the US dollar fix'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '2 goals will be shown in US dollars again. Their amounts do not '
          'change.',
        ),
        findsOneWidget,
      );
    });
  });
}

class _Unlocked extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState(hasPin: false, isLocked: false);
}
