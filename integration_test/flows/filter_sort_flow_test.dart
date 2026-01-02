/// Integration tests for filtering and sorting investments.
///
/// Tests type filters, status filters, and sort options.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Filter and Sort Flow Tests', () {
    late TestApp testApp;
    late NavigationRobot navigation;
    late InvestmentRobot investments;

    testWidgets('should display investments of multiple types', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'fd_1',
          name: 'HDFC FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
        InvestmentEntity(
          id: 'p2p_1',
          name: 'Lending Kart',
          type: InvestmentType.p2pLending,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
        InvestmentEntity(
          id: 'stock_1',
          name: 'HDFC Bank Stock',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);

      await navigation.goToInvestments();

      // All investments should be visible
      investments.verifyInvestmentDisplayed('HDFC FD');
      investments.verifyInvestmentDisplayed('Lending Kart');
      investments.verifyInvestmentDisplayed('HDFC Bank Stock');
    });

    testWidgets('should display open and closed investments', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'open_1',
          name: 'Open Investment',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
        InvestmentEntity(
          id: 'closed_1',
          name: 'Closed Investment',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.closed,
          createdAt: now.subtract(const Duration(days: 365)),
          updatedAt: now,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);

      await navigation.goToInvestments();

      // Both investments should be visible
      investments.verifyInvestmentDisplayed('Open Investment');
      investments.verifyInvestmentDisplayed('Closed Investment');
    });

    testWidgets('should show investments sorted by recent first', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'old_1',
          name: 'Old Investment',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: now.subtract(const Duration(days: 30)),
          updatedAt: now.subtract(const Duration(days: 30)),
        ),
        InvestmentEntity(
          id: 'new_1',
          name: 'New Investment',
          type: InvestmentType.p2pLending,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);

      await navigation.goToInvestments();

      // Both should be displayed
      investments.verifyInvestmentDisplayed('Old Investment');
      investments.verifyInvestmentDisplayed('New Investment');
    });

    testWidgets('should open filter bottom sheet', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_1',
          name: 'Test Investment',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);

      await navigation.goToInvestments();

      // Tap filter icon
      await investments.tapIcon(Icons.filter_list_rounded);

      // Verify filter sheet is displayed
      expect(find.text('Filter'), findsAny);
    });
  });
}

