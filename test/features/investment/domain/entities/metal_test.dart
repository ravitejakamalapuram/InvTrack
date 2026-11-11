// The metal of a precious-metals investment (#946): Gold or Silver. The stored
// type id stays `gold`, so records written before the choice read as before.

import 'package:flutter_test/flutter_test.dart';
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
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  currency: 'INR',
  metal: metal,
);

void main() {
  group('Metal', () {
    test('has gold and silver, stored by name', () {
      expect(Metal.values.map((m) => m.name), ['gold', 'silver']);
    });

    test('tryParse reads a stored name and rejects anything else', () {
      expect(Metal.tryParse('silver'), Metal.silver);
      expect(Metal.tryParse('gold'), Metal.gold);
      expect(Metal.tryParse('platinum'), isNull);
      expect(Metal.tryParse(null), isNull);
      expect(Metal.tryParse(3), isNull);
    });
  });

  group('InvestmentEntity metal', () {
    test('the type is named Precious metals, its id stays gold', () {
      expect(InvestmentType.gold.displayName, 'Precious metals');
      expect(InvestmentType.gold.name, 'gold');
      expect(InvestmentType.fromString('gold'), InvestmentType.gold);
    });

    test('a record from before the choice has no metal', () {
      expect(_inv().metal, isNull);
      expect(_inv().typeLabel, 'Precious metals');
    });

    test('the type label names the chosen metal', () {
      expect(_inv(metal: Metal.gold).typeLabel, 'Gold');
      expect(_inv(metal: Metal.silver).typeLabel, 'Silver');
    });

    test('another type ignores a metal', () {
      expect(
        _inv(type: InvestmentType.stocks, metal: Metal.silver).typeLabel,
        'Stocks',
      );
    });

    test('copyWith keeps and changes the metal', () {
      final silver = _inv(metal: Metal.silver);
      expect(silver.copyWith(name: 'x').metal, Metal.silver);
      expect(silver.copyWith(metal: Metal.gold).metal, Metal.gold);
    });

    test('the metal takes part in equality', () {
      expect(_inv(metal: Metal.gold), isNot(_inv(metal: Metal.silver)));
      expect(_inv(metal: Metal.gold), _inv(metal: Metal.gold));
      expect(
        _inv(metal: Metal.gold).hashCode,
        _inv(metal: Metal.gold).hashCode,
      );
    });
  });
}
