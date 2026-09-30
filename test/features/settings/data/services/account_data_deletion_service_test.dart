// Regression tests for account deletion completeness.
//
// The project has no fake_cloud_firestore dependency, so this file builds a
// tiny in-memory Firestore out of mocktail mocks: each subcollection of
// users/{uid} holds document ids, batch.delete() queues a reference and
// batch.commit() actually removes the queued documents (like the server).

// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/settings/data/services/account_data_deletion_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {}

class FakeQueryDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  FakeQueryDoc(this.reference);
  @override
  final DocumentReference<Map<String, dynamic>> reference;
}

class FakeSnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  FakeSnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class FakeBatch extends Fake implements WriteBatch {
  FakeBatch(this._onCommit);
  final Future<void> Function(List<DocumentReference> queued) _onCommit;
  final queued = <DocumentReference>[];

  @override
  void delete(DocumentReference document) => queued.add(document);

  @override
  Future<void> commit() => _onCommit(queued);
}

/// In-memory stand-in for the `users/{uid}` tree.
class FakeUserTree {
  FakeUserTree(Map<String, int> sizes) {
    // Collection name -> live document refs.
    sizes.forEach((name, n) {
      _docs[name] = [for (var i = 0; i < n; i++) _makeDoc('$name/$i')];
    });
    _wire();
  }

  static const uid = 'uid-1';

  final _docs = <String, List<MockDoc>>{};
  final _pathOf = <MockDoc, String>{};
  final firestore = MockFirestore();
  final userDoc = MockDoc();
  bool userDocExists = true;

  /// When set, commits/gets fail or hang to simulate offline/failure.
  bool commitsHang = false;
  bool getsHang = false;
  Object? commitError;
  int? commitFailsAfter; // succeed this many commits, then fail
  final batchSizes = <int>[];
  var _commits = 0;

  MockDoc _makeDoc(String path) {
    final d = MockDoc();
    _pathOf[d] = path;
    return d;
  }

  int remaining(String collection) => _docs[collection]?.length ?? 0;
  int get totalRemaining => _docs.values.fold(0, (a, b) => a + b.length);

  Future<void> _commit(List<DocumentReference> queued) async {
    if (commitsHang) return Completer<void>().future;
    if (commitFailsAfter != null && _commits >= commitFailsAfter!) {
      throw commitError ?? Exception('boom');
    }
    _commits++;
    batchSizes.add(queued.length);
    for (final ref in queued) {
      if (identical(ref, userDoc)) {
        userDocExists = false;
        continue;
      }
      for (final list in _docs.values) {
        list.removeWhere((d) => identical(d, ref));
      }
    }
  }

  void _wire() {
    final users = MockCollection();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(uid)).thenReturn(userDoc);

    for (final name in AccountDataDeletionService.userCollections) {
      _docs.putIfAbsent(name, () => []);
    }
    for (final name in _docs.keys.toList()) {
      final col = MockCollection();
      when(() => userDoc.collection(name)).thenReturn(col);
      when(() => col.get(any())).thenAnswer((_) async {
        if (getsHang) {
          return Completer<QuerySnapshot<Map<String, dynamic>>>().future;
        }
        return FakeSnapshot([for (final d in _docs[name]!) FakeQueryDoc(d)]);
      });
    }

    when(() => firestore.batch()).thenAnswer((_) => FakeBatch(_commit));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(MockDoc());
    registerFallbackValue(const GetOptions());
  });

  AccountDataDeletionService build(
    FakeUserTree tree, {
    int batchSize = 500,
    Duration timeout = const Duration(milliseconds: 50),
  }) => AccountDataDeletionService(
    firestore: tree.firestore,
    userId: FakeUserTree.uid,
    batchSize: batchSize,
    confirmTimeout: timeout,
  );

  test('userCollections covers every collection the app writes', () {
    expect(
      AccountDataDeletionService.userCollections,
      containsAll(<String>[
        'investments',
        'cashflows',
        'archivedInvestments',
        'archivedCashflows',
        'goals',
        'archivedGoals',
        'expectedCashFlows',
        'documents',
        'healthScores',
        'fireSettings',
        'profile',
        'exchangeRates',
      ]),
    );
  });

  test(
    'deletes every collection incl. expectedCashFlows and documents',
    () async {
      final tree = FakeUserTree({
        for (final c in AccountDataDeletionService.userCollections) c: 3,
      });
      expect(tree.totalRemaining, 36);

      await build(tree).deleteAllServerData();

      for (final c in AccountDataDeletionService.userCollections) {
        expect(tree.remaining(c), 0, reason: '$c should be empty');
      }
      expect(tree.remaining('expectedCashFlows'), 0);
      expect(tree.remaining('documents'), 0);
      expect(tree.userDocExists, isFalse);
    },
  );

  test('deletes orphaned cash flows that no investment references', () async {
    final tree = FakeUserTree({'cashflows': 4, 'archivedCashflows': 2});
    await build(tree).deleteAllServerData();
    expect(tree.remaining('cashflows'), 0);
    expect(tree.remaining('archivedCashflows'), 0);
  });

  test('respects the batch limit for large collections', () async {
    final tree = FakeUserTree({'cashflows': 1203});
    await build(tree).deleteAllServerData();
    expect(tree.remaining('cashflows'), 0);
    expect(tree.batchSizes.where((n) => n > 500), isEmpty);
    expect(tree.batchSizes.where((n) => n == 500).length, 2);
    expect(tree.batchSizes, contains(203));
  });

  test(
    'offline (commit never confirms) throws NetworkException, not success',
    () async {
      final tree = FakeUserTree({'investments': 2, 'expectedCashFlows': 2})
        ..commitsHang = true;
      await expectLater(
        build(tree).deleteAllServerData(),
        throwsA(isA<NetworkException>()),
      );
      expect(tree.remaining('investments'), 2);
    },
  );

  test('offline (server read never returns) throws NetworkException', () async {
    final tree = FakeUserTree({'investments': 2})..getsHang = true;
    await expectLater(
      build(tree).deleteAllServerData(),
      throwsA(isA<NetworkException>()),
    );
  });

  test('a firestore "unavailable" error maps to NetworkException', () async {
    final tree = FakeUserTree({'investments': 1})
      ..commitFailsAfter = 0
      ..commitError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
    await expectLater(
      build(tree).deleteAllServerData(),
      throwsA(isA<NetworkException>()),
    );
  });

  test(
    'a mid-way failure propagates and leaves later data untouched',
    () async {
      final tree = FakeUserTree({'investments': 1, 'cashflows': 1, 'goals': 1})
        ..commitFailsAfter = 1;
      await expectLater(build(tree).deleteAllServerData(), throwsException);
      expect(tree.totalRemaining, greaterThan(0));
    },
  );

  group('deleteEverything', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'removes local files and per-user prefs after server success',
      () async {
        SharedPreferences.setMockInitialValues({
          'sample_data_mode_active': true,
          'sample_data_investment_ids': ['a'],
          'sample_data_goal_ids': ['b'],
          'last_live_cache_refresh': 'x',
          'currency_live_cache_last_refresh': 1,
          'themeMode': 1,
        });
        final prefs = await SharedPreferences.getInstance();
        final tree = FakeUserTree({'investments': 1});
        var filesDeleted = false;

        await build(tree).deleteEverything(
          deleteLocalFiles: () async => filesDeleted = true,
          prefs: prefs,
        );

        expect(filesDeleted, isTrue);
        for (final k in AccountDataDeletionService.userPreferenceKeys) {
          expect(prefs.containsKey(k), isFalse, reason: k);
        }
        expect(prefs.getInt('themeMode'), 1, reason: 'app settings are kept');
      },
    );

    test('on server failure nothing local is deleted and it throws', () async {
      SharedPreferences.setMockInitialValues({'sample_data_mode_active': true});
      final prefs = await SharedPreferences.getInstance();
      final tree = FakeUserTree({'investments': 1})..commitsHang = true;
      var filesDeleted = false;

      await expectLater(
        build(tree).deleteEverything(
          deleteLocalFiles: () async => filesDeleted = true,
          prefs: prefs,
        ),
        throwsA(isA<NetworkException>()),
      );

      expect(filesDeleted, isFalse);
      expect(prefs.getBool('sample_data_mode_active'), isTrue);
    });
  });
}
