// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/app_update/data/services/version_check_service.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late VersionCheckService service;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocRef;
  late MockDocumentSnapshot mockDocSnap;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockDocSnap = MockDocumentSnapshot();

    // Setup default mocking chain
    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);

    service = VersionCheckService(mockFirestore);
  });

  group('VersionCheckService', () {
    test(
      'fetchLatestVersion returns null when document does not exist',
      () async {
        // Arrange
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(false);

        // Act
        final result = await service.fetchLatestVersion();

        // Assert
        expect(result, isNull);
        verify(() => mockFirestore.collection('app_config')).called(1);
        verify(() => mockCollection.doc('version_info')).called(1);
      },
    );

    test('fetchLatestVersion returns null when data is null', () async {
      // Arrange
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnap);
      when(() => mockDocSnap.exists).thenReturn(true);
      when(() => mockDocSnap.data()).thenReturn(null);

      // Act
      final result = await service.fetchLatestVersion();

      // Assert
      expect(result, isNull);
    });

    test('fetchLatestVersion returns null on exception', () async {
      // Arrange
      when(() => mockDocRef.get()).thenThrow(Exception('Firestore error'));

      // Act
      final result = await service.fetchLatestVersion();

      // Assert
      expect(result, isNull);
    });
  });
}
