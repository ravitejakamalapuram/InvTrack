// A121 (#895): on a fresh install with no network, the investments listener
// answers from an empty cache. Overview took that for a new account: it
// showed the first-run empty state, offered "Try Sample Data" to a user whose
// portfolio is on the server, and counted an empty_state_viewed. Until the
// server confirms the account is empty, Overview must keep loading.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../investment/data/repositories/investment_snapshot_mocks.dart';

int _emptyStateEvents(FakeAnalyticsService analytics) =>
    analytics.loggedEvents.where((e) => e.name == 'empty_state_viewed').length;

void main() {
  setUpAll(registerInvestmentSnapshotFallbacks);

  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<(FakeAnalyticsService, InvestmentFirestoreMock)> pumpOverview(
    WidgetTester tester,
  ) async {
    final analytics = FakeAnalyticsService();
    final firestore = InvestmentFirestoreMock();
    addTearDown(firestore.close);
    final repository = firestore.repository();
    SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          analyticsServiceProvider.overrideWithValue(analytics),
          currencyCodeProvider.overrideWith((ref) => 'INR'),
          currencySymbolProvider.overrideWith((ref) => '₹'),
          currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
          // The real investment providers, fed by the repository.
          isAuthenticatedProvider.overrideWithValue(true),
          investmentRepositoryProvider.overrideWithValue(repository),
          allCashFlowsStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OverviewScreen(),
        ),
      ),
    );

    return (analytics, firestore);
  }

  testWidgets('an empty cache answer with no server answer keeps Overview '
      'loading: no empty state, no sample data, no empty_state_viewed; the '
      'server confirming the empty account then shows them', (tester) async {
    final (analytics, firestore) = await pumpOverview(tester);

    // Offline first launch: both collections answer from an empty cache.
    firestore.activeSnapshots.add(querySnapshot(fromCache: true));
    firestore.archivedSnapshots.add(querySnapshot(fromCache: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HeroCardSkeleton), findsOneWidget);
    expect(find.bySemanticsLabel('Loading your portfolio'), findsOneWidget);
    expect(find.byType(OverviewEmptyState), findsNothing);
    expect(find.text(l10n.trySampleData), findsNothing);
    expect(_emptyStateEvents(analytics), 0);

    // Back online: the server confirms both collections are empty.
    firestore.activeSnapshots.add(querySnapshot(fromCache: false));
    firestore.archivedSnapshots.add(querySnapshot(fromCache: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(OverviewEmptyState), findsOneWidget);
    expect(find.text(l10n.trySampleData), findsOneWidget);
    expect(_emptyStateEvents(analytics), 1);
  });

  testWidgets('offline, a portfolio whose investments are all archived shows '
      'the empty state at once from the cache, without the sample-data offer '
      'or empty_state_viewed', (tester) async {
    final (analytics, firestore) = await pumpOverview(tester);

    firestore.activeSnapshots.add(querySnapshot(fromCache: true));
    firestore.archivedSnapshots.add(
      querySnapshot(docs: {'inv-1': investmentDoc('Old FD')}, fromCache: true),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HeroCardSkeleton), findsNothing);
    expect(find.byType(OverviewEmptyState), findsOneWidget);
    expect(find.text(l10n.trySampleData), findsNothing);
    expect(_emptyStateEvents(analytics), 0);
  });
}
