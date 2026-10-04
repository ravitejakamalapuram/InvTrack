// A21 / ANLY-09: Year over Year compares the financial year to date with the
// same days of the previous Indian financial year, both half-open
// [1 Apr, day after today), by calendar day.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

CashFlowEntity _flow(CashFlowType type, double amount, DateTime date) =>
    CashFlowEntity(
      id: '${type.name}-${date.toIso8601String()}',
      investmentId: 'inv',
      type: type,
      amount: amount,
      currency: 'INR',
      date: date,
      createdAt: date,
    );

YoYComparison _compare(List<CashFlowEntity> flows, DateTime today) {
  final container = ProviderContainer(
    overrides: [
      convertedCashFlowsProvider.overrideWithValue(AsyncValue.data(flows)),
      valuationDateProvider.overrideWithValue(today),
    ],
  );
  addTearDown(container.dispose);
  return container.read(yoyComparisonProvider).requireValue;
}

void main() {
  test('compares FY-to-date with the same days of the previous FY', () {
    final yoy = _compare([
      // FY 2024-25: before both periods.
      _flow(CashFlowType.invest, 10000, DateTime(2025, 3, 31)),
      // FY 2025-26, 1 Apr to 4 Oct 2025: the same days last year.
      _flow(CashFlowType.invest, 300000, DateTime(2025, 4, 1)),
      _flow(CashFlowType.returnFlow, 50000, DateTime(2025, 9, 15)),
      _flow(CashFlowType.income, 1000, DateTime(2025, 10, 4)),
      // FY 2025-26 after 4 Oct: not compared.
      _flow(CashFlowType.invest, 300000, DateTime(2025, 10, 5)),
      _flow(CashFlowType.returnFlow, 40000, DateTime(2026, 1, 20)),
      _flow(CashFlowType.income, 2000, DateTime(2026, 3, 31)),
      // FY 2026-27 to date (today is 4 Oct 2026).
      _flow(CashFlowType.invest, 900000, DateTime(2026, 4, 1)),
      _flow(CashFlowType.fee, 200, DateTime(2026, 5, 1)),
      _flow(CashFlowType.returnFlow, 60000, DateTime(2026, 6, 30)),
      // Today, saved with a time of day: still today.
      _flow(CashFlowType.income, 500, DateTime(2026, 10, 4, 18, 30)),
      // Future-dated: not yet.
      _flow(CashFlowType.invest, 100000, DateTime(2026, 10, 5)),
    ], DateTime(2026, 10, 4));

    expect(yoy.lastYearInvested, closeTo(300000.00, 0.005));
    expect(yoy.lastYearReturned, closeTo(51000.00, 0.005));
    expect(yoy.lastYearNet, closeTo(-249000.00, 0.005));
    expect(yoy.thisYearInvested, closeTo(900200.00, 0.005));
    expect(yoy.thisYearReturned, closeTo(60500.00, 0.005));
    expect(yoy.thisYearNet, closeTo(-839700.00, 0.005));
    // Income (INCOME flows only) is reported on its own.
    expect(yoy.lastYearIncome, closeTo(1000.00, 0.005));
    expect(yoy.thisYearIncome, closeTo(500.00, 0.005));
    expect(yoy.lastYearCapitalReturned, closeTo(50000.00, 0.005));
    expect(yoy.thisYearCapitalReturned, closeTo(60000.00, 0.005));
  });

  test('principal coming back at maturity is not income growth', () {
    final yoy = _compare([
      // Last FY to date: ₹6,000 of interest.
      _flow(CashFlowType.income, 6000, DateTime(2025, 8, 1)),
      // This FY to date: a ₹1,00,000 FD matures with ₹7,000 of interest.
      _flow(CashFlowType.returnFlow, 100000, DateTime(2026, 8, 1)),
      _flow(CashFlowType.income, 7000, DateTime(2026, 8, 1)),
    ], DateTime(2026, 10, 4));

    expect(yoy.thisYearIncome, closeTo(7000.00, 0.005));
    expect(yoy.lastYearIncome, closeTo(6000.00, 0.005));
    // (7,000 − 6,000) / 6,000 = +16.666667%, not +1,683.3% for all money
    // received.
    expect(yoy.incomeChangePercent, closeTo(16.666667, 1e-6));
  });

  test('on 29 Feb the previous span ends on 28 Feb', () {
    final yoy = _compare([
      _flow(CashFlowType.invest, 1000, DateTime(2027, 2, 28)),
      _flow(CashFlowType.invest, 2000, DateTime(2027, 3, 1)),
      _flow(CashFlowType.invest, 5000, DateTime(2027, 4, 1)),
      _flow(CashFlowType.income, 300, DateTime(2028, 2, 29)),
    ], DateTime(2028, 2, 29));

    expect(yoy.lastYearInvested, closeTo(1000.00, 0.005));
    expect(yoy.thisYearInvested, closeTo(5000.00, 0.005));
    expect(yoy.thisYearReturned, closeTo(300.00, 0.005));
  });

  test('in April the comparison is only the first days of each FY', () {
    final yoy = _compare([
      _flow(CashFlowType.income, 700, DateTime(2025, 4, 3)),
      _flow(CashFlowType.income, 900, DateTime(2025, 4, 4)),
      _flow(CashFlowType.income, 800, DateTime(2026, 4, 2)),
    ], DateTime(2026, 4, 3));

    expect(yoy.lastYearReturned, closeTo(700.00, 0.005));
    expect(yoy.thisYearReturned, closeTo(800.00, 0.005));
  });
}
