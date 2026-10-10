/// A28 / ARCH-05, UX-15, UX-V01, ADOPT-11: Overview must tell loading and
/// load errors apart from a genuinely empty account. Existing users used to
/// see the new-user empty state, be offered sample data that is written into
/// their real account, and be counted in `empty_state_viewed`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

const _emptyStateEvent = 'empty_state_viewed';

final _investment = InvestmentEntity(
  id: 'inv-1',
  name: 'FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

int _emptyStateEvents(FakeAnalyticsService analytics) =>
    analytics.loggedEvents.where((e) => e.name == _emptyStateEvent).length;

Future<void> _pumpOverview(
  WidgetTester tester, {
  required FakeAnalyticsService analytics,
  required Stream<List<InvestmentEntity>> Function() investments,
  required Stream<List<CashFlowEntity>> Function() cashFlows,
  Stream<List<InvestmentEntity>> Function()? archivedInvestments,
  bool productionRetry = false,
}) async {
  SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      // Production (main.dart) keeps Riverpod's default retry policy.
      retry: productionRetry ? null : (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsServiceProvider.overrideWithValue(analytics),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
        allInvestmentsProvider.overrideWith((ref) => investments()),
        allCashFlowsStreamProvider.overrideWith((ref) => cashFlows()),
        archivedInvestmentsProvider.overrideWith(
          (ref) => archivedInvestments?.call() ?? Stream.value(const []),
        ),
        // The lists stand in for the server: the account is new when both
        // are empty.
        hasNoInvestmentsProvider.overrideWith((ref) {
          final active = ref.watch(allInvestmentsProvider.future);
          final archived = ref.watch(archivedInvestmentsProvider.future);
          return Stream.fromFuture(
            Future.wait([
              active,
              archived,
            ]).then((lists) => lists.every((list) => list.isEmpty)),
          );
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OverviewScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late FakeAnalyticsService analytics;

  setUp(() {
    analytics = FakeAnalyticsService();
  });

  testWidgets(
    'while data is loading, shows skeletons, not the empty state, and logs '
    'no empty_state_viewed',
    (tester) async {
      final investments = StreamController<List<InvestmentEntity>>();
      final cashFlows = StreamController<List<CashFlowEntity>>();
      addTearDown(() => unawaited(investments.close()));
      addTearDown(() => unawaited(cashFlows.close()));

      await _pumpOverview(
        tester,
        analytics: analytics,
        investments: () => investments.stream,
        cashFlows: () => cashFlows.stream,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(HeroCardSkeleton), findsOneWidget);
      expect(find.bySemanticsLabel('Loading your portfolio'), findsOneWidget);
      expect(find.byType(OverviewEmptyState), findsNothing);
      expect(find.text('Try Sample Data'), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
      expect(_emptyStateEvents(analytics), 0);
    },
  );

  testWidgets(
    'when data fails to load, shows a retry message and never offers sample '
    'data or logs empty_state_viewed',
    (tester) async {
      var investmentSubscriptions = 0;

      await _pumpOverview(
        tester,
        analytics: analytics,
        investments: () {
          investmentSubscriptions++;
          return Stream.error(Exception('permission-denied'));
        },
        cashFlows: () => Stream.value(const []),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text("Couldn't load your portfolio"), findsOneWidget);
      expect(
        find.text('Your data is safe. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.text('Retry')),
        containsSemantics(label: 'Retry', isButton: true),
      );
      expect(find.byType(OverviewEmptyState), findsNothing);
      expect(find.text('Try Sample Data'), findsNothing);
      expect(find.text('Get Started'), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
      expect(_emptyStateEvents(analytics), 0);

      // Retry subscribes to the data again.
      final before = investmentSubscriptions;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(investmentSubscriptions, greaterThan(before));
      expect(_emptyStateEvents(analytics), 0);
    },
  );

  testWidgets(
    'with the default retry policy, a load failure shows the retry message '
    'promptly instead of skeletons',
    (tester) async {
      await _pumpOverview(
        tester,
        analytics: analytics,
        productionRetry: true,
        investments: () => Stream.error(Exception('unavailable')),
        cashFlows: () => Stream.value(const []),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Couldn't load your portfolio"), findsOneWidget);
      expect(find.byType(HeroCardSkeleton), findsNothing);
      expect(find.byType(OverviewEmptyState), findsNothing);
      expect(find.text('Try Sample Data'), findsNothing);
      expect(_emptyStateEvents(analytics), 0);

      // Unmount so Riverpod cancels its pending retry timers.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'an account with no investments sees the empty state with sample data, '
    'and empty_state_viewed is logged once across rebuilds',
    (tester) async {
      final investments = StreamController<List<InvestmentEntity>>();
      addTearDown(() => unawaited(investments.close()));

      await _pumpOverview(
        tester,
        analytics: analytics,
        investments: () => investments.stream,
        cashFlows: () => Stream.value(const []),
      );
      investments.add(const []);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(OverviewEmptyState), findsOneWidget);
      expect(find.text('Try Sample Data'), findsOneWidget);

      // A new snapshot rebuilds the screen; it must not log again.
      investments.add(<InvestmentEntity>[]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      investments.add(<InvestmentEntity>[]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(OverviewEmptyState), findsOneWidget);
      expect(_emptyStateEvents(analytics), 1);
    },
  );

  testWidgets(
    'an account with investments but no cash flows is not offered sample '
    'data and is not counted as an empty state view',
    (tester) async {
      await _pumpOverview(
        tester,
        analytics: analytics,
        investments: () => Stream.value([_investment]),
        cashFlows: () => Stream.value(const []),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Try Sample Data'), findsNothing);
      expect(_emptyStateEvents(analytics), 0);
    },
  );

  testWidgets(
    'an account whose investments are all archived is not offered sample '
    'data and is not counted as an empty state view',
    (tester) async {
      await _pumpOverview(
        tester,
        analytics: analytics,
        investments: () => Stream.value(const []),
        cashFlows: () => Stream.value(const []),
        archivedInvestments: () => Stream.value([_investment]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Try Sample Data'), findsNothing);
      expect(_emptyStateEvents(analytics), 0);
    },
  );

  testWidgets(
    'an account whose investments are all archived sees why the totals are '
    'empty, not the first-run onboarding (A17)',
    (tester) async {
      await _pumpOverview(
        tester,
        analytics: analytics,
        investments: () => Stream.value(const []),
        cashFlows: () => Stream.value(const []),
        archivedInvestments: () => Stream.value([_investment]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(OverviewEmptyState), findsNothing);
      expect(find.text('All your investments are archived'), findsOneWidget);
      expect(
        find.text(
          'Overview totals, goals and FIRE leave archived investments out, '
          'so they show nothing for now. Your archived investments are '
          'still in the Investments tab.',
        ),
        findsOneWidget,
      );
      expect(find.text('View investments'), findsOneWidget);
      // The hero says what it leaves out.
      expect(find.text('Excludes 1 archived investment'), findsOneWidget);
      expect(_emptyStateEvents(analytics), 0);
    },
  );

  testWidgets(
    'a new account still sees the onboarding and no all-archived card',
    (tester) async {
      await _pumpOverview(
        tester,
        analytics: analytics,
        investments: () => Stream.value(const []),
        cashFlows: () => Stream.value(const []),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(OverviewEmptyState), findsOneWidget);
      expect(find.text('All your investments are archived'), findsNothing);
      expect(find.textContaining('Excludes'), findsNothing);
    },
  );

  testWidgets(
    'when archived investments fail to load, an empty account shows the retry '
    'message, and Retry loads them again',
    (tester) async {
      var archivedSubscriptions = 0;

      await _pumpOverview(
        tester,
        analytics: analytics,
        investments: () => Stream.value(const []),
        cashFlows: () => Stream.value(const []),
        archivedInvestments: () {
          archivedSubscriptions++;
          return Stream.error(Exception('unavailable'));
        },
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text("Couldn't load your portfolio"), findsOneWidget);
      expect(find.byType(OverviewEmptyState), findsNothing);
      expect(find.text('Try Sample Data'), findsNothing);
      expect(_emptyStateEvents(analytics), 0);

      final before = archivedSubscriptions;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(archivedSubscriptions, greaterThan(before));
      expect(_emptyStateEvents(analytics), 0);
    },
  );

  testWidgets(
    'with no cash flows yet, shows loading, not the empty state, while '
    'investments are still loading',
    (tester) async {
      final investments = StreamController<List<InvestmentEntity>>();
      final archived = StreamController<List<InvestmentEntity>>();
      addTearDown(() => unawaited(investments.close()));
      addTearDown(() => unawaited(archived.close()));

      await _pumpOverview(
        tester,
        analytics: analytics,
        investments: () => investments.stream,
        cashFlows: () => Stream.value(const []),
        archivedInvestments: () => archived.stream,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.bySemanticsLabel('Loading your portfolio'), findsOneWidget);
      expect(find.byType(OverviewEmptyState), findsNothing);
      expect(find.textContaining('₹'), findsNothing);

      // Active loaded, archived still loading: still loading.
      investments.add(const []);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('Loading your portfolio'), findsOneWidget);
      expect(find.byType(OverviewEmptyState), findsNothing);
      expect(_emptyStateEvents(analytics), 0);
    },
  );

  testWidgets('sample data waits until archived investments have loaded', (
    tester,
  ) async {
    final archived = StreamController<List<InvestmentEntity>>();
    addTearDown(() => unawaited(archived.close()));

    await _pumpOverview(
      tester,
      analytics: analytics,
      investments: () => Stream.value(const []),
      cashFlows: () => Stream.value(const []),
      archivedInvestments: () => archived.stream,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Try Sample Data'), findsNothing);
    expect(_emptyStateEvents(analytics), 0);

    archived.add(const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Try Sample Data'), findsOneWidget);
    expect(_emptyStateEvents(analytics), 1);
  });
}
