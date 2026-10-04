// A15 (#760, CALC-07, CALC-12, CALC-13): MOIC and return % are measured on
// paid-in capital, the most of the user's own money in an investment at one
// time, so a rollover or a re-lent payout is not counted twice. Money
// aggregates are rounded to the paisa.
//
// Expected values were computed independently in Python (actual/365, the
// same convention as Excel's XIRR):
//   Rollover: -10L 2023-01-01; +10.75L and -10.75L 2024-01-01;
//     +11.55625L 2025-01-01. Paid-in 10L, MOIC 1.155625, return 15.5625%,
//     XIRR 1.155625^(365/731) - 1 = 7.489365%.
//   P2P re-lending: -1L 2024-01-01; +50k 2024-07-01; -50k 2024-07-05;
//     +1.1L 2025-01-01. Paid-in 1L, MOIC 1.1, return 10%, XIRR 10.026104%.
//   Open rollover: -1L 2024-01-01; +1.07L and -1.07L 2025-01-01; value
//     1.1449L on 2026-01-01. MOIC 1.1449, return 14.49%,
//     XIRR 1.1449^(365/731) - 1 = 6.990097%.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

const _rateTol = 1e-6;

final _module = FinancialCalculatorModule();

var _nextId = 0;

CashFlowEntity _flow(
  CashFlowType type,
  double amount,
  DateTime date, {
  String investmentId = 'inv',
}) => CashFlowEntity(
  id: 'cf-${_nextId++}',
  investmentId: investmentId,
  date: date,
  type: type,
  amount: amount,
  createdAt: date,
  currency: 'INR',
);

TerminalValues _value(String investmentId, double amount, DateTime date) =>
    TerminalValues(
      flows: [
        CashFlowEntity(
          id: '${TerminalValues.idPrefix}$investmentId',
          investmentId: investmentId,
          date: date,
          type: CashFlowType.returnFlow,
          amount: amount,
          createdAt: date,
          currency: 'INR',
        ),
      ],
    );

void main() {
  group('paid-in capital (CALC-07)', () {
    // An FD that matured and was renewed for its full value on the same day.
    final rollover = [
      _flow(CashFlowType.invest, 1000000, DateTime.utc(2023, 1, 1)),
      _flow(CashFlowType.returnFlow, 1075000, DateTime.utc(2024, 1, 1)),
      _flow(CashFlowType.invest, 1075000, DateTime.utc(2024, 1, 1)),
      _flow(CashFlowType.returnFlow, 1155625, DateTime.utc(2025, 1, 1)),
    ];

    test('a same-day rollover counts the capital once: MOIC 1.156x, '
        'return 15.6%, XIRR 7.489%', () {
      final stats = _module.calculateStats(rollover);

      expect(stats.paidInCapital, 1000000.0);
      expect(stats.moic, closeTo(1.155625, _rateTol));
      expect(stats.moic.toStringAsFixed(3), '1.156');
      expect(stats.absoluteReturn, closeTo(15.5625, _rateTol));
      expect(stats.absoluteReturn.toStringAsFixed(1), '15.6');
      expect(stats.xirr, closeTo(0.07489365134674109, _rateTol));
      // Cash in and out stay gross: they are what the user moved.
      expect(stats.totalInvested, 2075000.0);
      expect(stats.totalReturned, 2230625.0);
      expect(stats.netCashFlow, 155625.0);
    });

    test('the order of the same-day RETURN and INVEST does not matter', () {
      final reordered = [rollover[0], rollover[2], rollover[1], rollover[3]];

      final stats = _module.calculateStats(reordered);

      expect(stats.paidInCapital, 1000000.0);
      expect(stats.moic, closeTo(1.155625, _rateTol));
    });

    test('a payout re-lent a few days later is not new capital', () {
      final stats = _module.calculateStats([
        _flow(CashFlowType.invest, 100000, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.returnFlow, 50000, DateTime.utc(2024, 7, 1)),
        _flow(CashFlowType.invest, 50000, DateTime.utc(2024, 7, 5)),
        _flow(CashFlowType.returnFlow, 110000, DateTime.utc(2025, 1, 1)),
      ]);

      expect(stats.paidInCapital, 100000.0);
      expect(stats.moic, closeTo(1.1, _rateTol));
      expect(stats.absoluteReturn, closeTo(10.0, _rateTol));
      expect(stats.xirr, closeTo(0.10026103749986992, _rateTol));
      expect(stats.totalInvested, 150000.0);
    });

    test('an open rollover adds its current value to the distributions', () {
      final stats = _module.calculateStats([
        _flow(CashFlowType.invest, 100000, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.returnFlow, 107000, DateTime.utc(2025, 1, 1)),
        _flow(CashFlowType.invest, 107000, DateTime.utc(2025, 1, 1)),
      ], terminalValues: _value('inv', 114490, DateTime.utc(2026, 1, 1)));

      expect(stats.paidInCapital, 100000.0);
      expect(stats.moic, closeTo(1.1449, _rateTol));
      expect(stats.absoluteReturn, closeTo(14.49, _rateTol));
      expect(stats.xirr, closeTo(0.06990096935201717, _rateTol));
    });

    test('fees are part of paid-in capital (net MOIC)', () {
      final stats = _module.calculateStats([
        _flow(CashFlowType.invest, 100000, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.fee, 1000, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.returnFlow, 110000, DateTime.utc(2025, 1, 1)),
      ]);

      expect(stats.paidInCapital, 101000.0);
      expect(stats.moic, closeTo(110000 / 101000, _rateTol));
      expect(stats.absoluteReturn, closeTo(9000 / 101000 * 100, _rateTol));
    });

    test('a portfolio adds up each investment\'s paid-in capital: money '
        'moved from one investment to another is not netted', () {
      final stats = _module.calculateStats([
        _flow(
          CashFlowType.invest,
          100000,
          DateTime.utc(2024, 1, 1),
          investmentId: 'a',
        ),
        _flow(
          CashFlowType.returnFlow,
          110000,
          DateTime.utc(2025, 1, 1),
          investmentId: 'a',
        ),
        _flow(
          CashFlowType.invest,
          110000,
          DateTime.utc(2025, 1, 2),
          investmentId: 'b',
        ),
      ], terminalValues: _value('b', 120000, DateTime.utc(2026, 1, 2)));

      expect(stats.paidInCapital, 210000.0);
      expect(stats.moic, closeTo(230000 / 210000, _rateTol));
      expect(stats.absoluteReturn, closeTo(20000 / 210000 * 100, _rateTol));
    });

    test('returns recorded before any investment fall back to the amount '
        'invested rather than divide by zero', () {
      final stats = _module.calculateStats([
        _flow(CashFlowType.returnFlow, 1000, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.invest, 500, DateTime.utc(2024, 2, 1)),
      ]);

      expect(stats.paidInCapital, 500.0);
      expect(stats.moic, closeTo(2.0, _rateTol));
    });
  });

  group('money rounded to the paisa (CALC-13)', () {
    test('a break-even position nets to exactly 0, not -0.00000000000001', () {
      final stats = _module.calculateStats([
        _flow(CashFlowType.invest, 101.00, DateTime.utc(2024, 1, 1)),
        for (var month = 2; month <= 11; month++)
          _flow(CashFlowType.income, 10.10, DateTime.utc(2024, month, 1)),
      ]);

      expect(stats.totalReturned, 101.0);
      expect(stats.netCashFlow, 0.0);
      expect(stats.netCashFlow.isNegative, isFalse);
      expect(stats.isLoss, isFalse);
      expect(stats.absoluteReturn, 0.0);
      expect(stats.moic, 1.0);
    });

    test('less than half a paisa below zero rounds to 0, not -0', () {
      final rounded = FinancialCalculator.roundMoney(-0.004);

      expect(rounded, 0.0);
      expect(rounded.isNegative, isFalse);
      expect(FinancialCalculator.roundMoney(1234.565001), 1234.57);
    });

    test('invested and returned are rounded to the paisa', () {
      final stats = _module.calculateStats([
        _flow(CashFlowType.invest, 0.1, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.fee, 0.2, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.income, 0.1, DateTime.utc(2024, 6, 1)),
        _flow(CashFlowType.returnFlow, 0.2, DateTime.utc(2025, 1, 1)),
      ]);

      expect(stats.totalInvested, 0.3);
      expect(stats.totalReturned, 0.3);
      expect(stats.paidInCapital, 0.3);
      expect(stats.netCashFlow, 0.0);
    });
  });

  group('holding period (CALC-12)', () {
    test('an open FD with one INVEST a year ago and a value as of today '
        'shows 1.0y, not <1mo', () {
      final stats = _module.calculateStats([
        _flow(CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
      ], terminalValues: _value('inv', 107185.90, DateTime(2026, 10, 2)));

      expect(stats.durationYears, closeTo(1.0, _rateTol));
      expect(stats.durationFormatted, '1.0y');
    });

    test('a closed investment runs from its first to its last cash flow', () {
      final stats = _module.calculateStats([
        _flow(CashFlowType.invest, 100000, DateTime(2024, 1, 1)),
        _flow(CashFlowType.returnFlow, 110000, DateTime(2025, 7, 2)),
      ]);

      expect(stats.durationYears, closeTo(548 / 365, _rateTol));
      expect(stats.durationFormatted, '1.5y');
    });
  });
}
