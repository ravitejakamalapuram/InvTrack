import 'package:flutter/widgets.dart';
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

class _SecurityNotifier extends SecurityNotifier {
  _SecurityNotifier({required this.locked});
  final bool locked;

  @override
  SecurityState build() => SecurityState(isLocked: locked, hasPin: locked);
}

/// The router's lock redirect: a locked app shows the lock screen and nothing
/// else (no portfolio frame may render first), and an unlocked app never
/// stays on it.
void main() {
  Future<String> resolve(
    WidgetTester tester,
    String location, {
    required bool locked,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(googleUser),
        ),
        securityProvider.overrideWith(() => _SecurityNotifier(locked: locked)),
        onboardingCompleteProvider.overrideWith((ref) async => true),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        isReportsTabEnabledProvider.overrideWithValue(false),
        isIncomeGuardianEnabledProvider.overrideWithValue(false),
      ],
    );
    container.listen(routerProvider, (_, _) {});
    container.listen(authStateProvider, (_, _) {});

    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    await tester.pump();
    expect(container.read(authStateProvider).value, googleUser);

    final matches = await container
        .read(routerProvider)
        .routeInformationParser
        .parseRouteInformationWithDependencies(
          RouteInformation(uri: Uri.parse(location)),
          context,
        );
    // Dispose inside the test body so Riverpod's zero-length refresh timer
    // does not outlive it.
    container.dispose();
    await tester.pump();
    return matches.uri.path;
  }

  testWidgets('locked: any screen redirects to the lock screen', (
    tester,
  ) async {
    expect(await resolve(tester, '/', locked: true), '/lock');
  });

  testWidgets('locked: a deep link to a settings screen redirects to lock', (
    tester,
  ) async {
    expect(await resolve(tester, '/settings', locked: true), '/lock');
  });

  testWidgets('locked: the lock screen stays put', (tester) async {
    expect(await resolve(tester, '/lock', locked: true), '/lock');
  });

  testWidgets('unlocked: the lock screen redirects home', (tester) async {
    expect(await resolve(tester, '/lock', locked: false), '/');
  });

  testWidgets('unlocked: other screens are left alone', (tester) async {
    expect(await resolve(tester, '/settings', locked: false), '/settings');
  });
}
