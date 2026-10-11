// The portfolio behind the Play screenshots is demo data. These checks keep it
// honest under the money rules in CLAUDE.md and keep every scene populated:
// since A11/A12 goals and FIRE count what is held today, so a portfolio with
// no open investments shows 0% everywhere.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../../integration_test/mocks/store_demo_data.dart';

bool _dateOnly(DateTime d) =>
    d.hour == 0 && d.minute == 0 && d.second == 0 && d.millisecond == 0;

void main() {
  // A fixed clock with a time of day, to prove dates are normalised.
  final data = StoreDemoData.build(DateTime(2026, 10, 10, 15, 47, 12));

  List<CashFlowEntity> flowsOf(InvestmentEntity inv) =>
      data.cashFlows.where((c) => c.investmentId == inv.id).toList();

  double sum(Iterable<CashFlowEntity> flows, Set<CashFlowType> types) => flows
      .where((c) => types.contains(c.type))
      .fold(0, (total, c) => total + c.amount);

  test('everything is in INR (never a defaulted currency)', () {
    expect(data.investments.map((i) => i.currency).toSet(), {'INR'});
    expect(data.cashFlows.map((c) => c.currency).toSet(), {'INR'});
    expect(data.goals.map((g) => g.currency).toSet(), {'INR'});
    expect(data.fireSettings.currency, 'INR');
  });

  test('mixes open holdings with closed positions so goals and FIRE have '
      'something held today', () {
    final open = data.investments.where(
      (i) => i.status == InvestmentStatus.open,
    );
    expect(open.length, greaterThanOrEqualTo(3));
    expect(
      data.investments.where((i) => i.status == InvestmentStatus.closed),
      isNotEmpty,
    );
  });

  test('every open investment has a dated current value (money rule 4)', () {
    for (final inv in data.investments.where(
      (i) => i.status == InvestmentStatus.open,
    )) {
      expect(inv.currentValue, isNotNull, reason: inv.name);
      expect(inv.currentValue, greaterThan(0), reason: inv.name);
      expect(inv.currentValueDate, DateTime(2026, 10, 10), reason: inv.name);
    }
  });

  test('every date is date-only (money rule 5)', () {
    for (final c in data.cashFlows) {
      expect(_dateOnly(c.date), isTrue, reason: '${c.id} ${c.date}');
    }
    for (final inv in data.investments) {
      expect(_dateOnly(inv.createdAt), isTrue, reason: inv.name);
      if (inv.closedAt != null) expect(_dateOnly(inv.closedAt!), isTrue);
    }
  });

  test('no cash flow is dated in the future', () {
    final today = DateTime(2026, 10, 10);
    expect(data.cashFlows.where((c) => c.date.isAfter(today)), isEmpty);
  });

  test('every position shows a gain: nothing resembling a loss is on a '
      'store screenshot', () {
    for (final inv in data.investments) {
      final flows = flowsOf(inv);
      final out = sum(flows, {CashFlowType.invest, CashFlowType.fee});
      final back =
          sum(flows, {CashFlowType.returnFlow, CashFlowType.income}) +
          (inv.status == InvestmentStatus.open ? inv.currentValue! : 0);
      expect(back, greaterThan(out), reason: inv.name);
    }
  });

  test('goals only link to investments that exist', () {
    final ids = data.investments.map((i) => i.id).toSet();
    for (final goal in data.goals) {
      expect(
        ids.containsAll(goal.linkedInvestmentIds),
        isTrue,
        reason: goal.name,
      );
    }
  });

  test('the detail screenshot investment exists exactly once', () {
    expect(
      data.investments.where(
        (i) => i.name == StoreDemoData.detailInvestmentName,
      ),
      hasLength(1),
    );
  });
}
