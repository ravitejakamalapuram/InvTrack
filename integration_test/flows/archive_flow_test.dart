/// Integration tests for archive/unarchive investment flows.
///
/// Tests the swipe-to-archive gesture, archived view, and unarchive functionality.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Archive Investment Flow Tests', () {
    late TestApp testApp;
    late NavigationRobot navigation;
    late InvestmentRobot investments;

    testWidgets('should archive investment from detail screen', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_inv_1',
          name: 'My FD to Archive',
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

      // Tap on investment to go to detail
      await investments.tapInvestment('My FD to Archive');

      // Tap archive button
      await investments.tapArchive();

      // Confirm archive
      await investments.confirmArchive();

      // Wait for navigation back
      await tester.pumpAndSettle();

      // Verify we're back on list and investment is gone from active view
      investments.verifyInvestmentNotDisplayed('My FD to Archive');
    });

    testWidgets('should show archived investment in archived tab',
        (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_active',
          name: 'Active Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
        InvestmentEntity(
          id: 'test_archived',
          name: 'Archived Investment',
          type: InvestmentType.mutualFunds,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
          isArchived: true,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);

      await navigation.goToInvestments();

      // Verify active investment is shown
      investments.verifyInvestmentDisplayed('Active Investment');

      // Verify archived investment is NOT shown in active view
      investments.verifyInvestmentNotDisplayed('Archived Investment');

      // Switch to archived view
      await investments.openArchivedView();

      // Verify archived investment is shown
      investments.verifyInvestmentDisplayed('Archived Investment');

      // Verify active investment is NOT shown in archived view
      investments.verifyInvestmentNotDisplayed('Active Investment');
    });

    testWidgets('should unarchive investment from archived view',
        (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test_archived',
          name: 'Archived FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
          isArchived: true,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      investments = InvestmentRobot(tester);

      await navigation.goToInvestments();

      // Switch to archived view
      await investments.openArchivedView();

      // Tap on archived investment
      await investments.tapInvestment('Archived FD');

      // Tap unarchive button
      await investments.tapUnarchive();

      // Confirm unarchive
      await investments.confirmUnarchive();

      // Wait for navigation
      await tester.pumpAndSettle();

      // Switch back to active view
      await investments.openActiveView();

      // Verify investment is now in active view
      investments.verifyInvestmentDisplayed('Archived FD');
    });
  });
}

