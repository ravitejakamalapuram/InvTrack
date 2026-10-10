// Unit tests for FirestoreInvestmentRepository account-deletion correctness.
//
// Regression coverage for the account-deletion bug described in
// docs/privacy findings: deleteInvestment / deleteArchivedInvestment must
// never silently delete the investment document while leaving its cash
// flows behind. If we cannot reliably determine which cash flows belong to
// an investment (e.g. offline with an unusable cache), the whole operation
// must fail loudly instead of "succeeding" with orphaned data.

// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockInvestmentsCollection;
  late MockCollectionReference mockCashFlowsCollection;
  late MockCollectionReference mockArchivedInvestmentsCollection;
  late MockCollectionReference mockArchivedCashFlowsCollection;
  late MockDocumentReference mockInvestmentDoc;
  late MockDocumentReference mockArchivedInvestmentDoc;
  late MockWriteBatch mockBatch;
  late FirestoreInvestmentRepository repository;

  const testUserId = 'test-user-123';
  const testInvestmentId = 'inv-1';

  setUpAll(() {
    registerFallbackValue(MockDocumentReference());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockInvestmentsCollection = MockCollectionReference();
    mockCashFlowsCollection = MockCollectionReference();
    mockArchivedInvestmentsCollection = MockCollectionReference();
    mockArchivedCashFlowsCollection = MockCollectionReference();
    mockInvestmentDoc = MockDocumentReference();
    mockArchivedInvestmentDoc = MockDocumentReference();
    mockBatch = MockWriteBatch();

    final mockUsersCollection = MockCollectionReference();
    final mockUserDoc = MockDocumentReference();

    when(() => mockFirestore.collection('users'))
        .thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc(testUserId)).thenReturn(mockUserDoc);
    when(() => mockUserDoc.collection('investments'))
        .thenReturn(mockInvestmentsCollection);
    when(() => mockUserDoc.collection('cashflows'))
        .thenReturn(mockCashFlowsCollection);
    when(() => mockUserDoc.collection('archivedInvestments'))
        .thenReturn(mockArchivedInvestmentsCollection);
    when(() => mockUserDoc.collection('archivedCashflows'))
        .thenReturn(mockArchivedCashFlowsCollection);
    // Deleting an investment also lists its valuation snapshots (#941);
    // this investment has none.
    final mockValuationsCollection = MockCollectionReference();
    final noSnapshotsQuery = MockQuery();
    final noSnapshots = MockQuerySnapshot();
    when(
      () => mockUserDoc.collection('valuations'),
    ).thenReturn(mockValuationsCollection);
    when(
      () => mockValuationsCollection.where(
        'investmentId',
        isEqualTo: testInvestmentId,
      ),
    ).thenReturn(noSnapshotsQuery);
    when(
      () => noSnapshotsQuery.get(const GetOptions(source: Source.cache)),
    ).thenAnswer((_) async => noSnapshots);
    when(
      () => noSnapshotsQuery.get(const GetOptions(source: Source.server)),
    ).thenAnswer((_) async => noSnapshots);
    when(() => noSnapshots.docs).thenReturn([]);
    // It also lists the investment's expected payments (#917); none here.
    final mockExpectedCollection = MockCollectionReference();
    when(
      () => mockUserDoc.collection('expectedCashFlows'),
    ).thenReturn(mockExpectedCollection);
    when(
      () => mockExpectedCollection.where(
        'investmentId',
        isEqualTo: testInvestmentId,
      ),
    ).thenReturn(noSnapshotsQuery);

    when(() => mockInvestmentsCollection.doc(testInvestmentId))
        .thenReturn(mockInvestmentDoc);
    when(() => mockArchivedInvestmentsCollection.doc(testInvestmentId))
        .thenReturn(mockArchivedInvestmentDoc);

    when(() => mockFirestore.batch()).thenReturn(mockBatch);
    when(() => mockBatch.delete(any())).thenReturn(null);
    when(() => mockBatch.commit()).thenAnswer((_) async {});

    repository = FirestoreInvestmentRepository(
      firestore: mockFirestore,
      userId: testUserId,
      baseCurrency: () => 'INR',
    );
  });

  group('deleteInvestment', () {
    test('deletes the investment and every cash flow found in the cache', () async {
      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      final cfDoc1 = MockQueryDocumentSnapshot();
      final cfDoc2 = MockQueryDocumentSnapshot();
      final cfRef1 = MockDocumentReference();
      final cfRef2 = MockDocumentReference();

      when(() => mockCashFlowsCollection.where(
            'investmentId',
            isEqualTo: testInvestmentId,
          )).thenReturn(mockQuery);
      when(() => mockQuery.get(const GetOptions(source: Source.cache)))
          .thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([cfDoc1, cfDoc2]);
      when(() => cfDoc1.reference).thenReturn(cfRef1);
      when(() => cfDoc2.reference).thenReturn(cfRef2);

      await repository.deleteInvestment(testInvestmentId);

      verify(() => mockBatch.delete(cfRef1)).called(1);
      verify(() => mockBatch.delete(cfRef2)).called(1);
      verify(() => mockBatch.delete(mockInvestmentDoc)).called(1);
      verify(() => mockBatch.commit()).called(1);
    });

    test(
        'throws instead of deleting the investment when cash flows cannot '
        'be determined (cache unusable, server unreachable)', () async {
      final mockQuery = MockQuery();

      when(() => mockCashFlowsCollection.where(
            'investmentId',
            isEqualTo: testInvestmentId,
          )).thenReturn(mockQuery);
      // Cache lookup fails outright.
      when(() => mockQuery.get(const GetOptions(source: Source.cache)))
          .thenThrow(Exception('cache unavailable'));
      // Server fallback can't complete either (offline).
      when(() => mockQuery.get()).thenThrow(TimeoutException('offline'));

      await expectLater(
        () => repository.deleteInvestment(testInvestmentId),
        throwsA(isA<NetworkException>()),
      );

      // Nothing should have been deleted - a partial delete would silently
      // orphan the cash flows forever.
      verifyNever(() => mockBatch.delete(any()));
      verifyNever(() => mockBatch.commit());
    });

    test('falls back to a server query when the cache lookup fails', () async {
      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      final cfDoc = MockQueryDocumentSnapshot();
      final cfRef = MockDocumentReference();

      when(() => mockCashFlowsCollection.where(
            'investmentId',
            isEqualTo: testInvestmentId,
          )).thenReturn(mockQuery);
      when(() => mockQuery.get(const GetOptions(source: Source.cache)))
          .thenThrow(Exception('cache unavailable'));
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([cfDoc]);
      when(() => cfDoc.reference).thenReturn(cfRef);

      await repository.deleteInvestment(testInvestmentId);

      verify(() => mockBatch.delete(cfRef)).called(1);
      verify(() => mockBatch.delete(mockInvestmentDoc)).called(1);
      verify(() => mockBatch.commit()).called(1);
    });
  });

  group('deleteArchivedInvestment', () {
    test('deletes the archived investment and its archived cash flows', () async {
      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      final cfDoc = MockQueryDocumentSnapshot();
      final cfRef = MockDocumentReference();

      when(() => mockArchivedCashFlowsCollection.where(
            'investmentId',
            isEqualTo: testInvestmentId,
          )).thenReturn(mockQuery);
      when(() => mockQuery.get(const GetOptions(source: Source.cache)))
          .thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([cfDoc]);
      when(() => cfDoc.reference).thenReturn(cfRef);

      await repository.deleteArchivedInvestment(testInvestmentId);

      verify(() => mockBatch.delete(cfRef)).called(1);
      verify(() => mockBatch.delete(mockArchivedInvestmentDoc)).called(1);
      verify(() => mockBatch.commit()).called(1);
    });

    test(
        'throws instead of deleting the archived investment when its cash '
        'flows cannot be determined', () async {
      final mockQuery = MockQuery();

      when(() => mockArchivedCashFlowsCollection.where(
            'investmentId',
            isEqualTo: testInvestmentId,
          )).thenReturn(mockQuery);
      when(() => mockQuery.get(const GetOptions(source: Source.cache)))
          .thenThrow(Exception('cache unavailable'));
      when(() => mockQuery.get()).thenThrow(TimeoutException('offline'));

      await expectLater(
        () => repository.deleteArchivedInvestment(testInvestmentId),
        throwsA(isA<NetworkException>()),
      );

      verifyNever(() => mockBatch.delete(any()));
      verifyNever(() => mockBatch.commit());
    });
  });
}
