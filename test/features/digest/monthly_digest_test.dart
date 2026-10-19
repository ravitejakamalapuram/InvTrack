import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/digest/domain/monthly_digest.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

CashFlowEntity _cf(String investmentId, DateTime date, double amount) =>
    CashFlowEntity(
      id: '$investmentId-$date',
      investmentId: investmentId,
      date: date,
      type: CashFlowType.income,
      amount: amount,
      createdAt: DateTime(2026),
      currency: 'INR',
    );

InvestmentEntity _inv(
  String id, {
  DateTime? maturityDate,
  InvestmentStatus status = InvestmentStatus.open,
}) => InvestmentEntity(
  id: id,
  name: 'Investment $id',
  type: InvestmentType.fixedDeposit,
  status: status,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
  currency: 'INR',
  maturityDate: maturityDate,
);

InvestmentStats _stats({int missingValueCount = 0}) => InvestmentStats(
  totalInvested: 100000,
  totalReturned: 0,
  netCashFlow: -100000,
  absoluteReturn: 0,
  moic: 0,
  xirr: null,
  xirrMethod: XirrMethod.undefined,
  cashFlowCount: 1,
  missingValueCount: missingValueCount,
);

void main() {
  group('DigestMonth', () {
    test('is the half-open range [1st, next 1st) and parses its key', () {
      final month = DigestMonth.parse('2026-12');

      expect(month.start, DateTime(2026, 12, 1));
      expect(month.end, DateTime(2027, 1, 1));
      expect(month.next.key, '2027-01');
      expect(month.previous.key, '2026-11');
      expect(DigestMonth.before(DateTime(2026, 11, 1, 10)).key, '2026-10');
    });

    test('rejects a malformed key', () {
      expect(() => DigestMonth.parse('2026-13'), throwsFormatException);
      expect(() => DigestMonth.parse('oct'), throwsFormatException);
    });
  });

  group('MonthlyDigest.build', () {
    final october = DigestMonth.parse('2026-10');

    test('totals the month, compares with the month before', () {
      final digest = MonthlyDigest.build(
        month: october,
        baseCurrency: 'INR',
        convertedFlows: [
          _cf('a', DateTime(2026, 9, 30), 1000),
          _cf('a', DateTime(2026, 10, 1), 1500.25),
          _cf('b', DateTime(2026, 10, 20), 2500.50),
        ],
        activeInvestments: [_inv('a'), _inv('b')],
        statsById: {'a': _stats(), 'b': _stats()},
      );

      expect(digest.moneyIn.total, closeTo(4000.75, 0.001));
      expect(digest.moneyIn.count, 2);
      expect(digest.moneyIn.investmentCount, 2);
      expect(digest.previousMoneyIn.total, 1000);
      expect(digest.change, closeTo(3000.75, 0.001));
    });

    test('lists open investments maturing next month, soonest first', () {
      final digest = MonthlyDigest.build(
        month: october,
        baseCurrency: 'INR',
        convertedFlows: const [],
        activeInvestments: [
          _inv('late', maturityDate: DateTime(2026, 11, 30)),
          _inv('early', maturityDate: DateTime(2026, 11, 1)),
          _inv('december', maturityDate: DateTime(2026, 12, 1)),
          _inv('october', maturityDate: DateTime(2026, 10, 31)),
          _inv(
            'closed',
            maturityDate: DateTime(2026, 11, 5),
            status: InvestmentStatus.closed,
          ),
        ],
        statsById: const {},
      );

      expect(digest.maturingNextMonth.map((i) => i.id), ['early', 'late']);
    });

    test('lists open investments that await a current value', () {
      final digest = MonthlyDigest.build(
        month: october,
        baseCurrency: 'INR',
        convertedFlows: const [],
        activeInvestments: [
          _inv('valued'),
          _inv('missing'),
          _inv('closed', status: InvestmentStatus.closed),
        ],
        statsById: {
          'valued': _stats(),
          'missing': _stats(missingValueCount: 1),
          'closed': _stats(missingValueCount: 1),
        },
      );

      expect(digest.needingValue.map((i) => i.id), ['missing']);
    });

    test('is quiet when nothing came in, matures or needs a value', () {
      final digest = MonthlyDigest.build(
        month: october,
        baseCurrency: 'INR',
        convertedFlows: const [],
        activeInvestments: [_inv('a')],
        statsById: {'a': _stats()},
      );

      expect(digest.isQuiet, isTrue);
    });
  });
}
