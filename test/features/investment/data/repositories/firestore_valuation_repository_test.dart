// #941: the dated-valuation collection users/{uid}/valuations. The snapshot
// and the investment's currentValue mirror change in ONE batch (a failing
// batch leaves neither), every write is a whole-document set, and a document
// that cannot be trusted is ignored rather than reinterpreted.
//
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/stored_date.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_valuation_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../valuation/valuation_fixtures.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

/// Records what is written, so that a test can see which documents change
/// together in one batch.
class _RecordingBatch implements WriteBatch {
  final sets = <(DocumentReference, Map<String, dynamic>)>[];
  final updates = <(DocumentReference, Map<Object, Object?>)>[];
  var commits = 0;
  Object? commitError;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    sets.add((document, data as Map<String, dynamic>));
  }

  @override
  void update(DocumentReference document, Map<Object, Object?> data) {
    updates.add((document, data));
  }

  @override
  void delete(DocumentReference document) =>
      throw StateError('a valuation write must not delete');

  @override
  Future<void> commit() async {
    commits++;
    final error = commitError;
    if (error != null) throw error;
  }
}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  const uid = 'user-1';
  late _MockFirestore firestore;
  late _MockCollection valuations;
  late _MockCollection investments;
  late Map<String, _MockDoc> valuationDocs;
  late Map<String, _MockDoc> investmentDocs;
  late List<_RecordingBatch> batches;
  late FirestoreValuationRepository repository;

  setUpAll(() {
    registerFallbackValue(_MockDoc());
  });

  setUp(() {
    firestore = _MockFirestore();
    valuations = _MockCollection();
    investments = _MockCollection();
    valuationDocs = {};
    investmentDocs = {};
    batches = [];
    final users = _MockCollection();
    final userDoc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(uid)).thenReturn(userDoc);
    when(() => userDoc.collection('valuations')).thenReturn(valuations);
    when(() => userDoc.collection('investments')).thenReturn(investments);
    when(() => valuations.doc(any())).thenAnswer(
      (i) => valuationDocs.putIfAbsent(
        i.positionalArguments.first as String,
        _MockDoc.new,
      ),
    );
    when(() => investments.doc(any())).thenAnswer(
      (i) => investmentDocs.putIfAbsent(
        i.positionalArguments.first as String,
        _MockDoc.new,
      ),
    );
    when(() => firestore.batch()).thenAnswer((_) {
      final batch = _RecordingBatch();
      batches.add(batch);
      return batch;
    });
    repository = FirestoreValuationRepository(
      firestore: firestore,
      userId: uid,
    );
  });

  final snapshot = testSnapshot(
    'snap-1',
    amount: 500000,
    date: DateTime(2026, 1, 1),
    provenance: ValuationProvenance.openingBaseline,
  );

  group('mapper', () {
    test('every kind and provenance round-trips', () {
      for (final kind in ValuationKind.values) {
        for (final provenance in [
          ValuationProvenance.manual,
          ValuationProvenance.openingBaseline,
          ValuationProvenance.imported,
        ]) {
          final original = testSnapshot(
            'x',
            amount: 1234.56,
            date: DateTime(2026, 4, 1),
            kind: kind,
            provenance: provenance,
          );
          final data = FirestoreValuationRepository.snapshotToFirestore(
            original,
          );
          // The server stamps updatedAt; read it back as a stored time.
          data['updatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 4, 2));
          final back = FirestoreValuationRepository.snapshotFromFirestore(
            data,
            'x',
          )!;
          expect(back.kind, kind);
          expect(back.provenance, provenance);
          expect(back.amount, 1234.56);
          expect(back.currency, 'INR');
          expect(back.effectiveDate, DateTime(2026, 4, 1));
          expect(back.investmentId, 'i1');
          expect(back.deletedAt, isNull);
        }
      }
    });

    test('the date is stored as UTC midnight of its calendar day', () {
      final data = FirestoreValuationRepository.snapshotToFirestore(snapshot);
      expect(
        (data['effectiveDate'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 1, 1),
      );
      expect(data['kind'], 'carryingValue');
      expect(data['provenance'], 'openingBaseline');
      expect(data['currency'], 'INR');
      expect(data['updatedAt'], isA<FieldValue>());
      expect(data['deletedAt'], isNull);
      expect(data.keys, containsAll(['investmentId', 'amount', 'createdAt']));
    });

    test('the same day is read in any time zone', () {
      final data = FirestoreValuationRepository.snapshotToFirestore(snapshot)
        ..['updatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 1, 2));
      for (final hours in [-8, 0, 5, 14]) {
        final read = FirestoreValuationRepository.snapshotFromFirestore(
          data,
          'snap-1',
          offsetAt: (_) => Duration(hours: hours),
        )!;
        expect(read.effectiveDate, DateTime(2026, 1, 1), reason: 'UTC+$hours');
      }
    });

    test('the amount is rounded to the currency at write', () {
      final jpy = testSnapshot(
        'j',
        amount: 125.6,
        date: DateTime(2026, 1, 1),
        currency: 'JPY',
      );
      expect(
        FirestoreValuationRepository.snapshotToFirestore(jpy)['amount'],
        126,
      );
      final inr = snapshot.copyWith(amount: 10.005);
      expect(
        FirestoreValuationRepository.snapshotToFirestore(inr)['amount'],
        10.01,
      );
    });

    test('a write that cannot be trusted is refused', () {
      for (final bad in [
        snapshot.copyWith(amount: -1),
        snapshot.copyWith(amount: double.nan),
        snapshot.copyWith(amount: double.infinity),
        snapshot.copyWith(provenance: ValuationProvenance.estimate),
      ]) {
        expect(
          () => FirestoreValuationRepository.snapshotToFirestore(bad),
          throwsArgumentError,
          reason: '${bad.amount} ${bad.provenance}',
        );
      }
      final blank = testSnapshot(
        'b',
        amount: 1,
        date: DateTime(2026, 1, 1),
        currency: ' ',
      );
      expect(
        () => FirestoreValuationRepository.snapshotToFirestore(blank),
        throwsArgumentError,
      );
    });
  });

  group('reading bad data (plan test 20)', () {
    Map<String, dynamic> good() =>
        FirestoreValuationRepository.snapshotToFirestore(snapshot)
          ..['updatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 1, 2));

    test('a good document is read', () {
      expect(
        FirestoreValuationRepository.snapshotFromFirestore(good(), 's'),
        isNotNull,
      );
    });

    test('an unknown or missing kind is ignored, never reinterpreted', () {
      expect(
        FirestoreValuationRepository.snapshotFromFirestore(
          good()..['kind'] = 'fairValue',
          's',
        ),
        isNull,
      );
      expect(
        FirestoreValuationRepository.snapshotFromFirestore(
          good()..remove('kind'),
          's',
        ),
        isNull,
      );
    });

    test('a missing or blank currency is ignored, never defaulted', () {
      expect(
        FirestoreValuationRepository.snapshotFromFirestore(
          good()..remove('currency'),
          's',
        ),
        isNull,
      );
      expect(
        FirestoreValuationRepository.snapshotFromFirestore(
          good()..['currency'] = '',
          's',
        ),
        isNull,
      );
    });

    test('a non-finite or negative amount is ignored', () {
      for (final amount in [double.nan, double.infinity, -5.0]) {
        expect(
          FirestoreValuationRepository.snapshotFromFirestore(
            good()..['amount'] = amount,
            's',
          ),
          isNull,
          reason: '$amount',
        );
      }
    });

    test('a missing amount, date, investment or provenance is ignored', () {
      for (final key in [
        'amount',
        'effectiveDate',
        'investmentId',
        'provenance',
      ]) {
        expect(
          FirestoreValuationRepository.snapshotFromFirestore(
            good()..remove(key),
            's',
          ),
          isNull,
          reason: key,
        );
      }
    });

    test('a pending server timestamp reads as a null updatedAt', () {
      final read = FirestoreValuationRepository.snapshotFromFirestore(
        good()..['updatedAt'] = null,
        's',
      )!;
      expect(read.updatedAt, isNull);
    });

    test('a cleared snapshot is read with its deletedAt', () {
      final read = FirestoreValuationRepository.snapshotFromFirestore(
        good()..['deletedAt'] = Timestamp.fromDate(DateTime.utc(2026, 2, 1)),
        's',
      )!;
      expect(read.isLive, isFalse);
    });
  });

  group('writes', () {
    final mirror = CompatMirror(
      investmentId: 'i1',
      value: 500000,
      date: DateTime(2026, 1, 1),
    );

    test(
      'save sets the whole snapshot and updates the mirror in one batch',
      () async {
        await repository.save(snapshot, mirror: mirror);

        expect(batches, hasLength(1));
        final batch = batches.single;
        expect(batch.sets, hasLength(1));
        expect(batch.sets.single.$1, valuationDocs['snap-1']);
        expect(batch.sets.single.$2['amount'], 500000);
        expect(batch.sets.single.$2['deletedAt'], isNull);

        expect(batch.updates, hasLength(1));
        expect(batch.updates.single.$1, investmentDocs['i1']);
        final mirrored = batch.updates.single.$2;
        expect(mirrored['currentValue'], 500000);
        expect(
          (mirrored['currentValueDate'] as Timestamp).toDate(),
          DateTime(2026, 1, 1),
        );
        expect(mirrored['updatedAt'], isA<FieldValue>());
        expect(batch.commits, 1);
      },
    );

    test('the investment is updated, never created, by the mirror', () async {
      await repository.save(snapshot, mirror: mirror);
      final batch = batches.single;
      expect(
        batch.sets.map((w) => w.$1),
        isNot(contains(investmentDocs['i1'])),
      );
    });

    test('a mirror with no value clears the compat pair', () async {
      await repository.softDelete(
        snapshot,
        mirror: const CompatMirror(investmentId: 'i1'),
      );
      final batch = batches.single;
      expect(batch.sets.single.$2['deletedAt'], isA<Timestamp>());
      final mirrored = batch.updates.single.$2;
      expect(mirrored.containsKey('currentValue'), isTrue);
      expect(mirrored['currentValue'], isNull);
      expect(mirrored['currentValueDate'], isNull);
      expect(batch.commits, 1);
    });

    test('restore sets the snapshot live again with the mirror', () async {
      final cleared = snapshot.copyWith(deletedAt: DateTime.utc(2026, 2, 1));
      await repository.restore(cleared, mirror: mirror);
      final batch = batches.single;
      expect(batch.sets.single.$2['deletedAt'], isNull);
      expect(batch.updates.single.$2['currentValue'], 500000);
      expect(batch.commits, 1);
    });

    test(
      'a batch that fails is one failure for the snapshot and mirror',
      () async {
        when(() => firestore.batch()).thenAnswer((_) {
          final batch = _RecordingBatch()
            ..commitError = FirebaseException(
              plugin: 'cloud_firestore',
              code: 'not-found',
            );
          batches.add(batch);
          return batch;
        });
        await expectLater(
          () => repository.save(snapshot, mirror: mirror),
          throwsA(isA<FirebaseException>()),
        );
        // One batch holds both writes, so neither lands without the other.
        expect(batches, hasLength(1));
        expect(batches.single.sets, hasLength(1));
        expect(batches.single.updates, hasLength(1));
      },
    );

    test('an invalid snapshot is refused before any write', () async {
      await expectLater(
        () => repository.save(snapshot.copyWith(amount: -1), mirror: mirror),
        throwsArgumentError,
      );
      expect(batches, isEmpty);
    });
  });

  group('importAll', () {
    test('chunks at 450 writes per batch', () async {
      final many = [
        for (var i = 0; i < 901; i++)
          testSnapshot('s$i', amount: 1, date: DateTime(2026, 1, 1)),
      ];
      final written = await repository.importAll(many);
      expect(written, 901);
      expect([for (final b in batches) b.sets.length], [450, 450, 1]);
      expect([for (final b in batches) b.commits], [1, 1, 1]);
      expect([for (final b in batches) b.updates.length], [0, 0, 0]);
    });

    test('keeps the update time it was given', () async {
      final at = DateTime.utc(2026, 5, 5, 10);
      await repository.importAll([snapshot.copyWith(updatedAt: at)]);
      final data = batches.single.sets.single.$2;
      expect((data['updatedAt'] as Timestamp).toDate().toUtc(), at);
    });

    test('nothing to import writes nothing', () async {
      expect(await repository.importAll(const []), 0);
      expect(batches, isEmpty);
    });
  });

  group('reading', () {
    test('getAll drops documents that cannot be trusted', () async {
      final query = _MockQuerySnapshot();
      final good = _MockQueryDoc();
      final bad = _MockQueryDoc();
      when(() => good.id).thenReturn('good');
      when(() => good.data()).thenReturn(
        FirestoreValuationRepository.snapshotToFirestore(snapshot)
          ..['updatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
      );
      when(() => bad.id).thenReturn('bad');
      when(() => bad.data()).thenReturn({'kind': 'unknown'});
      when(() => query.docs).thenReturn([good, bad]);
      when(() => valuations.get()).thenAnswer((_) async => query);

      final all = await repository.getAll();
      expect(all.map((s) => s.id), ['good']);
    });
  });

  test('StoredDate is the date format of the collection', () {
    expect(
      StoredDate.toStorage(DateTime(2026, 1, 1)),
      DateTime.utc(2026, 1, 1),
    );
  });
}
