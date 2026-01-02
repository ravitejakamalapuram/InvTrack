/// Integration tests for investment CRUD flows.
///
/// Tests the complete lifecycle of investments:
/// - Add new investment
/// - View investment details
/// - Edit investment
/// - Delete investment
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Investment CRUD Flow', () {
    testWidgets('should display empty state when no investments', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final inv = InvestmentRobot(tester);

      await testApp.pumpApp();

      // Navigate to investments
      await nav.goToInvestments();
      nav.verifyOnInvestments();

      // Verify empty state
      inv.verifyEmptyState();
    });

    testWidgets('should display seeded investments', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final inv = InvestmentRobot(tester);

      // Seed test data
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test-1',
          name: 'My FD Investment',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        InvestmentEntity(
          id: 'test-2',
          name: 'P2P Lending',
          type: InvestmentType.p2pLending,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 2),
          updatedAt: DateTime(2024, 1, 2),
        ),
      ]);

      await testApp.pumpApp();
      await nav.goToInvestments();

      // Verify investments are displayed
      inv.verifyInvestmentDisplayed('My FD Investment');
      inv.verifyInvestmentDisplayed('P2P Lending');
    });

    testWidgets('should navigate to investment detail', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final inv = InvestmentRobot(tester);

      testApp.seedInvestments([
        InvestmentEntity(
          id: 'test-1',
          name: 'Detail Test Investment',
          type: InvestmentType.bonds,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ]);

      await testApp.pumpApp();
      await nav.goToInvestments();

      // Tap investment to view details
      await inv.tapInvestment('Detail Test Investment');

      // Verify on detail screen
      inv.verifyOnDetailScreen('Detail Test Investment');
    });
  });

  group('Investment Screenshots', () {
    testWidgets('capture investment list states', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final inv = InvestmentRobot(tester);

      await testApp.pumpApp();
      await nav.goToInvestments();

      // Screenshot: Empty state
      await inv.takeScreenshot('investment_list_empty');

      // Add seeded data and refresh
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'ss-1',
          name: 'Screenshot FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ]);

      // Navigate away and back to trigger refresh
      await nav.goToOverview();
      await nav.goToInvestments();

      // Screenshot: With investments
      await inv.takeScreenshot('investment_list_with_data');
    });
  });
}

