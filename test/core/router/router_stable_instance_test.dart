import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

import '../../mocks/fake_auth_repository.dart';
import '../../mocks/mock_analytics_service.dart';

class _TestSecurity extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
  void setLocked(bool v) => state = state.copyWith(isLocked: v);
}

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final _reportsFlag = NotifierProvider<_Flag, bool>(_Flag.new);

/// A27: one GoRouter for the whole session. Rebuilding it on a lock, auth,
/// onboarding or flag change reset navigation to '/' and dropped open forms.
void main() {
  testWidgets('same router across lock, flag and onboarding changes, and '
      'redirects follow the new state', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(googleUser),
        ),
        securityProvider.overrideWith(_TestSecurity.new),
        onboardingCompleteProvider.overrideWith((ref) async => true),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        isReportsTabEnabledProvider.overrideWith(
          (ref) => ref.watch(_reportsFlag),
        ),
        isIncomeGuardianEnabledProvider.overrideWithValue(false),
      ],
    );
    container.listen(routerProvider, (_, _) {});
    container.listen(authStateProvider, (_, _) {});
    container.listen(onboardingCompleteProvider, (_, _) {});
    await tester.pump();

    final router = container.read(routerProvider);
    final security = container.read(securityProvider.notifier) as _TestSecurity;

    Future<String> resolve(String path) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      final m = await router.routeInformationParser
          .parseRouteInformationWithDependencies(
            RouteInformation(uri: Uri.parse(path)),
            context,
          );
      return m.uri.path;
    }

    expect(await resolve('/'), '/');

    security.setLocked(true);
    await tester.pump();
    expect(identical(container.read(routerProvider), router), isTrue);
    expect(await resolve('/'), '/lock', reason: 'redirect reads live state');

    security.setLocked(false);
    await tester.pump();
    expect(identical(container.read(routerProvider), router), isTrue);
    expect(await resolve('/lock'), '/');

    container.read(_reportsFlag.notifier).set(true);
    await tester.pump();
    expect(identical(container.read(routerProvider), router), isTrue);
    expect(await resolve('/reports'), '/reports');

    container.invalidate(onboardingCompleteProvider);
    await tester.pump();
    await tester.pump();
    expect(identical(container.read(routerProvider), router), isTrue);
    // Dispose inside the body so Riverpod's refresh timer does not outlive it.
    container.dispose();
    await tester.pump();
  });

  testWidgets('a mounted router follows the lock', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(googleUser),
        ),
        securityProvider.overrideWith(_TestSecurity.new),
        onboardingCompleteProvider.overrideWith((ref) async => true),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        isReportsTabEnabledProvider.overrideWith(
          (ref) => ref.watch(_reportsFlag),
        ),
        isIncomeGuardianEnabledProvider.overrideWithValue(false),
      ],
    );
    container.listen(authStateProvider, (_, _) {});
    container.listen(onboardingCompleteProvider, (_, _) {});
    final router = container.read(routerProvider);
    final security = container.read(securityProvider.notifier) as _TestSecurity;
    // Mounted for real: a refresh count alone would pass while a locked user
    // stays on '/'. The screens need services this test does not set up and
    // throw while building; only the router's location matters here, so
    // those build errors are drained.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => Offstage(child: child),
        ),
      ),
    );
    Future<String> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      while (tester.takeException() != null) {}
      return router.state.uri.path;
    }

    var refreshes = 0;
    router.routeInformationProvider.addListener(() => refreshes++);
    expect(await settle(), '/');

    security.setLocked(true);
    expect(await settle(), '/lock');
    expect(refreshes, greaterThan(0));

    security.setLocked(false);
    expect(await settle(), '/');

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
}
