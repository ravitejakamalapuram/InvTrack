// #941 (plan test 16): deleting an investment deletes its valuation snapshots,
// tombstones included. deleteInvestment and deleteArchivedInvestment throw
// rather than orphan them when they cannot tell which exist; bulkDelete stays
// best-effort (cash flows are orphaned there by design) and relies on
// validValuationSnapshotsProvider filtering by active investment.
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

void main() {
  const uid = 'user-1';
  const id = 'inv-1';
  late _MockFirestore firestore;
  late Map<String, _MockCollection> collections;
  late Map<String, _MockDoc> investmentDocs;
  late List<_MockBatch> batches;
  late List<List<DocumentReference>> deletedPerBatch;
  late FirestoreInvestmentRepository repository;

  /// A query on [collection] by investmentId whose cache answer holds [refs].
  void stubDocs(String collection, String investmentId, List<_MockDoc> refs) {
    final query = _MockQuery();
    final QuerySnapshot<Map<String, dynamic>> snapshot = _MockQuerySnapshot();
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final ref in refs) {
      final doc = _MockQueryDoc();
      when(() => doc.reference).thenReturn(ref);
      docs.add(doc);
    }
    when(() => snapshot.docs).thenReturn(docs);
    when(
      () => collections[collection]!.where(
        'investmentId',
        isEqualTo: investmentId,
      ),
    ).thenReturn(query);
    when(
      () => query.get(const GetOptions(source: Source.cache)),
    ).thenAnswer((_) async => snapshot);
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
      when(() => collections[name]!.doc(id)).thenAnswer(
        (_) => investmentDocs.putIfAbsent('$name/$id', _MockDoc.new),
      );
    }
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

    test('stays best-effort when snapshots cannot be listed', () async {
      stubDocs('cashflows', id, []);
      stubUnreadable('valuations', id);

      expect(await repository.bulkDelete([id]), 1);
      final all = deletedPerBatch.expand((d) => d).toList();
      expect(all, [investmentDocs['investments/$id']]);
    });
  });
}
