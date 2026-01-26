/// Integration tests for cash flow CRUD operations.
///
/// Tests adding, editing, and deleting cash flows (deposits, withdrawals, income).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cash Flow CRUD Tests', () {
    late TestApp testApp;
    late NavigationRobot navigation;
    late InvestmentRobot investments;
    late CashFlowRobot cashFlows;

    testWidgets('should open add cash flow screen from investment detail', (
      tester,
    ) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv',
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
      cashFlows = CashFlowRobot(tester);

      await navigation.goToInvestments();
      await investments.tapInvestment('Test Investment');

      // Open add cash flow (FAB on detail screen)
      await investments.openAddCashFlow();

      // Verify on cash flow screen
      cashFlows.verifyOnAddCashFlowScreen();
    });

    testWidgets('should add deposit cash flow', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv',
          name: 'FD Investment',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);
      cashFlows = CashFlowRobot(tester);

      await navigation.goToInvestments();
      await investments.tapInvestment('FD Investment');
      await investments.openAddCashFlow();

      // Add deposit
      await cashFlows.addCashFlow(
        type: CashFlowType.invest,
        amount: '50000',
        notes: 'Initial deposit',
      );

      // Should return to detail screen
      await tester.pumpAndSettle();
    });

    testWidgets('should show validation error for empty amount', (
      tester,
    ) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv',
          name: 'Validation Test',
          type: InvestmentType.p2pLending,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);
      cashFlows = CashFlowRobot(tester);

      await navigation.goToInvestments();
      await investments.tapInvestment('Validation Test');
      await investments.openAddCashFlow();

      // Try to submit without amount
      await cashFlows.tapSave();

      // Verify validation error
      cashFlows.verifyAmountRequired();
    });

    testWidgets('should add income cash flow', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv',
          name: 'Income Test',
          type: InvestmentType.p2pLending,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);
      cashFlows = CashFlowRobot(tester);

      await navigation.goToInvestments();
      await investments.tapInvestment('Income Test');
      await investments.openAddCashFlow();

      // Select income type and add
      await cashFlows.selectType(CashFlowType.income);
      await cashFlows.enterAmount('500');
      cashFlows.verifyCashInPreview();
    });
  });
}
