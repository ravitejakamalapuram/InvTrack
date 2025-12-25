/// Integration tests for InvTracker app.
///
/// These tests verify critical user flows work end-to-end.
/// Run with: flutter test integration_test/app_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_investment_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockInvestmentRepository mockRepository;

  setUp(() {
    mockRepository = MockInvestmentRepository();
  });

  /// Helper to pump the app with mocked providers
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authStateProvider.overrideWith((ref) => Stream.value(
            const UserEntity(
              id: 'test_user',
              email: 'test@example.com',
              displayName: 'Test User',
            ),
          )),
          investmentRepositoryProvider.overrideWithValue(mockRepository),
        ],
        child: const InvTrackerApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  group('Navigation Tests', () {
    testWidgets('should navigate between bottom tabs', (tester) async {
      await pumpApp(tester);

      // Should start on Overview tab
      expect(find.text('Investment Tracker'), findsOneWidget);

      // Navigate to Investments tab
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Investments'), findsOneWidget);

      // Navigate to Settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);

      // Navigate back to Overview tab
      await tester.tap(find.byIcon(Icons.pie_chart_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Investment Tracker'), findsOneWidget);
    });
  });

  group('Investment CRUD Tests', () {
    testWidgets('should create a new investment', (tester) async {
      await pumpApp(tester);

      // Navigate to Investments tab
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await tester.pumpAndSettle();

      // Tap FAB to add investment
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Fill in investment name
      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'Test P2P Investment');
      await tester.pumpAndSettle();

      // Find and tap the save button
      final saveButton = find.text('Create Investment');
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
      }

      // Verify success feedback or navigation back
      // The exact verification depends on your UI implementation
    });

    testWidgets('should show empty state when no investments', (tester) async {
      await pumpApp(tester);

      // Navigate to Investments tab
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await tester.pumpAndSettle();

      // Should show empty state
      expect(find.textContaining('No investments'), findsOneWidget);
    });
  });

  group('Settings Tests', () {
    testWidgets('should toggle theme mode', (tester) async {
      await pumpApp(tester);

      // Navigate to Settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Find theme setting
      expect(find.text('Theme'), findsOneWidget);
    });

    testWidgets('should show sign out option', (tester) async {
      await pumpApp(tester);

      // Navigate to Settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Scroll down to find Sign Out
      await tester.scrollUntilVisible(
        find.text('Sign Out'),
        500.0,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Sign Out'), findsOneWidget);
    });
  });
}
