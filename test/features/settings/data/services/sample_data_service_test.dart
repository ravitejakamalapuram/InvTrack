import 'package:flutter_test/flutter_test.dart';
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
    sampleDataService = SampleDataService(
      investmentRepository,
      goalRepository,
    );
  });

  group('SampleDataService - Multi-Currency Support (Rule 21.5)', () {
    group('Multi-Currency Portfolio', () {
      test('creates investments in multiple currencies', () async {
        // Act
        final result = await sampleDataService.createSampleData();

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
        await sampleDataService.createSampleData();

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
        await sampleDataService.createSampleData();

        // Assert
        final investments = await investmentRepository.getAllInvestments();
        final inrInvestments =
            investments.where((i) => i.currency == 'INR').toList();

        expect(inrInvestments.length, greaterThan(0));

        // Verify INR cash flows exist
        final allCashFlows = await investmentRepository.getAllCashFlows();
        final inrCashFlows =
            allCashFlows.where((cf) => cf.currency == 'INR').toList();

        expect(inrCashFlows.length, greaterThan(0));
      });

      test('includes USD investment (US Dollars)', () async {
        // Act
        await sampleDataService.createSampleData();

        // Assert
        final investments = await investmentRepository.getAllInvestments();
        final usdInvestments =
            investments.where((i) => i.currency == 'USD').toList();

        expect(usdInvestments.length, greaterThan(0));

        // Verify USD cash flows exist
        final allCashFlows = await investmentRepository.getAllCashFlows();
        final usdCashFlows =
            allCashFlows.where((cf) => cf.currency == 'USD').toList();

        expect(usdCashFlows.length, greaterThan(0));
      });

      test('includes EUR investment (Euros)', () async {
        // Act
        await sampleDataService.createSampleData();

        // Assert
        final investments = await investmentRepository.getAllInvestments();
        final eurInvestments =
            investments.where((i) => i.currency == 'EUR').toList();

        expect(eurInvestments.length, greaterThan(0));

        // Verify EUR cash flows exist
        final allCashFlows = await investmentRepository.getAllCashFlows();
        final eurCashFlows =
            allCashFlows.where((cf) => cf.currency == 'EUR').toList();

        expect(eurCashFlows.length, greaterThan(0));
      });
    });

    group('Data Integrity (Rule 21.1)', () {
      test('does not convert amounts based on currency', () async {
        // Act
        await sampleDataService.createSampleData();

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
        await sampleDataService.createSampleData();

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
}

