import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/router/navigation_extensions.dart';

void main() {
  group('SafeNavigationExtension', () {
    group('safePop', () {
      testWidgets('pops when canPop returns true', (tester) async {
        bool didPop = false;

        final router = GoRouter(
          initialLocation: '/first',
          routes: [
            GoRoute(
              path: '/first',
              builder: (context, state) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => context.push('/second'),
                  child: const Text('Go to Second'),
                ),
              ),
            ),
            GoRoute(
              path: '/second',
              builder: (context, state) => Scaffold(
                body: ElevatedButton(
                  key: const Key('pop_button'),
                  onPressed: () {
                    didPop = context.canPop();
                    context.safePop();
                  },
                  child: const Text('Pop'),
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Navigate to second screen
        await tester.tap(find.text('Go to Second'));
        await tester.pumpAndSettle();

        // Verify we're on second screen
        expect(find.text('Pop'), findsOneWidget);

        // Now pop - should work since we can pop
        await tester.tap(find.byKey(const Key('pop_button')));
        await tester.pumpAndSettle();

        // Should be back on first screen
        expect(find.text('Go to Second'), findsOneWidget);
        expect(didPop, isTrue);
      });

      testWidgets('navigates to fallback when canPop returns false', (
        tester,
      ) async {
        final router = GoRouter(
          initialLocation: '/only',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(
              path: '/only',
              builder: (context, state) => Scaffold(
                body: ElevatedButton(
                  key: const Key('pop_button'),
                  onPressed: () => context.safePop(),
                  child: const Text('Safe Pop'),
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Verify we're on the only screen (root)
        expect(find.text('Safe Pop'), findsOneWidget);

        // Try to pop - should navigate to fallback '/'
        await tester.tap(find.byKey(const Key('pop_button')));
        await tester.pumpAndSettle();

        // Should be on home (fallback)
        expect(find.text('Home'), findsOneWidget);
      });

      testWidgets('uses custom fallback route', (tester) async {
        final router = GoRouter(
          initialLocation: '/start',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (context, state) =>
                  const Scaffold(body: Text('Dashboard')),
            ),
            GoRoute(
              path: '/start',
              builder: (context, state) => Scaffold(
                body: ElevatedButton(
                  key: const Key('pop_button'),
                  onPressed: () => context.safePop('/dashboard'),
                  child: const Text('Safe Pop to Dashboard'),
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Try to pop with custom fallback
        await tester.tap(find.byKey(const Key('pop_button')));
        await tester.pumpAndSettle();

        // Should be on dashboard (custom fallback)
        expect(find.text('Dashboard'), findsOneWidget);
      });
    });

    group('safePopWithResult', () {
      testWidgets('pops with result when canPop returns true', (tester) async {
        String? receivedResult;

        final router = GoRouter(
          initialLocation: '/first',
          routes: [
            GoRoute(
              path: '/first',
              builder: (context, state) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    final result = await context.push<String>('/second');
                    receivedResult = result;
                  },
                  child: const Text('Go to Second'),
                ),
              ),
            ),
            GoRoute(
              path: '/second',
              builder: (context, state) => Scaffold(
                body: ElevatedButton(
                  key: const Key('pop_button'),
                  onPressed: () => context.safePopWithResult('success'),
                  child: const Text('Pop with Result'),
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Navigate to second screen
        await tester.tap(find.text('Go to Second'));
        await tester.pumpAndSettle();

        // Pop with result
        await tester.tap(find.byKey(const Key('pop_button')));
        await tester.pumpAndSettle();

        // Should be back on first screen with result
        expect(find.text('Go to Second'), findsOneWidget);
        expect(receivedResult, equals('success'));
      });

      testWidgets(
        'navigates to fallback (discarding result) when canPop returns false',
        (tester) async {
          final router = GoRouter(
            initialLocation: '/only',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const Scaffold(body: Text('Home')),
              ),
              GoRoute(
                path: '/only',
                builder: (context, state) => Scaffold(
                  body: ElevatedButton(
                    key: const Key('pop_button'),
                    // Result 'data' will be discarded when falling back
                    onPressed: () => context.safePopWithResult('data'),
                    child: const Text('Safe Pop with Result'),
                  ),
                ),
              ),
            ],
          );

          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          await tester.pumpAndSettle();

          // Try to pop with result - should navigate to fallback
          await tester.tap(find.byKey(const Key('pop_button')));
          await tester.pumpAndSettle();

          // Should be on home (fallback), result was discarded
          expect(find.text('Home'), findsOneWidget);
        },
      );
    });
  });
}
