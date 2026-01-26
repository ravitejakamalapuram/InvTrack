/// Test app helper for integration tests.
///
/// Provides a clean way to set up the app with mocked dependencies.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_analytics_service.dart';
import 'mocks/mock_goal_repository.dart';
import 'mocks/mock_investment_repository.dart';
import 'mocks/mock_notification_service.dart';

/// Fake implementation of LocalAuthentication for testing.
class FakeLocalAuthentication implements LocalAuthentication {
  bool canCheckBiometricsValue = false;
  bool isDeviceSupportedValue = false;
  bool authenticateResult = false;

  @override
  Future<bool> get canCheckBiometrics async => canCheckBiometricsValue;

  @override
  Future<bool> isDeviceSupported() async => isDeviceSupportedValue;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [];

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    return authenticateResult;
  }

  @override
  Future<bool> stopAuthentication() async => true;
}

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

/// Helper class for setting up the test app with mocked dependencies.
class TestApp {
  final WidgetTester tester;
  final FakeInvestmentRepository investmentRepository;
  final FakeGoalRepository goalRepository;
  final FakeAnalyticsService analyticsService;
  final FakeNotificationService notificationService;
  final FakeFlutterSecureStorage secureStorage;
  final FakeLocalAuthentication localAuth;
  late SharedPreferences sharedPreferences;

  TestApp._({
    required this.tester,
    required this.investmentRepository,
    required this.goalRepository,
    required this.analyticsService,
    required this.notificationService,
    required this.secureStorage,
    required this.localAuth,
  });

  /// Create a new test app instance
  static Future<TestApp> create(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    final app = TestApp._(
      tester: tester,
      investmentRepository: FakeInvestmentRepository(),
      goalRepository: FakeGoalRepository(),
      analyticsService: FakeAnalyticsService(),
      notificationService: FakeNotificationService(),
      secureStorage: FakeFlutterSecureStorage(),
      localAuth: FakeLocalAuthentication(),
    );

    app.sharedPreferences = await SharedPreferences.getInstance();
    return app;
  }

  /// Seed investments for testing
  void seedInvestments(
    List<InvestmentEntity> investments, [
    List<CashFlowEntity>? cashFlows,
  ]) {
    investmentRepository.seed(investments: investments, cashFlows: cashFlows);
  }

  /// Seed goals for testing
  void seedGoals(List<GoalEntity> goals) {
    goalRepository.seed(goals: goals);
  }

  /// Reset all test data
  void reset() {
    investmentRepository.reset();
    goalRepository.reset();
    analyticsService.reset();
    notificationService.reset();
  }

  /// Pump the app with all mocked providers
  Future<void> pumpApp({bool showOnboarding = false}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          onboardingCompleteProvider.overrideWith(
            (ref) async => !showOnboarding,
          ),
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
    // Pump a fixed number of frames to let the UI settle
    // Don't use pumpAndSettle as it can hang on infinite animations
    await pumpFrames(30);
  }

  /// Pump a fixed number of frames
  Future<void> pumpFrames([int frames = 20]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}
