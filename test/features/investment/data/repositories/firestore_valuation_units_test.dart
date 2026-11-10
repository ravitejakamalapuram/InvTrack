// #946: quantity, unit and price per unit round-trip through the valuation
// document; a document whose unit data cannot be trusted keeps its amount and
// loses the unit data, never the other way round.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_valuation_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';

import '../../valuation/valuation_fixtures.dart';

void main() {
  const holding = UnitHolding(
    quantity: 12.5,
    unit: QuantityUnit.gram,
    unitPrice: 6543.25,
  );
  final snap = testSnapshot(
    'u1',
    amount: 1,
    date: DateTime(2026, 11, 3),
    kind: ValuationKind.marketValue,
  ).copyWith(holding: holding);

  Map<String, dynamic> stored() =>
      FirestoreValuationRepository.snapshotToFirestore(snap)
        ..['updatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 11, 4));

  InvestmentValuationSnapshot? read(Map<String, dynamic> d) =>
      FirestoreValuationRepository.snapshotFromFirestore(d, 'u1');

  test('quantity, unit and price per unit round-trip', () {
    final data = stored();
    expect(data['quantity'], 12.5);
    expect(data['unit'], 'gram');
    expect(data['unitPrice'], 6543.25);
    expect(data['amount'], 81790.63); // 12.5 x 6543.25 = 81790.625
    final back = read(data)!;
    expect(back.holding, holding);
    expect(back.amount, 81790.63);
  });

  test('an amount-only snapshot writes no unit keys', () {
    final data = FirestoreValuationRepository.snapshotToFirestore(
      testSnapshot('a', amount: 100, date: DateTime(2026, 1, 1)),
    );
    expect(data.containsKey('quantity'), isFalse);
    expect(data.containsKey('unit'), isFalse);
    expect(data.containsKey('unitPrice'), isFalse);
  });

  test('a legacy document without unit keys reads as amount-only', () {
    final data = stored()
      ..remove('quantity')
      ..remove('unit')
      ..remove('unitPrice');
    expect(read(data)!.holding, isNull);
    expect(read(data)!.amount, 81790.63);
  });

  test('partial, unknown or invalid unit data is dropped, amount kept', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (d) => d.remove('unitPrice'),
      (d) => d['unit'] = 'carat',
      (d) => d['quantity'] = -3,
      (d) => d['quantity'] = double.nan,
      (d) => d['unitPrice'] = 'x',
      // Amount no longer equals quantity x price: the amount is what was
      // saved and what totals use, so the weight claim is dropped.
      (d) => d['amount'] = 70000.0,
    ]) {
      final data = stored();
      mutate(data);
      final back = read(data);
      expect(back, isNotNull);
      expect(back!.holding, isNull);
      expect(back.amount, data['amount']);
    }
  });
}
