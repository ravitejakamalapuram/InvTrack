// #936: reusable custom types live in users/{uid}/customInvestmentTypes, one
// small document per definition, written offline-first.

// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_custom_investment_type_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:mocktail/mocktail.dart';

import 'investment_snapshot_mocks.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

final _created = DateTime.utc(2026, 10, 1, 8);
final _updated = DateTime.utc(2026, 10, 5, 9);
final _removed = DateTime.utc(2026, 10, 7, 10);

void main() {
  late _MockCollection types;
  late _MockDoc doc;
  late FirestoreCustomInvestmentTypeRepository repository;

  setUpAll(() {
    registerFallbackValue(<Object, Object?>{});
    registerInvestmentSnapshotFallbacks();
  });

  setUp(() {
    final firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    types = _MockCollection();
    doc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('uid-1')).thenReturn(userDoc);
    when(() => userDoc.collection('customInvestmentTypes')).thenReturn(types);
    when(() => types.doc('c1')).thenReturn(doc);
    when(() => doc.set(any())).thenAnswer((_) async {});
    repository = FirestoreCustomInvestmentTypeRepository(
      firestore: firestore,
      userId: 'uid-1',
    );
  });

  test(
    'put writes the label and dates, with removedAt null while active',
    () async {
      await repository.put(
        CustomInvestmentType(
          id: 'c1',
          label: 'Stamps',
          createdAt: _created,
          updatedAt: _updated,
        ),
      );

      final written =
          (verify(() => doc.set(captureAny())).captured.single as Map)
              .cast<String, dynamic>();
      expect(written, {
        'label': 'Stamps',
        'createdAt': Timestamp.fromDate(_created),
        'updatedAt': Timestamp.fromDate(_updated),
        'removedAt': null,
      });
    },
  );

  test('a removed definition keeps its label and gets removedAt', () async {
    await repository.put(
      CustomInvestmentType(
        id: 'c1',
        label: 'Stamps',
        createdAt: _created,
        updatedAt: _removed,
        removedAt: _removed,
      ),
    );

    final written = (verify(() => doc.set(captureAny())).captured.single as Map)
        .cast<String, dynamic>();
    expect(written['label'], 'Stamps');
    expect(written['removedAt'], Timestamp.fromDate(_removed));
  });

  test('a document reads back as the definition that was written', () {
    final def = FirestoreCustomInvestmentTypeRepository.fromFirestore({
      'label': 'Stamps',
      'createdAt': Timestamp.fromDate(_created),
      'updatedAt': Timestamp.fromDate(_updated),
      'removedAt': Timestamp.fromDate(_removed),
    }, 'c1')!;
    expect(
      def,
      CustomInvestmentType(
        id: 'c1',
        label: 'Stamps',
        createdAt: _created.toLocal(),
        updatedAt: _updated.toLocal(),
        removedAt: _removed.toLocal(),
      ),
    );
    expect(def.isRemoved, isTrue);
  });

  test('a document with no updatedAt or removedAt still reads', () {
    final def = FirestoreCustomInvestmentTypeRepository.fromFirestore({
      'label': 'Stamps',
      'createdAt': Timestamp.fromDate(_created),
    }, 'c1')!;
    expect(def.updatedAt, _created.toLocal());
    expect(def.removedAt, isNull);
  });

  test('getAll lists every definition, removed ones included', () async {
    when(() => types.get()).thenAnswer(
      (_) async => querySnapshot(
        fromCache: false,
        docs: {
          'c1': {
            'label': 'Stamps',
            'createdAt': Timestamp.fromDate(_created),
            'updatedAt': Timestamp.fromDate(_updated),
          },
          'c2': {
            'label': 'Wine',
            'createdAt': Timestamp.fromDate(_created),
            'updatedAt': Timestamp.fromDate(_updated),
            'removedAt': Timestamp.fromDate(_removed),
          },
        },
      ),
    );

    final all = await repository.getAll();

    expect(all.map((d) => d.id), ['c1', 'c2']);
    expect(all.map((d) => d.isRemoved), [false, true]);
  });

  test('getAll skips a malformed definition and lists the rest', () async {
    when(() => types.get()).thenAnswer(
      (_) async => querySnapshot(
        fromCache: false,
        docs: {
          'bad1': {'label': 42, 'createdAt': Timestamp.fromDate(_created)},
          'bad2': {'createdAt': Timestamp.fromDate(_created)},
          'bad3': {'label': '   ', 'createdAt': Timestamp.fromDate(_created)},
          'c1': {'label': 'Stamps', 'createdAt': Timestamp.fromDate(_created)},
          'late': {'label': 'Wine', 'createdAt': 'yesterday'},
        },
      ),
    );

    final all = await repository.getAll();

    expect(all.map((d) => d.id), ['c1', 'late']);
    expect(all.map((d) => d.label), ['Stamps', 'Wine']);
  });

  test('watchAll skips a malformed definition too', () async {
    final query = querySnapshot(
      fromCache: false,
      docs: {
        'bad': {'label': 42, 'createdAt': Timestamp.fromDate(_created)},
        'c1': {'label': 'Stamps', 'createdAt': Timestamp.fromDate(_created)},
      },
    );
    when(() => types.snapshots()).thenAnswer((_) => Stream.value(query));

    final all = await repository.watchAll().first;

    expect(all.map((d) => d.id), ['c1']);
  });

  test('a label is cleaned and cut on read', () {
    final def = FirestoreCustomInvestmentTypeRepository.fromFirestore({
      'label': '  Art   Prints ${'x' * 60}',
      'createdAt': Timestamp.fromDate(_created),
    }, 'c1')!;
    expect(def.label, 'Art Prints ${'x' * 29}');
  });

  test(
    'deleteAll deletes every document for good, a malformed one too',
    () async {
      final badDoc = _MockDoc();
      when(() => types.doc('bad')).thenReturn(badDoc);
      when(() => doc.delete()).thenAnswer((_) async {});
      when(() => badDoc.delete()).thenAnswer((_) async {});
      when(() => types.get()).thenAnswer(
        (_) async => querySnapshot(
          fromCache: false,
          docs: {
            'c1': {
              'label': 'Stamps',
              'createdAt': Timestamp.fromDate(_created),
            },
            'bad': {'label': 42},
          },
        ),
      );

      await repository.deleteAll();

      verify(() => doc.delete()).called(1);
      verify(() => badDoc.delete()).called(1);
    },
  );
}
