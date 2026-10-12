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
        expect(investment.currencyAssumed, isTrue);
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
        expect(cashFlow.currencyAssumed, isTrue);
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
        expect(goal.currencyAssumed, isTrue);
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
        expect(cashFlow.currencyAssumed, isFalse);
      });

      test('a stored currency is not marked as assumed (all three)', () {
        final investment =
            FirestoreInvestmentRepository.investmentFromFirestore(
              {
                'name': 'US ETF',
                'type': 'stocks',
                'status': 'open',
                'createdAt': created,
                'currency': 'EUR',
              },
              'inv-2',
              baseCurrency: 'INR',
            );
        final goal = GoalModel.fromFirestore(
          {
            'name': 'House',
            'type': 'targetAmount',
            'targetAmount': 1000,
            'trackingMode': 'all',
            'createdAt': created,
            'currency': 'EUR',
          },
          'goal-2',
          baseCurrency: 'INR',
        );

        expect(investment.currency, 'EUR');
        expect(investment.currencyAssumed, isFalse);
        expect(goal.currency, 'EUR');
        expect(goal.currencyAssumed, isFalse);
      });

      test('choosing a currency on an assumed record clears the mark', () {
        final cashFlow = FirestoreInvestmentRepository.cashFlowFromFirestore(
          {
            'investmentId': 'inv-1',
            'date': created,
            'type': 'INVEST',
            'amount': 100,
            'createdAt': created,
          },
          'cf-3',
          baseCurrency: 'INR',
        );

        expect(cashFlow.copyWith(notes: 'n').currencyAssumed, isTrue);
        expect(cashFlow.copyWith(currency: 'USD').currencyAssumed, isFalse);
      });
    },
  );
}
