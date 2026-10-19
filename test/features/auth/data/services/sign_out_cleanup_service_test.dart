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
      () => firestore.terminate(),
    ).thenAnswer((_) async => calls.add('terminate'));
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
    'wipe removes PIN, documents, per-user prefs and the Firestore cache',
    () async {
      await service.wipe('u1');

      expect(calls, ['pin', 'docs:u1', 'terminate', 'clear']);
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

    expect(calls, ['docs:u1', 'terminate', 'clear']);
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
}
