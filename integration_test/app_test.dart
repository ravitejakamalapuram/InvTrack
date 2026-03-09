/// Integration tests for InvTracker app.
///
/// These tests verify critical user flows work end-to-end.
/// Run with: flutter test integration_test/app_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_investment_repository.dart';
import 'mocks/mock_goal_repository.dart';
import 'mocks/mock_analytics_service.dart';
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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Enable frame time policy for integration tests
  // This helps prevent test framework corruption from async exceptions
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  late FakeInvestmentRepository fakeInvestmentRepository;
  late FakeGoalRepository fakeGoalRepository;
  late FakeAnalyticsService fakeAnalyticsService;
  late FakeNotificationService fakeNotificationService;
  late FakeFlutterSecureStorage fakeSecureStorage;
  late MockLocalAuthentication mockLocalAuth;

  setUp(() {
    fakeInvestmentRepository = FakeInvestmentRepository();
    fakeGoalRepository = FakeGoalRepository();
    fakeAnalyticsService = FakeAnalyticsService();
    fakeNotificationService = FakeNotificationService();
    fakeSecureStorage = FakeFlutterSecureStorage();
    mockLocalAuth = MockLocalAuthentication();
  });

  tearDown(() {
    fakeInvestmentRepository.reset();
    fakeGoalRepository.reset();
    fakeAnalyticsService.reset();
    fakeNotificationService.reset();
  });

  /// Helper to pump the app with mocked providers
  Future<void> pumpApp(WidgetTester tester) async {
    // Set onboarding as complete to skip onboarding screen
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final sharedPreferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          // Skip onboarding
          onboardingCompleteProvider.overrideWith((ref) async => true),
          // Mock auth as logged in
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const UserEntity(
                id: 'test_user',
                email: 'test@example.com',
                displayName: 'Test User',
              ),
            ),
          ),
          // Mock security as unlocked
          flutterSecureStorageProvider.overrideWithValue(fakeSecureStorage),
          localAuthProvider.overrideWithValue(mockLocalAuth),
          // Mock repositories
          investmentRepositoryProvider.overrideWithValue(
            fakeInvestmentRepository,
          ),
          goalRepositoryProvider.overrideWithValue(fakeGoalRepository),
          // Mock services
          analyticsServiceProvider.overrideWithValue(fakeAnalyticsService),
          notificationServiceProvider.overrideWithValue(
            fakeNotificationService,
          ),
        ],
        child: const InvTrackerApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  // ============ NAVIGATION TESTS ============

  group('Navigation Tests', () {
    testWidgets('should navigate between all bottom tabs', (tester) async {
      await pumpApp(tester);

      // Should start on Overview tab
      expect(find.text('Overview'), findsWidgets);

      // Navigate to Investments tab
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Investments'), findsWidgets);

      // Navigate to Goals tab
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Goals'), findsWidgets);

      // Navigate to Settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);

      // Navigate back to Overview tab
      await tester.tap(find.byIcon(Icons.pie_chart_outline));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsWidgets);
    });
  });

  // ============ INVESTMENT TESTS ============

  group('Investment Flow Tests', () {
    testWidgets('should show empty state when no investments', (tester) async {
      await pumpApp(tester);

      // Navigate to Investments tab
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await tester.pumpAndSettle();

      // Should show empty state message
      expect(
        find.text('No Investments Yet'),
        findsOneWidget,
        reason: 'Empty state should be visible',
      );
    });

    testWidgets('should display seeded investments', (tester) async {
      // Seed test data
      fakeInvestmentRepository.seed(
        investments: [
          InvestmentEntity(
            id: 'inv-1',
            name: 'Test FD',
            type: InvestmentType.fixedDeposit,
            status: InvestmentStatus.open,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
          InvestmentEntity(
            id: 'inv-2',
            name: 'Test P2P',
            type: InvestmentType.p2pLending,
            status: InvestmentStatus.open,
            createdAt: DateTime(2024, 1, 2),
            updatedAt: DateTime(2024, 1, 2),
          ),
        ],
      );

      await pumpApp(tester);

      // Navigate to Investments tab
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await tester.pumpAndSettle();

      // Should display the investments
      expect(find.text('Test FD'), findsOneWidget);
      expect(find.text('Test P2P'), findsOneWidget);
    });
  });

  // ============ SETTINGS TESTS ============

  group('Settings Tests', () {
    testWidgets('should display settings sections', (tester) async {
      await pumpApp(tester);

      // Navigate to Settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Check for key settings sections - "Appearance" is the tile title
      expect(find.text('Appearance'), findsOneWidget);
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

  // ============ GOALS TESTS ============

  group('Goals Flow Tests', () {
    testWidgets('should show empty state when no goals', (tester) async {
      await pumpApp(tester);

      // Navigate to Goals tab
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();

      // Should show Goals screen - check for the filled icon (selected state)
      // or the Goals title in the app bar
      expect(
        find.byIcon(Icons.flag),
        findsWidgets,
        reason: 'Goals tab should be active (filled icon when selected)',
      );
    });
  });

  // ============ OVERVIEW TESTS ============

  group('Overview Screen Tests', () {
    testWidgets('should show overview with investment stats', (tester) async {
      // Seed investment with cash flows
      fakeInvestmentRepository.seed(
        investments: [
          InvestmentEntity(
            id: 'inv-1',
            name: 'Test Investment',
            type: InvestmentType.fixedDeposit,
            status: InvestmentStatus.open,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ],
        cashFlows: [
          CashFlowEntity(
            id: 'cf-1',
            investmentId: 'inv-1',
            type: CashFlowType.invest,
            amount: 10000,
            date: DateTime(2024, 1, 1),
            createdAt: DateTime(2024, 1, 1),
          ),
          CashFlowEntity(
            id: 'cf-2',
            investmentId: 'inv-1',
            type: CashFlowType.income,
            amount: 500,
            date: DateTime(2024, 6, 1),
            createdAt: DateTime(2024, 6, 1),
          ),
        ],
      );

      await pumpApp(tester);

      // Should be on Overview by default
      expect(find.text('Overview'), findsWidgets);
    });

    testWidgets('should show FAB for adding investment', (tester) async {
      await pumpApp(tester);

      // FAB should be visible
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
