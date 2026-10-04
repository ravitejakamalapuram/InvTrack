import 'dart:math' as math;

import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// What a set of open investments is worth today, in the currency of the
/// cash flows and values it was worked out from.
class CorpusValue {
  /// Current values (A10) of the open investments that have one.
  final double currentValues;

  /// Principal still invested, max(0, INVEST − RETURN), in the open
  /// investments that have no current value.
  final double principalWithoutValue;

  final int valuedCount;
  final int principalOnlyCount;

  const CorpusValue({
    this.currentValues = 0,
    this.principalWithoutValue = 0,
    this.valuedCount = 0,
    this.principalOnlyCount = 0,
  });

  double get total => currentValues + principalWithoutValue;
}

/// Net new money invested per month, from the cash flows.
class MonthlySavingsEstimate {
  /// Per month; null when there are fewer than
  /// [PlanningInputsCalculator.minHistoryMonths] months of history.
  final double? amount;

  /// Whole months from the first cash flow to the valuation date.
  final int monthsOfHistory;

  const MonthlySavingsEstimate({this.amount, this.monthsOfHistory = 0});

  bool get hasEnoughHistory => amount != null;
}

/// Portfolio inputs for plans (FIRE, goals): the single implementation of
/// "corpus" and "monthly savings" (money rule 3).
///
/// Callers pass cash flows and terminal values already converted to the
/// base currency (money rule 2), and only active (non-archived)
/// investments (money rule 9).
class PlanningInputsCalculator {
  PlanningInputsCalculator._();

  /// Months of history needed before savings are estimated.
  static const minHistoryMonths = 3;

  /// Months of cash flows the savings estimate looks back over.
  static const trailingMonths = 12;

  /// Σ current value of the open [investments], falling back to
  /// max(0, INVEST − RETURN) for each open investment without one. Closed
  /// investments hold no capital and count as nothing. Fees and income are
  /// not capital.
  static CorpusValue corpus({
    required Iterable<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
    required Map<String, TerminalValues> terminalValues,
  }) {
    final principal = <String, double>{};
    for (final cf in cashFlows) {
      if (cf.type == CashFlowType.invest) {
        principal[cf.investmentId] =
            (principal[cf.investmentId] ?? 0) + cf.amount;
      } else if (cf.type == CashFlowType.returnFlow) {
        principal[cf.investmentId] =
            (principal[cf.investmentId] ?? 0) - cf.amount;
      }
    }

    var currentValues = 0.0;
    var principalWithoutValue = 0.0;
    var valued = 0;
    var principalOnly = 0;
    for (final investment in investments) {
      if (!investment.isOpen) continue;
      final values = terminalValues[investment.id]?.flows ?? const [];
      if (values.isNotEmpty) {
        for (final value in values) {
          currentValues += value.amount;
        }
        valued++;
        continue;
      }
      final invested = principal[investment.id];
      if (invested == null) continue;
      principalWithoutValue += math.max(0, invested);
      principalOnly++;
    }

    return CorpusValue(
      currentValues: currentValues,
      principalWithoutValue: principalWithoutValue,
      valuedCount: valued,
      principalOnlyCount: principalOnly,
    );
  }

  /// Net new money (INVEST − RETURN) dated in the [trailingMonths] months up
  /// to and including [asOf], floored at 0, per month. With less history
  /// than that it is divided by the months there are, and under
  /// [minHistoryMonths] months there is no estimate. Income and fees are
  /// not new money, and flows after [asOf] have not happened yet.
  static MonthlySavingsEstimate monthlySavings({
    required List<CashFlowEntity> cashFlows,
    required DateTime asOf,
  }) {
    final today = _dateOnly(asOf);
    DateTime? first;
    for (final cf in cashFlows) {
      final date = _dateOnly(cf.date);
      if (date.isAfter(today)) continue;
      if (first == null || date.isBefore(first)) first = date;
    }
    if (first == null) return const MonthlySavingsEstimate();

    final history = wholeMonthsBetween(first, today);
    if (history < minHistoryMonths) {
      return MonthlySavingsEstimate(monthsOfHistory: history);
    }

    final windowStart = addMonths(today, -trailingMonths);
    var net = 0.0;
    for (final cf in cashFlows) {
      final date = _dateOnly(cf.date);
      if (!date.isAfter(windowStart) || date.isAfter(today)) continue;
      if (cf.type == CashFlowType.invest) net += cf.amount;
      if (cf.type == CashFlowType.returnFlow) net -= cf.amount;
    }

    return MonthlySavingsEstimate(
      amount: math.max(0, net) / math.min(trailingMonths, history),
      monthsOfHistory: history,
    );
  }

  /// [date] plus [months] calendar months, with the day clamped to the
  /// length of the month (31 Jan + 1 month = 28 or 29 Feb).
  static DateTime addMonths(DateTime date, int months) {
    final firstOfMonth = DateTime(date.year, date.month + months);
    final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
    return DateTime(
      firstOfMonth.year,
      firstOfMonth.month,
      math.min(date.day, lastDay),
    );
  }

  /// Whole calendar months from [from] to [to] (0 when [to] is earlier).
  static int wholeMonthsBetween(DateTime from, DateTime to) {
    var months = (to.year - from.year) * 12 + to.month - from.month;
    if (to.day < from.day) months--;
    return math.max(0, months);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
