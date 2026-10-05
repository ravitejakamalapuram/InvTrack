// A22 (#764, INV-05): a cleared optional field must be removed from the
// stored investment document, not left out of the write. `update()` keeps
// any field missing from its map, so every optional field has to be written
// (as null when cleared), and the mapper has to read null back as null.
// The write is the same queued local write when offline.

// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

const _optionalKeys = [
  'notes',
  'maturityDate',
  'incomeFrequency',
  'startDate',
  'expectedRate',
  'tenureMonths',
  'platform',
  'interestPayoutMode',
  'autoRenewal',
  'riskLevel',
  'compoundingFrequency',
];

void main() {
  late _MockDoc activeDoc;
  late _MockDoc archivedDoc;
  late FirestoreInvestmentRepository repository;

  setUpAll(() => registerFallbackValue(<Object, Object?>{}));

  setUp(() {
    final firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    final investments = _MockCollection();
    final archived = _MockCollection();
    activeDoc = _MockDoc();
    archivedDoc = _MockDoc();

    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('uid-1')).thenReturn(userDoc);
    when(() => userDoc.collection('investments')).thenReturn(investments);
    when(() => userDoc.collection('archivedInvestments')).thenReturn(archived);
    when(() => investments.doc('inv-fd')).thenReturn(activeDoc);
    when(() => archived.doc('inv-fd')).thenReturn(archivedDoc);
    when(() => activeDoc.update(any())).thenAnswer((_) async {});
    when(() => archivedDoc.update(any())).thenAnswer((_) async {});

    repository = FirestoreInvestmentRepository(
      firestore: firestore,
      userId: 'uid-1',
      baseCurrency: () => 'INR',
    );
  });

  final cleared = InvestmentEntity(
    id: 'inv-fd',
    name: 'HDFC FD',
    type: InvestmentType.fixedDeposit,
    status: InvestmentStatus.open,
    createdAt: DateTime(2026, 4, 1),
    updatedAt: DateTime(2026, 10, 3),
    currency: 'INR',
  );

  void expectClearedWrite(Map<Object, Object?> written) {
    for (final key in _optionalKeys) {
      expect(written.containsKey(key), isTrue, reason: '$key must be written');
      expect(written[key], isNull, reason: '$key must be written as null');
    }

    // Read the written document back the way the app does after a restart.
    final readBack = FirestoreInvestmentRepository.investmentFromFirestore(
      {
        ...written.cast<String, dynamic>(),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 3)),
      },
      'inv-fd',
      baseCurrency: 'INR',
    );
    expect(readBack.notes, isNull);
    expect(readBack.maturityDate, isNull);
    expect(readBack.incomeFrequency, isNull);
    expect(readBack.startDate, isNull);
    expect(readBack.expectedRate, isNull);
    expect(readBack.tenureMonths, isNull);
    expect(readBack.platform, isNull);
    expect(readBack.interestPayoutMode, isNull);
    expect(readBack.autoRenewal, isNull);
    expect(readBack.riskLevel, isNull);
    expect(readBack.compoundingFrequency, isNull);
  }

  test('updateInvestment writes cleared optional fields as null', () async {
    await repository.updateInvestment(cleared);

    final written =
        verify(() => activeDoc.update(captureAny())).captured.single
            as Map<Object, Object?>;
    expectClearedWrite(written);
  });

  test(
    'updateArchivedInvestment writes cleared optional fields as null',
    () async {
      await repository.updateArchivedInvestment(cleared);

      final written =
          verify(() => archivedDoc.update(captureAny())).captured.single
              as Map<Object, Object?>;
      expectClearedWrite(written);
    },
  );

  test('a document without the optional fields reads them as null', () {
    final legacy = FirestoreInvestmentRepository.investmentFromFirestore(
      {
        'name': 'HDFC FD',
        'type': 'fixedDeposit',
        'status': 'OPEN',
        'createdAt': Timestamp.fromDate(DateTime(2026, 4, 1)),
        'currency': 'INR',
      },
      'inv-fd',
      baseCurrency: 'INR',
    );
    for (final value in [
      legacy.notes,
      legacy.maturityDate,
      legacy.incomeFrequency,
      legacy.startDate,
      legacy.expectedRate,
      legacy.tenureMonths,
      legacy.platform,
      legacy.interestPayoutMode,
      legacy.autoRenewal,
      legacy.riskLevel,
      legacy.compoundingFrequency,
    ]) {
      expect(value, isNull);
    }
  });
}
