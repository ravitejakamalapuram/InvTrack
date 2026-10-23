import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/merged_valuation_snapshots.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';

InvestmentValuationSnapshot snap(
  String id,
  String inv,
  double amount,
  DateTime date, {
  String currency = 'INR',
  ValuationKind kind = ValuationKind.marketValue,
  ValuationProvenance provenance = ValuationProvenance.manual,
  DateTime? deletedAt,
}) => InvestmentValuationSnapshot(
  id: id,
  investmentId: inv,
  amount: amount,
  currency: currency,
  effectiveDate: date,
  kind: kind,
  provenance: provenance,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  deletedAt: deletedAt,
);

List<InvestmentValuationSnapshot> combine(
  List<InvestmentValuationSnapshot> all, {
  List<String> sources = const ['a', 'b'],
}) {
  var n = 0;
  return MergedValuationSnapshots.combine(
    snapshots: all,
    sourceIds: sources,
    mergedId: 'm',
    newId: () => 'n${n++}',
    now: DateTime(2025),
  );
}

void main() {
  final d1 = DateTime(2024, 1, 1);
  final d2 = DateTime(2024, 6, 1);
  final d3 = DateTime(2024, 9, 1);

  test('sums each source latest value as of every date both are valued', () {
    final out = combine([
      snap('1', 'a', 1000, d1),
      snap('2', 'b', 500, d2),
      snap('3', 'a', 1200, d3),
    ]);
    // d1: b has no value yet, so no honest total. d2: 1000 + 500. d3: 1200 + 500.
    expect(out.map((s) => (s.effectiveDate, s.amount, s.investmentId)), [
      (d2, 1500.0, 'm'),
      (d3, 1700.0, 'm'),
    ]);
  });

  test('a source without any live valuation yields nothing', () {
    expect(
      combine([
        snap('1', 'a', 1000, d1),
        snap('2', 'b', 500, d2, deletedAt: DateTime(2024, 7)),
      ]),
      isEmpty,
    );
  });

  test('mixed currencies yield nothing', () {
    expect(
      combine([
        snap('1', 'a', 1000, d1),
        snap('2', 'b', 5, d1, currency: 'USD'),
      ]),
      isEmpty,
    );
  });

  test('mixed kinds become a market value, same kinds are kept', () {
    final mixed = combine([
      snap('1', 'a', 1, d1, kind: ValuationKind.carryingValue),
      snap('2', 'b', 1, d1),
    ]);
    expect(mixed.single.kind, ValuationKind.marketValue);
    final same = combine([
      snap('1', 'a', 1, d1, kind: ValuationKind.carryingValue),
      snap('2', 'b', 1, d1, kind: ValuationKind.carryingValue),
    ]);
    expect(same.single.kind, ValuationKind.carryingValue);
  });

  test('only the earliest total can be an opening baseline', () {
    final out = combine([
      snap('1', 'a', 1000, d1, provenance: ValuationProvenance.openingBaseline),
      snap('2', 'b', 500, d1),
      snap('3', 'b', 600, d2),
    ]);
    expect(out.map((s) => s.provenance), [
      ValuationProvenance.openingBaseline,
      ValuationProvenance.manual,
    ]);
  });

  test('sums at the currency precision', () {
    final out = combine([snap('1', 'a', 0.1, d1), snap('2', 'b', 0.2, d1)]);
    expect(out.single.amount, 0.3);
  });
}
