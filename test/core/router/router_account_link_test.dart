import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

import '../../mocks/fake_auth_repository.dart';

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

/// A05 / PLAT-13: after a guest links Google, the app must show the Google
/// account at once, without resetting navigation (the UID is unchanged).
void main() {
  late FakeAuthRepository authRepo;
  late ProviderContainer container;

  setUp(() {
    authRepo = FakeAuthRepository(guestUser);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        securityProvider.overrideWith(_TestSecurityNotifier.new),
        onboardingCompleteProvider.overrideWith((ref) async => true),
        analyticsObserverProvider.overrideWithValue(null),
        isReportsTabEnabledProvider.overrideWithValue(false),
        isIncomeGuardianEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'linking a guest updates auth state and keeps the same router',
    () async {
      container.listen(routerProvider, (_, _) {});
      container.listen(authStateProvider, (_, _) {});
      await settle();
      expect(container.read(authStateProvider).value, guestUser);
      final routerBefore = container.read(routerProvider);

      // Firebase reports the link: same UID, no longer anonymous.
      const linked = UserEntity(
        id: 'anon-uid',
        email: 'existing@example.com',
        displayName: 'Existing User',
      );
      authRepo.emit(linked);
      await settle();

      expect(container.read(authStateProvider).value, linked);
      expect(container.read(authStateProvider).value!.isAnonymous, isFalse);
      expect(identical(container.read(routerProvider), routerBefore), isTrue);
    },
  );

  test('signing in as a different user still rebuilds the router', () async {
    container.listen(routerProvider, (_, _) {});
    await settle();
    final routerBefore = container.read(routerProvider);

    authRepo.emit(googleUser);
    await settle();
    expect(container.read(authStateProvider).value, googleUser);

    expect(identical(container.read(routerProvider), routerBefore), isFalse);
  });
}
