// A21 (#769): the health score's returns component is one XIRR over the
// merged base-currency cash flows plus current values (CALC-02), an empty
// portfolio has not enough data for a score, and having no goals is neutral
// rather than a free 100 (ANLY-07).
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';

final _asOf = DateTime(2026, 10, 4);

InvestmentEntity _investment(
  String id,
  InvestmentType type, {
  InvestmentStatus status = InvestmentStatus.open,
  double? expectedRate,
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: status,
  currency: 'INR',
  expectedRate: expectedRate,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

CashFlowEntity _flow(
  String investmentId,
  CashFlowType type,
  double amount,
  DateTime date,
) => CashFlowEntity(
  id: '$investmentId-${date.toIso8601String()}-${type.name}',
  investmentId: investmentId,
  type: type,
  amount: amount,
  currency: 'INR',
  date: date,
  createdAt: date,
);

/// Scores [investments] the way the app does: current values from the A10
/// calculator, stats from the one stats implementation.
PortfolioHealthScore? _score(
  List<InvestmentEntity> investments,
  List<CashFlowEntity> flows,
) {
  final terminalValues = <String, TerminalValues>{
    for (final inv in investments)
      inv.id: CurrentValueCalculator.terminalValues(
        investments: [inv],
        cashFlows: [
          for (final cf in flows)
            if (cf.investmentId == inv.id) cf,
        ],
        asOf: _asOf,
      ),
  };
  return PortfolioHealthCalculator.calculate(
    investments: investments,
    investmentStats: FinancialCalculatorModule().calculateStatsByInvestment(
      flows,
      terminalValues: terminalValues,
    ),
    allCashFlows: flows,
    goalProgress: const [],
    terminalValues: terminalValues,
    asOf: _asOf,
    benchmarkInflationRate: 0.06,
  );
}

void main() {
  test('a single open 7% FD with no goals is not scored Poor by its returns '
      'or its goals', () {
    // ₹1,00,000 on 1 Jul 2026 at 7% compounding yearly: its accrued value on
    // 4 Oct 2026 gives an XIRR of exactly 7%.
    final score = _score(
      [_investment('fd', InvestmentType.fixedDeposit, expectedRate: 7)],
      [_flow('fd', CashFlowType.invest, 100000, DateTime(2026, 7, 1))],
    )!;

    // 7% is 1 point above 6% inflation: 60 + (0.01 / 0.05) × 20 = 64.
    expect(score.returnsPerformance.score, closeTo(64.0, 1e-6));
    // No goals: neutral, neither a penalty nor a free 100.
    expect(score.goalAlignment.score, 50.0);
    // 0.30 × 64 + 0.25 × 0 (one type) + 0.20 × 60 (nothing maturing soon)
    // + 0.15 × 50 + 0.10 × 100 = 48.7.
    expect(score.overallScore, closeTo(48.7, 1e-6));
    expect(score.tier, ScoreTier.fair);
  });

  test('returns use one XIRR over the merged cash flows, not an average of '
      'XIRRs weighted by amount invested', () {
    // CALC-02: A earns 8.000% for a year, B 43.28% for 30 days. Merged-flow
    // XIRR 8.0245734%; the invested-weighted average would be 8.3493091%.
    final score = _score(
      [
        _investment(
          'a',
          InvestmentType.fixedDeposit,
          status: InvestmentStatus.closed,
        ),
        _investment(
          'b',
          InvestmentType.p2pLending,
          status: InvestmentStatus.closed,
        ),
      ],
      [
        _flow('a', CashFlowType.invest, 1000000, DateTime(2025, 1, 1)),
        _flow('a', CashFlowType.returnFlow, 1080000, DateTime(2026, 1, 1)),
        _flow('b', CashFlowType.invest, 10000, DateTime(2025, 6, 1)),
        _flow('b', CashFlowType.returnFlow, 10300, DateTime(2025, 7, 1)),
      ],
    )!;

    // 60 + ((0.0802457339 − 0.06) / 0.05) × 20.
    expect(score.returnsPerformance.score, closeTo(68.09829356, 1e-6));
  });

  test('an empty portfolio has not enough data for a score', () {
    final score = PortfolioHealthCalculator.calculate(
      investments: [],
      investmentStats: {},
      allCashFlows: [],
      goalProgress: [],
      asOf: _asOf,
    );

    expect(score, isNull);
  });

  test('a portfolio whose only holding still needs a current value has not '
      'enough data for a score', () {
    // Gold has no estimate: until the user enters a value its return is
    // unknown (money rule 4), so there is nothing to score returns on.
    final score = _score(
      [_investment('gold', InvestmentType.gold)],
      [_flow('gold', CashFlowType.invest, 100000, DateTime(2026, 1, 15))],
    );

    expect(score, isNull);
  });

  // Review follow-ups: a partial portfolio has no score, a total loss is
  // scored rather than called "not enough data", and short holdings are not
  // annualised (the Overview's ReturnDisplay rules).
  group('review follow-ups', () {
    test('a portfolio with an open holding still awaiting a current value has '
        'not enough data, even when other holdings have a return', () {
      // ₹50,00,000 of gold with no value, next to a closed ₹10,000 P2P loan
      // that returned ₹14,000: scoring the loan alone would judge 0.2% of the
      // money. The Overview shows "Awaiting current value" for this portfolio.
      final score = _score(
        [
          _investment('gold', InvestmentType.gold),
          _investment(
            'p2p',
            InvestmentType.p2pLending,
            status: InvestmentStatus.closed,
          ),
        ],
        [
          _flow('gold', CashFlowType.invest, 5000000, DateTime(2025, 10, 1)),
          _flow('p2p', CashFlowType.invest, 10000, DateTime(2025, 1, 1)),
          _flow('p2p', CashFlowType.returnFlow, 14000, DateTime(2026, 1, 1)),
        ],
      );

      expect(score, isNull);
    });

    test('a closed investment that returned nothing is scored as a total '
        'loss, not as not enough data', () {
      // A fully defaulted P2P loan: the portfolio is fully known.
      final score = _score(
        [
          _investment(
            'p2p',
            InvestmentType.p2pLending,
            status: InvestmentStatus.closed,
          ),
        ],
        [_flow('p2p', CashFlowType.invest, 50000, DateTime(2026, 1, 1))],
      )!;

      // −100%: max(0, 20 + (−1 / 0.20) × 20) = 0.
      expect(score.returnsPerformance.score, 0.0);
      expect(
        score.returnsPerformance.suggestions.first,
        'Negative returns detected. Review underperforming investments',
      );
      // 0.30 × 0 + 0.25 × 0 (one type) + 0.20 × 0 (nothing open)
      // + 0.15 × 50 (no goals) + 0.10 × 100 (nothing open) = 17.5.
      expect(score.overallScore, closeTo(17.5, 1e-6));
    });

    for (final value in [103000.0, 97000.0]) {
      test('a holding of 30 days valued at ₹$value gets a neutral returns '
          'score, not an annualised one', () {
        // ₹1,00,000 of stock on 4 Sep 2026, valued on 4 Oct 2026: ±3% in 30
        // days annualises to about +43% or −31%. The Overview shows "+3.0% in
        // 30 days" (ReturnDisplay.shortHolding) instead.
        final stock = InvestmentEntity(
          id: 'stock',
          name: 'stock',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          currency: 'INR',
          currentValue: value,
          currentValueDate: _asOf,
          createdAt: DateTime(2026, 9, 4),
          updatedAt: DateTime(2026, 10, 4),
        );
        final score = _score(
          [stock],
          [_flow('stock', CashFlowType.invest, 100000, DateTime(2026, 9, 4))],
        )!;

        expect(score.returnsPerformance.score, 50.0);
        // The screen words this from the ARB file; the domain only says why.
        expect(score.returnsPerformance.note, ComponentNote.tooEarlyToJudge);
        expect(score.returnsPerformance.description, isEmpty);
        expect(score.returnsPerformance.suggestions, isEmpty);
        // 0.30 × 50 + 0.25 × 0 + 0.20 × 60 + 0.15 × 50 + 0.10 × 100 = 44.5.
        expect(score.overallScore, closeTo(44.5, 1e-6));
      });
    }
  });
}
