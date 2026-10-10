// #941 (AC11): a flow built only for a calculation (the terminal value, the
// tracking-period start) is never stored. Its id says what it is, so the
// repositories refuse it, whatever code asks them to write it.
//
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_valuation_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../valuation/valuation_fixtures.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  late _MockFirestore firestore;
  late FirestoreInvestmentRepository investments;
  late FirestoreValuationRepository valuations;

  setUp(() {
    firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(any())).thenReturn(userDoc);
    investments = FirestoreInvestmentRepository(
      firestore: firestore,
      userId: 'u',
      baseCurrency: () => 'INR',
    );
    valuations = FirestoreValuationRepository(
      firestore: firestore,
      userId: 'u',
    );
  });

  CashFlowEntity flow(String id) => CashFlowEntity(
    id: id,
    investmentId: 'i1',
    date: DateTime(2026, 1, 1),
    type: CashFlowType.returnFlow,
    amount: 1,
    createdAt: DateTime(2026, 1, 1),
    currency: 'INR',
  );

  for (final id in ['current-value:i1', 'tracking-start:i1']) {
    test('a cash flow with the id "$id" is refused', () async {
      await expectLater(
        () => investments.addCashFlow(flow(id)),
        throwsArgumentError,
      );
      await expectLater(
        () => investments.updateCashFlow(flow(id)),
        throwsArgumentError,
      );
      await expectLater(
        () => investments.bulkImport(
          investments: const [],
          cashFlows: [flow(id)],
        ),
        throwsArgumentError,
      );
    });

    test('a snapshot with the id "$id" is refused', () async {
      final snapshot = testSnapshot(id, amount: 1, date: DateTime(2026, 1, 1));
      await expectLater(
        () => valuations.save(
          snapshot,
          mirror: const CompatMirror(investmentId: 'i1'),
        ),
        throwsArgumentError,
      );
      await expectLater(
        () => valuations.importAll([snapshot]),
        throwsArgumentError,
      );
    });
  }
}
