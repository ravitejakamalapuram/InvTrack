// #941 (plan test 16): deleting an investment deletes its valuation snapshots,
// tombstones included. Snapshots are looked up on the server as well as in the
// cache, because no listener keeps them in the cache (the flag is off, or
// this is a fresh install or another account). deleteInvestment,
// deleteArchivedInvestment and bulkDelete throw, deleting nothing, rather
// than orphan them when they cannot tell which exist.
//
// #917: the same holds for the investment's expected payments
// (users/{uid}/expectedCashFlows), which no listener keeps cached while
// Income Guardian is off.
//
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _MockBatch extends Mock implements WriteBatch {}

QuerySnapshot<Map<String, dynamic>> _snapshotOf(List<_MockDoc> refs) {
  final QuerySnapshot<Map<String, dynamic>> snapshot = _MockQuerySnapshot();
  final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  for (final ref in refs) {
    final doc = _MockQueryDoc();
    when(() => doc.reference).thenReturn(ref);
    docs.add(doc);
  }
  when(() => snapshot.docs).thenReturn(docs);
  return snapshot;
}

void main() {
  const uid = 'user-1';
  const id = 'inv-1';
  const otherId = 'inv-2';
  late _MockFirestore firestore;
  late Map<String, _MockCollection> collections;
  late Map<String, _MockDoc> investmentDocs;
  late List<_MockBatch> batches;
  late List<List<DocumentReference>> deletedPerBatch;
  late FirestoreInvestmentRepository repository;

  /// A query on [collection] by investmentId whose cache answer holds [refs].
  /// The server answers [serverRefs], or is unreachable when that is null.
  void stubDocs(
    String collection,
    String investmentId,
    List<_MockDoc> refs, {
    List<_MockDoc>? serverRefs,
  }) {
    final query = _MockQuery();
    when(
      () => collections[collection]!.where(
        'investmentId',
        isEqualTo: investmentId,
      ),
    ).thenReturn(query);
    when(
      () => query.get(const GetOptions(source: Source.cache)),
    ).thenAnswer((_) async => _snapshotOf(refs));
    if (serverRefs == null) {
      when(
        () => query.get(const GetOptions(source: Source.server)),
      ).thenThrow(TimeoutException('offline'));
    } else {
      when(
        () => query.get(const GetOptions(source: Source.server)),
      ).thenAnswer((_) async => _snapshotOf(serverRefs));
    }
  }

  /// The cache and the server both fail for [collection] (offline, no cache).
  void stubUnreadable(String collection, String investmentId) {
    final query = _MockQuery();
    when(
      () => collections[collection]!.where(
        'investmentId',
        isEqualTo: investmentId,
      ),
    ).thenReturn(query);
    when(
      () => query.get(const GetOptions(source: Source.cache)),
    ).thenThrow(Exception('cache unavailable'));
    when(
      () => query.get(const GetOptions(source: Source.server)),
    ).thenThrow(TimeoutException('offline'));
    when(() => query.get()).thenThrow(TimeoutException('offline'));
  }

  setUpAll(() {
    registerFallbackValue(_MockDoc());
  });

  setUp(() {
    firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    collections = {
      for (final name in [
        'investments',
        'cashflows',
        'archivedInvestments',
        'archivedCashflows',
        'valuations',
        'expectedCashFlows',
      ])
        name: _MockCollection(),
    };
    investmentDocs = {};
    batches = [];
    deletedPerBatch = [];
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(uid)).thenReturn(userDoc);
    collections.forEach((name, collection) {
      when(() => userDoc.collection(name)).thenReturn(collection);
    });
    for (final name in ['investments', 'archivedInvestments']) {
      for (final investmentId in [id, otherId]) {
        when(() => collections[name]!.doc(investmentId)).thenAnswer(
          (_) =>
              investmentDocs.putIfAbsent('$name/$investmentId', _MockDoc.new),
        );
      }
    }
    // Unless a test says otherwise, the investment has no expected payments.
    stubDocs('expectedCashFlows', id, []);
    stubDocs('expectedCashFlows', otherId, []);
    when(() => firestore.batch()).thenAnswer((_) {
      final batch = _MockBatch();
      final deleted = <DocumentReference>[];
      when(() => batch.delete(any())).thenAnswer((i) {
        deleted.add(i.positionalArguments.first as DocumentReference);
      });
      when(() => batch.commit()).thenAnswer((_) async {});
      batches.add(batch);
      deletedPerBatch.add(deleted);
      return batch;
    });
    repository = FirestoreInvestmentRepository(
      firestore: firestore,
      userId: uid,
      baseCurrency: () => 'INR',
    );
  });

  group('deleteInvestment', () {
    test('deletes cash flows, every snapshot (tombstones too) and the '
        'investment in one batch', () async {
      final cf = _MockDoc();
      final live = _MockDoc();
      final tombstone = _MockDoc();
      stubDocs('cashflows', id, [cf]);
      stubDocs('valuations', id, [live, tombstone]);

      await repository.deleteInvestment(id);

      expect(batches, hasLength(1));
      expect(deletedPerBatch.single, containsAll([cf, live, tombstone]));
      expect(
        deletedPerBatch.single,
        contains(investmentDocs['investments/$id']),
      );
      expect(deletedPerBatch.single, hasLength(4));
      verify(() => batches.single.commit()).called(1);
    });

    test('deletes snapshots only the server holds (an empty cache is not '
        'proof there are none)', () async {
      final remoteLive = _MockDoc();
      final remoteTombstone = _MockDoc();
      stubDocs('cashflows', id, []);
      stubDocs('valuations', id, [], serverRefs: [remoteLive, remoteTombstone]);

      await repository.deleteInvestment(id);

      expect(
        deletedPerBatch.expand((d) => d),
        containsAll([remoteLive, remoteTombstone]),
      );
    });

    test('deletes a snapshot written on this device that the server has not '
        'seen yet, once, next to the ones it holds', () async {
      final pending = _MockDoc();
      final remote = _MockDoc();
      stubDocs('valuations', id, [pending, remote], serverRefs: [remote]);
      stubDocs('cashflows', id, []);

      await repository.deleteInvestment(id);

      final all = deletedPerBatch.expand((d) => d).toList();
      expect(all.where((d) => d == pending), hasLength(1));
      expect(all.where((d) => d == remote), hasLength(1));
    });

    test('uses the cache alone when the server cannot be reached', () async {
      final cached = _MockDoc();
      stubDocs('cashflows', id, []);
      stubDocs('valuations', id, [cached]);

      await repository.deleteInvestment(id);

      expect(deletedPerBatch.expand((d) => d), contains(cached));
    });

    // Pins the offline policy, which matches cash flows (cache-first, no
    // server needed): an empty cache and an unreachable server still delete.
    // Requiring a server answer here would make every offline delete fail,
    // flag on or off, for the sake of accounts that may hold snapshots no
    // listener ever cached. That is the owner's call (PR 961 review).
    test('deletes offline when the cache is empty and the server cannot be '
        'reached, like cash flows', () async {
      stubDocs('cashflows', id, []);
      stubDocs('valuations', id, []);

      await repository.deleteInvestment(id);

      expect(
        deletedPerBatch.expand((d) => d),
        contains(investmentDocs['investments/$id']),
      );
    });

    test('uses the server alone when the cache cannot be read', () async {
      final remote = _MockDoc();
      stubDocs('cashflows', id, []);
      final query = _MockQuery();
      when(
        () => collections['valuations']!.where('investmentId', isEqualTo: id),
      ).thenReturn(query);
      when(
        () => query.get(const GetOptions(source: Source.cache)),
      ).thenThrow(Exception('cache unavailable'));
      when(
        () => query.get(const GetOptions(source: Source.server)),
      ).thenAnswer((_) async => _snapshotOf([remote]));

      await repository.deleteInvestment(id);

      expect(deletedPerBatch.expand((d) => d), contains(remote));
    });

    test('throws, deleting nothing, when snapshots cannot be listed', () async {
      stubDocs('cashflows', id, []);
      stubUnreadable('valuations', id);

      await expectLater(
        () => repository.deleteInvestment(id),
        throwsA(isA<NetworkException>()),
      );
      expect(batches, isEmpty);
    });

    test('splits a large delete and removes the investment last', () async {
      final cashFlows = [for (var i = 0; i < 300; i++) _MockDoc()];
      final snapshots = [for (var i = 0; i < 300; i++) _MockDoc()];
      stubDocs('cashflows', id, cashFlows);
      stubDocs('valuations', id, snapshots);

      await repository.deleteInvestment(id);

      expect(batches.length, greaterThan(1));
      for (final batch in batches) {
        verify(() => batch.commit()).called(1);
      }
      for (final deleted in deletedPerBatch) {
        expect(deleted.length, lessThanOrEqualTo(450));
      }
      final all = deletedPerBatch.expand((d) => d).toList();
      expect(all, hasLength(601));
      expect(all.last, investmentDocs['investments/$id']);
      expect(
        all.where((d) => d == investmentDocs['investments/$id']),
        hasLength(1),
      );
    });
  });

  group('deleteArchivedInvestment', () {
    test('deletes the archived cash flows and the snapshots', () async {
      final cf = _MockDoc();
      final snapshot = _MockDoc();
      stubDocs('archivedCashflows', id, [cf]);
      stubDocs('valuations', id, [snapshot]);

      await repository.deleteArchivedInvestment(id);

      expect(batches, hasLength(1));
      expect(deletedPerBatch.single, containsAll([cf, snapshot]));
      expect(
        deletedPerBatch.single,
        contains(investmentDocs['archivedInvestments/$id']),
      );
    });

    test('deletes snapshots only the server holds', () async {
      final remote = _MockDoc();
      stubDocs('archivedCashflows', id, []);
      stubDocs('valuations', id, [], serverRefs: [remote]);

      await repository.deleteArchivedInvestment(id);

      expect(deletedPerBatch.expand((d) => d), contains(remote));
    });

    test('throws, deleting nothing, when snapshots cannot be listed', () async {
      stubDocs('archivedCashflows', id, []);
      stubUnreadable('valuations', id);
      await expectLater(
        () => repository.deleteArchivedInvestment(id),
        throwsA(isA<NetworkException>()),
      );
      expect(batches, isEmpty);
    });
  });

  group('bulkDelete', () {
    test('deletes the snapshots of every investment', () async {
      final snapshot = _MockDoc();
      stubDocs('cashflows', id, []);
      stubDocs('valuations', id, [snapshot]);

      expect(await repository.bulkDelete([id]), 1);

      final all = deletedPerBatch.expand((d) => d).toList();
      expect(all, contains(snapshot));
      expect(all, contains(investmentDocs['investments/$id']));
    });

    test('deletes snapshots only the server holds', () async {
      final remote = _MockDoc();
      stubDocs('cashflows', id, []);
      stubDocs('valuations', id, [], serverRefs: [remote]);

      expect(await repository.bulkDelete([id]), 1);

      expect(deletedPerBatch.expand((d) => d), contains(remote));
    });

    test('throws, deleting nothing, when snapshots cannot be listed', () async {
      stubDocs('cashflows', id, []);
      stubUnreadable('valuations', id);

      await expectLater(
        () => repository.bulkDelete([id]),
        throwsA(isA<NetworkException>()),
      );
      expect(batches, isEmpty);
    });
  });

  // #917: an investment's expected payments go with it, in the same batches.
  group('expected payments', () {
    setUp(() {
      // Nothing else belongs to the investment unless a test says so.
      for (final collection in [
        'cashflows',
        'archivedCashflows',
        'valuations',
      ]) {
        stubDocs(collection, id, []);
      }
    });

    test('deleteInvestment deletes them with the cash flows, snapshots and '
        'the investment in one batch', () async {
      final cf = _MockDoc();
      final snapshot = _MockDoc();
      final payment1 = _MockDoc();
      final payment2 = _MockDoc();
      stubDocs('cashflows', id, [cf]);
      stubDocs('valuations', id, [snapshot]);
      stubDocs('expectedCashFlows', id, [payment1, payment2]);

      await repository.deleteInvestment(id);

      expect(batches, hasLength(1));
      expect(
        deletedPerBatch.single,
        containsAll([cf, snapshot, payment1, payment2]),
      );
      expect(
        deletedPerBatch.single,
        contains(investmentDocs['investments/$id']),
      );
      expect(deletedPerBatch.single, hasLength(5));
    });

    test('deleteInvestment deletes payments only the server holds, and a '
        'payment written offline once', () async {
      final remote = _MockDoc();
      final pending = _MockDoc();
      stubDocs(
        'expectedCashFlows',
        id,
        [pending, remote],
        serverRefs: [remote],
      );

      await repository.deleteInvestment(id);

      final all = deletedPerBatch.expand((d) => d).toList();
      expect(all.where((d) => d == remote), hasLength(1));
      expect(all.where((d) => d == pending), hasLength(1));
    });

    test('deleteInvestment deletes payments the server holds when the cache '
        'is empty', () async {
      final remote = _MockDoc();
      stubDocs('expectedCashFlows', id, [], serverRefs: [remote]);

      await repository.deleteInvestment(id);

      expect(deletedPerBatch.expand((d) => d), contains(remote));
    });

    test('deleteInvestment throws, deleting nothing, when payments cannot be '
        'listed', () async {
      stubUnreadable('expectedCashFlows', id);

      await expectLater(
        () => repository.deleteInvestment(id),
        throwsA(isA<NetworkException>()),
      );
      expect(batches, isEmpty);
    });

    test('deleteInvestment keeps every batch within the limit and removes '
        'the investment last', () async {
      stubDocs('cashflows', id, [for (var i = 0; i < 300; i++) _MockDoc()]);
      stubDocs('expectedCashFlows', id, [
        for (var i = 0; i < 300; i++) _MockDoc(),
      ]);

      await repository.deleteInvestment(id);

      for (final deleted in deletedPerBatch) {
        expect(deleted.length, lessThanOrEqualTo(450));
      }
      final all = deletedPerBatch.expand((d) => d).toList();
      expect(all, hasLength(601));
      expect(all.last, investmentDocs['investments/$id']);
    });

    test('deleteArchivedInvestment deletes them with the archived cash '
        'flows and the investment', () async {
      final cf = _MockDoc();
      final payment = _MockDoc();
      final remote = _MockDoc();
      stubDocs('archivedCashflows', id, [cf]);
      stubDocs('expectedCashFlows', id, [payment], serverRefs: [remote]);

      await repository.deleteArchivedInvestment(id);

      expect(batches, hasLength(1));
      expect(deletedPerBatch.single, containsAll([cf, payment, remote]));
      expect(
        deletedPerBatch.single,
        contains(investmentDocs['archivedInvestments/$id']),
      );
    });

    test('deleteArchivedInvestment throws, deleting nothing, when payments '
        'cannot be listed', () async {
      stubDocs('archivedCashflows', id, []);
      stubUnreadable('expectedCashFlows', id);

      await expectLater(
        () => repository.deleteArchivedInvestment(id),
        throwsA(isA<NetworkException>()),
      );
      expect(batches, isEmpty);
    });

    test('bulkDelete deletes the payments of every investment', () async {
      final payment1 = _MockDoc();
      final payment2 = _MockDoc();
      stubDocs('cashflows', id, []);
      stubDocs('cashflows', otherId, []);
      stubDocs('valuations', id, []);
      stubDocs('valuations', otherId, []);
      stubDocs('expectedCashFlows', id, [payment1]);
      stubDocs('expectedCashFlows', otherId, [], serverRefs: [payment2]);

      expect(await repository.bulkDelete([id, otherId]), 2);

      final all = deletedPerBatch.expand((d) => d).toList();
      expect(all, containsAll([payment1, payment2]));
      expect(all, contains(investmentDocs['investments/$id']));
      expect(all, contains(investmentDocs['investments/$otherId']));
    });

    test('bulkDelete throws, deleting nothing, when payments cannot be '
        'listed', () async {
      stubDocs('cashflows', id, []);
      stubDocs('valuations', id, []);
      stubUnreadable('expectedCashFlows', id);

      await expectLater(
        () => repository.bulkDelete([id]),
        throwsA(isA<NetworkException>()),
      );
      expect(batches, isEmpty);
    });
  });
}
