// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {}

class FakeSnap extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  FakeSnap(this._exists);
  final bool _exists;
  @override
  bool get exists => _exists;
}

void main() {
  late MockFirestore firestore;
  late MockCollection collection;
  late MockDoc doc;
  late DeletionRequestService service;

  setUp(() {
    firestore = MockFirestore();
    collection = MockCollection();
    doc = MockDoc();
    when(() => firestore.collection('deletionRequests')).thenReturn(collection);
    when(() => collection.doc('uid-1')).thenReturn(doc);
    service = DeletionRequestService(
      firestore: firestore,
      userId: 'uid-1',
      timeout: const Duration(milliseconds: 50),
    );
  });

  void stubExists(bool exists) =>
      when(() => doc.get()).thenAnswer((_) async => FakeSnap(exists));

  group('requestDeletion', () {
    test('files an app request with server timestamp and version 1', () async {
      stubExists(false);
      when(() => doc.set(any())).thenAnswer((_) async {});

      expect(await service.requestDeletion(), isTrue);

      final data =
          verify(() => doc.set(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(data.keys.toSet(), {'requestedAt', 'source', 'version'});
      expect(data['source'], 'app');
      expect(data['version'], 1);
      expect(data['requestedAt'], isA<FieldValue>());
    });

    test('leaves an existing (e.g. web) request alone', () async {
      stubExists(true);

      expect(await service.requestDeletion(), isFalse);
      verifyNever(() => doc.set(any()));
    });

    test('never throws when the write is denied', () async {
      stubExists(false);
      when(() => doc.set(any())).thenThrow(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      );

      expect(await service.requestDeletion(), isFalse);
    });

    test('never hangs when offline', () async {
      stubExists(false);
      when(() => doc.set(any())).thenAnswer((_) => Completer<void>().future);

      expect(await service.requestDeletion(), isFalse);
    });
  });

  group('withdraw', () {
    test('deletes the request doc', () async {
      when(() => doc.delete()).thenAnswer((_) async {});

      expect(await service.withdraw(), isTrue);
      verify(() => doc.delete()).called(1);
    });

    test('returns false instead of throwing on failure', () async {
      when(
        () => doc.delete(),
      ).thenThrow(FirebaseException(plugin: 'firestore', code: 'unavailable'));

      expect(await service.withdraw(), isFalse);
    });
  });

  group('hasRequest', () {
    test('true when the doc exists', () async {
      stubExists(true);
      expect(await service.hasRequest(), isTrue);
    });

    test('false when absent', () async {
      stubExists(false);
      expect(await service.hasRequest(), isFalse);
    });

    test('false (fails soft) when unreadable', () async {
      when(
        () => doc.get(),
      ).thenThrow(FirebaseException(plugin: 'firestore', code: 'unavailable'));
      expect(await service.hasRequest(), isFalse);
    });
  });
}
