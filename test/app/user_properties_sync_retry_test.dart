// #980: the user-properties sync marked a value as sent before the write
// finished, and AnalyticsService.setUserProperty swallows errors, so one failed
// write was never retried until the value changed. Checked on the real
// AnalyticsService against a mocked Firebase, so the swallowed error is the
// one the app would see.
import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/app/user_properties_sync.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

class _Currency extends Notifier<String> {
  @override
  String build() => 'INR';

  void set(String code) => state = code;
}

final _currencyProvider = NotifierProvider<_Currency, String>(_Currency.new);

void main() {
  late StreamController<UserEntity?> auth;
  late _MockFirebaseAnalytics firebase;
  late ProviderContainer container;
  final calls = <({String name, String? value})>[];

  /// Decides, per write, whether Firebase accepts it. The default accepts.
  late Future<void> Function(String name, String? value) firebaseWrite;

  setUp(() {
    calls.clear();
    firebaseWrite = (_, _) async {};
    auth = StreamController<UserEntity?>();
    firebase = _MockFirebaseAnalytics();
    when(
      () => firebase.setUserProperty(
        name: any(named: 'name'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((call) {
      final name = call.namedArguments[#name] as String;
      final value = call.namedArguments[#value] as String?;
      calls.add((name: name, value: value));
      return firebaseWrite(name, value);
    });
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => auth.stream),
        analyticsServiceProvider.overrideWithValue(
          AnalyticsService(analytics: firebase),
        ),
        currencyCodeProvider.overrideWith(
          (ref) => ref.watch(_currencyProvider),
        ),
      ],
    );
    addTearDown(auth.close);
    addTearDown(container.dispose);
    container.listen(userPropertiesSyncProvider, (_, _) {});
  });

  Future<void> emit(UserEntity? user) async {
    auth.add(user);
    await pumpEventQueue();
  }

  const guest = UserEntity(id: 'g1', email: '', isAnonymous: true);
  // Same account state, so the same properties: a token refresh, say.
  const guestRefreshed = UserEntity(
    id: 'g1',
    email: '',
    isAnonymous: true,
    displayName: 'refreshed',
  );

  Iterable<String?> writesOf(String name) =>
      calls.where((c) => c.name == name).map((c) => c.value);

  group('user-property retry', () {
    test('a write that failed is sent again at the next sync, though the value '
        'is unchanged', () async {
      var failed = false;
      firebaseWrite = (name, _) async {
        if (name == 'is_guest' && !failed) {
          failed = true;
          throw Exception('analytics offline');
        }
      };

      await emit(guest);
      expect(writesOf('is_guest'), ['true'], reason: 'the first write failed');

      await emit(guestRefreshed);

      expect(writesOf('is_guest'), ['true', 'true']);
      expect(
        writesOf('base_currency'),
        ['INR'],
        reason: 'the one that went through is not sent again',
      );
    });

    test('once a retry goes through, the value is not sent again', () async {
      var failures = 1;
      firebaseWrite = (name, _) async {
        if (name == 'is_guest' && failures-- > 0) throw Exception('offline');
      };

      await emit(guest);
      await emit(guestRefreshed);
      await emit(guest);

      expect(writesOf('is_guest'), ['true', 'true']);
    });

    test('a failure for a value that has been replaced does not undo the newer '
        'one', () async {
      final slowInr = Completer<void>();
      firebaseWrite = (name, value) {
        if (name == 'base_currency' && value == 'INR') return slowInr.future;
        return Future<void>.value();
      };

      await emit(guest);
      container.read(_currencyProvider.notifier).set('USD');
      await pumpEventQueue();
      expect(writesOf('base_currency'), ['INR', 'USD']);

      // The old write fails after the new one went through.
      slowInr.completeError(Exception('analytics offline'));
      await pumpEventQueue();
      await emit(guestRefreshed);

      expect(
        writesOf('base_currency'),
        ['INR', 'USD'],
        reason: 'USD is what Analytics holds, so it is not written again',
      );
    });
  });
}
