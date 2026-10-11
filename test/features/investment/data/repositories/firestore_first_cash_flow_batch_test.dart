// A40 (#783) PR A1: an investment and its first cash flow are saved in ONE
// WriteBatch, so a failure leaves neither and a retry with the same ids leaves
// exactly one of each. The batch returns true when the server confirmed within
// the write timeout and false when it did not (a write still pending offline).
//
// The project has no fake_cloud_firestore dependency, so a small in-memory
// Firestore with an atomic batch stands in for the server.
//
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// users/{uid}/{collection}/{id} documents in memory, with a batch that is
/// applied all together or not at all.
class _InMemoryFirestore extends Fake implements FirebaseFirestore {
  static const uid = 'uid-1';

  /// collection name -> document id -> stored fields.
  final data = <String, Map<String, Map<String, dynamic>>>{};

  /// Thrown by the next commit, which then applies nothing (a rejected write).
  Object? commitError;

  /// What the commit with this number throws. Commits are numbered from 1 over
  /// the life of the store. A failed commit applies nothing, but the commits
  /// before it have already been applied, like a real server would have.
  final failingCommits = <int, Object>{};

  /// While set, a commit applies its writes at once, like the local cache, but
  /// only completes when this does (the server has not answered).
  Completer<void>? serverAnswer;

  int batches = 0;
  int commits = 0;
  int sets = 0;

  Map<String, Map<String, dynamic>> of(String collection) =>
      data[collection] ?? {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'users');
    return _Collection(this, 'users');
  }

  @override
  WriteBatch batch() {
    batches++;
    return _Batch(this);
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.name);
  final _InMemoryFirestore store;
  final String name;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      name == 'users' ? _UserDoc(store) : _Doc(collectionName: name, id: path!);
}

class _UserDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _UserDoc(this.store);
  final _InMemoryFirestore store;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, path);
}

class _Doc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Doc({required this.collectionName, required this.id});
  final String collectionName;
  @override
  final String id;
}

class _Batch extends Fake implements WriteBatch {
  _Batch(this.store);
  final _InMemoryFirestore store;
  final _writes = <(_Doc, Map<String, dynamic>)>[];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    store.sets++;
    _writes.add((document as _Doc, Map.of(data as Map<String, dynamic>)));
  }

  @override
  Future<void> commit() async {
    store.commits++;
    final numbered = store.failingCommits.remove(store.commits);
    if (numbered != null) throw numbered;
    final error = store.commitError;
    if (error != null) {
      store.commitError = null;
      throw error;
    }
    for (final (doc, fields) in _writes) {
      store.data.putIfAbsent(doc.collectionName, () => {})[doc.id] = fields;
    }
    final answer = store.serverAnswer;
    if (answer != null) await answer.future;
  }
}

void main() {
  late _InMemoryFirestore firestore;
  late FirestoreInvestmentRepository repository;

  setUp(() {
    firestore = _InMemoryFirestore();
    repository = FirestoreInvestmentRepository(
      firestore: firestore,
      userId: _InMemoryFirestore.uid,
      baseCurrency: () => 'INR',
    );
  });

  InvestmentEntity investment({String id = 'inv-1', DateTime? startDate}) =>
      InvestmentEntity(
        id: id,
        name: 'HDFC FD',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        createdAt: DateTime(2026, 10, 11, 23, 30),
        updatedAt: DateTime(2026, 10, 11, 23, 30),
        startDate: startDate ?? DateTime(2026, 10, 11, 23, 30),
        currency: 'INR',
      );

  CashFlowEntity firstFlow({
    String id = 'cf-1',
    String investmentId = 'inv-1',
    DateTime? date,
  }) => CashFlowEntity(
    id: id,
    investmentId: investmentId,
    type: CashFlowType.invest,
    amount: 100000,
    date: date ?? DateTime(2026, 10, 11, 23, 30),
    createdAt: DateTime(2026, 10, 11, 23, 30),
    currency: 'INR',
  );

  group('createInvestmentWithFirstCashFlow', () {
    test('stores the investment and one INVEST flow of 100000.00 INR dated '
        '2026-10-11T00:00:00Z from a date with a time of day', () async {
      final confirmed = await repository.createInvestmentWithFirstCashFlow(
        investment(),
        firstFlow(),
      );

      expect(confirmed, isTrue);
      final flow = _firstFlowDoc(firestore);
      expect(flow['investmentId'], 'inv-1');
      expect(flow['type'], 'INVEST');
      expect(flow['amount'], 100000.00);
      expect(flow['currency'], 'INR');
      expect(
        (flow['date'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 10, 11),
      );
      final stored = firestore.of('investments')['inv-1']!;
      expect(stored['name'], 'HDFC FD');
      expect(
        (stored['startDate'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 10, 11),
      );
    });

    test('writes both documents in one batch and one commit', () async {
      await repository.createInvestmentWithFirstCashFlow(
        investment(),
        firstFlow(),
      );

      expect(firestore.batches, 1);
      expect(firestore.sets, 2);
      expect(firestore.commits, 1);
    });

    test('a rejected commit leaves no investment and no flow', () async {
      firestore.commitError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      await expectLater(
        repository.createInvestmentWithFirstCashFlow(investment(), firstFlow()),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );

      expect(firestore.of('investments'), isEmpty);
      expect(firestore.of('cashflows'), isEmpty);
    });

    test('a retry with the same ids after a failure leaves exactly one '
        'investment and one flow', () async {
      firestore.commitError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await expectLater(
        repository.createInvestmentWithFirstCashFlow(investment(), firstFlow()),
        throwsA(isA<FirebaseException>()),
      );

      await repository.createInvestmentWithFirstCashFlow(
        investment(),
        firstFlow(),
      );

      expect(firestore.of('investments').keys, ['inv-1']);
      expect(firestore.of('cashflows').keys, ['cf-1']);
    });

    test('saving the same ids again leaves one of each, not two', () async {
      await repository.createInvestmentWithFirstCashFlow(
        investment(),
        firstFlow(),
      );
      await repository.createInvestmentWithFirstCashFlow(
        investment(),
        firstFlow(),
      );

      expect(firestore.of('investments'), hasLength(1));
      expect(firestore.of('cashflows'), hasLength(1));
    });

    test('with no first flow it writes the investment only', () async {
      final confirmed = await repository.createInvestmentWithFirstCashFlow(
        investment(),
        null,
      );

      expect(confirmed, isTrue);
      expect(firestore.of('investments').keys, ['inv-1']);
      expect(firestore.of('cashflows'), isEmpty);
      expect(firestore.sets, 1);
    });

    test(
      'refuses a flow built for a calculation, and writes nothing',
      () async {
        await expectLater(
          repository.createInvestmentWithFirstCashFlow(
            investment(),
            firstFlow(id: 'current-value:inv-1'),
          ),
          throwsArgumentError,
        );

        expect(firestore.batches, 0);
        expect(firestore.of('investments'), isEmpty);
      },
    );

    test('refuses a first flow of another investment, and writes nothing, '
        'so no flow is left without its investment', () async {
      await expectLater(
        repository.createInvestmentWithFirstCashFlow(
          investment(),
          firstFlow(investmentId: 'inv-2'),
        ),
        throwsArgumentError,
      );

      expect(firestore.batches, 0);
      expect(firestore.of('investments'), isEmpty);
      expect(firestore.of('cashflows'), isEmpty);
    });

    // A date with a time of day, stored as the local calendar day at UTC
    // midnight. The two values have a UTC date that differs from the local
    // date in some zones (23:30 in Los Angeles is already the next UTC day;
    // 01:00 in Kolkata is still the previous one), so the stored day must come
    // from the local year, month and day fields, never from toUtc(). A test
    // cannot change the process zone: under a UTC runner the two dates agree,
    // so run with TZ=America/Los_Angeles to exercise the difference.
    for (final (:local, :day) in [
      (local: DateTime(2026, 10, 11, 23, 30), day: DateTime.utc(2026, 10, 11)),
      (local: DateTime(2026, 10, 12, 1, 0), day: DateTime.utc(2026, 10, 12)),
    ]) {
      test('a date of $local is stored as $day on both records', () async {
        await repository.createInvestmentWithFirstCashFlow(
          investment(startDate: local),
          firstFlow(date: local),
        );

        expect(
          (_firstFlowDoc(firestore)['date'] as Timestamp).toDate().toUtc(),
          day,
        );
        expect(
          (firestore.of('investments')['inv-1']!['startDate'] as Timestamp)
              .toDate()
              .toUtc(),
          day,
        );
      });
    }

    testWidgets('is true when the server answers before the write timeout, '
        'false when it does not', (tester) async {
      final answer = firestore.serverAnswer = Completer<void>();
      bool? confirmed;
      unawaited(
        repository
            .createInvestmentWithFirstCashFlow(investment(), firstFlow())
            .then((value) => confirmed = value),
      );

      await tester.pump(const Duration(seconds: 2));
      expect(confirmed, isNull, reason: 'still within the 3 s write timeout');

      await tester.pump(const Duration(seconds: 1));
      expect(confirmed, isFalse, reason: 'the server never answered');
      // The write is pending in the local cache; it syncs when back online.
      expect(firestore.of('investments').keys, ['inv-1']);
      expect(firestore.of('cashflows').keys, ['cf-1']);

      // Answered in time: confirmed.
      firestore.serverAnswer = null;
      answer.complete();
      final second = await repository.createInvestmentWithFirstCashFlow(
        investment(),
        firstFlow(),
      );
      expect(second, isTrue);
    });
  });

  // The count test above ("one batch, one commit") would pass for any code that
  // happens to build one batch. What matters is what a failure leaves behind,
  // so the fake can fail the Nth commit, whichever write that is.
  group('atomicity is what a failed commit leaves, not a commit count', () {
    FirebaseException failure() =>
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

    for (final n in [1, 2]) {
      test('with commit #$n set to fail, the repository stores both records '
          'or neither', () async {
        firestore.failingCommits[n] = failure();

        try {
          await repository.createInvestmentWithFirstCashFlow(
            investment(),
            firstFlow(),
          );
        } on FirebaseException {
          // Commit #1 failing is the expected rejection.
        }

        expect(
          firestore.of('investments').length,
          firestore.of('cashflows').length,
          reason:
              'an investment without its first flow, or a flow without '
              'its investment, was left behind',
        );
      });
    }

    test(
      'the same failure leaves an investment without its flow when the '
      'save is split in two batches: what the test above guards against',
      () async {
        firestore.failingCommits[2] = failure();
        final user = firestore.collection('users').doc(_InMemoryFirestore.uid);

        final first = firestore.batch()
          ..set(user.collection('investments').doc('inv-1'), {
            'name': 'HDFC FD',
          });
        await first.commit();
        final second = firestore.batch()
          ..set(user.collection('cashflows').doc('cf-1'), {'amount': 100000});

        await expectLater(second.commit(), throwsA(isA<FirebaseException>()));

        expect(firestore.of('investments').keys, ['inv-1']);
        expect(firestore.of('cashflows'), isEmpty);
      },
    );
  });
}

/// The one stored cash flow, as Firestore holds it.
Map<String, dynamic> _firstFlowDoc(_InMemoryFirestore firestore) {
  expect(firestore.of('cashflows'), hasLength(1));
  return firestore.of('cashflows').values.single;
}
