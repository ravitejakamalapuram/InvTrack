/// Integration tests for cash flow (transaction) form.
///
/// Tests adding deposits, returns, income, and fees to investments.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cash Flow Form Tests', () {
    late TestApp testApp;
    late NavigationRobot navigation;
    late InvestmentRobot investments;
    late CashFlowRobot cashFlows;

    testWidgets('should open add cash flow screen from investment detail', (tester) async {
      testApp = await TestApp.create(tester);

      // Seed an investment
      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv_1',
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

      // Open add transaction
      await investments.openAddTransaction();

      // Verify on add cash flow screen
      cashFlows.verifyOnAddCashFlowScreen();
    });

    testWidgets('should show validation error for empty amount', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv_1',
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
      await investments.openAddTransaction();

      // Try to submit without entering amount
      await cashFlows.tapSave();

      // Verify validation error
      cashFlows.verifyAmountRequired();
    });

    testWidgets('should add invest (deposit) cash flow', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv_1',
          name: 'My FD',
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
      await investments.tapInvestment('My FD');
      await investments.openAddTransaction();

      // Add an investment cash flow
      await cashFlows.addCashFlow(
        type: CashFlowType.invest,
        amount: '10000',
        notes: 'Initial deposit',
      );

      // Verify we're back on detail screen
      investments.verifyOnDetailScreen('My FD');
    });

    testWidgets('should show cash out preview for invest type', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv_1',
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
      await investments.openAddTransaction();

      // Select invest type (default)
      await cashFlows.selectType(CashFlowType.invest);

      // Verify cash out preview
      cashFlows.verifyCashOutPreview();
    });

    testWidgets('should show cash in preview for income type', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv_1',
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
      await investments.openAddTransaction();

      // Select income type
      await cashFlows.selectType(CashFlowType.income);

      // Verify cash in preview
      cashFlows.verifyCashInPreview();
    });
  });
}
