// #941: the dated-valuation collection users/{uid}/valuations. The snapshot
// and the investment's currentValue mirror change in ONE batch (a failing
// batch leaves neither), every write is a whole-document set, and a document
// that cannot be trusted is ignored rather than reinterpreted.
//
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/utils/stored_date.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_valuation_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
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

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockMetadata extends Mock implements SnapshotMetadata {}

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

    // CodeRabbit round 3 on PR 961: a batch that fails after earlier ones
    // committed must not leave an investment with part of its history. An
    // investment's snapshots go into one batch.
    group('an investment is never split between batches', () {
      List<InvestmentValuationSnapshot> history(String investmentId, int n) => [
        for (var i = 0; i < n; i++)
          testSnapshot(
            '$investmentId-$i',
            investmentId: investmentId,
            amount: 1000000.0 + i * 1000,
            date: DateTime(2025, 1, 1).add(Duration(days: i)),
          ),
      ];

      /// For each batch, the count written per investment (ids are
      /// '<investment>-<n>').
      List<Map<String, int>> perBatch() {
        final idOf = {for (final e in valuationDocs.entries) e.value: e.key};
        return [
          for (final b in batches)
            () {
              final counts = <String, int>{};
              for (final (ref, _) in b.sets) {
                final investment = idOf[ref]!.split('-').first;
                counts[investment] = (counts[investment] ?? 0) + 1;
              }
              return counts;
            }(),
        ];
      }

      void expectWhole(Map<String, int> sizes) {
        final seen = <String, int>{};
        for (final batch in perBatch()) {
          for (final e in batch.entries) {
            expect(
              seen.containsKey(e.key),
              isFalse,
              reason: '${e.key} is in more than one batch',
            );
            seen[e.key] = e.value;
          }
        }
        expect(seen, sizes);
      }

      test('exactly 450 snapshots are one batch', () async {
        final all = [for (var n = 0; n < 5; n++) ...history('inv$n', 90)];
        expect(await repository.importAll(all), 450);
        expect([for (final b in batches) b.sets.length], [450]);
      });

      test(
        '451 snapshots start a second batch at an investment boundary',
        () async {
          final all = [
            for (var n = 0; n < 4; n++) ...history('inv$n', 100),
            ...history('inv4', 51),
          ];
          expect(await repository.importAll(all), 451);
          expect([for (final b in batches) b.sets.length], [400, 51]);
          expectWhole({
            'inv0': 100,
            'inv1': 100,
            'inv2': 100,
            'inv3': 100,
            'inv4': 51,
          });
        },
      );

      test('5 investments of 100: 400 then 100, not 450 then 50', () async {
        final all = [for (var n = 0; n < 5; n++) ...history('inv$n', 100)];
        expect(await repository.importAll(all), 500);
        expect([for (final b in batches) b.sets.length], [400, 100]);
        expectWhole({for (var n = 0; n < 5; n++) 'inv$n': 100});
      });

      test('an investment that alone exceeds a batch gets batches of its '
          'own', () async {
        final all = [
          ...history('inv0', 50),
          ...history('big', 460),
          ...history('inv2', 30),
        ];
        expect(await repository.importAll(all), 540);
        expect([for (final b in batches) b.sets.length], [50, 450, 10, 30]);
      });

      test('snapshots of one investment apart in the list still go '
          'together', () async {
        final a = history('a', 300);
        final b = history('b', 300);
        // a, b, a, b, ...: no investment is contiguous.
        await repository.importAll([
          for (var i = 0; i < 300; i++) ...[a[i], b[i]],
        ]);
        expect([for (final batch in batches) batch.sets.length], [300, 300]);
        expectWhole({'a': 300, 'b': 300});
      });

      test('a rejected second batch leaves no investment with part of its '
          'history, and every reader still shows the latest value', () async {
        // The second batch to be created is rejected by the server.
        var created = 0;
        when(() => firestore.batch()).thenAnswer((_) {
          final batch = _RecordingBatch();
          if (++created == 2) batch.commitError = StateError('exhausted');
          batches.add(batch);
          return batch;
        });
        final all = [for (var n = 0; n < 5; n++) ...history('inv$n', 100)];
        await expectLater(
          () => repository.importAll(all),
          throwsA(isA<StateError>()),
        );

        // What the server has: the first batch only.
        final idOf = {for (final e in valuationDocs.entries) e.value: e.key};
        final stored = <String, List<InvestmentValuationSnapshot>>{};
        for (final (ref, data) in batches.first.sets) {
          final s = FirestoreValuationRepository.snapshotFromFirestore(
            data,
            idOf[ref]!,
          )!;
          stored.putIfAbsent(s.investmentId, () => []).add(s);
        }
        expect(
          {for (final e in stored.entries) e.key: e.value.length},
          {'inv0': 100, 'inv1': 100, 'inv2': 100, 'inv3': 100},
        );

        // Each investment holds the backup's latest in its pair, as the
        // import wrote it. Complete ones show their latest snapshot; the one
        // with none shows the pair.
        for (var n = 0; n < 5; n++) {
          final investment = testInvestment(
            'inv$n',
            compatValue: 1000000.0 + 99 * 1000,
            compatDate: DateTime(2025, 1, 1).add(const Duration(days: 99)),
            updatedAt: DateTime.utc(2026, 6, 1),
          );
          final shown = CurrentValueCalculator.valuationOf(
            investment,
            [
              testFlow(
                'inv$n',
                CashFlowType.invest,
                1000000,
                DateTime(2024, 1, 1),
              ),
            ],
            asOf: DateTime(2026, 10, 10),
            snapshots: {'inv$n': stored['inv$n'] ?? const []},
          );
          expect(shown?.amount, 1099000.00, reason: 'inv$n');
          expect(shown?.date, DateTime(2025, 4, 10), reason: 'inv$n');
        }
      });
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

  group('reading one investment', () {
    test('getByInvestment asks for it by one field, tombstones included, '
        'and drops what cannot be trusted', () async {
      final query = _MockQuery();
      final result = _MockQuerySnapshot();
      final live = _MockQueryDoc();
      final cleared = _MockQueryDoc();
      final bad = _MockQueryDoc();
      when(() => live.id).thenReturn('live');
      when(
        () => live.data(),
      ).thenReturn(FirestoreValuationRepository.snapshotToFirestore(snapshot));
      when(() => cleared.id).thenReturn('cleared');
      when(() => cleared.data()).thenReturn(
        FirestoreValuationRepository.snapshotToFirestore(
          snapshot.copyWith(deletedAt: DateTime.utc(2026, 2, 1)),
        ),
      );
      when(() => bad.id).thenReturn('bad');
      when(() => bad.data()).thenReturn({'kind': 'unknown'});
      when(() => result.docs).thenReturn([live, cleared, bad]);
      when(
        () => valuations.where('investmentId', isEqualTo: 'i1'),
      ).thenReturn(query);
      when(() => query.get()).thenAnswer((_) async => result);

      final own = await repository.getByInvestment('i1');

      expect(own.map((s) => s.id), ['live', 'cleared']);
      expect(own.map((s) => s.isLive), [true, false]);
      verify(() => valuations.where('investmentId', isEqualTo: 'i1')).called(1);
      // A single-field equality: no ordering, so no composite index.
      verifyNever(() => valuations.get());
    });
  });

  group('server-confirmed state', () {
    QuerySnapshot<Map<String, dynamic>> query({
      required bool fromCache,
      required bool pending,
      required String id,
    }) {
      final metadata = _MockMetadata();
      when(() => metadata.isFromCache).thenReturn(fromCache);
      when(() => metadata.hasPendingWrites).thenReturn(pending);
      final doc = _MockQueryDoc();
      when(() => doc.id).thenReturn(id);
      when(() => doc.data()).thenReturn(
        FirestoreValuationRepository.snapshotToFirestore(snapshot)
          ..['updatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
      );
      final result = _MockQuerySnapshot();
      when(() => result.metadata).thenReturn(metadata);
      when(() => result.docs).thenReturn([doc]);
      return result;
    }

    test(
      'only states from the server with no pending write get through',
      () async {
        final controller =
            StreamController<QuerySnapshot<Map<String, dynamic>>>();
        addTearDown(controller.close);
        when(
          () => valuations.snapshots(includeMetadataChanges: true),
        ).thenAnswer((_) => controller.stream);

        final seen = <String>[];
        final sub = repository.watchServerConfirmed().listen(
          (all) => seen.addAll(all.map((s) => s.id)),
        );
        addTearDown(sub.cancel);

        controller
          ..add(query(fromCache: true, pending: false, id: 'cache'))
          ..add(query(fromCache: false, pending: true, id: 'pending'))
          ..add(query(fromCache: false, pending: false, id: 'server'));
        await Future<void>.delayed(Duration.zero);

        expect(seen, ['server']);
      },
    );
  });

  test('StoredDate is the date format of the collection', () {
    expect(
      StoredDate.toStorage(DateTime(2026, 1, 1)),
      DateTime.utc(2026, 1, 1),
    );
  });
}
