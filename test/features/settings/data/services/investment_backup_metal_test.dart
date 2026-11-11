// The metal of an investment (#946) in investments.json: a backup carries it,
// a restore reads it back, and a file from before the choice has none.

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal.dart';
import 'package:inv_tracker/features/settings/data/services/investment_backup_json.dart';

InvestmentEntity _inv({Metal? metal}) => InvestmentEntity(
  id: 'i1',
  name: 'Coins',
  type: InvestmentType.gold,
  status: InvestmentStatus.open,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  currency: 'INR',
  metal: metal,
);

void main() {
  test('a silver investment survives a backup and restore', () {
    final row = investmentToBackupJson(_inv(metal: Metal.silver));
    expect(row['metal'], 'silver');
    expect(investmentFromBackupJson(row)!.metal, Metal.silver);
  });

  test('an investment without a metal writes none and restores without', () {
    final row = investmentToBackupJson(_inv());
    expect(row.containsKey('metal'), isFalse);
    expect(investmentFromBackupJson(row)!.metal, isNull);
  });

  test('an unknown metal in a file is ignored, the row is kept', () {
    final row = investmentToBackupJson(_inv())..['metal'] = 'platinum';
    final back = investmentFromBackupJson(row)!;
    expect(back.metal, isNull);
    expect(back.name, 'Coins');
  });
}
