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
    group('Two-Track Document Selection', () {
      test('fetches production document when isBetaUser is false', () async {
        // Arrange
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(() => mockDocSnap.data()).thenReturn({
          'latestVersion': '1.0.0',
          'latestBuildNumber': 100,
          'minimumVersion': '0.9.0',
          'minimumBuildNumber': 90,
          'forceUpdate': false,
          'updateMessage': 'Update available',
          'whatsNew': '- Bug fixes',
          'downloadUrl': 'https://play.google.com/store/apps',
        });

        // Act
        final result = await service.fetchLatestVersion(isBetaUser: false);

        // Assert
        expect(result, isNotNull);
        expect(result!.latestVersion, '1.0.0');
        verify(() => mockCollection.doc('version_info')).called(1);
      });

      test('fetches beta document when isBetaUser is true', () async {
        // Arrange
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(() => mockDocSnap.data()).thenReturn({
          'latestVersion': '1.1.0-beta.1',
          'latestBuildNumber': 110,
          'minimumVersion': '1.0.0',
          'minimumBuildNumber': 100,
          'forceUpdate': false,
          'updateMessage': 'Beta update available',
          'whatsNew': '- Beta features',
          'downloadUrl': 'https://play.google.com/store/apps',
        });

        // Act
        final result = await service.fetchLatestVersion(isBetaUser: true);

        // Assert
        expect(result, isNotNull);
        expect(result!.latestVersion, '1.1.0-beta.1');
        verify(() => mockCollection.doc('version_info_beta')).called(1);
      });
    });

    group('Error Handling', () {
      test('returns null when document does not exist', () async {
        // Arrange
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(false);

        // Act
        final result = await service.fetchLatestVersion(isBetaUser: false);

        // Assert
        expect(result, isNull);
        verify(() => mockFirestore.collection('app_config')).called(1);
        verify(() => mockCollection.doc('version_info')).called(1);
      });

      test('returns null when data is null', () async {
        // Arrange
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(() => mockDocSnap.data()).thenReturn(null);

        // Act
        final result = await service.fetchLatestVersion(isBetaUser: false);

        // Assert
        expect(result, isNull);
      });

      test('returns null on exception', () async {
        // Arrange
        when(() => mockDocRef.get()).thenThrow(Exception('Firestore error'));

        // Act
        final result = await service.fetchLatestVersion(isBetaUser: false);

        // Assert
        expect(result, isNull);
      });
    });

    group('Data Parsing', () {
      test('parses all required fields correctly', () async {
        // Arrange
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnap);
        when(() => mockDocSnap.exists).thenReturn(true);
        when(() => mockDocSnap.data()).thenReturn({
          'latestVersion': '2.5.7',
          'latestBuildNumber': 257,
          'minimumVersion': '2.0.0',
          'minimumBuildNumber': 200,
          'forceUpdate': true,
          'updateMessage': 'Critical security update',
          'whatsNew': '- Security patch\n- Performance improvements',
          'downloadUrl': 'https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker',
        });

        // Act
        final result = await service.fetchLatestVersion(isBetaUser: false);

        // Assert
        expect(result, isNotNull);
        expect(result!.latestVersion, '2.5.7');
        expect(result.latestBuildNumber, 257);
        expect(result.minimumVersion, '2.0.0');
        expect(result.minimumBuildNumber, 200);
        expect(result.forceUpdate, isTrue);
        expect(result.updateMessage, 'Critical security update');
        expect(result.whatsNew, '- Security patch\n- Performance improvements');
        expect(result.downloadUrl, 'https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker');
      });
    });
  });
}
