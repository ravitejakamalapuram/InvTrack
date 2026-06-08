import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/models/cash_flow_interface.dart';
import 'package:inv_tracker/core/calculations/tax_and_basis_calculator.dart';

class SimpleCashFlow implements ICashFlow {
  @override
  final String investmentId;
  @override
  final DateTime date;
  @override
  final double amount;
  @override
  final double signedAmount;
  @override
  final String currency;
  @override
  final CalculationCashFlowType calculationType;

  const SimpleCashFlow({
    required this.investmentId,
    required this.date,
    required this.amount,
    required this.signedAmount,
    required this.currency,
    required this.calculationType,
  });
}

void main() {
  group('TaxAndBasisCalculator Tests', () {
    group('Monthly Buckets Aggregation', () {
      test('aggregates cash flows by month correctly', () {
        final cashFlows = [
          // May 2023
          SimpleCashFlow(
            investmentId: 'inv-1',
            date: DateTime(2023, 5, 15),
            amount: 1000.0,
            signedAmount: -1000.0,
            currency: 'USD',
            calculationType: CalculationCashFlowType.invest,
          ),
          SimpleCashFlow(
            investmentId: 'inv-1',
            date: DateTime(2023, 5, 20),
            amount: 50.0,
            signedAmount: -50.0,
            currency: 'USD',
            calculationType: CalculationCashFlowType.fee,
          ),
          SimpleCashFlow(
            investmentId: 'inv-2',
            date: DateTime(2023, 5, 25),
            amount: 200.0,
            signedAmount: 200.0,
            currency: 'USD',
            calculationType: CalculationCashFlowType.income,
          ),
          // June 2023
          SimpleCashFlow(
            investmentId: 'inv-1',
            date: DateTime(2023, 6, 2),
            amount: 500.0,
            signedAmount: 500.0,
            currency: 'USD',
            calculationType: CalculationCashFlowType.returnFlow,
          ),
        ];

        final buckets = TaxAndBasisCalculator.calculateMonthlyBuckets(cashFlows);

        expect(buckets.length, 2);

        final mayKey = DateTime(2023, 5, 1);
        expect(buckets.containsKey(mayKey), isTrue);
        final mayBucket = buckets[mayKey]!;
        expect(mayBucket.invested, 1000.0);
        expect(mayBucket.fees, 50.0);
        expect(mayBucket.income, 200.0);
        expect(mayBucket.returns, 0.0);
        expect(mayBucket.net, -850.0); // (0 + 200) - (1000 + 50) = 200 - 1050 = -850

        final juneKey = DateTime(2023, 6, 1);
        expect(buckets.containsKey(juneKey), isTrue);
        final juneBucket = buckets[juneKey]!;
        expect(juneBucket.invested, 0.0);
        expect(juneBucket.fees, 0.0);
        expect(juneBucket.income, 0.0);
        expect(juneBucket.returns, 500.0);
        expect(juneBucket.net, 500.0);
      });

      test('returns empty map for empty cash flows list', () {
        final buckets = TaxAndBasisCalculator.calculateMonthlyBuckets([]);
        expect(buckets.isEmpty, isTrue);
      });
    });

    group('Capital Gains Calculation', () {
      test('classifies short-term vs long-term capital gains correctly', () {
        final startDates = {
          'inv-short': DateTime(2023, 1, 1),
          'inv-long': DateTime(2022, 1, 1),
        };

        final cashFlows = [
          // Exit on inv-short within 6 months (Short Term)
          SimpleCashFlow(
            investmentId: 'inv-short',
            date: DateTime(2023, 6, 1),
            amount: 2000.0,
            signedAmount: 2000.0,
            currency: 'USD',
            calculationType: CalculationCashFlowType.returnFlow,
          ),
          // Exit on inv-long after 1.5 years (Long Term)
          SimpleCashFlow(
            investmentId: 'inv-long',
            date: DateTime(2023, 7, 1),
            amount: 5000.0,
            signedAmount: 5000.0,
            currency: 'USD',
            calculationType: CalculationCashFlowType.returnFlow,
          ),
          // An investment flow (should be ignored for capital gains)
          SimpleCashFlow(
            investmentId: 'inv-short',
            date: DateTime(2023, 2, 1),
            amount: 1000.0,
            signedAmount: -1000.0,
            currency: 'USD',
            calculationType: CalculationCashFlowType.invest,
          ),
        ];

        final (shortTerm, longTerm) = TaxAndBasisCalculator.calculateCapitalGains(
          cashFlows: cashFlows,
          investmentStartDates: startDates,
          assumedGainPercentage: 0.15, // 15% gain
        );

        // short-term gains: 2000 * 0.15 = 300
        expect(shortTerm, 300.0);
        // long-term gains: 5000 * 0.15 = 750
        expect(longTerm, 750.0);
      });

      test('returns zero gains if there are no return/exit transactions', () {
        final startDates = {'inv-1': DateTime(2023, 1, 1)};
        final cashFlows = [
          SimpleCashFlow(
            investmentId: 'inv-1',
            date: DateTime(2023, 2, 1),
            amount: 1000.0,
            signedAmount: -1000.0,
            currency: 'USD',
            calculationType: CalculationCashFlowType.invest,
          ),
        ];

        final (shortTerm, longTerm) = TaxAndBasisCalculator.calculateCapitalGains(
          cashFlows: cashFlows,
          investmentStartDates: startDates,
        );

        expect(shortTerm, 0.0);
        expect(longTerm, 0.0);
      });
    });
  });
}
