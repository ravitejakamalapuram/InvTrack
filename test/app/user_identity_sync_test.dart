// A101: the Analytics user ID and the Crashlytics user identifier follow the
// signed-in account through a guest start, a link, a merge, a sign-out and a
// deletion. One listener sets them; screens do not.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/app/user_identity_sync.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mock_analytics_service.dart';

class _MockCrashlyticsService extends Mock implements CrashlyticsService {}

void main() {
  late StreamController<UserEntity?> auth;
  late MockAnalyticsService analytics;
  late _MockCrashlyticsService crashlytics;

  setUp(() {
    auth = StreamController<UserEntity?>();
    analytics = MockAnalyticsService();
    crashlytics = _MockCrashlyticsService();
    when(() => analytics.setUserId(any())).thenAnswer((_) async {});
    when(() => crashlytics.setUserIdentifier(any())).thenAnswer((_) async {});
    when(() => crashlytics.clearUserIdentifier()).thenAnswer((_) async {});
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => auth.stream),
        analyticsServiceProvider.overrideWithValue(analytics),
        crashlyticsServiceProvider.overrideWithValue(crashlytics),
      ],
    );
    addTearDown(auth.close);
    addTearDown(container.dispose);
    // Listened to, as the app root does: an unlistened provider is paused.
    container.listen(userIdentitySyncProvider, (_, _) {});
  });

  Future<void> emit(UserEntity? user) async {
    auth.add(user);
    await pumpEventQueue();
  }

  const guest = UserEntity(id: 'g1', email: '', isAnonymous: true);

  test('a guest gets an ID, which a token refresh and a link keep', () async {
    await emit(guest);
    await emit(guest); // token refresh re-emits the same user
    await emit(
      const UserEntity(
        id: 'g1',
        email: 'ravi@example.com',
        displayName: 'Ravi',
      ),
    ); // linked to Google: same UID, no longer anonymous

    verify(() => analytics.setUserId('g1')).called(1);
    verify(() => crashlytics.setUserIdentifier('g1')).called(1);
    verifyNever(() => analytics.setUserId(null));
    verifyNever(() => crashlytics.clearUserIdentifier());
    verifyNoMoreInteractions(analytics);
    verifyNoMoreInteractions(crashlytics);
  });

  test('a merge moves both IDs to the Google account, and sign-out or '
      'deletion clears them', () async {
    await emit(guest);
    await emit(
      const UserEntity(id: 'google1', email: 'ravi@example.com'),
    ); // merged into an existing Google account

    verify(() => analytics.setUserId('google1')).called(1);
    verify(() => crashlytics.setUserIdentifier('google1')).called(1);

    await emit(null); // signed out, or the account was deleted

    verify(() => analytics.setUserId(null)).called(1);
    verify(() => crashlytics.clearUserIdentifier()).called(1);
    verify(() => analytics.setUserId('g1')).called(1);
    verify(() => crashlytics.setUserIdentifier('g1')).called(1);
    verifyNoMoreInteractions(analytics);
    verifyNoMoreInteractions(crashlytics);
  });

  test('a failing Crashlytics call does not break the sync', () async {
    when(
      () => crashlytics.setUserIdentifier(any()),
    ).thenAnswer((_) => Future<void>.error(StateError('no Firebase')));

    await emit(guest);
    await emit(const UserEntity(id: 'google1', email: ''));

    verify(() => analytics.setUserId('google1')).called(1);
  });

  test('an Analytics failure keeps the same UID eligible for retry', () async {
    var failures = 1;
    when(() => analytics.setUserId(any())).thenAnswer((_) async {
      if (failures-- > 0) throw StateError('analytics unavailable');
    });

    await emit(guest);
    // A link re-emits the same UID: the failed Analytics update must be retried.
    await emit(const UserEntity(id: 'g1', email: 'a@example.com'));
    // Once both services succeed, the same UID is not sent again.
    await emit(guest);

    verify(() => analytics.setUserId('g1')).called(2);
    verify(() => crashlytics.setUserIdentifier('g1')).called(2);
  });

  test('same UID emitted while update is pending is retried after failure', () async {
    final firstAttempt = Completer<void>();
    final releaseFirstAttempt = Completer<void>();
    var calls = 0;

    when(() => analytics.setUserId('g1')).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        firstAttempt.complete();
        await releaseFirstAttempt.future;
        throw StateError('analytics unavailable');
      }
    });

    auth.add(guest);
    await firstAttempt.future;

    // The second emission happens while the first update is still pending.
    // It carries the same UID but a different account state, as a link does;
    // an identical UserEntity would compare equal and never reach the
    // listener at all.
    auth.add(const UserEntity(id: 'g1', email: 'ravi@example.com'));
    await pumpEventQueue();

    releaseFirstAttempt.complete();
    await pumpEventQueue();
    await pumpEventQueue();

    verify(() => analytics.setUserId('g1')).called(2);
    verify(() => crashlytics.setUserIdentifier('g1')).called(2);
  });

  test('a failed update is tried again when the same UID comes back', () async {
    var failures = 1;
    when(() => crashlytics.setUserIdentifier(any())).thenAnswer((_) async {
      if (failures-- > 0) throw StateError('no Firebase');
    });

    await emit(guest);
    // A link re-emits the same UID: the failed update is tried again.
    await emit(const UserEntity(id: 'g1', email: 'a@example.com'));
    // Once it has succeeded, the same UID is not sent again.
    await emit(guest);

    verify(() => crashlytics.setUserIdentifier('g1')).called(2);
    verify(() => analytics.setUserId('g1')).called(2);
  });
}
