/// Integration tests for investment form flows.
///
/// Tests add/edit investment form with validation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Investment Form Flow Tests', () {
    late TestApp testApp;
    late NavigationRobot navigation;
    late InvestmentRobot investments;

    testWidgets('should open add investment form from FAB', (tester) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);

      // Navigate to investments
      await navigation.goToInvestments();

      // Open add investment form
      await investments.openAddInvestment();

      // Verify form is displayed
      investments.verifyOnAddInvestmentScreen();
    });

    testWidgets('should show validation error for empty name', (tester) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);

      await navigation.goToInvestments();
      await investments.openAddInvestment();

      // Try to submit without entering name
      await investments.tapSave();

      // Verify validation error
      investments.verifyValidationError('Please enter a name');
    });

    testWidgets('should successfully add investment with all fields', (
      tester,
    ) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);

      await navigation.goToInvestments();

      // Add investment with type, name, and notes
      await investments.addInvestment(
        name: 'My New FD',
        type: InvestmentType.fixedDeposit,
        notes: 'Test investment notes',
      );

      // Verify investment is now in the list
      investments.verifyInvestmentDisplayed('My New FD');
    });

    testWidgets('should select different investment types', (tester) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);

      await navigation.goToInvestments();
      await investments.openAddInvestment();

      // Verify default type is P2P Lending
      investments.verifyTextDisplayed('P2P Lending');

      // Select Fixed Deposit
      await investments.selectType(InvestmentType.fixedDeposit);

      // Select Bonds
      await investments.selectType(InvestmentType.bonds);

      // Select Real Estate
      await investments.selectType(InvestmentType.realEstate);
    });

    testWidgets('should edit existing investment', (tester) async {
      testApp = await TestApp.create(tester);

      // Seed an investment
      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv_1',
          name: 'Original FD',
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

      // Tap on the investment
      await investments.tapInvestment('Original FD');

      // Open edit screen
      await investments.openEdit();

      // Verify edit screen
      investments.verifyOnEditInvestmentScreen();

      // Update the name
      await investments.clearName();
      await investments.enterName('Updated FD');

      // Save changes
      await investments.tapSave();

      // Verify the updated name is shown
      investments.verifyTextDisplayed('Updated FD');
    });
  });
}
