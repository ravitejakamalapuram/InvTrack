/// Patrol Finders E2E tests for InvTrack app.
///
/// These tests use patrol_finders for enhanced widget finding capabilities.
/// Run with: flutter test integration_test/patrol_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_analytics_service.dart';
import 'mocks/mock_goal_repository.dart';
import 'mocks/mock_investment_repository.dart';
import 'mocks/mock_notification_service.dart';

/// Mock for LocalAuthentication
class MockLocalAuthentication extends Mock implements LocalAuthentication {}

/// Fake FlutterSecureStorage for testing
class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};

  FakeFlutterSecureStorage() : super();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }
}

/// Helper to create fresh mocks for each test
FakeInvestmentRepository createFakeInvestmentRepository() =>
    FakeInvestmentRepository();
FakeGoalRepository createFakeGoalRepository() => FakeGoalRepository();
FakeAnalyticsService createFakeAnalyticsService() => FakeAnalyticsService();
FakeNotificationService createFakeNotificationService() =>
    FakeNotificationService();
FakeFlutterSecureStorage createFakeSecureStorage() =>
    FakeFlutterSecureStorage();
MockLocalAuthentication createMockLocalAuth() => MockLocalAuthentication();

/// Helper to pump the app with mocked providers
Future<void> pumpApp(
  PatrolTester $, {
  required FakeInvestmentRepository investmentRepository,
  required FakeGoalRepository goalRepository,
  required FakeAnalyticsService analyticsService,
  required FakeNotificationService notificationService,
  required FakeFlutterSecureStorage secureStorage,
  required MockLocalAuthentication localAuth,
}) async {
  SharedPreferences.setMockInitialValues({'onboarding_complete': true});
  final sharedPreferences = await SharedPreferences.getInstance();

  await $.pumpWidgetAndSettle(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        onboardingCompleteProvider.overrideWith((ref) async => true),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const UserEntity(
              id: 'test_user',
              email: 'test@example.com',
              displayName: 'Test User',
            ),
          ),
        ),
        flutterSecureStorageProvider.overrideWithValue(secureStorage),
        localAuthProvider.overrideWithValue(localAuth),
        investmentRepositoryProvider.overrideWithValue(investmentRepository),
        goalRepositoryProvider.overrideWithValue(goalRepository),
        analyticsServiceProvider.overrideWithValue(analyticsService),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const InvTrackerApp(),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ============ PATROL FINDERS NAVIGATION TESTS ============

  patrolWidgetTest(
    'should navigate between all bottom tabs using Patrol finders',
    ($) async {
      // Create fresh mocks for this test
      final investmentRepository = createFakeInvestmentRepository();
      final goalRepository = createFakeGoalRepository();
      final analyticsService = createFakeAnalyticsService();
      final notificationService = createFakeNotificationService();
      final secureStorage = createFakeSecureStorage();
      final localAuth = createMockLocalAuth();

      await pumpApp(
        $,
        investmentRepository: investmentRepository,
        goalRepository: goalRepository,
        analyticsService: analyticsService,
        notificationService: notificationService,
        secureStorage: secureStorage,
        localAuth: localAuth,
      );

      // Should start on Overview tab - using Patrol's $ finder
      expect($('Overview'), findsWidgets);

      // Navigate to Investments tab using Patrol tap
      await $(Icons.account_balance_wallet_outlined).tap();
      expect($('Investments'), findsWidgets);

      // Navigate to Goals tab
      await $(Icons.flag_outlined).tap();
      expect($('Goals'), findsWidgets);

      // Navigate to Settings tab
      await $(Icons.settings_outlined).tap();
      expect($('Settings'), findsWidgets);

      // Navigate back to Overview tab
      await $(Icons.pie_chart_outline).tap();
      expect($('Overview'), findsWidgets);
    },
  );
}

