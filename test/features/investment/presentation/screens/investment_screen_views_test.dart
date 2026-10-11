// A41 (#784): the screens the investment list and detail open to add an
// investment or a cash flow are pushed imperatively. Each carries a screen
// name, so screen_view shows the funnel steps.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_route_observer.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_detail_fab_widgets.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_currency_conversion_service.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
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

/// [screen] as the first, named page of an app that reports screen views.
Future<void> _pump(
  WidgetTester tester,
  FakeAnalyticsService analytics, {
  required String name,
  required Widget screen,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsServiceProvider.overrideWithValue(analytics),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
        currencyCodeProvider.overrideWithValue('INR'),
        currencyConversionServiceProvider.overrideWithValue(
          MockCurrencyConversionService(),
        ),
        allInvestmentsProvider.overrideWith((ref) => Stream.value([_fund])),
        archivedInvestmentsProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        filteredInvestmentsProvider.overrideWith(
          (ref) => AsyncValue.data([_fund]),
        ),
        investmentCountsProvider.overrideWithValue((
          all: 1,
          open: 1,
          closed: 0,
          archived: 0,
        )),
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
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [AnalyticsRouteObserver(analytics)],
        initialRoute: name,
        onGenerateRoute: (settings) =>
            MaterialPageRoute(settings: settings, builder: (_) => screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeAnalyticsService analytics;

  setUp(() => analytics = FakeAnalyticsService());

  testWidgets('the list\'s Add Investment button opens add_investment', (
    tester,
  ) async {
    await _pump(
      tester,
      analytics,
      name: 'investments',
      screen: const InvestmentListScreen(),
    );

    await tester.tap(find.text('Add Investment'));
    await tester.pumpAndSettle();

    expect(analytics.screenViews, ['investments', 'add_investment']);
  });

  testWidgets('the detail\'s add transaction button opens add_cash_flow', (
    tester,
  ) async {
    await _pump(
      tester,
      analytics,
      name: 'investment_detail',
      screen: InvestmentDetailScreen(investment: _fund),
    );

    await tester.tap(find.byType(TransactionFab));
    await tester.pumpAndSettle();

    expect(analytics.screenViews, ['investment_detail', 'add_cash_flow']);
  });
}
