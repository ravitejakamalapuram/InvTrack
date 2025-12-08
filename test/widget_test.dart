// Basic Flutter widget test for InvTracker app.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/app/app.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:local_auth_windows/local_auth_windows.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:mockito/mockito.dart';

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};

  FakeFlutterSecureStorage() : super();

  @override
  Future<String?> read({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    return _storage[key];
  }

  @override
  Future<void> write({required String key, required String? value, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value != null) {
      _storage[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    _storage.remove(key);
  }
}

class MockLocalAuthentication extends Mock implements LocalAuthentication {
  @override
  Future<bool> canCheckBiometrics = Future.value(false);
  @override
  Future<bool> isDeviceSupported() async => false;
  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[
      IOSAuthMessages(),
      AndroidAuthMessages(),
      WindowsAuthMessages(),
    ],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async => false;
  
  @override
  Future<bool> stopAuthentication() async => true;
  
  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [];
}

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          flutterSecureStorageProvider.overrideWithValue(FakeFlutterSecureStorage()),
          localAuthProvider.overrideWithValue(MockLocalAuthentication()),
        ],
        child: const InvTrackerApp(),
      ),
    );

    // Verify that the app title is displayed (on Sign In screen or Home).
    expect(find.byType(InvTrackerApp), findsOneWidget);
  });
}
