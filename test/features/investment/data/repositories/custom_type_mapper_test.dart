// #936: the custom type of an investment (definition id + its own copy of the
// label) is stored on the investment document. Old documents without the
// fields read as plain Other, a cleared type is written as null (`update()`
// keeps fields missing from its map), and archiving and restoring move the
// document, and so the custom type, unchanged.

// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:mocktail/mocktail.dart';

import 'investment_snapshot_mocks.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

/// Records what a batch is asked to set.
class _RecordingBatch extends Fake implements WriteBatch {
  final sets = <(DocumentReference<Object?>, Object?)>[];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    sets.add((document, data));
  }

  @override
  void delete(DocumentReference document) {}

  @override
  Future<void> commit() async {}
}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

InvestmentEntity _stamps({String? id, String? label}) => InvestmentEntity(
  id: 'inv-stamps',
  name: 'Stamp album',
  type: InvestmentType.other,
  status: InvestmentStatus.open,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2026, 10, 2),
  currency: 'INR',
  customTypeId: id,
  customTypeLabel: label,
);

InvestmentEntity _read(Map<String, dynamic> data) =>
    FirestoreInvestmentRepository.investmentFromFirestore(
      {...data, 'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 2))},
      'inv-stamps',
      baseCurrency: 'INR',
    );

void main() {
  late _MockFirestore firestore;
  late _MockCollection users;
  late _MockDoc userDoc;
  late _MockCollection investments;
  late _MockDoc doc;
  late FirestoreInvestmentRepository repository;

  setUpAll(() {
    registerFallbackValue(<Object, Object?>{});
    registerFallbackValue(_MockDoc());
    registerInvestmentSnapshotFallbacks();
  });

  setUp(() {
    firestore = _MockFirestore();
    users = _MockCollection();
    userDoc = _MockDoc();
    investments = _MockCollection();
    doc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('uid-1')).thenReturn(userDoc);
    when(() => userDoc.collection('investments')).thenReturn(investments);
    when(() => investments.doc('inv-stamps')).thenReturn(doc);
    when(() => doc.set(any())).thenAnswer((_) async {});
    when(() => doc.update(any())).thenAnswer((_) async {});
    repository = FirestoreInvestmentRepository(
      firestore: firestore,
      userId: 'uid-1',
      baseCurrency: () => 'INR',
    );
  });

  Future<Map<String, dynamic>> writtenByUpdate(InvestmentEntity i) async {
    await repository.updateInvestment(i);
    return (verify(() => doc.update(captureAny())).captured.single as Map)
        .cast<String, dynamic>();
  }

  test('the custom type round-trips through a create', () async {
    await repository.createInvestment(_stamps(id: 'c1', label: 'Stamps'));
    final written = (verify(() => doc.set(captureAny())).captured.single as Map)
        .cast<String, dynamic>();
    expect(written['customTypeId'], 'c1');
    expect(written['customTypeLabel'], 'Stamps');
    expect(written['type'], 'other');

    final readBack = _read(written);
    expect(readBack.customTypeId, 'c1');
    expect(readBack.customTypeLabel, 'Stamps');
    expect(readBack.type, InvestmentType.other);
  });

  test('a label used on one investment only is stored without an id', () async {
    final written = await writtenByUpdate(_stamps(label: 'Stamps'));
    expect(written['customTypeId'], isNull);
    expect(written['customTypeLabel'], 'Stamps');
    final readBack = _read(written);
    expect(readBack.customTypeId, isNull);
    expect(readBack.customTypeLabel, 'Stamps');
  });

  test('a cleared custom type is written as null, not left out', () async {
    final written = await writtenByUpdate(_stamps());
    expect(written.containsKey('customTypeId'), isTrue);
    expect(written.containsKey('customTypeLabel'), isTrue);
    expect(written['customTypeId'], isNull);
    expect(written['customTypeLabel'], isNull);
  });

  test('a document written before custom types reads as plain Other', () {
    final legacy = _read({
      'name': 'Stamp album',
      'type': 'other',
      'status': 'OPEN',
      'createdAt': Timestamp.fromDate(DateTime.utc(2025, 1, 1)),
      'currency': 'INR',
    });
    expect(legacy.customTypeId, isNull);
    expect(legacy.customTypeLabel, isNull);
    expect(legacy.typeLabel, 'Other');
  });

  test('a blank stored label reads as no custom type', () {
    final blank = _read({
      'name': 'Stamp album',
      'type': 'other',
      'status': 'OPEN',
      'createdAt': Timestamp.fromDate(DateTime.utc(2025, 1, 1)),
      'currency': 'INR',
      'customTypeId': 'c1',
      'customTypeLabel': '   ',
    });
    expect(blank.customTypeLabel, isNull);
    expect(blank.customTypeId, 'c1');
    expect(blank.typeLabel, 'Other');
  });

  group('stored text is normalised on the way in and out', () {
    Map<String, dynamic> doc({
      required String type,
      String? id = 'c1',
      String? label,
    }) => {
      'name': 'Stamp album',
      'type': type,
      'status': 'OPEN',
      'createdAt': Timestamp.fromDate(DateTime.utc(2025, 1, 1)),
      'currency': 'INR',
      'customTypeId': id,
      'customTypeLabel': label,
    };

    test('padded, spaced and invisible characters are cleaned on read', () {
      final read = _read(doc(type: 'other', label: '  Art \n  Prints\u200B '));
      expect(read.customTypeLabel, 'Art Prints');
      expect(read.customTypeId, 'c1');
    });

    test('a label over 40 characters is cut to 40 on read', () {
      // 45 characters, the last of them an emoji that counts as one.
      final read = _read(doc(type: 'other', label: '${'a' * 44}🎨'));
      expect(read.customTypeLabel, 'a' * 40);

      final emoji = _read(doc(type: 'other', label: '${'a' * 39}🎨🎨🎨'));
      expect(emoji.customTypeLabel, '${'a' * 39}🎨');
    });

    test('a stale label on a built-in type reads as no custom type', () {
      // An older client can change the type and leave the label behind.
      final read = _read(doc(type: 'bonds', label: 'Stamps'));
      expect(read.type, InvestmentType.bonds);
      expect(read.customTypeLabel, isNull);
      expect(read.customTypeId, isNull);
    });

    test('a built-in type is written without a custom type', () async {
      final written = await writtenByUpdate(
        _stamps(id: 'c1', label: 'Stamps').copyWith(type: InvestmentType.bonds),
      );
      expect(written.containsKey('customTypeId'), isTrue);
      expect(written.containsKey('customTypeLabel'), isTrue);
      expect(written['customTypeId'], isNull);
      expect(written['customTypeLabel'], isNull);
    });

    test('an Other investment is still written with both fields', () async {
      final written = await writtenByUpdate(_stamps(id: 'c1', label: 'Stamps'));
      expect(written['customTypeId'], 'c1');
      expect(written['customTypeLabel'], 'Stamps');
    });
  });

  group('archive and restore', () {
    late _RecordingBatch batch;
    late _MockCollection archived;
    late _MockDoc archivedDoc;
    late _MockCollection cashFlows;
    late _MockCollection archivedCashFlows;

    setUp(() {
      batch = _RecordingBatch();
      archived = _MockCollection();
      archivedDoc = _MockDoc();
      cashFlows = _MockCollection();
      archivedCashFlows = _MockCollection();
      when(() => firestore.batch()).thenReturn(batch);
      when(
        () => userDoc.collection('archivedInvestments'),
      ).thenReturn(archived);
      when(() => archived.doc('inv-stamps')).thenReturn(archivedDoc);
      when(() => userDoc.collection('cashflows')).thenReturn(cashFlows);
      when(
        () => userDoc.collection('archivedCashflows'),
      ).thenReturn(archivedCashFlows);
      final noFlows = _MockQuery();
      when(
        () => cashFlows.where('investmentId', isEqualTo: 'inv-stamps'),
      ).thenReturn(noFlows);
      when(
        () => archivedCashFlows.where('investmentId', isEqualTo: 'inv-stamps'),
      ).thenReturn(noFlows);
      when(
        () => noFlows.get(),
      ).thenAnswer((_) async => querySnapshot(fromCache: false));
    });

    Future<void> stubDoc(_MockDoc ref, Map<String, dynamic> data) async {
      final snapshot = _MockSnapshot();
      when(() => snapshot.exists).thenReturn(true);
      when(() => snapshot.data()).thenReturn({...data});
      when(() => ref.get()).thenAnswer((_) async => snapshot);
    }

    Map<String, dynamic> storedData() => {
      'name': 'Stamp album',
      'type': 'other',
      'status': 'OPEN',
      'createdAt': Timestamp.fromDate(DateTime.utc(2025, 1, 1)),
      'currency': 'INR',
      'customTypeId': 'c1',
      'customTypeLabel': 'Stamps',
    };

    test('archiving keeps the custom type on the moved document', () async {
      await stubDoc(doc, storedData());

      await repository.archiveInvestment('inv-stamps');

      final (target, data) = batch.sets.single;
      expect(target, same(archivedDoc));
      final moved = data as Map<String, dynamic>;
      expect(moved['customTypeId'], 'c1');
      expect(moved['customTypeLabel'], 'Stamps');
      expect(moved['isArchived'], isTrue);
    });

    test('restoring keeps the custom type on the moved document', () async {
      await stubDoc(archivedDoc, storedData());

      await repository.unarchiveInvestment('inv-stamps');

      final (target, data) = batch.sets.single;
      expect(target, same(doc));
      final moved = data as Map<String, dynamic>;
      expect(moved['customTypeId'], 'c1');
      expect(moved['customTypeLabel'], 'Stamps');
      expect(moved['isArchived'], isFalse);
    });
  });
}
