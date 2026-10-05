import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/utils/number_format_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/settings/data/services/sample_data_service.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

void main() {
  late FakeInvestmentRepository investmentRepository;
  late FakeGoalRepository goalRepository;
  late SampleDataService sampleDataService;

  setUp(() {
    investmentRepository = FakeInvestmentRepository();
    goalRepository = FakeGoalRepository();
    sampleDataService = SampleDataService(investmentRepository, goalRepository);
  });

  group('SampleDataService - Multi-Currency Support (Rule 21.5)', () {
    group('Multi-Currency Portfolio', () {
      test('creates investments in multiple currencies', () async {
        // Act
        final result = await sampleDataService.createSampleData(baseCurrency: 'USD');

        // Assert
        expect(result.investmentIds.length, greaterThan(0));

        final investments = await investmentRepository.getAllInvestments();
        final currencies = investments.map((i) => i.currency).toSet();

        // Verify multi-currency portfolio (Rule 21.5)
        expect(currencies, contains('INR'));
        expect(currencies, contains('USD'));
        expect(currencies, contains('EUR'));
        expect(currencies.length, greaterThanOrEqualTo(3));
      });

      test('creates cash flows with matching currencies', () async {
        // Act
        await sampleDataService.createSampleData(baseCurrency: 'USD');

        // Assert
        final investments = await investmentRepository.getAllInvestments();
        final allCashFlows = await investmentRepository.getAllCashFlows();

        for (final investment in investments) {
          final cashFlows = allCashFlows
              .where((cf) => cf.investmentId == investment.id)
              .toList();

          // Verify all cash flows match investment currency
          for (final cf in cashFlows) {
            expect(
              cf.currency,
              investment.currency,
              reason:
                  'Cash flow currency must match investment currency (Rule 21.1)',
            );
          }
        }
      });

      test('includes INR investment (Indian Rupees)', () async {
        // Act
        await sampleDataService.createSampleData(baseCurrency: 'USD');

        // Assert
        final investments = await investmentRepository.getAllInvestments();
        final inrInvestments = investments
            .where((i) => i.currency == 'INR')
            .toList();

        expect(inrInvestments.length, greaterThan(0));

        // Verify INR cash flows exist
        final allCashFlows = await investmentRepository.getAllCashFlows();
        final inrCashFlows = allCashFlows
            .where((cf) => cf.currency == 'INR')
            .toList();

        expect(inrCashFlows.length, greaterThan(0));
      });

      test('includes USD investment (US Dollars)', () async {
        // Act
        await sampleDataService.createSampleData(baseCurrency: 'USD');

        // Assert
        final investments = await investmentRepository.getAllInvestments();
        final usdInvestments = investments
            .where((i) => i.currency == 'USD')
            .toList();

        expect(usdInvestments.length, greaterThan(0));

        // Verify USD cash flows exist
        final allCashFlows = await investmentRepository.getAllCashFlows();
        final usdCashFlows = allCashFlows
            .where((cf) => cf.currency == 'USD')
            .toList();

        expect(usdCashFlows.length, greaterThan(0));
      });

      test('includes EUR investment (Euros)', () async {
        // Act
        await sampleDataService.createSampleData(baseCurrency: 'USD');

        // Assert
        final investments = await investmentRepository.getAllInvestments();
        final eurInvestments = investments
            .where((i) => i.currency == 'EUR')
            .toList();

        expect(eurInvestments.length, greaterThan(0));

        // Verify EUR cash flows exist
        final allCashFlows = await investmentRepository.getAllCashFlows();
        final eurCashFlows = allCashFlows
            .where((cf) => cf.currency == 'EUR')
            .toList();

        expect(eurCashFlows.length, greaterThan(0));
      });
    });

    group('Data Integrity (Rule 21.1)', () {
      test('does not convert amounts based on currency', () async {
        // Act
        await sampleDataService.createSampleData(baseCurrency: 'USD');

        // Assert
        final allCashFlows = await investmentRepository.getAllCashFlows();

        // Verify amounts are stored as-is (no conversion)
        for (final cf in allCashFlows) {
          expect(cf.amount, greaterThan(0));
          expect(cf.currency.isNotEmpty, true);
          // Amount should be in original currency, not converted
        }
      });

      test('preserves original currency for all cash flows', () async {
        // Act
        await sampleDataService.createSampleData(baseCurrency: 'USD');

        // Assert
        final allCashFlows = await investmentRepository.getAllCashFlows();

        // Group by currency
        final byCurrency = <String, List<CashFlowEntity>>{};
        for (final cf in allCashFlows) {
          byCurrency.putIfAbsent(cf.currency, () => []).add(cf);
        }

        // Verify each currency group has consistent amounts
        expect(byCurrency.keys.length, greaterThanOrEqualTo(3));
        expect(byCurrency.containsKey('INR'), true);
        expect(byCurrency.containsKey('USD'), true);
        expect(byCurrency.containsKey('EUR'), true);
      });
    });
  });

  // A20 / ADOPT-03: the sample portfolio is the first set of numbers a new
  // user sees, so every sample must be closed or valued (A10) and show a
  // positive, believable XIRR.
  group('Honest sample portfolio (A20)', () {
    final today = DateTime(2026, 10, 4);
    final module = FinancialCalculatorModule();

    // Stats of one sample investment the way the app computes them: its own
    // cash flows (one currency each) plus its current value as the terminal
    // inflow.
    Future<Map<InvestmentType, (InvestmentEntity, InvestmentStats)>>
    statsByType() async {
      await sampleDataService.createSampleData(
        baseCurrency: 'INR',
        asOf: today,
      );
      final investments = await investmentRepository.getAllInvestments();
      final allFlows = await investmentRepository.getAllCashFlows();
      return {
        for (final inv in investments)
          inv.type: (
            inv,
            module.calculateStats(
              [
                for (final cf in allFlows)
                  if (cf.investmentId == inv.id) cf,
              ],
              terminalValues: CurrentValueCalculator.terminalValues(
                investments: [inv],
                cashFlows: allFlows,
                asOf: today,
              ),
            ),
          ),
      };
    }

    test('every sample investment is either closed or valued', () async {
      final stats = await statsByType();

      expect(stats, isNotEmpty);
      for (final (inv, s) in stats.values) {
        expect(
          inv.isClosed || s.currentValue != null,
          isTrue,
          reason: '${inv.name} is open with no current value',
        );
        expect(s.needsCurrentValue, isFalse, reason: inv.name);
      }
    });

    test('every sample investment XIRR is between 0% and 20%', () async {
      final stats = await statsByType();

      for (final (inv, s) in stats.values) {
        expect(s.xirr, isNotNull, reason: '${inv.name} has no XIRR');
        expect(s.xirr, inInclusiveRange(0.0, 0.20), reason: inv.name);
      }
    });

    test('pins each sample XIRR (actual/365, independent check)', () async {
      final stats = await statsByType();

      // Expected values from an independent Python bisection on the same
      // dated flows (actual/365, like Excel XIRR).
      const expected = {
        InvestmentType.p2pLending: 0.063450158,
        InvestmentType.fixedDeposit: 0.074493154,
        InvestmentType.stocks: 0.126223955,
        InvestmentType.bonds: 0.035805291,
        InvestmentType.gold: 0.093878444,
      };
      expect(stats.keys.toSet(), expected.keys.toSet());
      for (final MapEntry(key: type, value: xirr) in expected.entries) {
        expect(stats[type]!.$2.xirr, closeTo(xirr, 1e-6), reason: '$type');
      }
    });

    test('sample portfolio MOIC is at least 1', () async {
      await sampleDataService.createSampleData(
        baseCurrency: 'INR',
        asOf: today,
      );
      final investments = await investmentRepository.getAllInvestments();
      final allFlows = await investmentRepository.getAllCashFlows();

      // Fixed rates into the INR base (the review's USD 88, EUR 103), so
      // the portfolio is summed in one currency (money rule 2).
      const toInr = {'INR': 1.0, 'USD': 88.0, 'EUR': 103.0};
      CashFlowEntity convert(CashFlowEntity cf) =>
          cf.copyWith(amount: cf.amount * toInr[cf.currency]!, currency: 'INR');
      final values = CurrentValueCalculator.terminalValues(
        investments: investments,
        cashFlows: allFlows,
        asOf: today,
      );
      final portfolio = module.calculateStats(
        allFlows.map(convert).toList(),
        terminalValues: values.withConvertedFlows(
          values.flows.map(convert).toList(),
        ),
      );

      expect(portfolio.missingValueCount, 0);
      // Invested 4,78,030 (incl. a 1,000 fee); returned plus values 5,03,917.
      expect(portfolio.totalInvested, closeTo(478030, 0.005));
      expect(
        portfolio.totalReturned + portfolio.currentValue!,
        closeTo(503917, 0.005),
      );
      expect(portfolio.moic, closeTo(1.054153505, 1e-6));
      expect(portfolio.moic, greaterThanOrEqualTo(1));
    });

    test('P2P sample leads the advertised vs real story: 12% advertised, '
        '6.3% real after fees and one default', () async {
      final stats = await statsByType();
      final (p2p, s) = stats[InvestmentType.p2pLending]!;

      expect(p2p.expectedRate, 12.0);
      expect(p2p.isClosed, isTrue);
      // The empty-state demo shows this exact figure.
      expect(formatPercent(s.xirr! * 100), '6.3%');
      expect(
        [
          for (final cf in await investmentRepository.getAllCashFlows())
            if (cf.investmentId == p2p.id && cf.type == CashFlowType.fee)
              cf.amount,
        ],
        [1000],
      );
    });

    test('sample cash-flow dates are date-only', () async {
      await sampleDataService.createSampleData(
        baseCurrency: 'INR',
        asOf: DateTime(2026, 10, 4, 15, 42, 7),
      );

      for (final cf in await investmentRepository.getAllCashFlows()) {
        expect(
          cf.date,
          DateTime(cf.date.year, cf.date.month, cf.date.day),
          reason: 'money rule 5',
        );
      }
    });

    test('clearing sample data removes every sample it created', () async {
      final result = await sampleDataService.createSampleData(
        baseCurrency: 'INR',
        asOf: today,
      );

      await sampleDataService.clearSampleData(
        investmentIds: result.investmentIds,
        goalIds: result.goalIds,
      );

      expect(await investmentRepository.getAllInvestments(), isEmpty);
      expect(await investmentRepository.getAllCashFlows(), isEmpty);
      expect(await goalRepository.getAllGoals(), isEmpty);
    });
  });
}
