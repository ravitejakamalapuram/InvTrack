import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/data/models/goal_model.dart';
import 'package:inv_tracker/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/user_profile/data/models/user_profile_model.dart';

/// Firestore documents written before the multi-currency field existed have
/// no `currency`. They must resolve to the user's base currency, never USD,
/// or an INR amount is converted as dollars (about 88x too high).
void main() {
  final created = Timestamp.fromDate(DateTime(2024, 1, 15));

  group(
    'Firestore mappers: missing currency resolves to the base currency',
    () {
      test('investment document', () {
        final investment =
            FirestoreInvestmentRepository.investmentFromFirestore(
              {
                'name': 'HDFC FD',
                'type': 'fixedDeposit',
                'status': 'open',
                'createdAt': created,
              },
              'inv-1',
              baseCurrency: 'INR',
            );

        expect(investment.currency, 'INR');
      });

      test('cash flow document', () {
        final cashFlow = FirestoreInvestmentRepository.cashFlowFromFirestore(
          {
            'investmentId': 'inv-1',
            'date': created,
            'type': 'INVEST',
            'amount': 100000,
            'createdAt': created,
          },
          'cf-1',
          baseCurrency: 'INR',
        );

        expect(cashFlow.currency, 'INR');
        expect(cashFlow.amount, 100000.0);
      });

      test('goal document', () {
        final goal = GoalModel.fromFirestore(
          {
            'name': 'Retirement',
            'type': 'targetAmount',
            'targetAmount': 1000000,
            'trackingMode': 'all',
            'createdAt': created,
          },
          'goal-1',
          baseCurrency: 'INR',
        );

        expect(goal.currency, 'INR');
      });

      test('expected cash flow document', () {
        final expected =
            FirestoreExpectedCashFlowRepository.expectedCashFlowFromFirestore(
              {
                'investmentId': 'inv-1',
                'expectedDate': created,
                'expectedAmount': 3500,
                'createdAt': created,
              },
              'ecf-1',
              baseCurrency: 'INR',
            );

        expect(expected.currency, 'INR');
      });

      test('user profile document', () {
        final profile = UserProfileModel.fromFirestore(
          {'userId': 'user-1'},
          'user-1',
          baseCurrency: 'INR',
        );

        expect(profile.preferredCurrency, 'INR');
      });

      test('a stored currency is kept as is', () {
        final cashFlow = FirestoreInvestmentRepository.cashFlowFromFirestore(
          {
            'investmentId': 'inv-1',
            'date': created,
            'type': 'INVEST',
            'amount': 1000,
            'createdAt': created,
            'currency': 'USD',
          },
          'cf-2',
          baseCurrency: 'INR',
        );

        expect(cashFlow.currency, 'USD');
      });
    },
  );
}
