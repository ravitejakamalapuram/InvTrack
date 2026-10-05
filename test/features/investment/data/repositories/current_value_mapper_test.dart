// A10 (#754): the user's current value is stored on the investment document,
// date-only, and survives a write and a read. Clearing it must write null,
// because `update()` keeps fields missing from its map.

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

void main() {
  late _MockDoc doc;
  late FirestoreInvestmentRepository repository;

  setUpAll(() => registerFallbackValue(<Object, Object?>{}));

  setUp(() {
    final firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    final investments = _MockCollection();
    doc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('uid-1')).thenReturn(userDoc);
    when(() => userDoc.collection('investments')).thenReturn(investments);
    when(() => investments.doc('inv-gold')).thenReturn(doc);
    when(() => doc.update(any())).thenAnswer((_) async {});
    repository = FirestoreInvestmentRepository(
      firestore: firestore,
      userId: 'uid-1',
      baseCurrency: () => 'INR',
    );
  });

  InvestmentEntity gold({double? value, DateTime? date}) => InvestmentEntity(
    id: 'inv-gold',
    name: 'SGB 2031',
    type: InvestmentType.gold,
    status: InvestmentStatus.open,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2026, 10, 2),
    currency: 'INR',
    currentValue: value,
    currentValueDate: date,
  );

  Future<InvestmentEntity> writeAndReadBack(InvestmentEntity investment) async {
    await repository.updateInvestment(investment);
    final written =
        verify(() => doc.update(captureAny())).captured.single
            as Map<Object, Object?>;
    return FirestoreInvestmentRepository.investmentFromFirestore(
      {
        ...written.cast<String, dynamic>(),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 2)),
      },
      'inv-gold',
      baseCurrency: 'INR',
    );
  }

  test('current value and its date round-trip through Firestore', () async {
    final readBack = await writeAndReadBack(
      gold(value: 125000.55, date: DateTime(2026, 10, 1)),
    );
    expect(readBack.currentValue, 125000.55);
    expect(readBack.currentValueDate, DateTime(2026, 10, 1));
  });

  test('a cleared current value is written as null', () async {
    await repository.updateInvestment(gold());
    final written =
        verify(() => doc.update(captureAny())).captured.single
            as Map<Object, Object?>;
    expect(written.containsKey('currentValue'), isTrue);
    expect(written['currentValue'], isNull);
    expect(written.containsKey('currentValueDate'), isTrue);
    expect(written['currentValueDate'], isNull);
  });

  test('an integer value stored by another client reads as a double', () {
    final readBack = FirestoreInvestmentRepository.investmentFromFirestore(
      {
        'name': 'SGB 2031',
        'type': 'gold',
        'status': 'OPEN',
        'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        'currency': 'INR',
        'currentValue': 125000,
        'currentValueDate': Timestamp.fromDate(DateTime(2026, 10, 1)),
      },
      'inv-gold',
      baseCurrency: 'INR',
    );
    expect(readBack.currentValue, 125000.0);
    expect(readBack.currentValueDate, DateTime(2026, 10, 1));
  });

  test('a value without a date is ignored instead of guessed', () {
    final readBack = FirestoreInvestmentRepository.investmentFromFirestore(
      {
        'name': 'SGB 2031',
        'type': 'gold',
        'status': 'OPEN',
        'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        'currency': 'INR',
        'currentValue': 125000,
      },
      'inv-gold',
      baseCurrency: 'INR',
    );
    expect(readBack.currentValue, isNull);
    expect(readBack.currentValueDate, isNull);
  });
}
