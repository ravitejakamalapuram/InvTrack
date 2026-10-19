import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/auth/data/services/sign_out_cleanup_service.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockSecurity extends Mock implements SecurityService {}

void main() {
  late _MockFirestore firestore;
  late _MockSecurity security;
  late SharedPreferences prefs;
  late List<String> calls;
  late SignOutCleanupService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sample_data_mode_active': true,
      'milestone_shown_inv1_2.0': true,
      'goal_milestone_shown_g1_50': true,
      'idle_alert_last_shown_inv1': 'x',
      'user_signup_date': '2026-01-01',
      'activation_day_3_sent': true,
      'theme_mode': 'dark',
    });
    prefs = await SharedPreferences.getInstance();
    firestore = _MockFirestore();
    security = _MockSecurity();
    calls = [];
    when(() => security.removePin()).thenAnswer((_) async => calls.add('pin'));
    when(
      () => firestore.clearPersistence(),
    ).thenAnswer((_) async => calls.add('clear'));
    service = SignOutCleanupService(
      firestore: firestore,
      security: security,
      prefs: prefs,
      deleteDocuments: (uid) async => calls.add('docs:$uid'),
      syncTimeout: const Duration(milliseconds: 50),
    );
  });

  test(
    'wipe removes PIN, documents and per-user prefs, and queues the cache clear',
    () async {
      await service.wipe('u1');

      expect(calls, ['pin', 'docs:u1']);
      verifyNever(() => firestore.terminate());
      verifyNever(() => firestore.clearPersistence());
      expect(prefs.getString(SignOutCleanupService.pendingCacheClearKey), 'u1');
      expect(prefs.containsKey('sample_data_mode_active'), isFalse);
      expect(prefs.containsKey('milestone_shown_inv1_2.0'), isFalse);
      expect(prefs.containsKey('goal_milestone_shown_g1_50'), isFalse);
      expect(prefs.containsKey('idle_alert_last_shown_inv1'), isFalse);
      expect(prefs.containsKey('user_signup_date'), isFalse);
      expect(prefs.containsKey('activation_day_3_sent'), isFalse);
      expect(prefs.getString('theme_mode'), 'dark');
    },
  );

  test('a failing step does not stop the others', () async {
    when(() => security.removePin()).thenThrow(Exception('storage'));

    await service.wipe('u1');

    expect(calls, ['docs:u1']);
  });

  test('hasUnsyncedWrites is false once pending writes complete', () async {
    when(() => firestore.waitForPendingWrites()).thenAnswer((_) async {});
    expect(await service.hasUnsyncedWrites(), isFalse);
  });

  test(
    'hasUnsyncedWrites is true when pending writes do not finish in time',
    () async {
      when(
        () => firestore.waitForPendingWrites(),
      ).thenAnswer((_) => Completer<void>().future);
      expect(await service.hasUnsyncedWrites(), isTrue);
    },
  );

  group('clearPendingCache', () {
    Future<void> run(Future<String?> Function() uid) =>
        SignOutCleanupService.clearPendingCache(
          firestore: firestore,
          prefs: prefs,
          currentUserId: uid,
        );

    Future<void> queue() =>
        prefs.setString(SignOutCleanupService.pendingCacheClearKey, 'u1');

    bool queued() =>
        prefs.containsKey(SignOutCleanupService.pendingCacheClearKey);

    test(
      'does nothing, and never asks for the user, when nothing is queued',
      () async {
        await run(() async => fail('must not be called'));
        expect(calls, isEmpty);
      },
    );

    test('clears the cache and the marker when nobody is signed in', () async {
      await queue();
      await run(() async => null);
      expect(calls, ['clear']);
      expect(queued(), isFalse);
    });

    test(
      'never clears while a user is signed in, so their unsynced edits survive',
      () async {
        for (final uid in ['u1', 'u2']) {
          await queue();
          await run(() async => uid);
          expect(queued(), isFalse);
        }
        expect(calls, isEmpty);
      },
    );

    test('keeps the marker when the session cannot be resolved', () async {
      await queue();
      await run(() async => throw TimeoutException('auth'));
      expect(calls, isEmpty);
      expect(queued(), isTrue);
    });

    test(
      'keeps the marker when clearing fails, so the next start retries',
      () async {
        await queue();
        when(() => firestore.clearPersistence()).thenThrow(Exception('busy'));
        await run(() async => null);
        expect(queued(), isTrue);
      },
    );
  });
}
