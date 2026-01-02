/// Test helpers and utilities for integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_investment_repository.dart';
import 'mocks/mock_goal_repository.dart';
import 'mocks/mock_analytics_service.dart';
import 'mocks/mock_notification_service.dart';

/// Test user for authenticated flows
const testUser = UserEntity(
  id: 'test_user_123',
  email: 'test@invtracker.app',
  displayName: 'Test User',
);

/// Creates a ProviderScope with all mocks configured for integration tests
Future<ProviderScope> createTestApp({
  FakeInvestmentRepository? investmentRepository,
  FakeGoalRepository? goalRepository,
  FakeAnalyticsService? analyticsService,
  FakeNotificationService? notificationService,
  UserEntity? user,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();

  final invRepo = investmentRepository ?? FakeInvestmentRepository();
  final goalRepo = goalRepository ?? FakeGoalRepository();
  final analytics = analyticsService ?? FakeAnalyticsService();
  final notifications = notificationService ?? FakeNotificationService();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      authStateProvider.overrideWith(
        (ref) => Stream.value(user ?? testUser),
      ),
      investmentRepositoryProvider.overrideWithValue(invRepo),
      goalRepositoryProvider.overrideWithValue(goalRepo),
      analyticsServiceProvider.overrideWithValue(analytics),
      notificationServiceProvider.overrideWithValue(notifications),
    ],
    child: const InvTrackerApp(),
  );
}

/// Pumps the app and waits for it to settle
Future<void> pumpTestApp(
  WidgetTester tester, {
  FakeInvestmentRepository? investmentRepository,
  FakeGoalRepository? goalRepository,
  Duration settleTimeout = const Duration(seconds: 5),
}) async {
  final app = await createTestApp(
    investmentRepository: investmentRepository,
    goalRepository: goalRepository,
  );

  await tester.pumpWidget(app);
  await tester.pumpAndSettle(settleTimeout);
}

/// Extension for common test interactions
extension WidgetTesterExtensions on WidgetTester {
  /// Navigate to a bottom nav tab by label
  Future<void> navigateToTab(String label) async {
    final tab = find.text(label);
    expect(tab, findsOneWidget, reason: 'Tab "$label" should exist');
    await tap(tab);
    await pumpAndSettle();
  }

  /// Navigate to bottom tab by icon
  Future<void> navigateToTabByIcon(IconData icon) async {
    await tap(find.byIcon(icon));
    await pumpAndSettle();
  }

  /// Tap the FAB (Floating Action Button)
  Future<void> tapFab() async {
    await tap(find.byType(FloatingActionButton).first);
    await pumpAndSettle();
  }

  /// Enter text in a field with given label
  Future<void> enterTextInField(String label, String text) async {
    final field = find.widgetWithText(TextFormField, label);
    if (field.evaluate().isEmpty) {
      // Try finding by looking for TextField with matching label/hint
      final hintField = find.byWidgetPredicate(
        (widget) {
          if (widget is TextField) {
            final decoration = widget.decoration;
            return decoration?.labelText == label ||
                decoration?.hintText == label;
          }
          return false;
        },
      );
      await enterText(hintField.first, text);
    } else {
      await enterText(field.first, text);
    }
    await pumpAndSettle();
  }

  /// Tap a button with given text
  Future<void> tapButton(String text) async {
    final button = find.text(text);
    expect(button, findsOneWidget, reason: 'Button "$text" should exist');
    await tap(button);
    await pumpAndSettle();
  }

  /// Scroll until a widget is visible
  Future<void> scrollToWidget(Finder finder) async {
    await scrollUntilVisible(
      finder,
      500.0,
      scrollable: find.byType(Scrollable).first,
    );
  }

  /// Verify a snackbar with message appears
  Future<void> expectSnackbar(String message) async {
    await pumpAndSettle();
    expect(find.text(message), findsOneWidget);
  }
}

/// Common test data generators
class TestData {
  static DateTime get today => DateTime.now();
  static DateTime get yesterday => today.subtract(const Duration(days: 1));
  static DateTime get lastMonth => today.subtract(const Duration(days: 30));
}

