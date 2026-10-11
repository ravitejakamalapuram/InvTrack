// A41 (#784): the Analytics user properties is_guest and base_currency follow
// the signed-in account. They are set when they change and cleared when
// no one is signed in; nothing about the portfolio is sent (that waits for
// the analytics consent toggle, A34).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/app/user_properties_sync.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';

import '../mocks/mock_analytics_service.dart';

/// Records every call, to tell a repeated write from a kept value.
class _RecordingAnalytics extends FakeAnalyticsService {
  final calls = <({String name, String? value})>[];
  Object? failWith;

  @override
  Future<bool> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (failWith != null) throw failWith!;
    calls.add((name: name, value: value));
    return super.setUserProperty(name: name, value: value);
  }
}

class _Currency extends Notifier<String> {
  @override
  String build() => 'INR';

  void set(String code) => state = code;
}

final _currencyProvider = NotifierProvider<_Currency, String>(_Currency.new);

void main() {
  late StreamController<UserEntity?> auth;
  late _RecordingAnalytics analytics;
  late ProviderContainer container;

  setUp(() {
    auth = StreamController<UserEntity?>();
    analytics = _RecordingAnalytics();
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => auth.stream),
        analyticsServiceProvider.overrideWithValue(analytics),
        currencyCodeProvider.overrideWith(
          (ref) => ref.watch(_currencyProvider),
        ),
      ],
    );
    addTearDown(auth.close);
    addTearDown(container.dispose);
    // Listened to, as the app root does: an unlistened provider is paused.
    container.listen(userPropertiesSyncProvider, (_, _) {});
  });

  Future<void> emit(UserEntity? user) async {
    auth.add(user);
    await pumpEventQueue();
  }

  const guest = UserEntity(id: 'g1', email: '', isAnonymous: true);

  test('a guest is labelled is_guest with the base currency', () async {
    await emit(guest);

    expect(analytics.userProperties, {
      'is_guest': 'true',
      'base_currency': 'INR',
    });
  });

  test('nothing is set while sign-in is still loading or has failed', () async {
    await pumpEventQueue();
    expect(analytics.calls, isEmpty);

    auth.addError(StateError('auth unavailable'));
    await pumpEventQueue();
    expect(analytics.calls, isEmpty);
  });

  test('linking a guest to Google keeps the UID and flips is_guest', () async {
    await emit(guest);
    await emit(
      const UserEntity(
        id: 'g1',
        email: 'ravi@example.com',
        displayName: 'Ravi',
      ),
    );

    expect(analytics.userProperties['is_guest'], 'false');
    expect(analytics.userProperties['base_currency'], 'INR');
    expect(
      analytics.calls.where((c) => c.name == 'is_guest').map((c) => c.value),
      ['true', 'false'],
    );
    expect(
      analytics.calls.where((c) => c.name == 'base_currency'),
      hasLength(1),
    );
  });

  test('changing the base currency updates only base_currency', () async {
    await emit(guest);
    container.read(_currencyProvider.notifier).set('USD');
    await pumpEventQueue();

    expect(analytics.userProperties, {
      'is_guest': 'true',
      'base_currency': 'USD',
    });
    expect(analytics.calls.where((c) => c.name == 'is_guest'), hasLength(1));
  });

  test('an emission that changes neither property writes nothing', () async {
    await emit(
      const UserEntity(id: 'g1', email: 'a@example.com', displayName: 'A'),
    );
    final before = analytics.calls.length;

    // A token refresh with a new display name: same account state.
    await emit(
      const UserEntity(id: 'g1', email: 'a@example.com', displayName: 'B'),
    );

    expect(analytics.calls, hasLength(before));
  });

  test('signing out clears both properties', () async {
    await emit(guest);
    await emit(null);

    expect(analytics.userProperties, {'is_guest': null, 'base_currency': null});
  });

  test('a second user does not inherit the first one\'s properties', () async {
    await emit(guest);
    await emit(null);
    await emit(const UserEntity(id: 'google1', email: 'a@example.com'));

    expect(analytics.userProperties, {
      'is_guest': 'false',
      'base_currency': 'INR',
    });
  });

  test('a failing analytics call never breaks sign-in', () async {
    analytics.failWith = StateError('analytics unavailable');

    await emit(guest);
    await emit(null);

    expect(analytics.calls, isEmpty);
  });
}
