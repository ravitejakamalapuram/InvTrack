// Unit tests for FirestoreDocumentRepository.deleteAllDocuments.
//
// Regression coverage: account deletion must remove ALL document metadata
// for a user, not just documents scoped to a single investment. Before this
// fix, nothing in the app ever called a "delete everything" method for the
// documents collection, so document metadata survived account deletion.

// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_document_repository.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockDocumentsCollection;
  late MockWriteBatch mockBatch;
  late FirestoreDocumentRepository repository;

  const testUserId = 'test-user-123';

  setUpAll(() {
    registerFallbackValue(MockDocumentReference());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockDocumentsCollection = MockCollectionReference();
    mockBatch = MockWriteBatch();

    final mockUsersCollection = MockCollectionReference();
    final mockUserDoc = MockDocumentReference();

    when(() => mockFirestore.collection('users'))
        .thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc(testUserId)).thenReturn(mockUserDoc);
    when(() => mockUserDoc.collection('documents'))
        .thenReturn(mockDocumentsCollection);

    when(() => mockFirestore.batch()).thenReturn(mockBatch);
    when(() => mockBatch.delete(any())).thenReturn(null);
    when(() => mockBatch.commit()).thenAnswer((_) async {});

    repository = FirestoreDocumentRepository(
      firestore: mockFirestore,
      userId: testUserId,
    );
  });

  group('deleteAllDocuments', () {
    test('deletes every document regardless of which investment it belongs to', () async {
      final mockSnapshot = MockQuerySnapshot();
      final doc1 = MockQueryDocumentSnapshot();
      final doc2 = MockQueryDocumentSnapshot();
      final ref1 = MockDocumentReference();
      final ref2 = MockDocumentReference();

      when(() => mockDocumentsCollection.get())
          .thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([doc1, doc2]);
      when(() => doc1.reference).thenReturn(ref1);
      when(() => doc2.reference).thenReturn(ref2);

      await repository.deleteAllDocuments();

      verify(() => mockBatch.delete(ref1)).called(1);
      verify(() => mockBatch.delete(ref2)).called(1);
      verify(() => mockBatch.commit()).called(1);
    });

    test('does nothing when there are no documents', () async {
      final mockSnapshot = MockQuerySnapshot();

      when(() => mockDocumentsCollection.get())
          .thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([]);

      await repository.deleteAllDocuments();

      verifyNever(() => mockBatch.commit());
    });
  });
}
