// #917: a one-off cleanup of expected payments (users/{uid}/expectedCashFlows)
// whose investment exists in neither `investments` nor `archivedInvestments`.
// Everything is read from the server, an investment is only judged missing
// after the server says so, and any failed read deletes nothing and records
// nothing, so the next start retries.
//
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/income_projection/data/services/orphaned_expected_cash_flow_cleanup_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockDocSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _MockBatch extends Mock implements WriteBatch {}

/// One stored expected payment: its snapshot and the reference a delete uses.
class _Payment {
  _Payment(String? investmentId) {
    when(() => doc.reference).thenReturn(ref);
    when(
      () => doc.data(),
    ).thenReturn({'amount': 1.0, 'investmentId': ?investmentId});
  }

  final doc = _MockQueryDoc();
  final ref = _MockDoc();
}

void main() {
  const uid = 'user-1';
  const server = GetOptions(source: Source.server);
  late _MockFirestore firestore;
  late Map<String, _MockCollection> collections;
  late SharedPreferences prefs;
  late List<List<DocumentReference>> deletedPerBatch;
  late List<String> readsOf;

  /// The ids of the investments the server holds, by collection.
  late Map<String, Set<String>> onServer;

  /// Makes the server answer the expected payments query with [payments].
  void serverHolds(List<_Payment> payments) {
    final snapshot = _MockQuerySnapshot();
    when(() => snapshot.docs).thenReturn([for (final p in payments) p.doc]);
    when(() => collections['expectedCashFlows']!.get(server)).thenAnswer((_) {
      readsOf.add('expectedCashFlows');
      return Future.value(snapshot);
    });
  }

  OrphanedExpectedCashFlowCleanupService service({
    Duration writeTimeout = const Duration(seconds: 3),
  }) => OrphanedExpectedCashFlowCleanupService(
    firestore: firestore,
    userId: uid,
    prefs: prefs,
    writeTimeout: writeTimeout,
  );

  List<DocumentReference> deleted() =>
      deletedPerBatch.expand((d) => d).toList();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    collections = {
      for (final name in [
        'expectedCashFlows',
        'investments',
        'archivedInvestments',
      ])
        name: _MockCollection(),
    };
    onServer = {'investments': {}, 'archivedInvestments': {}};
    deletedPerBatch = [];
    readsOf = [];
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(uid)).thenReturn(userDoc);
    collections.forEach((name, collection) {
      when(() => userDoc.collection(name)).thenReturn(collection);
    });
    for (final name in ['investments', 'archivedInvestments']) {
      when(() => collections[name]!.doc(any())).thenAnswer((call) {
        final investmentId = call.positionalArguments.first as String;
        final ref = _MockDoc();
        when(() => ref.get(server)).thenAnswer((_) async {
          readsOf.add(name);
          final snapshot = _MockDocSnapshot();
          when(
            () => snapshot.exists,
          ).thenReturn(onServer[name]!.contains(investmentId));
          return snapshot;
        });
        return ref;
      });
    }
    when(() => firestore.batch()).thenAnswer((_) {
      final batch = _MockBatch();
      final inBatch = <DocumentReference>[];
      when(() => batch.delete(any())).thenAnswer((i) {
        inBatch.add(i.positionalArguments.first as DocumentReference);
      });
      when(() => batch.commit()).thenAnswer((_) async {});
      deletedPerBatch.add(inBatch);
      return batch;
    });
  });

  setUpAll(() {
    registerFallbackValue(_MockDoc());
  });

  test('deletes the payments of an investment that is in neither collection '
      'and keeps the others', () async {
    onServer['investments']!.add('active');
    onServer['archivedInvestments']!.add('archived');
    final ofActive = _Payment('active');
    final ofArchived = _Payment('archived');
    final orphan1 = _Payment('gone');
    final orphan2 = _Payment('gone');
    final orphan3 = _Payment('also-gone');
    serverHolds([ofActive, orphan1, ofArchived, orphan2, orphan3]);

    expect(await service().cleanup(), 3);

    expect(deleted(), unorderedEquals([orphan1.ref, orphan2.ref, orphan3.ref]));
    expect(deletedPerBatch, hasLength(1));
  });

  test('reads the payments and each investment from the server, once per '
      'distinct investment', () async {
    serverHolds([_Payment('gone'), _Payment('gone'), _Payment('active')]);
    onServer['investments']!.add('active');

    await service().cleanup();

    expect(readsOf.where((r) => r == 'expectedCashFlows'), hasLength(1));
    expect(readsOf.where((r) => r == 'investments'), hasLength(2));
    expect(readsOf.where((r) => r == 'archivedInvestments'), hasLength(2));
  });

  test(
    'deletes nothing, but records completion, when there are no orphans',
    () async {
      onServer['investments']!.add('active');
      serverHolds([_Payment('active')]);

      expect(await service().cleanup(), 0);

      expect(deletedPerBatch, isEmpty);
      expect(service().isComplete, isTrue);
    },
  );

  test('leaves payments with no investment id alone', () async {
    final missing = _Payment(null);
    final blank = _Payment('  ');
    final orphan = _Payment('gone');
    serverHolds([missing, blank, orphan]);

    expect(await service().cleanup(), 1);

    expect(deleted(), [orphan.ref]);
  });

  test('deletes nothing and records nothing when the payments cannot be read '
      '(offline)', () async {
    when(
      () => collections['expectedCashFlows']!.get(server),
    ).thenThrow(TimeoutException('offline'));

    await expectLater(service().cleanup(), throwsA(isA<TimeoutException>()));

    expect(deletedPerBatch, isEmpty);
    expect(service().isComplete, isFalse);
  });

  test('deletes nothing and records nothing when an investment cannot be '
      'checked (offline)', () async {
    serverHolds([_Payment('gone'), _Payment('other')]);
    final failing = _MockDoc();
    when(() => failing.get(server)).thenThrow(TimeoutException('offline'));
    when(
      () => collections['archivedInvestments']!.doc('other'),
    ).thenReturn(failing);

    await expectLater(service().cleanup(), throwsA(isA<TimeoutException>()));

    expect(deletedPerBatch, isEmpty);
    expect(service().isComplete, isFalse);
  });

  test('splits many orphans into batches within the Firestore limit', () async {
    final orphans = [for (var i = 0; i < 1000; i++) _Payment('gone-$i')];
    serverHolds(orphans);

    expect(await service().cleanup(), 1000);

    expect(deletedPerBatch.length, greaterThan(1));
    for (final batch in deletedPerBatch) {
      expect(batch.length, lessThanOrEqualTo(450));
    }
    expect(deleted(), hasLength(1000));
    expect(deleted().toSet(), orphans.map((p) => p.ref).toSet());
  });

  group('runOnce', () {
    test('cleans up, records completion and returns true', () async {
      final orphan = _Payment('gone');
      serverHolds([orphan]);

      expect(await service().runOnce(), isTrue);

      expect(deleted(), [orphan.ref]);
      expect(service().isComplete, isTrue);
    });

    test('does not read anything again once complete', () async {
      serverHolds([_Payment('gone')]);
      await service().runOnce();
      readsOf.clear();

      expect(await service().runOnce(), isTrue);

      expect(readsOf, isEmpty);
      expect(deletedPerBatch, hasLength(1));
    });

    test('completion is recorded per user', () async {
      await prefs.setBool('expected_payments_orphan_cleanup_done_user-2', true);
      serverHolds([_Payment('gone')]);

      expect(service().isComplete, isFalse);
      await service().runOnce();

      expect(deleted(), hasLength(1));
    });

    test('returns false instead of throwing when offline, and retries '
        'later', () async {
      when(
        () => collections['expectedCashFlows']!.get(server),
      ).thenThrow(TimeoutException('offline'));

      expect(await service().runOnce(), isFalse);
      expect(service().isComplete, isFalse);

      final orphan = _Payment('gone');
      serverHolds([orphan]);
      expect(await service().runOnce(), isTrue);
      expect(deleted(), [orphan.ref]);
    });

    test('returns false and records nothing when a delete fails', () async {
      serverHolds([_Payment('gone')]);
      when(() => firestore.batch()).thenAnswer((_) {
        final batch = _MockBatch();
        when(() => batch.delete(any())).thenReturn(null);
        when(() => batch.commit()).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );
        return batch;
      });

      expect(await service().runOnce(), isFalse);
      expect(service().isComplete, isFalse);
    });

    test('counts a delete that is queued offline as done, like every other '
        'write in the app', () async {
      serverHolds([_Payment('gone')]);
      when(() => firestore.batch()).thenAnswer((_) {
        final batch = _MockBatch();
        when(() => batch.delete(any())).thenReturn(null);
        when(() => batch.commit()).thenAnswer((_) => Completer<void>().future);
        return batch;
      });

      expect(
        await service(writeTimeout: const Duration(milliseconds: 20)).runOnce(),
        isTrue,
      );
      expect(service().isComplete, isTrue);
    });

    test('two calls at once share one run', () async {
      serverHolds([_Payment('gone')]);
      final s = service();

      final results = await Future.wait([s.runOnce(), s.runOnce()]);

      expect(results, [true, true]);
      expect(readsOf.where((r) => r == 'expectedCashFlows'), hasLength(1));
    });
  });
}
