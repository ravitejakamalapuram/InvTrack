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

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

/// A42: Income Guardian is hidden while its flag is off, so its calendar
/// screen must not open from a deep link or a stale navigation either.
void main() {
  Future<String> resolve(WidgetTester tester, {required bool enabled}) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(googleUser),
        ),
        securityProvider.overrideWith(_TestSecurityNotifier.new),
        onboardingCompleteProvider.overrideWith((ref) async => true),
        analyticsObserverProvider.overrideWithValue(null),
        isReportsTabEnabledProvider.overrideWithValue(false),
        isIncomeGuardianEnabledProvider.overrideWithValue(enabled),
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
          RouteInformation(uri: Uri.parse('/income-calendar')),
          context,
        );
    // Dispose inside the test body so Riverpod's zero-length refresh timer
    // does not outlive it.
    container.dispose();
    await tester.pump();
    return matches.uri.path;
  }

  testWidgets('flag off: /income-calendar redirects to Overview', (
    tester,
  ) async {
    expect(await resolve(tester, enabled: false), '/');
  });

  testWidgets('flag on: /income-calendar opens', (tester) async {
    expect(await resolve(tester, enabled: true), '/income-calendar');
  });
}
