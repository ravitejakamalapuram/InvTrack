import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/period_inflows.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

CashFlowEntity _cf(
  String id,
  String investmentId,
  DateTime date,
  CashFlowType type,
  double amount,
) => CashFlowEntity(
  id: id,
  investmentId: investmentId,
  date: date,
  type: type,
  amount: amount,
  createdAt: DateTime(2026),
  currency: 'INR',
);

void main() {
  group('PeriodInflows.of', () {
    final start = DateTime(2026, 10, 1);
    final end = DateTime(2026, 11, 1);

    test('sums RETURN and INCOME inside [start, end) to the paisa', () {
      final flows = [
        _cf('a', 'fd', DateTime(2026, 10, 1), CashFlowType.income, 1234.56),
        _cf('b', 'p2p', DateTime(2026, 10, 15), CashFlowType.income, 0.01),
        _cf('c', 'p2p', DateTime(2026, 10, 31), CashFlowType.returnFlow, 50000),
      ];

      final inflows = PeriodInflows.of(flows, start: start, end: end);

      expect(inflows.total, closeTo(51234.57, 0.001));
      expect(inflows.count, 3);
      expect(inflows.investmentCount, 2);
    });

    test('leaves out outflows and flows on the end date', () {
      final flows = [
        _cf('a', 'fd', DateTime(2026, 10, 5), CashFlowType.invest, 100000),
        _cf('b', 'fd', DateTime(2026, 10, 6), CashFlowType.fee, 50),
        _cf('c', 'fd', DateTime(2026, 11, 1), CashFlowType.income, 800),
        _cf('d', 'fd', DateTime(2026, 9, 30), CashFlowType.income, 700),
      ];

      final inflows = PeriodInflows.of(flows, start: start, end: end);

      expect(inflows.total, 0);
      expect(inflows.count, 0);
      expect(inflows.investmentCount, 0);
    });

    test('ignores the time of day on a flow date', () {
      final flows = [
        _cf('a', 'fd', DateTime(2026, 10, 31, 23, 59), CashFlowType.income, 10),
      ];

      expect(PeriodInflows.of(flows, start: start, end: end).total, 10);
    });
  });
}
