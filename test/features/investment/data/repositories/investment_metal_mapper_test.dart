// The metal of an investment (#946) in Firestore: written for precious metals
// only, read back, and absent from documents saved before the choice.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal.dart';

InvestmentEntity _inv({
  InvestmentType type = InvestmentType.gold,
  Metal? metal,
}) => InvestmentEntity(
  id: 'i1',
  name: 'Coins',
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  currency: 'INR',
  metal: metal,
);

Map<String, dynamic> _doc({String type = 'gold', Object? metal}) => {
  'name': 'Coins',
  'type': type,
  'status': 'OPEN',
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
  'currency': 'INR',
  'metal': ?metal,
};

InvestmentEntity _read(Map<String, dynamic> data) =>
    FirestoreInvestmentRepository.investmentFromFirestore(
      data,
      'i1',
      baseCurrency: 'INR',
    );

void main() {
  group('metal in Firestore', () {
    test('a chosen metal is written by name', () {
      final map = FirestoreInvestmentRepository.investmentToFirestore(
        _inv(metal: Metal.silver),
      );
      expect(map['metal'], 'silver');
      expect(map['type'], 'gold');
    });

    test('no metal writes null, so an update clears a stored one', () {
      final map = FirestoreInvestmentRepository.investmentToFirestore(_inv());
      expect(map.containsKey('metal'), isTrue);
      expect(map['metal'], isNull);
    });

    test('only precious metals carry a metal', () {
      final map = FirestoreInvestmentRepository.investmentToFirestore(
        _inv(type: InvestmentType.stocks, metal: Metal.silver),
      );
      expect(map['metal'], isNull);
    });

    test('a written metal reads back', () {
      expect(_read(_doc(metal: 'silver')).metal, Metal.silver);
      expect(_read(_doc(metal: 'gold')).metal, Metal.gold);
    });

    test('a document from before the choice has no metal', () {
      expect(_read(_doc()).metal, isNull);
    });

    test('an unknown or misplaced metal is dropped', () {
      expect(_read(_doc(metal: 'platinum')).metal, isNull);
      expect(_read(_doc(metal: 7)).metal, isNull);
      expect(_read(_doc(type: 'stocks', metal: 'silver')).metal, isNull);
    });
  });
}
