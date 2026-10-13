// A41 (#784): the screens a new user opens from Overview to add their first
// investment are pushed imperatively. Each carries a screen name, so
// screen_view shows where the funnel starts and where it is left.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_route_observer.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

final _fd = InvestmentEntity(
  currency: 'INR',
  id: 'inv-1',
  name: 'FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<void> _pumpOverview(
  WidgetTester tester,
  FakeAnalyticsService analytics, {
  required List<InvestmentEntity> investments,
}) async {
  // Tall enough for the empty state's buttons to be on screen.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsServiceProvider.overrideWithValue(analytics),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
        allInvestmentsProvider.overrideWith((ref) => Stream.value(investments)),
        allCashFlowsStreamProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        archivedInvestmentsProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        hasNoInvestmentsProvider.overrideWith(
          (ref) => Stream.value(investments.isEmpty),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [AnalyticsRouteObserver(analytics)],
        initialRoute: 'overview',
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const OverviewScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late FakeAnalyticsService analytics;

  setUp(() => analytics = FakeAnalyticsService());

  testWidgets('the Add Investment button opens add_investment', (tester) async {
    await _pumpOverview(tester, analytics, investments: [_fd]);

    await tester.tap(find.text('Add Investment'));
    await tester.pumpAndSettle();

    expect(analytics.screenViews, ['overview', 'add_investment']);
  });

  testWidgets('Add Manually in the empty state opens add_investment', (
    tester,
  ) async {
    await _pumpOverview(tester, analytics, investments: const []);

    await tester.tap(find.text('Add Manually'));
    await tester.pumpAndSettle();

    expect(analytics.screenViews, ['overview', 'add_investment']);
  });

  testWidgets('Import CSV in the empty state opens bulk_import', (
    tester,
  ) async {
    await _pumpOverview(tester, analytics, investments: const []);

    await tester.tap(find.text('Import CSV'));
    await tester.pumpAndSettle();

    expect(analytics.screenViews, ['overview', 'bulk_import']);
  });

  testWidgets('a template chip in the empty state opens add_investment', (
    tester,
  ) async {
    await _pumpOverview(tester, analytics, investments: const []);

    final chip = find
        .byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label ?? '').startsWith('Template: '),
        )
        .first;
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(analytics.screenViews, ['overview', 'add_investment']);
  });
}
