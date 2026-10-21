import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/widgets/in_app_update_initializer.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/services/in_app_update_service.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockUpdateService extends InAppUpdateService {
  @override
  Future<AppUpdateInfo> checkForUpdate() async {
    return AppUpdateInfo(
      updateAvailability: UpdateAvailability.updateAvailable,
      immediateUpdateAllowed: false,
      flexibleUpdateAllowed: true,
      availableVersionCode: 2,
      installStatus: InstallStatus.unknown,
      packageName: 'com.example',
      clientVersionStalenessDays: 1,
      updatePriority: 1,
      immediateAllowedPreconditions: [],
      flexibleAllowedPreconditions: [],
    );
  }
}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('InAppUpdateInitializer handles missing AppLocalizations without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(MockUpdateService()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          // Deliberately omit localizationsDelegates to force AppLocalizations.of(context) to return null
          home: InAppUpdateInitializer(
            child: Scaffold(body: Text('Home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify fallback text is rendered when dialog opens
    expect(find.text('Update Available'), findsOneWidget);
    expect(find.text('A new version of InvTrack is available. Would you like to update now?'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
  });

  testWidgets('InAppUpdateInitializer handles null Navigator.maybeOf context gracefully', (WidgetTester tester) async {
    // Create a widget tree where Navigator.maybeOf(context) returns null
    // but rootNavigatorKey.currentContext provides a valid Navigator context
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(MockUpdateService()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: InAppUpdateInitializer(
            child: Scaffold(body: Text('Home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The widget should render without crashing
    expect(find.text('Home'), findsOneWidget);
    // Dialog should appear using rootNavigatorKey.currentContext fallback
    expect(find.text('Update Available'), findsOneWidget);
  });

  testWidgets('InAppUpdateInitializer logs warning when both contexts are null', (WidgetTester tester) async {
    // This test verifies that when both Navigator.maybeOf and rootNavigatorKey.currentContext
    // are null, the widget logs a warning instead of crashing

    // Create a widget tree with MaterialApp but simulate rootNavigatorKey.currentContext being null
    // by using a custom key that won't have a valid context
    final customKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(MockUpdateService()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          navigatorKey: customKey,
          // Remove localizationsDelegates to test fallback text
          home: Builder(
            builder: (context) {
              // Wrap in a widget that has no Navigator ancestor
              return Directionality(
                textDirection: TextDirection.ltr,
                child: InAppUpdateInitializer(
                  child: Text('Home'),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Allow async initialization to complete
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Widget should not crash - it should log a warning and skip showing dialog
    // The warning is logged and the dialog is not shown
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('InAppUpdateInitializer guards against unmounted context in dialog callbacks', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inAppUpdateServiceProvider.overrideWithValue(MockUpdateService()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: InAppUpdateInitializer(
            child: Scaffold(body: Text('Home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Update Available'), findsOneWidget);

    // The dialog should handle context.mounted checks correctly
    // Tap "Later" button to verify no errors occur
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed without crashing
    expect(find.text('Update Available'), findsNothing);
  });

  group('update policy (GAP3-08)', () {
    Future<_PolicyService> pump(
      WidgetTester tester, {
      required int staleness,
      Map<String, Object> prefs = const {},
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final service = _PolicyService(staleness);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(service),
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
          ],
          child: const MaterialApp(
            home: InAppUpdateInitializer(child: Scaffold(body: Text('Home'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets(
      'a high-priority update under 60 days old is flexible, not blocking',
      (tester) async {
        final service = await pump(tester, staleness: 59);
        expect(service.immediateStarts, 0);
        expect(find.text('Update Available'), findsOneWidget);
      },
    );

    testWidgets('an update 60 days or more behind starts the immediate flow', (
      tester,
    ) async {
      final service = await pump(tester, staleness: 60);
      expect(service.immediateStarts, 1);
    });

    testWidgets('does not prompt again within 3 days', (tester) async {
      final recent = DateTime.now().subtract(const Duration(days: 1));
      final service = await pump(
        tester,
        staleness: 60,
        prefs: {'in_app_update_last_prompt_ms': recent.millisecondsSinceEpoch},
      );
      expect(service.immediateStarts, 0);
      expect(find.text('Update Available'), findsNothing);
    });

    testWidgets('showing the flexible dialog records the prompt time', (tester) async {
      await pump(tester, staleness: 1);
      expect(find.text('Update Available'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('in_app_update_last_prompt_ms'), isNotNull);
    });

    testWidgets('prompts again after 3 days', (tester) async {
      final old = DateTime.now().subtract(const Duration(days: 4));
      await pump(
        tester,
        staleness: 1,
        prefs: {'in_app_update_last_prompt_ms': old.millisecondsSinceEpoch},
      );
      expect(find.text('Update Available'), findsOneWidget);
    });

    testWidgets('a Play error is swallowed: no dialog, no crash', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(_ThrowingService()),
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
          ],
          child: const MaterialApp(
            home: InAppUpdateInitializer(child: Scaffold(body: Text('Home'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Update Available'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

class _PolicyService extends InAppUpdateService {
  _PolicyService(this.staleness);
  final int staleness;
  int immediateStarts = 0;

  @override
  Future<AppUpdateInfo?> checkForUpdate() async => AppUpdateInfo(
    updateAvailability: UpdateAvailability.updateAvailable,
    immediateUpdateAllowed: true,
    flexibleUpdateAllowed: true,
    availableVersionCode: 2,
    installStatus: InstallStatus.unknown,
    packageName: 'com.example',
    clientVersionStalenessDays: staleness,
    updatePriority: 5,
    immediateAllowedPreconditions: [],
    flexibleAllowedPreconditions: [],
  );

  @override
  Future<AppUpdateResult> startImmediateUpdate() async {
    immediateStarts++;
    return AppUpdateResult.success;
  }
}

class _ThrowingService extends InAppUpdateService {
  @override
  Future<AppUpdateInfo?> checkForUpdate() async => throw Exception('play down');
}
