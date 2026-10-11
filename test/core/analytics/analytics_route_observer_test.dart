// A41 (#784): every named page logs one screen_view, through
// AnalyticsService; dialogs, sheets and unnamed pages log nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_route_observer.dart';

import '../../mocks/mock_analytics_service.dart';

Route<void> _page(String? name, {String label = 'page'}) => MaterialPageRoute(
  settings: RouteSettings(name: name),
  builder: (_) => Scaffold(body: Text(label)),
);

void main() {
  group('on a Navigator', () {
    late FakeAnalyticsService analytics;
    final navigatorKey = GlobalKey<NavigatorState>();
    NavigatorState navigator() => navigatorKey.currentState!;

    setUp(() async {
      analytics = FakeAnalyticsService();
    });

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [AnalyticsRouteObserver(analytics)],
          initialRoute: 'overview',
          onGenerateRoute: (settings) => _page(settings.name),
        ),
      );
    }

    testWidgets('logs a named page when pushed and again when it is '
        'revealed by a pop', (tester) async {
      await pumpApp(tester);
      expect(analytics.screenViews, ['overview']);

      navigator().push(_page('add_investment'));
      await tester.pumpAndSettle();
      expect(analytics.screenViews, ['overview', 'add_investment']);

      navigator().pop();
      await tester.pumpAndSettle();
      expect(analytics.screenViews, ['overview', 'add_investment', 'overview']);
    });

    testWidgets('logs the new page of a replacement', (tester) async {
      await pumpApp(tester);

      navigator().pushReplacement(_page('lock'));
      await tester.pumpAndSettle();

      expect(analytics.screenViews, ['overview', 'lock']);
    });

    testWidgets('an unnamed page is not a screen: it logs nothing when '
        'pushed', (tester) async {
      await pumpApp(tester);

      navigator().push(_page(null));
      await tester.pumpAndSettle();

      expect(analytics.screenViews, ['overview']);
    });

    testWidgets('a dialog and a bottom sheet log nothing, opened or closed', (
      tester,
    ) async {
      await pumpApp(tester);
      final context = navigator().context;

      showDialog<void>(
        context: context,
        routeSettings: const RouteSettings(name: 'a_dialog'),
        builder: (_) => const AlertDialog(title: Text('Sure?')),
      );
      await tester.pumpAndSettle();
      navigator().pop();
      await tester.pumpAndSettle();

      showModalBottomSheet<void>(
        context: context,
        routeSettings: const RouteSettings(name: 'a_sheet'),
        builder: (_) => const SizedBox(height: 100),
      );
      await tester.pumpAndSettle();
      navigator().pop();
      await tester.pumpAndSettle();

      expect(analytics.screenViews, ['overview']);
    });
  });

  // The app gives GoRouter one observer. go_router forwards the events of
  // every tab's own Navigator to it (notifyRootObserver), so a second
  // observer on a tab would log each tab screen twice.
  group('on a GoRouter with tabs', () {
    late FakeAnalyticsService analytics;
    late GoRouter router;

    setUp(() {
      analytics = FakeAnalyticsService();
      router = GoRouter(
        observers: [AnalyticsRouteObserver(analytics)],
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => shell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/',
                    name: 'overview',
                    builder: (_, _) => const Text('overview'),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/goals',
                    name: 'goals',
                    builder: (_, _) => const Text('goals'),
                    routes: [
                      GoRoute(
                        path: 'create',
                        name: 'goal_create',
                        builder: (_, _) => const Text('create'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/lock',
            name: 'lock',
            builder: (_, _) => const Text('lock'),
          ),
        ],
      );
      addTearDown(router.dispose);
    });

    testWidgets('logs each tab page and each pushed page once', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(analytics.screenViews, ['overview']);

      router.go('/goals');
      await tester.pumpAndSettle();
      expect(analytics.screenViews, ['overview', 'goals']);

      router.go('/goals/create');
      await tester.pumpAndSettle();
      expect(analytics.screenViews, ['overview', 'goals', 'goal_create']);

      router.go('/lock');
      await tester.pumpAndSettle();
      expect(analytics.screenViews, [
        'overview',
        'goals',
        'goal_create',
        'lock',
      ]);
    });
  });
}
