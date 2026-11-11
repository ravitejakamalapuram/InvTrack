// Weight on a cash flow (#946): the optional quantity and unit of a gold
// purchase or sale survive a write and a read, a document without them still
// reads, and an unusable pair is dropped rather than guessed at.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';

CashFlowEntity _flow({double? quantity, QuantityUnit? unit}) => CashFlowEntity(
  id: 'cf1',
  investmentId: 'gold',
  date: DateTime(2026, 11, 3),
  type: CashFlowType.invest,
  amount: 64500,
  createdAt: DateTime.utc(2026, 11, 3),
  currency: 'INR',
  quantity: quantity,
  quantityUnit: unit,
);

Map<String, dynamic> _doc({Object? quantity, Object? unit}) => {
  'investmentId': 'gold',
  'date': Timestamp.fromDate(DateTime.utc(2026, 11, 3)),
  'type': 'INVEST',
  'amount': 64500,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 3)),
  'currency': 'INR',
  'quantity': ?quantity,
  'quantityUnit': ?unit,
};

CashFlowEntity _read(Map<String, dynamic> data) =>
    FirestoreInvestmentRepository.cashFlowFromFirestore(
      data,
      'cf1',
      baseCurrency: 'INR',
    );

void main() {
  group('CashFlowEntity weight', () {
    test('a flow without a weight has none and no grams', () {
      final flow = _flow();
      expect(flow.quantity, isNull);
      expect(flow.quantityUnit, isNull);
      expect(flow.grams, isNull);
    });

    test('grams follow the unit', () {
      expect(_flow(quantity: 10, unit: QuantityUnit.gram).grams, 10);
      expect(_flow(quantity: 2, unit: QuantityUnit.kilogram).grams, 2000);
      expect(_flow(quantity: 1, unit: QuantityUnit.sovereign).grams, 8);
    });

    test('copyWith keeps the weight and can change it', () {
      final flow = _flow(quantity: 10, unit: QuantityUnit.gram);
      expect(flow.copyWith(notes: 'x').quantity, 10);
      expect(flow.copyWith(quantity: 12).quantity, 12);
    });

    test('copyWith(clearWeight: true) removes the weight as a pair', () {
      final cleared = _flow(
        quantity: 10,
        unit: QuantityUnit.gram,
      ).copyWith(clearWeight: true);
      expect(cleared.quantity, isNull);
      expect(cleared.quantityUnit, isNull);
    });

    test('the weight takes part in equality', () {
      expect(
        _flow(quantity: 10, unit: QuantityUnit.gram),
        isNot(_flow(quantity: 11, unit: QuantityUnit.gram)),
      );
      expect(
        _flow(quantity: 10, unit: QuantityUnit.gram),
        _flow(quantity: 10, unit: QuantityUnit.gram),
      );
    });
  });

  group('cash flow weight in Firestore', () {
    test('a weight is written as quantity and unit name', () {
      final map = FirestoreInvestmentRepository.cashFlowToFirestore(
        _flow(quantity: 10, unit: QuantityUnit.tola),
      );
      expect(map['quantity'], 10);
      expect(map['quantityUnit'], 'tola');
    });

    test('a flow without a weight writes null, so an update clears it', () {
      final map = FirestoreInvestmentRepository.cashFlowToFirestore(_flow());
      expect(map.containsKey('quantity'), isTrue);
      expect(map['quantity'], isNull);
      expect(map.containsKey('quantityUnit'), isTrue);
      expect(map['quantityUnit'], isNull);
    });

    test('a written weight reads back', () {
      final back = _read(_doc(quantity: 10.5, unit: 'gram'));
      expect(back.quantity, 10.5);
      expect(back.quantityUnit, QuantityUnit.gram);
    });

    test('a document from before weights reads without one', () {
      final back = _read(_doc());
      expect(back.quantity, isNull);
      expect(back.quantityUnit, isNull);
    });

    test(
      'an unknown unit, a missing unit or a bad quantity drops the weight',
      () {
        for (final bad in <Map<String, dynamic>>[
          _doc(quantity: 10, unit: 'carat'),
          _doc(quantity: 10),
          _doc(unit: 'gram'),
          _doc(quantity: 0, unit: 'gram'),
          _doc(quantity: -3, unit: 'gram'),
          _doc(quantity: double.nan, unit: 'gram'),
          _doc(quantity: '10', unit: 'gram'),
        ]) {
          final back = _read(bad);
          expect(back.quantity, isNull, reason: '$bad');
          expect(back.quantityUnit, isNull, reason: '$bad');
          expect(back.amount, 64500, reason: 'the money is untouched');
        }
      },
    );
  });
}
