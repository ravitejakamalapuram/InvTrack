// #917: a one-off cleanup of expected payments (users/{uid}/expectedCashFlows)
// whose investment exists in neither `investments` nor `archivedInvestments`.
// Everything is read from the server, an investment is only judged missing
// after the server says so, and any failed read, or delete the server did not
// confirm in time, records nothing, so the next start retries. A sweep asked
// for while one is running is never lost.
//
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'dart:math' as math;

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

  /// The investment ids whose existence was asked of the server, in order.
  late List<String> readIds;

  /// When set, an investment read takes one event-loop turn, so reads started
  /// together are in flight together.
  late bool slowReads;
  late int inFlightReads;
  late int maxInFlightReads;

  /// The ids of the investments the server holds, by collection.
  late Map<String, Set<String>> onServer;

  QuerySnapshot<Map<String, dynamic>> snapshotOf(List<_Payment> payments) {
    final snapshot = _MockQuerySnapshot();
    when(() => snapshot.docs).thenReturn([for (final p in payments) p.doc]);
    return snapshot;
  }

  /// Makes the server answer the expected payments query with [payments].
  void serverHolds(List<_Payment> payments) {
    final snapshot = snapshotOf(payments);
    when(() => collections['expectedCashFlows']!.get(server)).thenAnswer((_) {
      readsOf.add('expectedCashFlows');
      return Future.value(snapshot);
    });
  }

  OrphanedExpectedCashFlowCleanupService service({
    Duration readTimeout = const Duration(seconds: 20),
    Duration writeTimeout = const Duration(seconds: 3),
  }) => OrphanedExpectedCashFlowCleanupService(
    firestore: firestore,
    userId: uid,
    prefs: prefs,
    readTimeout: readTimeout,
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
    readIds = [];
    slowReads = false;
    inFlightReads = 0;
    maxInFlightReads = 0;
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
          readIds.add(investmentId);
          inFlightReads++;
          maxInFlightReads = math.max(maxInFlightReads, inFlightReads);
          if (slowReads) await Future<void>.delayed(Duration.zero);
          inFlightReads--;
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

  group('existence checks', () {
    List<_Payment> manyInvestments(int count) => [
      for (var i = 0; i < count; i++) _Payment('id-$i'),
    ];

    test('start at most 50 investments at a time, not all at once', () async {
      slowReads = true;
      serverHolds(manyInvestments(120));

      await service().cleanup();

      // Two server reads (active and archived) per investment.
      expect(maxInFlightReads, lessThanOrEqualTo(100));
      expect(readIds.toSet(), hasLength(120));
    });

    test('keep each result with its own investment across chunks', () async {
      slowReads = true;
      final payments = manyInvestments(120);
      serverHolds(payments);
      for (var i = 0; i < 120; i += 2) {
        onServer['investments']!.add('id-$i');
      }

      expect(await service().cleanup(), 60);

      expect(deleted().toSet(), {
        for (var i = 1; i < 120; i += 2) payments[i].ref,
      });
    });

    test('a chunk that never answers fails the run before the next chunk '
        'starts', () async {
      serverHolds(manyInvestments(120));
      final hanging = _MockDoc();
      when(() => hanging.get(server)).thenAnswer(
        (_) => Completer<DocumentSnapshot<Map<String, dynamic>>>().future,
      );
      when(() => collections['investments']!.doc('id-60')).thenReturn(hanging);

      await expectLater(
        service(readTimeout: const Duration(milliseconds: 50)).cleanup(),
        throwsA(isA<TimeoutException>()),
      );

      expect(readIds, isNot(contains('id-100')));
      expect(deletedPerBatch, isEmpty);
      expect(service().isComplete, isFalse);
    });
  });

  group('prefs keys', () {
    const requestedKey = 'expected_payments_orphan_sweep_requested_user-1';
    const completedKey = 'expected_payments_orphan_sweep_completed_user-1';

    test('prefsKeysFor lists every key a request and a finished run write, '
        'all of them integers', () async {
      await OrphanedExpectedCashFlowCleanupService.requestSweep(prefs, uid);
      serverHolds([_Payment('gone')]);
      await service().runOnce();

      expect(prefs.getKeys(), {requestedKey, completedKey});
      expect(
        OrphanedExpectedCashFlowCleanupService.prefsKeysFor(uid),
        unorderedEquals([requestedKey, completedKey]),
      );
      expect(prefs.getInt(requestedKey), isNotNull);
      expect(prefs.getInt(completedKey), isNotNull);
    });

    test(
      'requestSweep makes the next run sweep again, for that user only',
      () async {
        await prefs.setInt(
          'expected_payments_orphan_sweep_requested_user-2',
          1,
        );
        await prefs.setInt(
          'expected_payments_orphan_sweep_completed_user-2',
          1,
        );
        serverHolds([_Payment('gone')]);
        await service().runOnce();
        expect(service().isComplete, isTrue);

        await OrphanedExpectedCashFlowCleanupService.requestSweep(prefs, uid);

        expect(service().isComplete, isFalse);
        expect(
          prefs.getInt('expected_payments_orphan_sweep_requested_user-2'),
          1,
        );
        expect(
          prefs.getInt('expected_payments_orphan_sweep_completed_user-2'),
          1,
        );
        readsOf.clear();
        expect(await service().runOnce(), isTrue);
        expect(readsOf, contains('expectedCashFlows'));
        expect(service().isComplete, isTrue);
      },
    );
  });

  group('a sweep requested while a cleanup runs', () {
    Future<void> requestSweep() =>
        OrphanedExpectedCashFlowCleanupService.requestSweep(prefs, uid);

    test('is not lost when it lands during the payments read', () async {
      final gate = Completer<QuerySnapshot<Map<String, dynamic>>>();
      when(() => collections['expectedCashFlows']!.get(server)).thenAnswer((_) {
        readsOf.add('expectedCashFlows');
        return gate.future;
      });
      final run = service().runOnce();
      await pumpEventQueue();
      expect(readsOf, ['expectedCashFlows']);

      await requestSweep();
      gate.complete(snapshotOf([_Payment('gone')]));

      // The run finished the sweep it started, not the one asked for since.
      final finished = await run;
      expect(service().isComplete, isFalse);
      expect(finished, isFalse);

      serverHolds([_Payment('gone-too')]);
      readsOf.clear();
      expect(await service().runOnce(), isTrue);
      expect(readsOf, [
        'expectedCashFlows',
        'investments',
        'archivedInvestments',
      ]);
      expect(service().isComplete, isTrue);
    });

    test('is not lost when it lands during a delete', () async {
      serverHolds([_Payment('gone')]);
      final commit = Completer<void>();
      when(() => firestore.batch()).thenAnswer((_) {
        final batch = _MockBatch();
        when(() => batch.delete(any())).thenReturn(null);
        when(() => batch.commit()).thenAnswer((_) => commit.future);
        return batch;
      });
      final run = service().runOnce();
      await pumpEventQueue();

      await requestSweep();
      commit.complete();

      final finished = await run;
      expect(service().isComplete, isFalse);
      expect(finished, isFalse);
    });

    test(
      'several requests during one run still cost only one more sweep',
      () async {
        final gate = Completer<QuerySnapshot<Map<String, dynamic>>>();
        when(() => collections['expectedCashFlows']!.get(server)).thenAnswer((
          _,
        ) {
          readsOf.add('expectedCashFlows');
          return gate.future;
        });
        final run = service().runOnce();
        await pumpEventQueue();

        await requestSweep();
        await requestSweep();
        gate.complete(snapshotOf([]));
        await run;
        expect(service().isComplete, isFalse);

        serverHolds([]);
        readsOf.clear();
        expect(await service().runOnce(), isTrue);
        expect(readsOf, ['expectedCashFlows']);
        expect(await service().runOnce(), isTrue);
        expect(readsOf, ['expectedCashFlows']);
      },
    );

    test('asked for before the run starts is covered by that run', () async {
      await requestSweep();
      serverHolds([_Payment('gone')]);

      expect(await service().runOnce(), isTrue);

      expect(service().isComplete, isTrue);
    });

    test('a run that fails does not record the request as done', () async {
      await requestSweep();
      when(
        () => collections['expectedCashFlows']!.get(server),
      ).thenThrow(TimeoutException('offline'));

      expect(await service().runOnce(), isFalse);

      expect(service().isComplete, isFalse);
    });
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
      await prefs.setInt('expected_payments_orphan_sweep_completed_user-2', 1);
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

    test('returns false and records nothing when the server has not confirmed '
        'a delete in time, and the next run sweeps again', () async {
      final orphan = _Payment('gone');
      serverHolds([orphan]);
      when(() => firestore.batch()).thenAnswer((_) {
        final batch = _MockBatch();
        when(() => batch.delete(any())).thenReturn(null);
        when(() => batch.commit()).thenAnswer((_) => Completer<void>().future);
        return batch;
      });

      expect(
        await service(writeTimeout: const Duration(milliseconds: 20)).runOnce(),
        isFalse,
      );
      expect(service().isComplete, isFalse);

      // Back online: the orphans are found afresh and deleted again.
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
      readsOf.clear();
      expect(await service().runOnce(), isTrue);
      expect(readsOf, contains('expectedCashFlows'));
      expect(deleted(), [orphan.ref]);
      expect(service().isComplete, isTrue);
    });

    test('cleanup lets a delete timeout through instead of recording '
        'completion', () async {
      serverHolds([_Payment('gone')]);
      when(() => firestore.batch()).thenAnswer((_) {
        final batch = _MockBatch();
        when(() => batch.delete(any())).thenReturn(null);
        when(() => batch.commit()).thenAnswer((_) => Completer<void>().future);
        return batch;
      });

      await expectLater(
        service(writeTimeout: const Duration(milliseconds: 20)).cleanup(),
        throwsA(isA<TimeoutException>()),
      );

      expect(service().isComplete, isFalse);
      expect(prefs.getKeys(), isEmpty);
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
