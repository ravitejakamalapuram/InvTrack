import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screenshot generation test for Play Store assets.
///
/// Run with: flutter test integration_test/screenshots_test.dart
/// Or: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screenshots_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Play Store Screenshots', () {
    Future<void> takeScreenshot(String name) async {
      // Add delay to ensure UI is fully rendered
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        final List<int> bytes = await binding.takeScreenshot(name);

        // Save to temp directory for CI pickup
        final file = File('/tmp/screenshot_$name.png');
        await file.writeAsBytes(bytes);
        debugPrint('📸 Screenshot saved: ${file.path}');
      } catch (e) {
        debugPrint('⚠️ Screenshot failed for $name: $e');
      }
    }

    testWidgets('Generate all store screenshots', (tester) async {
      // Launch the app
      await tester.pumpWidget(
        const ProviderScope(child: InvTrackerApp()),
      );

      // Wait for app to fully load
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Screenshot 1: Dashboard/Overview
      // The app should start on the Overview screen
      await tester.pumpAndSettle();
      await takeScreenshot('01_dashboard');

      // Screenshot 2: Investment List
      // Navigate to Investments tab
      final investmentsTab = find.byIcon(Icons.account_balance_wallet);
      if (investmentsTab.evaluate().isNotEmpty) {
        await tester.tap(investmentsTab);
        await tester.pumpAndSettle();
        await takeScreenshot('02_investment_list');
      }

      // Screenshot 3: Investment Detail
      // Tap first investment if available
      final investmentCards = find.byType(Card);
      if (investmentCards.evaluate().length > 1) {
        await tester.tap(investmentCards.first);
        await tester.pumpAndSettle();
        await takeScreenshot('03_investment_detail');

        // Go back
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }
      }

      // Screenshot 4: Add Investment (FAB)
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab);
        await tester.pumpAndSettle();
        await takeScreenshot('04_add_investment');

        // Close bottom sheet or go back
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }

      // Screenshot 5: Goals
      final goalsTab = find.byIcon(Icons.flag);
      if (goalsTab.evaluate().isNotEmpty) {
        await tester.tap(goalsTab);
        await tester.pumpAndSettle();
        await takeScreenshot('05_goals');
      }

      // Screenshot 6: Settings
      final settingsTab = find.byIcon(Icons.settings);
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab);
        await tester.pumpAndSettle();
        await takeScreenshot('06_settings');
      }

      debugPrint('✅ Screenshot generation complete!');
    });
  });
}

