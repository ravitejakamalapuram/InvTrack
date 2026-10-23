// A64 (#811): FirestoreExpectedCashFlowRepository public methods through
// mocktail. The document mapper has its own test; these pin queries, deletes,
// status updates, the 500-operation batch split, error propagation and the
// offline write timeout.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockBatch extends Mock implements WriteBatch {}

class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _FakeQueryDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDoc(this.id, this._data, this.reference);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  final DocumentReference<Map<String, dynamic>> reference;

  @override
  Map<String, dynamic> data() => _data;
}

void main() {
  final created = DateTime(2026, 1, 5);
  final expectedOn = DateTime(2026, 2, 5);

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<Object, Object?>{});
    registerFallbackValue(_MockDoc());
  });

  late _MockFirestore firestore;
  late _MockCollection ecfs;
  late Map<String, _MockDoc> docs;
  late List<_MockBatch> batches;

  _MockDoc docOf(String id) => docs.putIfAbsent(id, () {
    final doc = _MockDoc();
    when(() => ecfs.doc(id)).thenReturn(doc);
    return doc;
  });

  Map<String, dynamic> docData({String? currency}) => {
    'investmentId': 'inv-1',
    'expectedDate': Timestamp.fromDate(expectedOn),
    'expectedAmount': 3500,
    'currency': ?currency,
    'createdAt': Timestamp.fromDate(created),
  };

  QuerySnapshot<Map<String, dynamic>> snapshotOf(List<String> ids) =>
      _FakeQuerySnapshot([
        for (final id in ids) _FakeQueryDoc(id, docData(), docOf(id)),
      ]);

  ExpectedCashFlowEntity ecf({String id = 'e1'}) => ExpectedCashFlowEntity(
    id: id,
    investmentId: 'inv-1',
    expectedDate: expectedOn,
    expectedAmount: 3500,
    currency: 'EUR',
    predictionSource: PredictionSource.manual,
    status: ExpectedCashFlowStatus.upcoming,
    createdAt: created,
    updatedAt: created,
  );

  FirestoreExpectedCashFlowRepository repository() =>
      FirestoreExpectedCashFlowRepository(
        firestore: firestore,
        userId: 'uid-1',
        baseCurrency: () => 'INR',
      );

  setUp(() {
    firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    ecfs = _MockCollection();
    docs = {};
    batches = [];
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('uid-1')).thenReturn(userDoc);
    when(() => userDoc.collection('expectedCashFlows')).thenReturn(ecfs);
    when(() => firestore.batch()).thenAnswer((_) {
      final batch = _MockBatch();
      when(() => batch.commit()).thenAnswer((_) async {});
      batches.add(batch);
      return batch;
    });
    // Created up front: mocktail cannot create a stub inside another `when`.
    docOf('e1');
  });

  group('single document writes', () {
    test('create sets the document with the mapped fields', () async {
      final doc = docOf('e1');
      when(() => doc.set(any())).thenAnswer((_) async {});

      await repository().createExpectedCashFlow(ecf());

      final data =
          verify(() => doc.set(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(data['investmentId'], 'inv-1');
      expect(data['expectedAmount'], 3500.0);
      expect(data['currency'], 'EUR');
      expect(data['predictionSource'], 'manual');
      expect(data['status'], 'upcoming');
      expect(data['updatedAt'], isA<FieldValue>());
    });

    test('update updates the document', () async {
      final doc = docOf('e1');
      when(() => doc.update(any())).thenAnswer((_) async {});

      await repository().updateExpectedCashFlow(ecf());

      verify(() => doc.update(any())).called(1);
    });

    test('delete deletes the document', () async {
      final doc = docOf('e1');
      when(() => doc.delete()).thenAnswer((_) async {});

      await repository().deleteExpectedCashFlow('e1');

      verify(() => doc.delete()).called(1);
    });

    test('a write error propagates to the caller', () {
      final doc = docOf('e1');
      when(
        () => doc.set(any()),
      ).thenAnswer((_) async => throw FirebaseException(plugin: 'firestore'));

      expect(
        repository().createExpectedCashFlow(ecf()),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('an offline write that never acknowledges completes after 5s', () {
      final doc = docOf('e1');
      when(() => doc.set(any())).thenAnswer((_) => Completer<void>().future);

      fakeAsync((async) {
        var done = false;
        repository().createExpectedCashFlow(ecf()).then((_) => done = true);

        async.elapse(const Duration(milliseconds: 4999));
        expect(done, isFalse);
        async.elapse(const Duration(milliseconds: 2));
        expect(done, isTrue);
      });
    });
  });

  group('status updates', () {
    test('markAsReceived records the actual amount and date', () async {
      final doc = docOf('e1');
      when(() => doc.update(any())).thenAnswer((_) async {});
      final received = DateTime(2026, 2, 7);

      await repository().markAsReceived(
        id: 'e1',
        actualDate: received,
        actualAmount: 3400.5,
      );

      final data =
          verify(() => doc.update(captureAny())).captured.single
              as Map<Object, Object?>;
      expect(data['status'], 'received');
      expect(data['actualAmount'], 3400.5);
      expect(data['actualDate'], equals(Timestamp.fromDate(received)));
      expect(data['updatedAt'], isA<FieldValue>());
      expect(data.keys, hasLength(4));
    });

    test('markAsMissed dismisses the entry without touching amounts', () async {
      final doc = docOf('e1');
      when(() => doc.update(any())).thenAnswer((_) async {});

      await repository().markAsMissed('e1');

      final data =
          verify(() => doc.update(captureAny())).captured.single
              as Map<Object, Object?>;
      expect(data['status'], 'dismissed');
      expect(data['updatedAt'], isA<FieldValue>());
      expect(data.keys, hasLength(2));
    });

    test('an update error propagates', () {
      final doc = docOf('e1');
      when(
        () => doc.update(any()),
      ).thenAnswer((_) async => throw FirebaseException(plugin: 'firestore'));

      expect(
        repository().markAsMissed('e1'),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('reads', () {
    test(
      'watchAllExpectedCashFlows orders by date and maps documents',
      () async {
        final query = _MockQuery();
        when(
          () => ecfs.orderBy('expectedDate', descending: false),
        ).thenReturn(query);
        final snapshot = snapshotOf(['a', 'b']);
        when(() => query.snapshots()).thenAnswer((_) => Stream.value(snapshot));

        final result = await repository().watchAllExpectedCashFlows().first;

        expect(result.map((e) => e.id), equals(['a', 'b']));
        expect(result.first.expectedAmount, 3500.0);
      },
    );

    test('a document without a currency takes the base currency', () async {
      final query = _MockQuery();
      when(
        () => ecfs.orderBy('expectedDate', descending: false),
      ).thenReturn(query);
      final snapshot = snapshotOf(['a']);
      when(() => query.snapshots()).thenAnswer((_) => Stream.value(snapshot));

      final result = await repository().watchAllExpectedCashFlows().first;

      expect(result.single.currency, 'INR');
    });

    test(
      'watchExpectedCashFlowsByInvestment filters on the investment',
      () async {
        final filtered = _MockQuery();
        final ordered = _MockQuery();
        when(
          () => ecfs.where('investmentId', isEqualTo: 'inv-1'),
        ).thenReturn(filtered);
        when(
          () => filtered.orderBy('expectedDate', descending: false),
        ).thenReturn(ordered);
        final snapshot = snapshotOf(['a']);
        when(
          () => ordered.snapshots(),
        ).thenAnswer((_) => Stream.value(snapshot));

        final result = await repository()
            .watchExpectedCashFlowsByInvestment('inv-1')
            .first;

        expect(result.single.id, 'a');
      },
    );

    test(
      'getPendingExpectedCashFlows asks for the four open statuses',
      () async {
        final filtered = _MockQuery();
        final ordered = _MockQuery();
        when(
          () => ecfs.where(
            'status',
            whereIn: ['upcoming', 'dueSoon', 'gracePeriod', 'overdue'],
          ),
        ).thenReturn(filtered);
        when(
          () => filtered.orderBy('expectedDate', descending: false),
        ).thenReturn(ordered);
        final snapshot = snapshotOf(['a']);
        when(() => ordered.get()).thenAnswer((_) async => snapshot);

        final result = await repository().getPendingExpectedCashFlows();

        expect(result.single.id, 'a');
      },
    );

    test('a read error propagates', () {
      final query = _MockQuery();
      when(
        () => ecfs.where('investmentId', isEqualTo: 'inv-1'),
      ).thenReturn(query);
      when(
        () => query.orderBy('expectedDate', descending: false),
      ).thenReturn(query);
      when(
        () => query.snapshots(),
      ).thenAnswer((_) => Stream.error(FirebaseException(plugin: 'firestore')));

      expect(
        repository().watchExpectedCashFlowsByInvestment('inv-1').first,
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('deleteExpectedCashFlowsByInvestment', () {
    test('deletes every entry of the investment in one batch', () async {
      final query = _MockQuery();
      when(
        () => ecfs.where('investmentId', isEqualTo: 'inv-1'),
      ).thenReturn(query);
      final snapshot = snapshotOf(['a', 'b']);
      when(() => query.get()).thenAnswer((_) async => snapshot);

      await repository().deleteExpectedCashFlowsByInvestment('inv-1');

      expect(batches, hasLength(1));
      verify(() => batches.single.delete(docOf('a'))).called(1);
      verify(() => batches.single.delete(docOf('b'))).called(1);
      verify(() => batches.single.commit()).called(1);
    });

    test(
      'an investment with no entries still commits an empty batch',
      () async {
        final query = _MockQuery();
        when(
          () => ecfs.where('investmentId', isEqualTo: 'inv-1'),
        ).thenReturn(query);
        final snapshot = snapshotOf([]);
        when(() => query.get()).thenAnswer((_) async => snapshot);

        await repository().deleteExpectedCashFlowsByInvestment('inv-1');

        expect(batches, hasLength(1));
        verifyNever(() => batches.single.delete(any()));
      },
    );

    test('a failed commit propagates', () async {
      final query = _MockQuery();
      when(
        () => ecfs.where('investmentId', isEqualTo: 'inv-1'),
      ).thenReturn(query);
      final snapshot = snapshotOf(['a']);
      when(() => query.get()).thenAnswer((_) async => snapshot);
      final failing = _MockBatch();
      when(
        () => failing.commit(),
      ).thenAnswer((_) async => throw FirebaseException(plugin: 'firestore'));
      when(() => firestore.batch()).thenReturn(failing);

      await expectLater(
        repository().deleteExpectedCashFlowsByInvestment('inv-1'),
        throwsA(isA<FirebaseException>()),
      );

      verify(() => failing.delete(docOf('a'))).called(1);
    });
  });

  group('bulk operations', () {
    test('bulkCreate splits 501 entries into batches of 500 and 1', () async {
      final entries = [for (var i = 0; i < 501; i++) ecf(id: 'n$i')];
      for (final e in entries) {
        docOf(e.id);
      }

      await repository().bulkCreateExpectedCashFlows(entries);

      expect(batches, hasLength(2));
      verify(
        () => batches[0].set<Map<String, dynamic>>(any(), any(), any()),
      ).called(500);
      verify(
        () => batches[1].set<Map<String, dynamic>>(docOf('n500'), any(), any()),
      ).called(1);
      verify(() => batches[0].commit()).called(1);
      verify(() => batches[1].commit()).called(1);
    });

    test('bulkCreate of an empty list opens no batch', () async {
      await repository().bulkCreateExpectedCashFlows([]);

      expect(batches, isEmpty);
    });

    test('bulkDelete splits 501 ids into batches of 500 and 1', () async {
      final ids = [for (var i = 0; i < 501; i++) 'd$i'];
      for (final id in ids) {
        docOf(id);
      }

      await repository().bulkDeleteExpectedCashFlows(ids);

      expect(batches, hasLength(2));
      verify(() => batches[0].delete(any())).called(500);
      verify(() => batches[1].delete(docOf('d500'))).called(1);
      verify(() => batches[1].commit()).called(1);
    });

    test('bulkDelete of exactly 500 ids uses a single batch', () async {
      final ids = [for (var i = 0; i < 500; i++) 'd$i'];
      for (final id in ids) {
        docOf(id);
      }

      await repository().bulkDeleteExpectedCashFlows(ids);

      expect(batches, hasLength(1));
    });

    test('deleteAll deletes every document in the collection', () async {
      final snapshot = snapshotOf(['a', 'b', 'c']);
      when(() => ecfs.get()).thenAnswer((_) async => snapshot);

      await repository().deleteAllExpectedCashFlows();

      expect(batches, hasLength(1));
      verify(() => batches.single.delete(any())).called(3);
      verify(() => batches.single.commit()).called(1);
    });

    test('deleteAll on an empty collection opens no batch', () async {
      final snapshot = snapshotOf([]);
      when(() => ecfs.get()).thenAnswer((_) async => snapshot);

      await repository().deleteAllExpectedCashFlows();

      expect(batches, isEmpty);
    });
  });
}
