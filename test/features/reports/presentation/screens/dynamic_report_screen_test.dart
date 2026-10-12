// A115: the empty report's "Add your first investment" button opens the add
// investment form. It used to push '/investments/add', which is not a route:
// the router matched '/investments/:id' and bounced to the Investments list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_screens.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/reports/domain/entities/dynamic_report_data.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/presentation/providers/dynamic_report_provider.dart';
import 'package:inv_tracker/features/reports/presentation/screens/dynamic_report_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _IdleInvestmentNotifier extends InvestmentNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);
}

class _RouteLog extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);
}

void main() {
  testWidgets('empty report: add first investment opens the add form, not '
      'the Investments list', (tester) async {
    final config = ReportConfiguration.weeklySummary();
    final log = _RouteLog();
    // Mirrors app_router.dart: there is no '/investments/add' route, so that
    // path matches ':id', which falls back to '/investments' without extra.
    final router = GoRouter(
      observers: [log],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => DynamicReportScreen(configuration: config),
        ),
        GoRoute(
          path: '/investments',
          builder: (_, _) => const Text('INVESTMENTS LIST'),
          routes: [
            GoRoute(
              path: ':id',
              redirect: (_, state) =>
                  state.extra == null ? '/investments' : null,
              builder: (_, _) => const Text('INVESTMENT DETAIL'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyCodeProvider.overrideWithValue('INR'),
          currencySymbolProvider.overrideWithValue('₹'),
          currencyLocaleProvider.overrideWithValue('en_IN'),
          investmentNotifierProvider.overrideWith(_IdleInvestmentNotifier.new),
          dynamicReportProvider.overrideWith(
            (ref, c) async => DynamicReportData.empty(
              reportType: c.reportType,
              title: 'Weekly',
              configuration: c,
            ),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Your First Investment'));
    await tester.pumpAndSettle();

    expect(find.text('INVESTMENTS LIST'), findsNothing);
    expect(find.byType(AddInvestmentScreen), findsOneWidget);
    expect(log.names, contains(AnalyticsScreens.addInvestment));
  });
}
