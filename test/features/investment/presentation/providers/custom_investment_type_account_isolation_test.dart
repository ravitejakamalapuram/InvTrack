// #936: saved custom types belong to the signed-in account. Switching the
// signed-in user shows only that user's types, and never the previous user's,
// not even for the moment before the new account's types have loaded.

// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/custom_investment_type_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../data/repositories/investment_snapshot_mocks.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

const _alice = UserEntity(id: 'alice', email: 'alice@example.com');
const _bob = UserEntity(id: 'bob', email: 'bob@example.com');

Map<String, dynamic> _doc(String label) => {
  'label': label,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
};

void main() {
  late StreamController<UserEntity?> auth;
  late ProviderContainer container;
  late List<List<String>> seen;

  /// What `users/{uid}/customInvestmentTypes` holds, per user.
  void stubUser(
    _MockFirestore firestore,
    _MockCollection users,
    String uid,
    List<String> labels,
  ) {
    final userDoc = _MockDoc();
    final types = _MockCollection();
    when(() => users.doc(uid)).thenReturn(userDoc);
    when(() => userDoc.collection('customInvestmentTypes')).thenReturn(types);
    when(() => types.snapshots()).thenAnswer(
      (_) => Stream.value(
        querySnapshot(
          fromCache: false,
          docs: {for (final l in labels) 'id-$l': _doc(l)},
        ),
      ),
    );
  }

  setUp(() {
    registerInvestmentSnapshotFallbacks();
    final firestore = _MockFirestore();
    final users = _MockCollection();
    when(() => firestore.collection('users')).thenReturn(users);
    stubUser(firestore, users, 'alice', ['Stamps']);
    stubUser(firestore, users, 'bob', ['Wine']);

    auth = StreamController<UserEntity?>();
    container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(firestore),
        authStateProvider.overrideWith((ref) => auth.stream),
      ],
    );
    addTearDown(auth.close);
    addTearDown(container.dispose);
    seen = [];
    // Listened to, as the form does: an unlistened provider is paused.
    container.listen(customTypeSuggestionsProvider, (_, next) {
      seen.add([for (final d in next) d.label]);
    }, fireImmediately: true);
  });

  Future<void> signIn(UserEntity? user) async {
    auth.add(user);
    await pumpEventQueue();
  }

  List<String> now() => [
    for (final d in container.read(customTypeSuggestionsProvider)) d.label,
  ];

  test('each account sees only its own types', () async {
    await signIn(_alice);
    expect(now(), ['Stamps']);

    await signIn(null);
    expect(now(), isEmpty, reason: 'signed out');

    await signIn(_bob);
    expect(now(), ['Wine']);
  });

  test('switching straight from one user to another never shows the first '
      "user's types to the second", () async {
    await signIn(_alice);
    seen.clear();

    await signIn(_bob);

    expect(now(), ['Wine']);
    expect(
      seen.expand((labels) => labels),
      isNot(contains('Stamps')),
      reason: 'nothing of the previous account shows after the switch',
    );
  });
}
