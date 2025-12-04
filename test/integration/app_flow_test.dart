import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/database/app_database.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';

void main() {
  testWidgets('App Flow: Create Portfolio -> Add Investment -> Add Transaction -> Verify Dashboard', (tester) async {
    // 1. Setup Overrides
    SharedPreferences.setMockInitialValues({});
    
    final inMemoryDb = AppDatabase(NativeDatabase.memory());
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
          authStateProvider.overrideWith((ref) => Stream.value(
            const UserEntity(id: 'test_user', email: 'test@example.com', displayName: 'Test User'),
          )),
        ],
        child: const InvTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Navigate to Investments Tab
    await tester.tap(find.byIcon(Icons.show_chart_outlined));
    await tester.pumpAndSettle();

    // 3. Create Default Portfolio
    // App starts with "No Portfolios" empty state.
    final createPortfolioBtn = find.text('Create Default Portfolio');
    expect(createPortfolioBtn, findsOneWidget);
    
    await tester.tap(createPortfolioBtn);
    await tester.pumpAndSettle();

    // 3. Add Investment
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Apple Inc.');
    await tester.enterText(find.byType(TextFormField).at(1), 'AAPL');
    
    // Portfolio is auto-selected now
    
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Investment'));
    await tester.pumpAndSettle();

    // Verify added
    expect(find.text('Apple Inc.'), findsOneWidget);

    // 4. Add Transaction
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Transaction'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '10'); // Quantity
    await tester.enterText(find.byType(TextFormField).at(1), '150.0'); // Price

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Transaction'));
    await tester.pumpAndSettle();

    // 5. Verify Dashboard
    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();
    
    // Verify total value (10 * 150 = 1500)
    expect(find.text('\$1,500.00'), findsOneWidget);
    
    // Cleanup
    await inMemoryDb.close();
  });
}
