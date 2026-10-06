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
  FakeSnap(this._exists, {bool pendingWrites = false})
    : _metadata = FakeMetadata(pendingWrites);
  final bool _exists;
  final SnapshotMetadata _metadata;
  @override
  bool get exists => _exists;
  @override
  SnapshotMetadata get metadata => _metadata;
}

class FakeMetadata extends Fake implements SnapshotMetadata {
  FakeMetadata(this.hasPendingWrites);
  @override
  final bool hasPendingWrites;
}

void main() {
  late MockFirestore firestore;
  late MockCollection collection;
  late MockDoc doc;
  late DeletionRequestService service;

  setUpAll(() => registerFallbackValue(const GetOptions()));

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

  // A88: Firestore drops a deleted document from this device's view at once
  // and never flags it as a pending write, so a withdrawal that timed out is
  // only known to have reached the server once every queued write has.
  group('pendingWritesSent', () {
    test('true once the server has acknowledged every queued write', () async {
      when(() => firestore.waitForPendingWrites()).thenAnswer((_) async {});

      expect(await service.pendingWritesSent(), isTrue);
      verify(() => firestore.waitForPendingWrites()).called(1);
    });

    test('false instead of throwing when Firestore stops waiting', () async {
      when(
        () => firestore.waitForPendingWrites(),
      ).thenThrow(FirebaseException(plugin: 'firestore', code: 'cancelled'));

      expect(await service.pendingWritesSent(), isFalse);
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

  group('requestStatus', () {
    // Evaluated inside when() so mocktail records the matcher.
    GetOptions fromServer() => any(
      that: isA<GetOptions>().having((o) => o.source, 'source', Source.server),
    );

    test('confirmed only when the server has the doc with no pending local '
        'write', () async {
      when(() => doc.get(fromServer())).thenAnswer((_) async => FakeSnap(true));

      expect(await service.requestStatus(), DeletionRequestStatus.confirmed);
    });

    test('a write the server has not acknowledged yet is pending, not '
        'confirmed', () async {
      when(
        () => doc.get(fromServer()),
      ).thenAnswer((_) async => FakeSnap(true, pendingWrites: true));
      stubExists(true);

      expect(await service.requestStatus(), DeletionRequestStatus.pending);
    });

    test(
      'offline with the request only in the local cache is pending',
      () async {
        when(() => doc.get(fromServer())).thenThrow(
          FirebaseException(plugin: 'firestore', code: 'unavailable'),
        );
        stubExists(true);

        expect(await service.requestStatus(), DeletionRequestStatus.pending);
      },
    );

    test('a server read that never answers falls back to the cache', () async {
      when(
        () => doc.get(fromServer()),
      ).thenAnswer((_) => Completer<FakeSnap>().future);
      stubExists(false);

      expect(await service.requestStatus(), DeletionRequestStatus.none);
    });

    test('none when neither the server nor the cache has it', () async {
      when(
        () => doc.get(fromServer()),
      ).thenAnswer((_) async => FakeSnap(false));
      stubExists(false);

      expect(await service.requestStatus(), DeletionRequestStatus.none);
    });
  });
  // A88: the banner follows the request live, including whether the server
  // has seen it yet.
  group('watchStatus', () {
    test('maps each snapshot, including metadata-only changes, to none, '
        'pending or confirmed', () async {
      when(() => doc.snapshots(includeMetadataChanges: true)).thenAnswer(
        (_) => Stream.fromIterable([
          FakeSnap(false),
          FakeSnap(true, pendingWrites: true),
          FakeSnap(true),
          FakeSnap(false),
        ]),
      );

      expect(await service.watchStatus().toList(), [
        DeletionRequestStatus.none,
        DeletionRequestStatus.pending,
        DeletionRequestStatus.confirmed,
        DeletionRequestStatus.none,
      ]);
    });

    test('passes a listen error on instead of hiding it', () async {
      when(() => doc.snapshots(includeMetadataChanges: true)).thenAnswer(
        (_) => Stream.error(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        ),
      );

      await expectLater(
        service.watchStatus(),
        emitsError(isA<FirebaseException>()),
      );
    });
  });
}
