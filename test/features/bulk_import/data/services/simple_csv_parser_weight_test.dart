// Weight columns on cash flow rows (#946): Quantity and Unit survive a
// restore, and unusable ones are dropped without touching the money.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';

ParsedCashFlowRow _row(String quantity, String unit, {bool columns = true}) {
  final csv = columns
      ? 'Date,Investment Name,Type,Amount,Currency,Notes,Quantity,Unit\n'
            '2026-11-03,Gold,INVEST,64500,INR,,$quantity,$unit\n'
      : 'Date,Investment Name,Type,Amount,Currency,Notes\n'
            '2026-11-03,Gold,INVEST,64500,INR,\n';
  final result = SimpleCsvParser.parse(
    Uint8List.fromList(utf8.encode(csv)),
    baseCurrency: 'INR',
    fromBackup: true,
  );
  return result.rows.single;
}

void main() {
  test('a row with quantity and unit keeps its weight', () {
    final row = _row('10.5', 'gram');
    expect(row.isValid, isTrue);
    expect(row.quantity, 10.5);
    expect(row.quantityUnit, QuantityUnit.gram);
    expect(row.amount, 64500);
  });

  test('a file without the columns has no weight', () {
    final row = _row('', '', columns: false);
    expect(row.isValid, isTrue);
    expect(row.quantity, isNull);
    expect(row.quantityUnit, isNull);
  });

  test('a half, unknown or non-positive weight is dropped, the row stays', () {
    for (final bad in [
      ['10', ''],
      ['', 'gram'],
      ['10', 'carat'],
      ['0', 'gram'],
      ['-2', 'gram'],
      ['abc', 'gram'],
    ]) {
      final row = _row(bad[0], bad[1]);
      expect(row.isValid, isTrue, reason: '$bad');
      expect(row.quantity, isNull, reason: '$bad');
      expect(row.quantityUnit, isNull, reason: '$bad');
      expect(row.amount, 64500);
    }
  });
}
