// A64 (#811): FirestoreGoalRepository public methods through mocktail. Goals
// move between an active and an archived collection, so the tests pin the
// archive / restore batch, deletes, error propagation and the offline write
// timeout.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/data/repositories/firestore_goal_repository.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _FakeDocSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnapshot(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _FakeQueryDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDoc(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;
}

class _MockBatch extends Mock implements WriteBatch {}

void main() {
  final created = DateTime(2026, 1, 5);

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(_MockDoc());
  });

  late _MockFirestore firestore;
  late _MockCollection goals;
  late _MockCollection archived;
  late Map<String, _MockDoc> goalDocs;
  late Map<String, _MockDoc> archivedDocs;
  late _MockBatch batch;

  _MockDoc docIn(
    _MockCollection collection,
    Map<String, _MockDoc> docs,
    String id,
  ) => docs.putIfAbsent(id, () {
    final doc = _MockDoc();
    when(() => collection.doc(id)).thenReturn(doc);
    return doc;
  });

  _MockDoc goalDoc(String id) => docIn(goals, goalDocs, id);
  _MockDoc archivedDoc(String id) => docIn(archived, archivedDocs, id);

  Map<String, dynamic> goalData({String name = 'House', String? currency}) => {
    'name': name,
    'type': 'targetAmount',
    'targetAmount': 100000,
    'trackingMode': 'all',
    'currency': ?currency,
    'isArchived': false,
    'createdAt': Timestamp.fromDate(created),
    'updatedAt': Timestamp.fromDate(created),
  };

  DocumentSnapshot<Map<String, dynamic>> snapshotOf(
    String id,
    Map<String, dynamic>? data,
  ) => _FakeDocSnapshot(id, data);

  QuerySnapshot<Map<String, dynamic>> querySnapshotOf(
    Map<String, Map<String, dynamic>> docs,
  ) => _FakeQuerySnapshot([
    for (final entry in docs.entries) _FakeQueryDoc(entry.key, entry.value),
  ]);

  GoalEntity goal({String id = 'g1', String name = 'House'}) => GoalEntity(
    id: id,
    name: name,
    type: GoalType.targetAmount,
    targetAmount: 100000,
    trackingMode: GoalTrackingMode.all,
    icon: GoalIcons.defaultIcon,
    colorValue: 1,
    createdAt: created,
    updatedAt: created,
    currency: 'EUR',
  );

  FirestoreGoalRepository repository() => FirestoreGoalRepository(
    firestore: firestore,
    userId: 'uid-1',
    baseCurrency: () => 'INR',
  );

  setUp(() {
    firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    goals = _MockCollection();
    archived = _MockCollection();
    goalDocs = {};
    archivedDocs = {};
    batch = _MockBatch();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('uid-1')).thenReturn(userDoc);
    when(() => userDoc.collection('goals')).thenReturn(goals);
    when(() => userDoc.collection('archivedGoals')).thenReturn(archived);
    when(() => firestore.batch()).thenReturn(batch);
    when(() => batch.commit()).thenAnswer((_) async {});
    // Created up front: mocktail cannot create a stub inside another `when`.
    for (final id in ['g1', 'gone']) {
      goalDoc(id);
      archivedDoc(id);
    }
  });

  group('createGoal', () {
    test('sets the goal document under its own id', () async {
      final doc = goalDoc('g1');
      when(() => doc.set(any())).thenAnswer((_) async {});

      await repository().createGoal(goal());

      final data =
          verify(() => doc.set(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(data['name'], 'House');
      expect(data['currency'], 'EUR');
      expect(data['targetAmount'], 100000.0);
    });

    test('a write error propagates to the caller', () {
      final doc = goalDoc('g1');
      when(
        () => doc.set(any()),
      ).thenAnswer((_) async => throw FirebaseException(plugin: 'firestore'));

      expect(
        repository().createGoal(goal()),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('an offline write that never acknowledges completes after 3s', () {
      final doc = goalDoc('g1');
      when(() => doc.set(any())).thenAnswer((_) => Completer<void>().future);

      fakeAsync((async) {
        var done = false;
        repository().createGoal(goal()).then((_) => done = true);

        async.elapse(const Duration(milliseconds: 2999));
        expect(done, isFalse);
        async.elapse(const Duration(milliseconds: 2));
        expect(done, isTrue);
      });
    });
  });

  group('updateGoal and updateArchivedGoal', () {
    test('updateGoal updates the active document', () async {
      final doc = goalDoc('g1');
      when(() => doc.update(any())).thenAnswer((_) async {});

      await repository().updateGoal(goal(name: 'Car'));

      final data =
          verify(() => doc.update(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(data['name'], 'Car');
      verifyNever(() => archivedDoc('g1').update(any()));
    });

    test('updateArchivedGoal updates the archived document only', () async {
      final doc = archivedDoc('g1');
      when(() => doc.update(any())).thenAnswer((_) async {});

      await repository().updateArchivedGoal(goal(name: 'Old'));

      final data =
          verify(() => doc.update(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(data['name'], 'Old');
    });

    test('an update error propagates', () {
      final doc = goalDoc('g1');
      when(
        () => doc.update(any()),
      ).thenAnswer((_) async => throw FirebaseException(plugin: 'firestore'));

      expect(
        repository().updateGoal(goal()),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('deleteGoal and deleteArchivedGoal', () {
    test('deleteGoal deletes the active document only', () async {
      final doc = goalDoc('g1');
      when(() => doc.delete()).thenAnswer((_) async {});

      await repository().deleteGoal('g1');

      verify(() => doc.delete()).called(1);
    });

    test('deleteArchivedGoal deletes the archived document only', () async {
      final doc = archivedDoc('g1');
      when(() => doc.delete()).thenAnswer((_) async {});

      await repository().deleteArchivedGoal('g1');

      verify(() => doc.delete()).called(1);
    });

    test('a delete error propagates', () {
      final doc = goalDoc('g1');
      when(
        () => doc.delete(),
      ).thenAnswer((_) async => throw FirebaseException(plugin: 'firestore'));

      expect(repository().deleteGoal('g1'), throwsA(isA<FirebaseException>()));
    });

    test('an offline delete completes after the write timeout', () {
      final doc = archivedDoc('g1');
      when(() => doc.delete()).thenAnswer((_) => Completer<void>().future);

      fakeAsync((async) {
        var done = false;
        repository().deleteArchivedGoal('g1').then((_) => done = true);

        async.elapse(const Duration(seconds: 4));
        expect(done, isTrue);
      });
    });
  });

  group('archiveGoal', () {
    test('moves the document to archivedGoals flagged archived', () async {
      when(
        () => goalDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', goalData()));

      await repository().archiveGoal('g1');

      final setCall = verify(
        () => batch.set<Map<String, dynamic>>(
          archivedDoc('g1'),
          captureAny(),
          any(),
        ),
      );
      final data = setCall.captured.single as Map<String, dynamic>;
      expect(data['isArchived'], isTrue);
      expect(data['name'], 'House');
      expect(data['targetAmount'], 100000);
      expect(data['updatedAt'], isA<FieldValue>());
      verify(() => batch.delete(goalDoc('g1'))).called(1);
      verify(() => batch.commit()).called(1);
    });

    test('a missing goal writes nothing', () async {
      when(
        () => goalDoc('gone').get(),
      ).thenAnswer((_) async => snapshotOf('gone', null));

      await repository().archiveGoal('gone');

      verifyNever(() => firestore.batch());
      verifyNever(() => batch.commit());
    });

    test('a failed commit propagates, so the caller sees the failure', () {
      when(
        () => goalDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', goalData()));
      when(
        () => batch.commit(),
      ).thenAnswer((_) async => throw FirebaseException(plugin: 'firestore'));

      expect(repository().archiveGoal('g1'), throwsA(isA<FirebaseException>()));
    });

    test('an offline commit completes without throwing', () {
      when(
        () => goalDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', goalData()));
      when(() => batch.commit()).thenAnswer((_) => Completer<void>().future);

      fakeAsync((async) {
        var done = false;
        repository().archiveGoal('g1').then((_) => done = true);

        async.elapse(const Duration(seconds: 4));
        expect(done, isTrue);
      });
    });
  });

  group('unarchiveGoal', () {
    test('moves the document back to goals flagged active', () async {
      when(() => archivedDoc('g1').get()).thenAnswer(
        (_) async => snapshotOf('g1', {...goalData(), 'isArchived': true}),
      );

      await repository().unarchiveGoal('g1');

      final data =
          verify(
                () => batch.set<Map<String, dynamic>>(
                  goalDoc('g1'),
                  captureAny(),
                  any(),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(data['isArchived'], isFalse);
      expect(data['name'], 'House');
      expect(data['updatedAt'], isA<FieldValue>());
      verify(() => batch.delete(archivedDoc('g1'))).called(1);
      verify(() => batch.commit()).called(1);
    });

    test('a goal that is not archived writes nothing', () async {
      when(
        () => archivedDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', null));

      await repository().unarchiveGoal('g1');

      verifyNever(() => firestore.batch());
    });

    test('a failed commit propagates', () {
      when(
        () => archivedDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', goalData()));
      when(
        () => batch.commit(),
      ).thenAnswer((_) async => throw FirebaseException(plugin: 'firestore'));

      expect(
        repository().unarchiveGoal('g1'),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('reads', () {
    test(
      'getGoalById returns the active goal without touching archive',
      () async {
        when(
          () => goalDoc('g1').get(),
        ).thenAnswer((_) async => snapshotOf('g1', goalData(currency: 'EUR')));

        final result = await repository().getGoalById('g1');

        expect(result?.id, 'g1');
        expect(result?.currency, 'EUR');
      },
    );

    test('getGoalById falls back to the archived goal', () async {
      when(
        () => goalDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', null));
      when(() => archivedDoc('g1').get()).thenAnswer(
        (_) async => snapshotOf('g1', {...goalData(), 'isArchived': true}),
      );

      final result = await repository().getGoalById('g1');

      expect(result?.id, 'g1');
      expect(result?.isArchived, isTrue);
    });

    test('getGoalById returns null when neither collection has it', () async {
      when(
        () => goalDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', null));
      when(
        () => archivedDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', null));

      expect(await repository().getGoalById('g1'), isNull);
    });

    test('getArchivedGoalById reads only the archive', () async {
      when(
        () => archivedDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', goalData()));

      final result = await repository().getArchivedGoalById('g1');

      expect(result?.name, 'House');
    });

    test('getArchivedGoalById returns null for a missing goal', () async {
      when(
        () => archivedDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', null));

      expect(await repository().getArchivedGoalById('g1'), isNull);
    });

    test('a goal with no stored currency takes the base currency', () async {
      when(
        () => goalDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', goalData()));

      final result = await repository().getGoalById('g1');

      expect(result?.currency, 'INR');
      expect(result?.currencyAssumed, isTrue);
    });

    test('getAllGoals orders newest first and maps every document', () async {
      final query = _MockQuery();
      when(
        () => goals.orderBy('createdAt', descending: true),
      ).thenReturn(query);
      when(() => query.get()).thenAnswer(
        (_) async => querySnapshotOf({
          'a': goalData(name: 'A'),
          'b': goalData(name: 'B'),
        }),
      );

      final result = await repository().getAllGoals();

      expect(result.map((g) => g.id), equals(['a', 'b']));
      expect(result.map((g) => g.name), equals(['A', 'B']));
    });

    test('getGoalsForInvestment filters on the linked investment id', () async {
      final query = _MockQuery();
      when(
        () => goals.where('linkedInvestmentIds', arrayContains: 'inv-9'),
      ).thenReturn(query);
      when(
        () => query.get(),
      ).thenAnswer((_) async => querySnapshotOf({'a': goalData(name: 'A')}));

      final result = await repository().getGoalsForInvestment('inv-9');

      expect(result.single.id, 'a');
    });

    test('a read error propagates', () {
      when(
        () => goalDoc('g1').get(),
      ).thenAnswer((_) async => throw FirebaseException(plugin: 'firestore'));

      expect(repository().getGoalById('g1'), throwsA(isA<FirebaseException>()));
    });
  });

  group('streams', () {
    test(
      'watchAllGoals and watchActiveGoals map the goals collection',
      () async {
        final query = _MockQuery();
        when(
          () => goals.orderBy('createdAt', descending: true),
        ).thenReturn(query);
        when(() => query.snapshots()).thenAnswer(
          (_) => Stream.value(querySnapshotOf({'a': goalData(name: 'A')})),
        );

        final all = await repository().watchAllGoals().first;
        final active = await repository().watchActiveGoals().first;

        expect(all.single.id, 'a');
        expect(active.single.id, 'a');
      },
    );

    test('watchArchivedGoals maps the archived collection', () async {
      final query = _MockQuery();
      when(
        () => archived.orderBy('createdAt', descending: true),
      ).thenReturn(query);
      when(() => query.snapshots()).thenAnswer(
        (_) => Stream.value(querySnapshotOf({'z': goalData(name: 'Z')})),
      );

      final result = await repository().watchArchivedGoals().first;

      expect(result.single.id, 'z');
    });

    test('watchGoalById emits the active goal', () async {
      when(() => goalDoc('g1').snapshots()).thenAnswer(
        (_) => Stream.value(snapshotOf('g1', goalData(name: 'Live'))),
      );

      final result = await repository().watchGoalById('g1').first;

      expect(result?.name, 'Live');
    });

    test('watchGoalById falls back to the archived goal', () async {
      when(
        () => goalDoc('g1').snapshots(),
      ).thenAnswer((_) => Stream.value(snapshotOf('g1', null)));
      when(
        () => archivedDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', goalData(name: 'Old')));

      final result = await repository().watchGoalById('g1').first;

      expect(result?.name, 'Old');
    });

    test('watchGoalById emits null when the goal is nowhere', () async {
      when(
        () => goalDoc('g1').snapshots(),
      ).thenAnswer((_) => Stream.value(snapshotOf('g1', null)));
      when(
        () => archivedDoc('g1').get(),
      ).thenAnswer((_) async => snapshotOf('g1', null));

      expect(await repository().watchGoalById('g1').first, isNull);
    });
  });
}
