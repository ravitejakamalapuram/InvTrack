// A41 (#784): every route of the app has a stable screen name, so screen_view
// never carries ':id' or a path, and the router logs the first screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../mocks/fake_auth_repository.dart';
import '../../mocks/mock_analytics_service.dart';

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

/// Full path of every GoRoute, and the shell routes found on the way.
void _walk(
  List<RouteBase> routes,
  String parentPath,
  Map<String, String?> names,
  List<StatefulShellRoute> shells,
) {
  for (final route in routes) {
    switch (route) {
      case GoRoute():
        final path = route.path.startsWith('/')
            ? route.path
            : '${parentPath == '/' ? '' : parentPath}/${route.path}';
        names[path] = route.name;
        _walk(route.routes, path, names, shells);
      case StatefulShellRoute():
        shells.add(route);
        for (final branch in route.branches) {
          _walk(branch.routes, parentPath, names, shells);
        }
      default:
        _walk(route.routes, parentPath, names, shells);
    }
  }
}

void main() {
  late FakeAnalyticsService analytics;
  late ProviderContainer container;

  setUp(() {
    analytics = FakeAnalyticsService();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(null)),
        securityProvider.overrideWith(_TestSecurityNotifier.new),
        onboardingCompleteProvider.overrideWith((ref) async => false),
        analyticsServiceProvider.overrideWithValue(analytics),
        isReportsTabEnabledProvider.overrideWithValue(false),
        isIncomeGuardianEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
  });

  test('every GoRoute has its own snake_case screen name', () {
    final names = <String, String?>{};
    final shells = <StatefulShellRoute>[];
    _walk(
      container.read(routerProvider).configuration.routes,
      '/',
      names,
      shells,
    );

    expect(names, {
      '/': 'overview',
      '/investments': 'investments',
      '/investments/:id': 'investment_detail',
      '/investments/:id/add-cash-flow': 'add_cash_flow',
      '/goals': 'goals',
      '/goals/create': 'goal_create',
      '/goals/:id': 'goal_detail',
      '/reports': 'reports',
      '/reports/builder': 'report_builder',
      '/settings': 'settings',
      '/auth/signin': 'sign_in',
      '/lock': 'lock',
      '/onboarding': 'onboarding',
      '/fire': 'fire',
      '/fire/setup': 'fire_setup',
      '/fire/settings': 'fire_settings',
      '/portfolio-health': 'portfolio_health',
      '/income-calendar': 'income_calendar',
      '/recap/:month': 'monthly_recap',
    });
  });

  // go_router forwards the events of each tab's Navigator to the router's
  // observer. A second observer on a tab would log every tab screen twice.
  test('tabs rely on the router observer: none of their own', () {
    final shells = <StatefulShellRoute>[];
    _walk(
      container.read(routerProvider).configuration.routes,
      '/',
      <String, String?>{},
      shells,
    );

    expect(shells, hasLength(1));
    expect(shells.single.notifyRootObserver, isTrue);
    for (final branch in shells.single.branches) {
      expect(branch.observers, isNull);
    }
  });

  testWidgets('the first screen is logged by name', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            // Like the app root, but only once auth and onboarding are
            // known, so the first location is the redirected one.
            final ready =
                ref.watch(authStateProvider).hasValue &&
                ref.watch(onboardingCompleteProvider).hasValue;
            if (!ready) return const SizedBox();
            return MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: ref.watch(routerProvider),
            );
          },
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(analytics.screenViews, ['onboarding']);
  });
}
