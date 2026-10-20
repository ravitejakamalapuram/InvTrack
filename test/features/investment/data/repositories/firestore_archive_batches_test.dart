// #766 (A23): archive and unarchive move an investment and its cash flows in
// batches of at most 500 operations. 300 cash flows are 602 operations, which
// one batch cannot hold. Copies are written before anything is deleted, and
// the source investment is deleted first among the deletes, so a failed batch
// never leaves an active investment with part of its cash flows missing.
//
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {
  _MockDoc([this.id = '']);

  @override
  final String id;
}

class _MockDocSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _MockBatch extends Mock implements WriteBatch {}

/// One recorded operation: 'set' or 'delete', and the document it touched.
typedef _Op = ({String kind, DocumentReference ref});

void main() {
  const uid = 'user-1';
  const id = 'inv-1';
  late _MockFirestore firestore;
  late Map<String, _MockCollection> collections;
  late Map<String, _MockDoc> docs;
  late List<List<_Op>> opsPerBatch;
  late FirestoreInvestmentRepository repository;

  _MockDoc docAt(String collection, String docId) =>
      docs.putIfAbsent('$collection/$docId', () => _MockDoc(docId));

  /// [sourceCollection] holds the investment and [count] cash flows in
  /// [flowsCollection].
  void stubSource(String sourceCollection, String flowsCollection, int count) {
    final source = docAt(sourceCollection, id);
    final snapshot = _MockDocSnapshot();
    when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.data()).thenReturn({'name': 'FD'});
    when(() => snapshot.reference).thenReturn(source);
    when(source.get).thenAnswer((_) async => snapshot);

    final flowDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (var n = 0; n < count; n++) {
      final flow = _MockQueryDoc();
      when(() => flow.id).thenReturn('cf-$n');
      when(() => flow.data()).thenReturn({'investmentId': id});
      when(() => flow.reference).thenReturn(docAt(flowsCollection, 'cf-$n'));
      flowDocs.add(flow);
    }
    final querySnapshot = _MockQuerySnapshot();
    when(() => querySnapshot.docs).thenReturn(flowDocs);
    final query = _MockQuery();
    when(query.get).thenAnswer((_) async => querySnapshot);
    when(
      () => collections[flowsCollection]!.where('investmentId', isEqualTo: id),
    ).thenReturn(query);
  }

  setUpAll(() {
    registerFallbackValue(_MockDoc());
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    docs = {};
    opsPerBatch = [];
    collections = {
      for (final name in [
        'investments',
        'cashflows',
        'archivedInvestments',
        'archivedCashflows',
      ])
        name: _MockCollection(),
    };
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(uid)).thenReturn(userDoc);
    collections.forEach((name, collection) {
      when(() => userDoc.collection(name)).thenReturn(collection);
      when(
        () => collection.doc(any()),
      ).thenAnswer((i) => docAt(name, i.positionalArguments.first as String));
    });
    when(() => firestore.batch()).thenAnswer((_) {
      final batch = _MockBatch();
      final ops = <_Op>[];
      when(
        () => batch.set<Map<String, dynamic>>(any(), any(), any()),
      ).thenAnswer((i) {
        ops.add((
          kind: 'set',
          ref: i.positionalArguments.first as DocumentReference,
        ));
      });
      when(() => batch.delete(any())).thenAnswer((i) {
        ops.add((
          kind: 'delete',
          ref: i.positionalArguments.first as DocumentReference,
        ));
      });
      when(batch.commit).thenAnswer((_) async {});
      opsPerBatch.add(ops);
      return batch;
    });
    repository = FirestoreInvestmentRepository(
      firestore: firestore,
      userId: uid,
      baseCurrency: () => 'INR',
    );
  });

  void expectSafeMove({
    required String fromInvestments,
    required String toInvestments,
    required String fromFlows,
    required String toFlows,
  }) {
    final all = opsPerBatch.expand((ops) => ops).toList();
    expect(all, hasLength(602));
    expect(opsPerBatch.every((ops) => ops.length <= 500), isTrue);
    final sets = all.where((op) => op.kind == 'set').map((op) => op.ref);
    final deletes = all.where((op) => op.kind == 'delete').map((op) => op.ref);
    expect(sets, hasLength(301));
    expect(deletes, hasLength(301));
    expect(sets, contains(docAt(toInvestments, id)));
    expect(sets, contains(docAt(toFlows, 'cf-299')));
    expect(deletes, contains(docAt(fromFlows, 'cf-0')));
    // Nothing is deleted before every copy exists. The source investment goes
    // first among the deletes: if a later batch fails, the copy is complete
    // and the leftover source cash flows have no investment, so they are
    // filtered out (as in bulkDelete) instead of shown as a part-emptied one.
    final firstDelete = all.indexWhere((op) => op.kind == 'delete');
    final lastSet = all.lastIndexWhere((op) => op.kind == 'set');
    expect(firstDelete, greaterThan(lastSet));
    expect(all[firstDelete].ref, docAt(fromInvestments, id));
  }

  group('archiveInvestment', () {
    test('commits an investment with 300 cash flows in batches of at most '
        '500 operations', () async {
      stubSource('investments', 'cashflows', 300);

      await repository.archiveInvestment(id);

      expectSafeMove(
        fromInvestments: 'investments',
        toInvestments: 'archivedInvestments',
        fromFlows: 'cashflows',
        toFlows: 'archivedCashflows',
      );
    });

    test('keeps a small investment in one batch', () async {
      stubSource('investments', 'cashflows', 3);

      await repository.archiveInvestment(id);

      expect(opsPerBatch, hasLength(1));
      expect(opsPerBatch.single, hasLength(8));
    });
  });

  group('unarchiveInvestment', () {
    test('commits an investment with 300 cash flows in batches of at most '
        '500 operations', () async {
      stubSource('archivedInvestments', 'archivedCashflows', 300);

      await repository.unarchiveInvestment(id);

      expectSafeMove(
        fromInvestments: 'archivedInvestments',
        toInvestments: 'investments',
        fromFlows: 'archivedCashflows',
        toFlows: 'cashflows',
      );
    });
  });
}
