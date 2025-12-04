import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('create portfolio, add investment, add transaction, verify dashboard',
        (tester) async {
      // Setup Overrides
      SharedPreferences.setMockInitialValues({});
      final sharedPreferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authStateProvider.overrideWith((ref) => Stream.value(
              const UserEntity(id: 'test_user', email: 'test@example.com', displayName: 'Test User'),
            )),
          ],
          child: const InvTrackerApp(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 2. Navigate to Investments Tab (if not already there)
      // Use Icon finder as text might be flaky or hidden
      final investmentsTab = find.byIcon(Icons.show_chart_outlined);
      if (investmentsTab.evaluate().isEmpty) {
         // Maybe we are already there or different icon?
         // Let's try to find the "Investments" title in AppBar
         if (find.text('Investments').evaluate().isEmpty) {
             // If we can't find tab or title, dump tree (simulated by failing with descriptive message)
             // But let's try to tap the tab anyway if found
         }
      }
      
      await tester.tap(find.byIcon(Icons.show_chart_outlined));
      await tester.pumpAndSettle();

      // 3. Add Investment
      // Tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Fill form
      await tester.enterText(find.byType(TextFormField).at(0), 'Apple Inc.'); // Name
      await tester.enterText(find.byType(TextFormField).at(1), 'AAPL'); // Symbol
      // Type is Stock by default
      
      // Save
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Investment'));
      await tester.pumpAndSettle();

      // Verify added
      expect(find.text('Apple Inc.'), findsOneWidget);
      
      // Wait for SnackBar to dismiss
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 4. Add Transaction
      // Tap Investment
      final investmentItem = find.descendant(
        of: find.byType(ListView),
        matching: find.text('Apple Inc.'),
      );
      await tester.tap(investmentItem);
      await tester.pumpAndSettle();

      // Tap Add Transaction FAB
      await tester.tap(find.text('Add Transaction'));
      await tester.pumpAndSettle();

      // Fill form
      // Date is pre-filled
      // Type is BUY by default
      await tester.enterText(find.byType(TextFormField).at(0), '10'); // Quantity
      await tester.enterText(find.byType(TextFormField).at(1), '150.0'); // Price
      await tester.enterText(find.byType(TextFormField).at(2), '5.0'); // Fees
      
      // Save
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      // Verify transaction in list
      expect(find.text('10.0 units'), findsOneWidget);

      // 5. Verify Dashboard
      // Navigate to Dashboard tab
      await tester.tap(find.byIcon(Icons.dashboard));
      await tester.pumpAndSettle();

      // Verify Total Value
      // 10 * 150 = 1500. Fees don't subtract from value, they add to cost basis.
      // Value should be $1,500.00
      expect(find.text('\$1,500.00'), findsOneWidget);
    });
  });
}
