/// Integration tests for data management flows.
///
/// Tests data export and import functionality including CSV and ZIP formats.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Data Management Screen', () {
    testWidgets('should display all data management sections', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();

      // Navigate to Data Management
      await settings.tapDataManagement();

      // Verify all sections are visible
      settings.verifyOnDataManagementScreen();
      settings.verifyExportSection();
      settings.verifyImportSection();
    });

    testWidgets('should display export options', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();
      await settings.tapDataManagement();

      // Verify export options
      settings.verifyTextDisplayed('Export as CSV');
      settings.verifyTextDisplayed('Spreadsheet format');
      settings.verifyTextDisplayed('Export as ZIP');
      settings.verifyTextDisplayed('Full backup with documents');
    });

    testWidgets('should display import options', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();
      await settings.tapDataManagement();

      // Verify import options
      settings.verifyTextDisplayed('Import from CSV');
      settings.verifyTextDisplayed('Add investments from file');
      settings.verifyTextDisplayed('Import from ZIP');
      settings.verifyTextDisplayed('Restore from backup');
    });

    testWidgets('should display danger zone section', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();
      await settings.tapDataManagement();

      // Scroll to danger zone
      await settings.scrollUntilVisible(find.text('Delete Account'));

      settings.verifyDangerZone();
      settings.verifyTextDisplayed('Permanently delete all data');
    });
  });

  group('Data Management with Seeded Data', () {
    testWidgets('should show export options with investments', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      // Seed some test data
      testApp.seedInvestments([
        InvestmentEntity(
          id: 'inv-1',
          name: 'Test Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ], [
        CashFlowEntity(
          id: 'cf-1',
          investmentId: 'inv-1',
          type: CashFlowType.invest,
          amount: 10000,
          date: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ]);

      testApp.seedGoals([
        GoalEntity(
          id: 'goal-1',
          name: 'Test Goal',
          type: GoalType.targetAmount,
          targetAmount: 100000,
          trackingMode: GoalTrackingMode.all,
          icon: '🎯',
          colorValue: 0xFF4CAF50,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      await testApp.pumpApp();
      await nav.goToSettings();
      await settings.tapDataManagement();

      // Verify export section is available
      settings.verifyExportSection();
      settings.verifyImportSection();
    });
  });

  group('Data Management Screenshots', () {
    testWidgets('capture data management screen', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();
      await settings.tapDataManagement();

      await settings.takeScreenshot('data_management_main');
    });
  });
}

