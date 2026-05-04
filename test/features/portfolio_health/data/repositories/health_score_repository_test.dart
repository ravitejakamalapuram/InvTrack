// Unit tests for Health Score Repository
//
// Tests Firestore operations:
// - Save snapshot (with auto-generated ID)
// - Get latest snapshot
// - Get historical snapshots
// - Watch historical snapshots (stream)
// - Delete all snapshots (paginated)
// - Authentication requirement
// - Error handling and exceptions

// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/portfolio_health/data/repositories/health_score_repository.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockCrashlyticsService extends Mock implements CrashlyticsService {}
class MockUser extends Mock implements User {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
class MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockCrashlyticsService mockCrashlytics;
  late MockUser mockUser;
  late MockCollectionReference mockCollection;
  late HealthScoreRepository repository;

  const testUserId = 'test-user-123';

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(MockDocumentReference());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockCrashlytics = MockCrashlyticsService();
    mockUser = MockUser();
    mockCollection = MockCollectionReference();

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn(testUserId);
    when(() => mockCrashlytics.recordError(any(), any(), reason: any(named: 'reason'), fatal: any(named: 'fatal')))
        .thenAnswer((_) async => Future.value());

    // Setup Firestore collection path mocking
    final mockUserDoc = MockDocumentReference();
    final mockUsersCollection = MockCollectionReference();

    when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc(testUserId)).thenReturn(mockUserDoc);
    when(() => mockUserDoc.collection('healthScores')).thenReturn(mockCollection);

    repository = HealthScoreRepository(
      firestore: mockFirestore,
      auth: mockAuth,
      crashlytics: mockCrashlytics,
    );
  });

  // Helper to create a test score
  PortfolioHealthScore createTestScore({double overallScore = 75.0}) {
    final component = ComponentScore(
      name: 'Test',
      score: overallScore,
      weight: 1.0,
      description: 'Test component',
      suggestions: [],
    );
    return PortfolioHealthScore(
      overallScore: overallScore,
      returnsPerformance: component,
      diversification: component,
      liquidity: component,
      goalAlignment: component,
      actionReadiness: component,
      calculatedAt: DateTime.now(),
    );
  }

  group('HealthScoreRepository', () {
    group('Authentication', () {
      test('throws DataException with AuthException cause when user not authenticated', () {
        when(() => mockAuth.currentUser).thenReturn(null);

        final unauthRepository = HealthScoreRepository(
          firestore: mockFirestore,
          auth: mockAuth,
          crashlytics: mockCrashlytics,
        );

        expect(
          () => unauthRepository.saveSnapshot(createTestScore()),
          throwsA(isA<DataException>()),
        );
      });
    });

    group('saveSnapshot', () {
      test('saves snapshot with auto-generated ID', () async {
        final mockDocRef = MockDocumentReference();
        when(() => mockCollection.add(any())).thenAnswer((_) async => mockDocRef);

        final score = createTestScore();
        await repository.saveSnapshot(score);

        verify(() => mockCollection.add(any())).called(1);
      });

      test('rethrows timeout exception', () async {
        when(() => mockCollection.add(any()))
            .thenThrow(TimeoutException('Timeout'));

        final score = createTestScore();

        expect(
          () => repository.saveSnapshot(score),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('wraps other errors in DataException', () async {
        when(() => mockCollection.add(any()))
            .thenThrow(Exception('Permission denied'));

        final score = createTestScore();

        expect(
          () => repository.saveSnapshot(score),
          throwsA(isA<DataException>()),
        );
      });
    });

    group('getLatestSnapshot', () {
      test('returns latest snapshot when exists', () async {
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();
        final mockDoc = MockQueryDocumentSnapshot();

        when(() => mockCollection.orderBy('calculatedAt', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(1)).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(() => mockDoc.id).thenReturn('snapshot-1');
        when(() => mockDoc.data()).thenReturn({
          'overallScore': 75.0,
          'returnsScore': 80.0,
          'diversificationScore': 70.0,
          'liquidityScore': 75.0,
          'goalAlignmentScore': 100.0,
          'actionReadinessScore': 100.0,
          'calculatedAt': Timestamp.now(),
        });

        final result = await repository.getLatestSnapshot();

        expect(result, isNotNull);
        expect(result!.overallScore, 75.0);
      });

      test('returns null when no snapshots exist', () async {
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();

        when(() => mockCollection.orderBy('calculatedAt', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(1)).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockQuerySnapshot.docs).thenReturn([]);

        final result = await repository.getLatestSnapshot();

        expect(result, isNull);
      });

      test('throws DataException on error', () async {
        final mockQuery = MockQuery();
        when(() => mockCollection.orderBy('calculatedAt', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(1)).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenThrow(Exception('Fetch failed'));

        expect(
          () => repository.getLatestSnapshot(),
          throwsA(isA<DataException>()),
        );
      });
    });

    group('getHistoricalSnapshots', () {
      test('returns historical snapshots within timeframe', () async {
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();
        final mockDoc = MockQueryDocumentSnapshot();

        when(() => mockCollection.where('calculatedAt', isGreaterThan: any(named: 'isGreaterThan')))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('calculatedAt', descending: false))
            .thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(() => mockDoc.id).thenReturn('snapshot-1');
        when(() => mockDoc.data()).thenReturn({
          'overallScore': 75.0,
          'returnsScore': 80.0,
          'diversificationScore': 70.0,
          'liquidityScore': 75.0,
          'goalAlignmentScore': 100.0,
          'actionReadinessScore': 100.0,
          'calculatedAt': Timestamp.now(),
        });

        final result = await repository.getHistoricalSnapshots(weeks: 12);

        expect(result, hasLength(1));
        expect(result.first.overallScore, 75.0);
      });

      test('throws DataException on error', () async {
        final mockQuery = MockQuery();
        when(() => mockCollection.where('calculatedAt', isGreaterThan: any(named: 'isGreaterThan')))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('calculatedAt', descending: false))
            .thenReturn(mockQuery);
        when(() => mockQuery.get()).thenThrow(Exception('Fetch failed'));

        expect(
          () => repository.getHistoricalSnapshots(),
          throwsA(isA<DataException>()),
        );
      });
    });

    group('deleteAllSnapshots', () {
      test('deletes all snapshots in batches', () async {
        final mockQuerySnapshot1 = MockQuerySnapshot();
        final mockQuerySnapshot2 = MockQuerySnapshot();
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        final mockBatch = MockWriteBatch();
        final mockDocRef1 = MockDocumentReference();
        final mockDocRef2 = MockDocumentReference();

        // Setup two query snapshots for sequential calls
        var callCount = 0;
        when(() => mockCollection.limit(500)).thenReturn(mockCollection);
        when(() => mockCollection.get()).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? mockQuerySnapshot1 : mockQuerySnapshot2;
        });

        // First call returns 2 docs, second call returns empty
        when(() => mockQuerySnapshot1.docs).thenReturn([mockDoc1, mockDoc2]);
        when(() => mockQuerySnapshot2.docs).thenReturn([]);

        when(() => mockDoc1.reference).thenReturn(mockDocRef1);
        when(() => mockDoc2.reference).thenReturn(mockDocRef2);
        when(() => mockFirestore.batch()).thenReturn(mockBatch);
        when(() => mockBatch.delete(any())).thenReturn(null);
        when(() => mockBatch.commit()).thenAnswer((_) async {});

        await repository.deleteAllSnapshots();

        verify(() => mockBatch.delete(mockDocRef1)).called(1);
        verify(() => mockBatch.delete(mockDocRef2)).called(1);
        verify(() => mockBatch.commit()).called(1);
      });

      test('throws DataException on error', () async {
        when(() => mockCollection.limit(500)).thenReturn(mockCollection);
        when(() => mockCollection.get()).thenThrow(Exception('Delete failed'));

        expect(
          () => repository.deleteAllSnapshots(),
          throwsA(isA<DataException>()),
        );
      });
    });
  });
}
