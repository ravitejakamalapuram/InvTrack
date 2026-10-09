// A10 (#754, CALC-01, ANLY-01, ADOPT-08): open investments need a current
// value, used as the terminal inflow for XIRR, MOIC and return %.
//
// Expected values were computed independently in Python (actual/365, the
// same convention as Excel's XIRR) with today = 2026-10-02:
//   S1 cumulative FD ₹1L @7% quarterly from 2025-10-02:
//      V = 1,00,000 × 1.0175^4 = 1,07,185.903129, XIRR 7.185903%
//   S2 payout FD ₹1L @7.5%, 8 quarterly payouts of 1,875, V = principal:
//      XIRR 7.713779%, MOIC 1.15
//   S3 P2P ₹1L, 18 monthly payouts of 1,000, V = principal:
//      XIRR 12.669718%, MOIC 1.18
//   S4 closed P2P (−1L 2024-01-01, +1.12L 2025-01-01) plus an open
//      cumulative FD ₹5L @7% quarterly from 2026-04-01 (184 days):
//      V = 5,00,000 × 1.0175^(4·184/365) = 5,17,800.771973, XIRR 8.732892%
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

final _today = DateTime(2026, 10, 2);

InvestmentEntity _investment(
  String id,
  InvestmentType type, {
  InvestmentStatus status = InvestmentStatus.open,
  double? rate,
  CompoundingFrequency? compounding,
  InterestPayoutMode? payout,
  DateTime? maturityDate,
  double? currentValue,
  DateTime? currentValueDate,
  String currency = 'INR',
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: status,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  expectedRate: rate,
  compoundingFrequency: compounding,
  interestPayoutMode: payout,
  maturityDate: maturityDate,
  currentValue: currentValue,
  currentValueDate: currentValueDate,
  currency: currency,
);

CashFlowEntity _flow(
  String investmentId,
  CashFlowType type,
  double amount,
  DateTime date, {
  String currency = 'INR',
}) => CashFlowEntity(
  id: '$investmentId-${date.toIso8601String()}-${type.name}',
  investmentId: investmentId,
  date: date,
  type: type,
  amount: amount,
  createdAt: date,
  currency: currency,
);

DateTime _addMonths(DateTime d, int months) =>
    DateTime(d.year, d.month + months, d.day);

final _fdS1 = _investment(
  's1',
  InvestmentType.fixedDeposit,
  rate: 7,
  compounding: CompoundingFrequency.quarterly,
  payout: InterestPayoutMode.cumulative,
);
final _flowsS1 = [
  _flow('s1', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
];

final _fdS2 = _investment(
  's2',
  InvestmentType.fixedDeposit,
  rate: 7.5,
  compounding: CompoundingFrequency.quarterly,
  payout: InterestPayoutMode.periodic,
);
final _flowsS2 = [
  _flow('s2', CashFlowType.invest, 100000, DateTime(2024, 10, 2)),
  for (var k = 1; k <= 8; k++)
    _flow(
      's2',
      CashFlowType.income,
      1875,
      _addMonths(DateTime(2024, 10, 2), 3 * k),
    ),
];

final _p2pS3 = _investment('s3', InvestmentType.p2pLending, rate: 12);
final _flowsS3 = [
  _flow('s3', CashFlowType.invest, 100000, DateTime(2025, 4, 2)),
  for (var k = 1; k <= 18; k++)
    _flow('s3', CashFlowType.income, 1000, _addMonths(DateTime(2025, 4, 2), k)),
];

final _closedP2pS4 = _investment(
  's4-p2p',
  InvestmentType.p2pLending,
  status: InvestmentStatus.closed,
);
final _fdS4 = _investment(
  's4-fd',
  InvestmentType.fixedDeposit,
  rate: 7,
  compounding: CompoundingFrequency.quarterly,
  payout: InterestPayoutMode.cumulative,
);
final _flowsS4 = [
  _flow('s4-p2p', CashFlowType.invest, 100000, DateTime(2024, 1, 1)),
  _flow('s4-p2p', CashFlowType.returnFlow, 112000, DateTime(2025, 1, 1)),
  _flow('s4-fd', CashFlowType.invest, 500000, DateTime(2026, 4, 1)),
];

void main() {
  final module = FinancialCalculatorModule();

  group('CALC-01 golden scenarios (today = 2026-10-02)', () {
    test('S1 cumulative FD: accrued value is the terminal inflow', () {
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [_fdS1],
        cashFlows: _flowsS1,
        asOf: _today,
      );
      final stats = module.calculateStats(_flowsS1, terminalValues: terminal);

      expect(stats.currentValue, closeTo(107185.90, 0.005));
      expect(stats.xirr, closeTo(0.071859031, 1e-6));
      expect(stats.moic, closeTo(1.071859031, 1e-6));
      expect(stats.absoluteReturn, closeTo(7.185903, 1e-6));
      // Net cash flow stays the cash-only figure.
      expect(stats.netCashFlow, -100000);
      expect(stats.totalReturned, 0);
      expect(stats.currentValueIsEstimate, isTrue);
      expect(stats.currentValueRate, 7);
      expect(stats.missingValueCount, 0);
    });

    test('S2 payout FD: outstanding principal is the terminal inflow', () {
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [_fdS2],
        cashFlows: _flowsS2,
        asOf: _today,
      );
      final stats = module.calculateStats(_flowsS2, terminalValues: terminal);

      expect(stats.currentValue, 100000);
      expect(stats.xirr, closeTo(0.077137789, 1e-6));
      expect(stats.moic, closeTo(1.15, 1e-9));
      expect(stats.totalReturned, 15000);
    });

    test('S3 P2P loan: outstanding principal is the terminal inflow', () {
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [_p2pS3],
        cashFlows: _flowsS3,
        asOf: _today,
      );
      final stats = module.calculateStats(_flowsS3, terminalValues: terminal);

      expect(stats.currentValue, 100000);
      expect(stats.xirr, closeTo(0.126697181, 1e-6));
      expect(stats.moic, closeTo(1.18, 1e-9));
    });

    test('S4 portfolio XIRR and MOIC include the open FD terminal value', () {
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [_closedP2pS4, _fdS4],
        cashFlows: _flowsS4,
        asOf: _today,
      );
      final stats = module.calculateStats(_flowsS4, terminalValues: terminal);

      expect(stats.currentValue, closeTo(517800.77, 0.005));
      // Done-when: 8.73% ± 0.01pp.
      expect(stats.xirr, closeTo(0.0873, 0.0001));
      expect(stats.xirr, closeTo(0.087328923, 1e-6));
      expect(stats.moic, closeTo(1.049667953, 1e-6));
      expect(stats.totalInvested, 600000);
      expect(stats.totalReturned, 112000);
    });
  });

  group('Estimated current value', () {
    test('manual valuation rounds using the investment currency precision', () {
      final jpyGold = _investment(
        'jpy-gold',
        InvestmentType.gold,
        currentValue: 125.6,
        currentValueDate: DateTime(2026, 10, 1),
        currency: 'JPY',
      );
      final valuation = CurrentValueCalculator.valuationOf(jpyGold, [
        _flow(
          'jpy-gold',
          CashFlowType.invest,
          100,
          DateTime(2026, 10, 1),
          currency: 'JPY',
        ),
      ], asOf: _today)!;

      expect(valuation.amount, 126);
      expect(valuation.currency, 'JPY');
    });

    test('₹1,00,000 @7% quarterly accrues by actual/365 days', () {
      // 183 days: 1,00,000 × 1.0175^(4 × 183/365). Exactly half a year
      // (two full quarters) would be 1,03,530.63; see the PR for why the
      // actual/365 day count is used.
      final value = CurrentValueCalculator.accruedValue(
        principal: 100000,
        annualRatePercent: 7,
        compounding: CompoundingFrequency.quarterly,
        from: DateTime(2026, 4, 2),
        to: DateTime(2026, 10, 2),
      );
      expect(value, closeTo(103540.47, 0.005));
    });

    test('exactly two quarters of accrual give ₹1,03,530.63', () {
      final value = CurrentValueCalculator.accruedValueForYears(
        principal: 100000,
        annualRatePercent: 7,
        compounding: CompoundingFrequency.quarterly,
        years: 0.5,
      );
      expect(value, closeTo(103530.63, 0.005));
    });

    test('accrual stops at maturity', () {
      final fd = _investment(
        'cap',
        InvestmentType.fixedDeposit,
        rate: 7,
        compounding: CompoundingFrequency.quarterly,
        payout: InterestPayoutMode.cumulative,
        maturityDate: DateTime(2026, 4, 2),
      );
      final valuation = CurrentValueCalculator.valuationOf(fd, [
        _flow('cap', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
      ], asOf: _today)!;
      // 182 days to maturity.
      expect(valuation.amount, closeTo(103520.78, 0.005));
      expect(valuation.date, DateTime(2026, 4, 2));
      expect(valuation.source, ValuationSource.accruedInterest);
    });

    test('each recurring deposit accrues from its own date', () {
      final rd = _investment(
        'rd',
        InvestmentType.fixedDeposit,
        rate: 7,
        compounding: CompoundingFrequency.quarterly,
        payout: InterestPayoutMode.cumulative,
      );
      final valuation = CurrentValueCalculator.valuationOf(rd, [
        _flow('rd', CashFlowType.invest, 10000, DateTime(2026, 7, 2)),
        _flow('rd', CashFlowType.invest, 10000, DateTime(2026, 8, 2)),
        _flow('rd', CashFlowType.invest, 10000, DateTime(2026, 9, 2)),
      ], asOf: _today)!;
      expect(valuation.amount, closeTo(30350.30, 0.005));
    });

    test('payout FD, bond and P2P valuation is the outstanding principal', () {
      for (final type in [
        InvestmentType.fixedDeposit,
        InvestmentType.bonds,
        InvestmentType.p2pLending,
      ]) {
        final inv = _investment(
          'p',
          type,
          rate: 9,
          payout: InterestPayoutMode.periodic,
        );
        final valuation = CurrentValueCalculator.valuationOf(inv, [
          _flow('p', CashFlowType.invest, 100000, DateTime(2025, 1, 1)),
          _flow('p', CashFlowType.invest, 50000, DateTime(2025, 6, 1)),
          _flow('p', CashFlowType.income, 4000, DateTime(2025, 7, 1)),
          _flow('p', CashFlowType.returnFlow, 30000, DateTime(2026, 1, 1)),
          _flow('p', CashFlowType.fee, 500, DateTime(2026, 2, 1)),
        ], asOf: _today)!;
        expect(valuation.amount, 120000, reason: type.name);
        expect(valuation.date, _today, reason: type.name);
        expect(valuation.source, ValuationSource.outstandingPrincipal);
      }
    });

    test('gold, property and private deals are never estimated', () {
      for (final type in [
        InvestmentType.gold,
        InvestmentType.realEstate,
        InvestmentType.privateEquity,
        InvestmentType.angelInvesting,
      ]) {
        final inv = _investment('g', type, rate: 8);
        final valuation = CurrentValueCalculator.valuationOf(inv, [
          _flow('g', CashFlowType.invest, 100000, DateTime(2025, 1, 1)),
        ], asOf: _today);
        expect(valuation, isNull, reason: type.name);
      }
    });

    test('a cumulative FD without a rate needs a manual value', () {
      final fd = _investment(
        'n',
        InvestmentType.fixedDeposit,
        payout: InterestPayoutMode.cumulative,
      );
      expect(
        CurrentValueCalculator.valuationOf(fd, [
          _flow('n', CashFlowType.invest, 100000, DateTime(2025, 1, 1)),
        ], asOf: _today),
        isNull,
      );
    });
  });

  // Interest recorded as INCOME has left the deposit, like a RETURN, so it
  // comes off the accrued balance. Expected values from Python (actual/365):
  //   matured: 1,00,000 × 1.0175^(4·182/365) = 1,03,520.783740, less the
  //     RETURN of 1,00,000 and INCOME of 3,520.78 = 0.003740;
  //     MOIC 1.035207837, XIRR 7.185903%
  //   partial: 1,07,185.903129 − 2,000 × 1.0175^(4·183/365) (2,070.809344)
  //     = 1,05,115.093785; MOIC 1.071150938, XIRR 7.185903%
  group('Interest recorded as INCOME on a cumulative deposit', () {
    test('a matured at-maturity FD paid out in full is worth nothing', () {
      final fd = _investment(
        'mat',
        InvestmentType.fixedDeposit,
        rate: 7,
        compounding: CompoundingFrequency.quarterly,
        payout: InterestPayoutMode.atMaturity,
        maturityDate: DateTime(2026, 4, 2),
      );
      final flows = [
        _flow('mat', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
        _flow('mat', CashFlowType.returnFlow, 100000, DateTime(2026, 4, 2)),
        _flow('mat', CashFlowType.income, 3520.78, DateTime(2026, 4, 2)),
      ];
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [fd],
        cashFlows: flows,
        asOf: _today,
      );
      final stats = module.calculateStats(flows, terminalValues: terminal);

      expect(stats.currentValue, closeTo(0, 0.005));
      expect(stats.moic, closeTo(1.035207837, 1e-6));
      expect(stats.xirr, closeTo(0.071859031, 1e-6));
      expect(stats.absoluteReturn, closeTo(3.520784, 1e-6));
    });

    test('a partial INCOME payout before maturity comes off the balance', () {
      final fd = _investment(
        'part',
        InvestmentType.fixedDeposit,
        rate: 7,
        compounding: CompoundingFrequency.quarterly,
        payout: InterestPayoutMode.cumulative,
      );
      final flows = [
        _flow('part', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
        _flow('part', CashFlowType.income, 2000, DateTime(2026, 4, 2)),
      ];
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [fd],
        cashFlows: flows,
        asOf: _today,
      );
      final stats = module.calculateStats(flows, terminalValues: terminal);

      expect(stats.currentValue, closeTo(105115.09, 0.005));
      expect(stats.moic, closeTo(1.071150938, 1e-6));
      expect(stats.xirr, closeTo(0.071859031, 1e-6));
      expect(stats.absoluteReturn, closeTo(7.115094, 1e-6));
    });

    test('INCOME in another currency than the deposits is missing', () {
      final fd = _investment(
        'fx',
        InvestmentType.fixedDeposit,
        rate: 7,
        compounding: CompoundingFrequency.quarterly,
        payout: InterestPayoutMode.cumulative,
      );
      final flows = [
        _flow('fx', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
        _flow(
          'fx',
          CashFlowType.income,
          20,
          DateTime(2026, 4, 2),
          currency: 'USD',
        ),
      ];
      expect(
        CurrentValueCalculator.valuationOf(fd, flows, asOf: _today),
        isNull,
      );
    });
  });

  group('User-confirmed current value', () {
    test('overrides the estimate and is not labelled as an estimate', () {
      final fd = _investment(
        'm',
        InvestmentType.fixedDeposit,
        rate: 7,
        compounding: CompoundingFrequency.quarterly,
        payout: InterestPayoutMode.cumulative,
        currentValue: 107000,
        currentValueDate: DateTime(2026, 9, 30),
      );
      final flows = [
        _flow('m', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
      ];
      final valuation = CurrentValueCalculator.valuationOf(
        fd,
        flows,
        asOf: _today,
      )!;
      expect(valuation.amount, 107000);
      expect(valuation.date, DateTime(2026, 9, 30));
      expect(valuation.source, ValuationSource.manual);

      final stats = module.calculateStats(
        flows,
        terminalValues: CurrentValueCalculator.terminalValues(
          investments: [fd],
          cashFlows: flows,
          asOf: _today,
        ),
      );
      expect(stats.currentValueIsEstimate, isFalse);
      expect(stats.currentValueDate, DateTime(2026, 9, 30));
    });

    test('a gold holding uses its manual value', () {
      final gold = _investment(
        'gold',
        InvestmentType.gold,
        currentValue: 125000,
        currentValueDate: DateTime(2026, 10, 1),
      );
      final flows = [
        _flow('gold', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
      ];
      final stats = module.calculateStats(
        flows,
        terminalValues: CurrentValueCalculator.terminalValues(
          investments: [gold],
          cashFlows: flows,
          asOf: _today,
        ),
      );
      // 365 days from 2025-10-01 to 2026-10-01: exactly 25%.
      expect(stats.xirr, closeTo(0.25, 1e-6));
      expect(stats.moic, closeTo(1.25, 1e-9));
    });

    test('principal moved after the valuation date is carried forward', () {
      final gold = _investment(
        'gold',
        InvestmentType.gold,
        currentValue: 125000,
        currentValueDate: DateTime(2026, 6, 1),
      );
      final valuation = CurrentValueCalculator.valuationOf(gold, [
        _flow('gold', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
        _flow('gold', CashFlowType.invest, 20000, DateTime(2026, 8, 1)),
        _flow('gold', CashFlowType.returnFlow, 5000, DateTime(2026, 9, 1)),
        _flow('gold', CashFlowType.income, 700, DateTime(2026, 9, 15)),
      ], asOf: _today)!;
      // 1,25,000 + 20,000 − 5,000, dated at the last cash flow.
      expect(valuation.amount, 140000);
      expect(valuation.date, DateTime(2026, 9, 15));
    });

    test('a value dated before the first cash flow is missing, not added '
        'to all the principal', () {
      final plot = _investment(
        'plot',
        InvestmentType.realEstate,
        currentValue: 110000,
        currentValueDate: DateTime(2020, 1, 1),
      );
      final flows = [
        _flow('plot', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
      ];
      expect(
        CurrentValueCalculator.valuationOf(plot, flows, asOf: _today),
        isNull,
      );
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [plot],
        cashFlows: flows,
        asOf: _today,
      );
      expect(terminal.flows, isEmpty);
      expect(terminal.missingValueCount, 1);
    });

    test('a value dated on the first cash flow is used as entered', () {
      final plot = _investment(
        'plot',
        InvestmentType.realEstate,
        currentValue: 110000,
        currentValueDate: DateTime(2025, 10, 2),
      );
      final valuation = CurrentValueCalculator.valuationOf(plot, [
        _flow('plot', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
      ], asOf: _today)!;
      expect(valuation.amount, 110000);
      expect(valuation.date, DateTime(2025, 10, 2));
    });

    test('closed investments never get a terminal value', () {
      final closed = _investment(
        'c',
        InvestmentType.gold,
        status: InvestmentStatus.closed,
        currentValue: 999999,
        currentValueDate: DateTime(2026, 1, 1),
      );
      expect(
        CurrentValueCalculator.valuationOf(closed, [
          _flow('c', CashFlowType.invest, 100000, DateTime(2025, 1, 1)),
          _flow('c', CashFlowType.returnFlow, 110000, DateTime(2025, 12, 1)),
        ], asOf: _today),
        isNull,
      );
    });
  });

  group('Missing current values', () {
    test('an open holding without a value is counted, not valued at 0', () {
      final gold = _investment('gold', InvestmentType.gold);
      final flows = [
        _flow('gold', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
      ];
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [gold, _fdS1],
        cashFlows: [...flows, ..._flowsS1],
        asOf: _today,
      );
      expect(terminal.missingValueCount, 1);
      expect(terminal.flows, hasLength(1));

      final stats = module.calculateStats([
        ...flows,
        ..._flowsS1,
      ], terminalValues: terminal);
      expect(stats.missingValueCount, 1);
      expect(stats.needsCurrentValue, isTrue);
    });

    test('an open holding that has paid back its cost is not missing', () {
      final gold = _investment('gold', InvestmentType.gold);
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [gold],
        cashFlows: [
          _flow('gold', CashFlowType.invest, 100000, DateTime(2025, 1, 1)),
          _flow('gold', CashFlowType.returnFlow, 100000, DateTime(2026, 1, 1)),
        ],
        asOf: _today,
      );
      expect(terminal.missingValueCount, 0);
    });

    test('stats without terminal values keep the cash-only figures', () {
      final stats = module.calculateStats(_flowsS1);
      expect(stats.currentValue, isNull);
      expect(stats.moic, 0);
      expect(stats.missingValueCount, 0);
    });
  });

  // Each cash flow keeps its own currency, which can differ from the
  // investment's (A04). A value is only ever tagged with the currency its
  // amounts are in, so conversion to the base currency is right (rule 2).
  group('Currency of current values', () {
    test('an estimate is in the currency of its cash flows', () {
      final p2p = _investment('p2p', InvestmentType.p2pLending);
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [p2p],
        cashFlows: [
          _flow(
            'p2p',
            CashFlowType.invest,
            1000,
            DateTime(2026, 1, 1),
            currency: 'USD',
          ),
        ],
        asOf: _today,
      );
      expect(terminal.flows, hasLength(1));
      expect(terminal.flows.single.amount, 1000);
      expect(terminal.flows.single.currency, 'USD');
      expect(terminal.missingValueCount, 0);
    });

    test('an accrued estimate is in the currency of its deposits', () {
      final fd = _investment(
        'fd',
        InvestmentType.fixedDeposit,
        rate: 7,
        compounding: CompoundingFrequency.quarterly,
        payout: InterestPayoutMode.cumulative,
      );
      final valuation = CurrentValueCalculator.valuationOf(fd, [
        _flow(
          'fd',
          CashFlowType.invest,
          100000,
          DateTime(2025, 10, 2),
          currency: 'USD',
        ),
      ], asOf: _today)!;
      expect(valuation.currency, 'USD');
      expect(valuation.amount, closeTo(107185.903129, 0.005));
    });

    test('principal in more than one currency is missing, not estimated', () {
      final p2p = _investment('p2p', InvestmentType.p2pLending);
      final flows = [
        _flow('p2p', CashFlowType.invest, 50000, DateTime(2026, 1, 1)),
        _flow(
          'p2p',
          CashFlowType.invest,
          1000,
          DateTime(2026, 2, 1),
          currency: 'USD',
        ),
      ];
      expect(
        CurrentValueCalculator.valuationOf(p2p, flows, asOf: _today),
        isNull,
      );
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [p2p],
        cashFlows: flows,
        asOf: _today,
      );
      expect(terminal.flows, isEmpty);
      expect(terminal.missingValueCount, 1);
    });

    test('a manual value is in the investment currency', () {
      final gold = _investment(
        'gold',
        InvestmentType.gold,
        currency: 'USD',
        currentValue: 1200,
        currentValueDate: DateTime(2026, 9, 1),
      );
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [gold],
        cashFlows: [
          _flow(
            'gold',
            CashFlowType.invest,
            1000,
            DateTime(2026, 1, 1),
            currency: 'USD',
          ),
        ],
        asOf: _today,
      );
      expect(terminal.flows.single.currency, 'USD');
      expect(terminal.flows.single.amount, 1200);
    });

    test('a manual value is not carried forward across currencies', () {
      final gold = _investment(
        'gold',
        InvestmentType.gold,
        currentValue: 125000,
        currentValueDate: DateTime(2026, 6, 1),
      );
      final flows = [
        _flow('gold', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
        _flow(
          'gold',
          CashFlowType.invest,
          1000,
          DateTime(2026, 8, 1),
          currency: 'USD',
        ),
      ];
      expect(
        CurrentValueCalculator.valuationOf(gold, flows, asOf: _today),
        isNull,
      );
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [gold],
        cashFlows: flows,
        asOf: _today,
      );
      expect(terminal.flows, isEmpty);
      expect(terminal.missingValueCount, 1);
    });
  });
}
