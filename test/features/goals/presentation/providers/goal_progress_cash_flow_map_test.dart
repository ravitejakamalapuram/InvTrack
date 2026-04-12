/// Tests for the cashFlowsByInvestment optimization parameter added in the PR.
///
/// The optimization pre-groups cash flows by investment ID (Map<String, List<CashFlowEntity>>)
/// and passes the map to GoalProgressCalculator methods to avoid O(N*M) linear scans.
/// When the map is provided, it replaces the linear scan through allCashFlows.
/// When null, the original O(N*M) path using allCashFlows is used.
///
/// These tests verify:
/// 1. Both code paths (map vs. linear scan) produce identical results.
/// 2. The map correctly filters flows to only linked investments.
/// 3. Edge cases: empty maps, missing keys, no linked investments.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../../../../mocks/mock_currency_conversion_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GoalEntity _makeGoal({
  String id = 'goal1',
  GoalType type = GoalType.targetAmount,
  double targetAmount = 10000,
  GoalTrackingMode trackingMode = GoalTrackingMode.selected,
  List<String> linkedInvestmentIds = const ['inv1'],
  List<InvestmentType> linkedTypes = const [],
  String currency = 'USD',
  bool isArchived = false,
}) {
  return GoalEntity(
    id: id,
    name: 'Test Goal',
    type: type,
    targetAmount: targetAmount,
    trackingMode: trackingMode,
    linkedInvestmentIds: linkedInvestmentIds,
    linkedTypes: linkedTypes,
    icon: '🎯',
    colorValue: 0xFF3B82F6,
    isArchived: isArchived,
    currency: currency,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

InvestmentEntity _makeInvestment({
  String id = 'inv1',
  InvestmentType type = InvestmentType.stocks,
  InvestmentStatus status = InvestmentStatus.open,
  String currency = 'USD',
}) {
  return InvestmentEntity(
    id: id,
    name: 'Test Investment',
    type: type,
    status: status,
    currency: currency,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

CashFlowEntity _makeCashFlow({
  required String id,
  required String investmentId,
  required CashFlowType type,
  required double amount,
  DateTime? date,
  String currency = 'USD',
}) {
  return CashFlowEntity(
    id: id,
    investmentId: investmentId,
    type: type,
    amount: amount,
    currency: currency,
    date: date ?? DateTime(2024, 6, 1),
    createdAt: DateTime(2024, 1, 1),
  );
}

/// Pre-group cash flows into a map, matching the production optimization.
Map<String, List<CashFlowEntity>> _buildCashFlowMap(
  List<CashFlowEntity> cashFlows,
) {
  final map = <String, List<CashFlowEntity>>{};
  for (final cf in cashFlows) {
    map.putIfAbsent(cf.investmentId, () => []).add(cf);
  }
  return map;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // GoalProgressCalculator.calculate()
  // ---------------------------------------------------------------------------
  group('GoalProgressCalculator.calculate() – cashFlowsByInvestment', () {
    test(
      'produces identical result when map is provided vs. when it is null',
      () {
        final goal = _makeGoal(linkedInvestmentIds: ['inv1']);
        final investment = _makeInvestment(id: 'inv1');
        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.invest,
            amount: 5000,
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 2500,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final resultWithoutMap = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
        );
        final resultWithMap = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        expect(
          resultWithMap.currentAmount,
          closeTo(resultWithoutMap.currentAmount, 0.001),
          reason: 'currentAmount must match between both code paths',
        );
        expect(
          resultWithMap.progressPercent,
          closeTo(resultWithoutMap.progressPercent, 0.001),
          reason: 'progressPercent must match between both code paths',
        );
        expect(
          resultWithMap.linkedInvestmentCount,
          equals(resultWithoutMap.linkedInvestmentCount),
        );
      },
    );

    test(
      'only includes flows belonging to linked investments when map is provided',
      () {
        final goal = _makeGoal(linkedInvestmentIds: ['inv1']);
        final investment1 = _makeInvestment(id: 'inv1');
        final investment2 = _makeInvestment(id: 'inv2');

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 3000,
          ),
          // This flow belongs to inv2 which is NOT linked to the goal
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv2',
            type: CashFlowType.returnFlow,
            amount: 9999,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final result = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment1, investment2],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        // Only inv1's flow (3000) should count
        expect(result.currentAmount, closeTo(3000, 0.001));
      },
    );

    test(
      'returns zero progress when cashFlowsByInvestment is an empty map',
      () {
        final goal = _makeGoal(linkedInvestmentIds: ['inv1']);
        final investment = _makeInvestment(id: 'inv1');

        final result = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: const [],
          cashFlowsByInvestment: const {},
        );

        expect(result.currentAmount, equals(0.0));
        expect(result.progressPercent, equals(0.0));
      },
    );

    test(
      'handles map that does not contain the linked investment ID (no flows)',
      () {
        final goal = _makeGoal(linkedInvestmentIds: ['inv1']);
        final investment = _makeInvestment(id: 'inv1');

        // Map exists but has no entry for 'inv1'
        final emptyMap = {'inv_other': <CashFlowEntity>[]};

        final result = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: const [],
          cashFlowsByInvestment: emptyMap,
        );

        expect(result.currentAmount, equals(0.0));
        expect(result.linkedInvestmentCount, equals(1));
      },
    );

    test(
      'aggregates flows from multiple linked investments when map is provided',
      () {
        final goal = _makeGoal(linkedInvestmentIds: ['inv1', 'inv2']);
        final investment1 = _makeInvestment(id: 'inv1');
        final investment2 = _makeInvestment(id: 'inv2');

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 1000,
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv2',
            type: CashFlowType.returnFlow,
            amount: 2000,
          ),
          _makeCashFlow(
            id: 'cf3',
            investmentId: 'inv1',
            type: CashFlowType.income,
            amount: 500,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final result = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment1, investment2],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        // Returns + income = 1000 + 2000 + 500 = 3500
        expect(result.currentAmount, closeTo(3500, 0.001));
        expect(result.linkedInvestmentCount, equals(2));
      },
    );

    test(
      'GoalTrackingMode.all: map path includes flows from all investments',
      () {
        final goal = _makeGoal(
          trackingMode: GoalTrackingMode.all,
          linkedInvestmentIds: const [],
        );
        final investment1 = _makeInvestment(id: 'inv1');
        final investment2 = _makeInvestment(id: 'inv2');

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 800,
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv2',
            type: CashFlowType.returnFlow,
            amount: 400,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final resultNull = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment1, investment2],
          allCashFlows: cashFlows,
        );
        final resultMap = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment1, investment2],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        expect(
          resultMap.currentAmount,
          closeTo(resultNull.currentAmount, 0.001),
          reason: 'GoalTrackingMode.all must produce identical results',
        );
        expect(resultMap.currentAmount, closeTo(1200, 0.001));
      },
    );

    test(
      'GoalTrackingMode.byType: map path produces identical results to null path',
      () {
        final goal = _makeGoal(
          trackingMode: GoalTrackingMode.byType,
          linkedTypes: [InvestmentType.fixedDeposit],
          linkedInvestmentIds: const [],
        );
        final fdInvestment = _makeInvestment(
          id: 'inv1',
          type: InvestmentType.fixedDeposit,
        );
        final stockInvestment = _makeInvestment(
          id: 'inv2',
          type: InvestmentType.stocks,
        );

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 600,
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv2',
            type: CashFlowType.returnFlow,
            amount: 9000,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final resultNull = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [fdInvestment, stockInvestment],
          allCashFlows: cashFlows,
        );
        final resultMap = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [fdInvestment, stockInvestment],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        expect(
          resultMap.currentAmount,
          closeTo(resultNull.currentAmount, 0.001),
          reason: 'byType mode must produce identical results',
        );
        // Only fixedDeposit flows (600) should be counted
        expect(resultMap.currentAmount, closeTo(600, 0.001));
      },
    );

    test(
      'income goal: map path calculates monthly income the same as null path',
      () {
        final goal = _makeGoal(
          type: GoalType.incomeTarget,
          targetAmount: 60000,
          trackingMode: GoalTrackingMode.selected,
          linkedInvestmentIds: ['inv1'],
        );
        final investment = _makeInvestment(id: 'inv1');

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.income,
            amount: 5000,
            date: DateTime(2024, 1, 1),
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv1',
            type: CashFlowType.income,
            amount: 5000,
            date: DateTime(2024, 2, 1),
          ),
          _makeCashFlow(
            id: 'cf3',
            investmentId: 'inv1',
            type: CashFlowType.invest,
            amount: 100000,
            date: DateTime(2024, 1, 1),
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final resultNull = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
        );
        final resultMap = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        expect(
          resultMap.monthlyIncome,
          closeTo(resultNull.monthlyIncome, 0.001),
          reason: 'monthly income must match between code paths',
        );
        expect(
          resultMap.progressPercent,
          closeTo(resultNull.progressPercent, 0.001),
        );
      },
    );

    test(
      'unlinked investment flows are excluded even when map is provided',
      () {
        // Goal only tracks inv1, but map also contains inv3 flows
        final goal = _makeGoal(linkedInvestmentIds: ['inv1']);
        final investment1 = _makeInvestment(id: 'inv1');
        final investment3 = _makeInvestment(id: 'inv3');

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 1000,
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv3',
            type: CashFlowType.returnFlow,
            amount: 99999,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final result = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment1, investment3],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        // Only inv1's flow should count (inv3 is not linked)
        expect(result.currentAmount, closeTo(1000, 0.001));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // GoalProgressCalculator.getLastActivityDate()
  // ---------------------------------------------------------------------------
  group('GoalProgressCalculator.getLastActivityDate() – cashFlowsByInvestment', () {
    test(
      'returns the same max date whether map is provided or not',
      () {
        final goal = _makeGoal(linkedInvestmentIds: ['inv1']);
        final investment = _makeInvestment(id: 'inv1');

        final date1 = DateTime(2024, 3, 1);
        final date2 = DateTime(2024, 9, 15); // Latest
        final date3 = DateTime(2024, 1, 10);

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.invest,
            amount: 100,
            date: date1,
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 200,
            date: date2,
          ),
          _makeCashFlow(
            id: 'cf3',
            investmentId: 'inv1',
            type: CashFlowType.income,
            amount: 50,
            date: date3,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final dateWithoutMap = GoalProgressCalculator.getLastActivityDate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
        );
        final dateWithMap = GoalProgressCalculator.getLastActivityDate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        expect(dateWithMap, equals(dateWithoutMap));
        expect(dateWithMap, equals(date2)); // date2 is the latest
      },
    );

    test(
      'returns null when cashFlowsByInvestment has no entry for linked investment',
      () {
        final goal = _makeGoal(linkedInvestmentIds: ['inv1']);
        final investment = _makeInvestment(id: 'inv1');

        // Map exists but doesn't have 'inv1'
        final map = <String, List<CashFlowEntity>>{'inv_other': []};

        final result = GoalProgressCalculator.getLastActivityDate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: const [],
          cashFlowsByInvestment: map,
        );

        expect(result, isNull);
      },
    );

    test(
      'returns null when linked investments list is empty',
      () {
        // Goal with no linked investments at all
        final goal = _makeGoal(
          trackingMode: GoalTrackingMode.selected,
          linkedInvestmentIds: const [],
        );

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.invest,
            amount: 100,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final result = GoalProgressCalculator.getLastActivityDate(
          goal: goal,
          allInvestments: const [],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        expect(result, isNull);
      },
    );

    test(
      'returns null when cashFlowsByInvestment map is empty',
      () {
        final goal = _makeGoal(linkedInvestmentIds: ['inv1']);
        final investment = _makeInvestment(id: 'inv1');

        final result = GoalProgressCalculator.getLastActivityDate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: const [],
          cashFlowsByInvestment: const {},
        );

        expect(result, isNull);
      },
    );

    test(
      'returns correct max date across multiple linked investments using map',
      () {
        final goal = _makeGoal(linkedInvestmentIds: ['inv1', 'inv2']);
        final investment1 = _makeInvestment(id: 'inv1');
        final investment2 = _makeInvestment(id: 'inv2');

        final earlyDate = DateTime(2024, 2, 1);
        final laterDate = DateTime(2024, 11, 30); // Latest

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.invest,
            amount: 100,
            date: earlyDate,
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv2',
            type: CashFlowType.returnFlow,
            amount: 200,
            date: laterDate,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final result = GoalProgressCalculator.getLastActivityDate(
          goal: goal,
          allInvestments: [investment1, investment2],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        expect(result, equals(laterDate));
      },
    );

    test(
      'excludes flows from non-linked investments when using map',
      () {
        final goal = _makeGoal(linkedInvestmentIds: ['inv1']);
        final investment1 = _makeInvestment(id: 'inv1');
        final investment2 = _makeInvestment(id: 'inv2');

        final linkedDate = DateTime(2024, 5, 1);
        final unlinkedDate = DateTime(2024, 12, 31); // Would be max, but unlinked

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.invest,
            amount: 100,
            date: linkedDate,
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv2',
            type: CashFlowType.returnFlow,
            amount: 200,
            date: unlinkedDate,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final result = GoalProgressCalculator.getLastActivityDate(
          goal: goal,
          allInvestments: [investment1, investment2],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        // Should only pick up inv1's date, not inv2's
        expect(result, equals(linkedDate));
      },
    );

    test(
      'REGRESSION: null path and map path agree when goal has multiple investments',
      () {
        // Regression test: ensures the optimization does not change semantics
        // when processing multiple investments with many cash flows each.
        final goal = _makeGoal(linkedInvestmentIds: ['inv1', 'inv2', 'inv3']);
        final investments = [
          _makeInvestment(id: 'inv1'),
          _makeInvestment(id: 'inv2'),
          _makeInvestment(id: 'inv3'),
        ];

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.invest,
            amount: 1000,
            date: DateTime(2024, 1, 1),
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv2',
            type: CashFlowType.returnFlow,
            amount: 500,
            date: DateTime(2024, 6, 15),
          ),
          _makeCashFlow(
            id: 'cf3',
            investmentId: 'inv3',
            type: CashFlowType.income,
            amount: 200,
            date: DateTime(2024, 3, 10),
          ),
          _makeCashFlow(
            id: 'cf4',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 1200,
            date: DateTime(2024, 8, 20),
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final dateNull = GoalProgressCalculator.getLastActivityDate(
          goal: goal,
          allInvestments: investments,
          allCashFlows: cashFlows,
        );
        final dateMap = GoalProgressCalculator.getLastActivityDate(
          goal: goal,
          allInvestments: investments,
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        expect(dateMap, equals(dateNull));
        expect(dateMap, equals(DateTime(2024, 8, 20)));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // GoalProgressCalculator.calculateMultiCurrency()
  // ---------------------------------------------------------------------------
  group('GoalProgressCalculator.calculateMultiCurrency() – cashFlowsByInvestment', () {
    late MockCurrencyConversionService mockConversionService;
    late BatchCurrencyConverter batchConverter;

    setUp(() {
      mockConversionService = MockCurrencyConversionService();
      batchConverter = BatchCurrencyConverter(mockConversionService);
    });

    test(
      'produces identical result when map is provided vs. when it is null',
      () async {
        final goal = _makeGoal(
          linkedInvestmentIds: ['inv1'],
          currency: 'USD',
          targetAmount: 10000,
        );
        final investment = _makeInvestment(id: 'inv1', currency: 'USD');
        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.invest,
            amount: 5000,
            currency: 'USD',
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 3000,
            currency: 'USD',
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final resultNull =
            await GoalProgressCalculator.calculateMultiCurrency(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
          batchConverter: batchConverter,
          baseCurrency: 'USD',
        );
        final resultMap = await GoalProgressCalculator.calculateMultiCurrency(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
          batchConverter: batchConverter,
          baseCurrency: 'USD',
        );

        expect(
          resultMap.progressPercent,
          closeTo(resultNull.progressPercent, 0.001),
          reason:
              'calculateMultiCurrency must produce identical % with or without map',
        );
        expect(
          resultMap.currentAmount,
          closeTo(resultNull.currentAmount, 0.001),
        );
      },
    );

    test(
      'only counts flows for linked investments when map is provided',
      () async {
        final goal = _makeGoal(
          linkedInvestmentIds: ['inv1'],
          currency: 'USD',
          targetAmount: 5000,
        );
        final investment1 = _makeInvestment(id: 'inv1', currency: 'USD');
        final investment2 = _makeInvestment(id: 'inv2', currency: 'USD');

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 2500,
            currency: 'USD',
          ),
          // inv2 is not linked to the goal
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv2',
            type: CashFlowType.returnFlow,
            amount: 9999,
            currency: 'USD',
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final result = await GoalProgressCalculator.calculateMultiCurrency(
          goal: goal,
          allInvestments: [investment1, investment2],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
          batchConverter: batchConverter,
          baseCurrency: 'USD',
        );

        // Only inv1's 2500 should contribute → 2500 / 5000 = 50%
        expect(result.progressPercent, closeTo(50.0, 0.1));
        expect(result.currentAmount, closeTo(2500, 1));
      },
    );

    test(
      'returns zero progress when cashFlowsByInvestment is empty map',
      () async {
        final goal = _makeGoal(
          linkedInvestmentIds: ['inv1'],
          currency: 'USD',
          targetAmount: 10000,
        );
        final investment = _makeInvestment(id: 'inv1', currency: 'USD');

        final result = await GoalProgressCalculator.calculateMultiCurrency(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: const [],
          cashFlowsByInvestment: const {},
          batchConverter: batchConverter,
          baseCurrency: 'USD',
        );

        expect(result.currentAmount, equals(0.0));
        expect(result.progressPercent, equals(0.0));
      },
    );

    test(
      'progress % remains stable across currency changes when using map',
      () async {
        final goal = _makeGoal(
          linkedInvestmentIds: ['inv1'],
          currency: 'USD',
          targetAmount: 10000,
        );
        final investment = _makeInvestment(id: 'inv1', currency: 'USD');
        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.invest,
            amount: 8000,
            currency: 'USD',
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 2500,
            currency: 'USD',
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final progressUSD = await GoalProgressCalculator.calculateMultiCurrency(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
          batchConverter: batchConverter,
          baseCurrency: 'USD',
        );
        final progressINR = await GoalProgressCalculator.calculateMultiCurrency(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
          batchConverter: batchConverter,
          baseCurrency: 'INR',
        );

        // Progress % must be currency-invariant (Rule 21.3)
        expect(
          (progressUSD.progressPercent - progressINR.progressPercent).abs(),
          lessThan(0.5),
          reason:
              'Progress % must remain stable when switching USD↔INR (Rule 21.3)',
        );
        expect(progressUSD.progressPercent, closeTo(25.0, 0.1));
      },
    );

    test(
      'map and null paths agree for multi-investment goal',
      () async {
        final goal = _makeGoal(
          linkedInvestmentIds: ['inv1', 'inv2'],
          currency: 'USD',
          targetAmount: 20000,
        );
        final investment1 = _makeInvestment(id: 'inv1', currency: 'USD');
        final investment2 = _makeInvestment(id: 'inv2', currency: 'USD');

        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 4000,
            currency: 'USD',
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv2',
            type: CashFlowType.returnFlow,
            amount: 6000,
            currency: 'USD',
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final resultNull =
            await GoalProgressCalculator.calculateMultiCurrency(
          goal: goal,
          allInvestments: [investment1, investment2],
          allCashFlows: cashFlows,
          batchConverter: batchConverter,
          baseCurrency: 'USD',
        );
        final resultMap = await GoalProgressCalculator.calculateMultiCurrency(
          goal: goal,
          allInvestments: [investment1, investment2],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
          batchConverter: batchConverter,
          baseCurrency: 'USD',
        );

        expect(
          resultMap.currentAmount,
          closeTo(resultNull.currentAmount, 0.001),
        );
        expect(
          resultMap.progressPercent,
          closeTo(resultNull.progressPercent, 0.001),
        );
        // (4000 + 6000) / 20000 = 50%
        expect(resultMap.progressPercent, closeTo(50.0, 0.1));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Boundary / regression tests
  // ---------------------------------------------------------------------------
  group('GoalProgressCalculator – boundary cases for cashFlowsByInvestment', () {
    test(
      'BOUNDARY: single cash flow of type invest does not count toward progress',
      () {
        // invest flows are costs, not progress for corpus goals
        final goal = _makeGoal(
          linkedInvestmentIds: ['inv1'],
          targetAmount: 10000,
        );
        final investment = _makeInvestment(id: 'inv1');
        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.invest,
            amount: 5000,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final result = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        // Only returns/income count as progress; invest flows are excluded
        expect(result.currentAmount, equals(0.0));
        expect(result.progressPercent, equals(0.0));
      },
    );

    test(
      'BOUNDARY: fee flows do not count toward progress',
      () {
        final goal = _makeGoal(
          linkedInvestmentIds: ['inv1'],
          targetAmount: 10000,
        );
        final investment = _makeInvestment(id: 'inv1');
        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.fee,
            amount: 500,
          ),
          _makeCashFlow(
            id: 'cf2',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 2000,
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final result = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        // Only returnFlow counts toward corpus goal progress
        expect(result.currentAmount, closeTo(2000, 0.001));
      },
    );

    test(
      'REGRESSION: both paths produce status=achieved when currentAmount >= targetAmount',
      () {
        final goal = _makeGoal(
          linkedInvestmentIds: ['inv1'],
          targetAmount: 1000,
        );
        final investment = _makeInvestment(id: 'inv1');
        final cashFlows = [
          _makeCashFlow(
            id: 'cf1',
            investmentId: 'inv1',
            type: CashFlowType.returnFlow,
            amount: 1500, // Exceeds target
          ),
        ];
        final map = _buildCashFlowMap(cashFlows);

        final resultNull = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
        );
        final resultMap = GoalProgressCalculator.calculate(
          goal: goal,
          allInvestments: [investment],
          allCashFlows: cashFlows,
          cashFlowsByInvestment: map,
        );

        expect(resultNull.status, equals(GoalStatus.achieved));
        expect(resultMap.status, equals(GoalStatus.achieved));
        expect(resultMap.progressPercent, closeTo(100.0, 0.001));
      },
    );
  });
}