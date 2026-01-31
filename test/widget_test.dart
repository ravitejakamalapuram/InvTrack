// Basic Flutter widget test for InvTracker app.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/app/app.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/app_update/presentation/providers/version_check_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mock_analytics_service.dart';
import 'mocks/mock_notification_service.dart';

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};

  FakeFlutterSecureStorage() : super();

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
    }
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

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

/// Mock NavigatorObserver that replaces FirebaseAnalyticsObserver in tests
class MockNavigatorObserver extends NavigatorObserver {}

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          flutterSecureStorageProvider.overrideWithValue(
            FakeFlutterSecureStorage(),
          ),
          localAuthProvider.overrideWithValue(MockLocalAuthentication()),
          // Override analytics providers to avoid Firebase initialization
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          analyticsObserverProvider.overrideWithValue(
            FirebaseAnalyticsObserver(
              analytics: _FakeFirebaseAnalytics(),
            ),
          ),
          // Override notification service to avoid plugin initialization
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          // Override version check provider to avoid Firestore dependency
          versionCheckProvider.overrideWith(() {
            return _FakeVersionCheckNotifier();
          }),
        ],
        child: const InvTrackerApp(),
      ),
    );

    // Verify that the app title is displayed (on Sign In screen or Home).
    expect(find.byType(InvTrackerApp), findsOneWidget);
  });
}

/// Fake Firebase Analytics for testing that doesn't require initialization
class _FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

/// Fake VersionCheckNotifier for testing that doesn't require Firestore
class _FakeVersionCheckNotifier extends VersionCheckNotifier {
  @override
  VersionCheckState build() {
    // Return a simple state without checking for updates
    return const VersionCheckState(
      currentVersion: '1.0.0',
      currentBuildNumber: 1,
      hasChecked: true,
    );
  }

  @override
  Future<void> checkForUpdates() async {
    // Do nothing in tests
  }

  @override
  Future<void> dismissUpdate() async {
    // Do nothing in tests
  }
}
